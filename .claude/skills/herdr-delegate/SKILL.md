---
name: herdr-delegate
description: 現在の git repo で新規 worktree + herdr workspace を作成し、そこで別の Claude Code セッションを起動して指示を投げるスキル。「別 worktree で並列に作業させて」「delegate to worktree」「別の Claude に〜させて」「新しい workspace で〜」などのリクエスト時、または /delegate-workspace で起動する。
allowed-tools: Bash(~/.claude/skills/herdr-delegate/scripts/resolve-base.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/fetch-base.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/find-parent-workspace.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/ensure-parent-workspace.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/create-worktree.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/create-workspace-for-new-repo.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/start-claude-agent.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/send-instruction.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/confirm-trust-dialog.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/find-agent-pane.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/rename-existing-claude.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/read-pane.sh:*), Bash(ghq get:*), Skill
---

# Delegate work to a new herdr workspace

## 目的

現在の git repo で **新しい worktree + herdr workspace を作り、そこで別の Claude Code を起動して指示を投げる**。呼び出し元の workspace は残るので、並列に別作業を進められる。

## 前提

- herdr の pane から呼ばれること (`herdr` CLI と socket が利用可能)
- 現在の cwd が git repo (linked worktree の中でも OK。parent workspace を自動検出する)
- `herdr agent start` が新 pane に打ち込むコマンドラインは **pane 内の fish shell 経由で解釈される**。つまり `~/.config/fish/functions/claude.fish` の `claude` wrapper 関数がそのまま効き、`--mcp-config` や (NixOS 上での) `--settings '{"remoteControlAtStartup": true}'` は **wrapper が自動で注入する**。手動で同じフラグを重ねて渡すと argv が壊れて Remote Control が効かなくなる事故があったので(手順 4 参照)、**追加フラグなしで bare `claude` を起動する**のが正解
- このスキルのロジック(jq でのパース、リトライ、エラーハンドリングなど)は全て `scripts/*.sh` に切り出してある。SKILL.md 側では各 script を呼び出すだけで、生の `herdr ...` コマンドや jq を直接組み立てない

## 引数

ユーザーの依頼から抽出:

- `BRANCH`: 新しく作るブランチ名。kebab-case 推奨(例: `feature/family-relations-parallel`)。未指定なら会話文脈から推測して確認する
- `INSTRUCTION`: 新 Claude に投げる指示文。**単一の完結した指示にする**(小分けの往復は元 session ではなく新 session でやってもらう)。書き方は下記「INSTRUCTION の書き方」参照
- `BASE` (optional): 分岐元。未指定なら下記フローで自動検出

### INSTRUCTION の書き方

delegate 先の Claude は **`~/.claude/CLAUDE.shared.md` の「worktree Claude 内の 4 エージェント開発フロー」を読んでいる前提だが、指示文で明示しないと自分でコードを書き始める**(subagent を呼ばない)ことが多い。以下を **INSTRUCTION に必ず含める**:

1. **タスクのゴール** — 何を実装して欲しいか (1-3 文で完結に)
2. **4 エージェントフローに乗せる旨** — 例: 「複数ファイルにまたがる実装なので、`explore` → `implement` → `review` → `qa` のサブエージェントに委譲して進めて。あなた自身はオーケストレーターとして立ち回り、コードは書かない」
   - 1 ファイルの typo 修正など軽微なタスクの場合は「軽微な変更なので 4 エージェントフローは使わず直接やって」と明示する(そうしないと delegated Claude が過剰にサブエージェントを呼ぶ)
3. **PR の作成方針** — 「実装完了したら `create-pr` skill で PR 作成 → `/loop` でレビュー監視 → `pr-fix` で自動対応」まで一貫してやってもらうか、draft 止まりにするか (デジスマなら draft 止まり + `#m3pay-gitlab` レビュー依頼)
4. **スコープ外の扱い** — 「スコープ外の問題を見つけたら別 issue にして」を明示

**悪い例**: `"family-relations の親子関係を追加して"` — これだと delegated Claude が直接ファイルを触り始める

**良い例**:

```
family-relations の親子関係を patient-management-api-go に追加してほしい。

- 複数ファイル (handler / usecase / repository) にまたがるので、explore → implement → review → qa の 4 エージェントフローに乗せて進めて。あなた自身はオーケストレーターとしてサブエージェントに委譲し、直接コードは書かないこと。
- 実装完了したら create-pr で PR を作成 → /loop でレビュー監視 → pr-fix で対応、まで自動で回して。
- スコープ外の問題を見つけたら別 issue を作って main ブランチ側に拾ってもらって。
```

## 手順

### 1. base branch 決定 + fetch

```bash
BASE=$(~/.claude/skills/herdr-delegate/scripts/resolve-base.sh)
~/.claude/skills/herdr-delegate/scripts/fetch-base.sh "$(git rev-parse --show-toplevel)" "$BASE"
```

- `resolve-base.sh` の解決順序: (1) `gh pr view --json baseRefName`、(2) `git symbolic-ref --short refs/remotes/origin/HEAD`、(3) fallback `main`。
- `fetch-base.sh` は `git fetch origin <base> --quiet` を実行して remote-tracking ref を最新化する。`create-worktree.sh` が `origin/<base>` を fork 元に使うので、これを飛ばすと **worktree Claude が PR を merge して origin が進んでいるのに古い base から派生してしまう**(体感で「PR merge 後に delegate したら差分がおかしい」というやつ)。best-effort なので fetch 失敗しても続行する。**この step は絶対に飛ばさない**。
- 別リポに delegate するケース (下記「新規 repo」フロー) は `ensure-parent-workspace.sh` が内部で fetch + pull まで済ませるので、この step 1 の fetch は不要。ただし repo_root の指定を間違えない限り重複実行しても害はない。

### 2. parent workspace の検出 (無ければ作成)

linked worktree (`~/go/src/<host>/<org>/<repo>-wt/...` や `~/.herdr/worktrees/...`) から
呼ばれた場合、`herdr worktree create` は `linked_worktree_source` エラーで拒否される。
**必ず parent (non-linked) workspace を明示指定する**。

```bash
PARENT_WS=$(~/.claude/skills/herdr-delegate/scripts/find-parent-workspace.sh)
# 失敗時は script が exit 1 する。中断してユーザーに
# 「先に該当 repo の workspace を開いてください」と促す
```

`find-parent-workspace.sh` は引数無しなら現在の repo (linked worktree の中でも git common-dir から
親 repo root を自動算出) を対象にする。2 段でマッチ: (1) `worktree.repo_root` が一致かつ non-linked、
(2) fallback として `label == basename(repo_root)`。

#### 別リポで workspace がまだ開かれていないケース

既にローカルに clone 済みだが herdr workspace が無い別リポに delegate したいとき (今の作業リポ ≠ 委譲先) は、
find + refresh + create を一発で済ませる `ensure-parent-workspace.sh` を使うと安全:

```bash
REPO_ROOT=$HOME/go/src/github.com/foo/bar
PARENT_WS=$(~/.claude/skills/herdr-delegate/scripts/ensure-parent-workspace.sh "$REPO_ROOT")
```

script の挙動:

1. **find** — `find-parent-workspace.sh` で既存 workspace を探す。あればその ID を返して終了
2. **無ければ refresh** — 新規作成する前に repo を最新化:
   - `git fetch origin` (常に実行、失敗しても続行)
   - working tree が **clean** の場合のみ `git switch <default>` + `git pull --ff-only`
     (default branch は `symbolic-ref refs/remotes/origin/HEAD` → fallback で `ls-remote --symref` → 最終手段 `main`)
   - **dirty** なら switch/pull は skip し、warn を stderr に流す (ユーザーが元 workspace で作業中の可能性があるため、勝手に branch を切り替えない安全弁)
3. **workspace 作成** — `herdr workspace create --cwd $REPO_ROOT --label $(basename ...) --no-focus` (出力は既定で JSON。`--json` は廃止済みで付けるとエラー)
4. **新 workspace_id を stdout に返す**

`ensure-parent-workspace.sh` が exit 1 するのは `$REPO_ROOT` が git repo でない / herdr が使えないなどの根本的な問題のとき。中断してユーザーに状況を報告する。

**未 clone の完全新規 repo** の場合は下の「新規 repo に対して使う場合」参照 (`ghq get` + `create-workspace-for-new-repo.sh` フロー)。

### 3. worktree + workspace 作成

```bash
eval "$(~/.claude/skills/herdr-delegate/scripts/create-worktree.sh "$PARENT_WS" "$BRANCH" "$BASE")"
# => WS_ID / WT_PATH / PANE_ID がセットされる
```

- `create-worktree.sh` は内部で `--focus` を付けない(呼び出し元の focus を奪わないため。新 workspace は裏で作られるだけで画面は切り替わらない)
- script が非ゼロ終了した場合、stderr に生の JSON を出すのでそれを報告して中断する

### 4. Claude 起動

```bash
~/.claude/skills/herdr-delegate/scripts/start-claude-agent.sh "$PANE_ID"
```

このひとつの呼び出しで以下を順番にやっている(詳細はスクリプト内コメント参照):

- **agent name の衝突回避**: `herdr agent start` の name は session-wide global unique。呼び出し元 (自分自身) が
  既に `claude` を名乗っている場合 `agent_name_taken` になるので、先に `rename-existing-claude.sh` で
  一時的に別名へ逃がしてから "claude" を空ける。ただし `herdr agent list` が保持者を `.name` 付きで返さない
  ことがあり、これは空振りしうる。そこで `agent_name_taken` のエラー文にある `pane_id=` を見て、対象 pane 自身なら
  (前の試行で起動済みなので) 成功扱い、別 pane ならその agent を改名して再試行する
- **`herdr agent start claude --kind claude --pane "$PANE_ID"`** で起動。`--workspace`/`--cwd` オプションは
  現行 CLI に存在しない(旧仕様の名残りで書くと `unknown option` エラー)。`--kind claude` の時点で
  「pane に打ち込むコマンド = canonical executable (`claude`)」が決まっているので、**それ以上フラグを足さない**。
  fish 側の `claude` wrapper が `--mcp-config`/`--settings` を自動注入するため、二重に渡すと pane に
  `claude claude --mcp-config ...` という壊れたコマンドが打ち込まれ、Remote Control が効かなくなる
  (実際に発生した事故)
- `herdr worktree create` 直後は新 pane のシェルがまだ初期化中で `agent_pane_busy` になることがある。
  しかも `herdr agent start` はこのエラー時も **exit code が 0 になることがある**ため、`$?` を信用せず
  JSON 出力の `.error` を直接見て判定している。`agent_pane_busy` なら 1 秒間隔で最大 5 回リトライする
- 起動確認後は `herdr agent wait --until idle --timeout 60000` で idle まで待つ。60 秒を超えるなら
  env / 認証系の問題を疑って中断報告

### 5. 指示を送信 + 送信確認

```bash
~/.claude/skills/herdr-delegate/scripts/send-instruction.sh "$PANE_ID" "$INSTRUCTION"
```

`herdr agent send` というサブコマンドは存在しない(似た名前の `agent send-keys` は literal key を
打つだけで Enter や送信確定はしない)。指示を投げて確定させるには **`herdr agent prompt <target> <text>
--wait --until working --timeout ...`** を使う。これは送信 (Enter 相当) と「実際に処理が始まった
(`working` に遷移した) ことの確認」を 1 コマンドでやってくれる。`send-instruction.sh` はこれをラップし、
`working` に遷移しなければ pane の内容を stderr に出して exit 1 する(その出力をそのままユーザーに報告する)。

指示に改行を含めたい場合は、`INSTRUCTION` 内に literal newline (`$'...\n...'`) を含めても OK。

### 6. 完了報告

ユーザーに以下を報告:

- **新 workspace ID**: `$WS_ID`
- **worktree path**: `$WT_PATH`
- **branch name**: `$BRANCH`
- **投げた指示の要約**
- focus は元 workspace のまま(切り替わっていない)。新 workspace を見たくなったら agent 切替 (`prefix + shift + a` など) で `$WS_ID` / pane を選んでください

## 現在の repo ではなく、新規 repo に対して使う場合

このスキル本来の対象は「今いる git repo に worktree を足す」ケースだが、**まだローカルに無い/herdr が
把握していない全くの新規 repo** に対して同じような delegate をしたい時は手順 2-3 を以下に置き換える:

```bash
ghq get "$URL"
CWD="$(ghq root)/$(ghq list -e "$URL")"   # 実際には ghq get の出力から clone 先パスを特定する
eval "$(~/.claude/skills/herdr-delegate/scripts/create-workspace-for-new-repo.sh "$CWD" "$LABEL")"
# => WS_ID / PANE_ID がセットされる (worktree.path に相当するものは無いので WT_PATH は $CWD を使う)
```

手順 4 (`start-claude-agent.sh`) の直後に、trust ダイアログの確認を挟む:

```bash
~/.claude/skills/herdr-delegate/scripts/start-claude-agent.sh "$PANE_ID"
~/.claude/skills/herdr-delegate/scripts/confirm-trust-dialog.sh "$PANE_ID"
~/.claude/skills/herdr-delegate/scripts/send-instruction.sh "$PANE_ID" "$INSTRUCTION"
```

新規 repo は Claude Code にとって未信頼フォルダなので、起動直後に
`No, exit` / `Yes, I trust this folder` の trust ダイアログが出る (現行の Claude Code は **既定の選択が `No, exit`**)。このダイアログは通常のプロンプト
ではないので、確認せずに `send-instruction.sh` を呼ぶと指示がダイアログに向かって空振りする。
`confirm-trust-dialog.sh` はダイアログが出ていれば `down` でカーソルを `Yes, I trust this folder` に移し、選択されたことを画面で確かめてから `enter` で確定して idle まで再待機し (素の Enter だと `No, exit` で Claude が終了する。キー名は小文字の `down`/`enter`)、
出ていなければ何もせず exit 0 する(既存 repo への worktree はこのダイアログが出ない = 親 repo の
信頼を引き継ぐので、通常フローでは呼ばなくてよい)。

## 失敗時の後始末

`herdr worktree create` は成功したが後段が失敗した場合、放置すると空の worktree が残る。

- 対処: **ユーザーに確認**した上で `~/.claude/skills/herdr-delegate/scripts/remove-worktree.sh "$WS_ID"` で削除
- この script は意図的に allowed-tools に入れていない(=毎回パーミッションプロンプトが出る)。**自動削除しない**(ユーザーが手動で救出したいケースがある)

## やってはいけないこと

- **`fetch-base.sh` を飛ばして `create-worktree.sh` に進まない** — `create-worktree.sh` は `--base "origin/$base"` で remote-tracking ref を fork 元にする。`git fetch` を挟まないと、他 session で merge された PR 分だけ origin/$base が遅れて、新 worktree が古い base から派生する。過去に「delegate 直後の diff がおかしい」トラブルの原因になった (2026-08-13)。best-effort とはいえ **必ず step 1 の `fetch-base.sh` を通す**
- **`herdr worktree create` を引数なしで実行しない** — ランダム名の worktree が生成されて掃除が面倒。必ず `create-worktree.sh` 経由で branch/base を明示する
- **linked worktree 内から parent workspace を省略しない** — `find-parent-workspace.sh` は自動検出するが、失敗したらユーザーに「先に該当 repo の workspace を開いてください」と確認する。決め打ちで別の workspace を使わない
- **`remove-worktree.sh` を確認なしで実行しない** — `--force` 付きなので未 push の commit が消える
- **`create-worktree.sh` / `start-claude-agent.sh` の裏にある `--focus` を付けない改造をしない** — 付けると呼び出し元の画面が新 workspace に奪われ、作業のノイズになる。この skill は「裏で静かに作って投げる」ことが目的
- **`start-claude-agent.sh` の後に `-- claude --mcp-config ... --settings ...` のような手動フラグを追加しない** — `--kind claude` の時点で canonical executable が決まっており、かつ pane 内 fish shell の `claude` wrapper が `--mcp-config`/`--settings` を自動注入する。手動で重ねると pane に `claude claude --mcp-config ...` という二重コマンドが打ち込まれ、argv が壊れて Remote Control が効かなくなる(実際に発生した事故)
- **`send-instruction.sh` の代わりに `herdr agent send-keys` で直接文字を打って delegate を完了扱いにしない** — `send-keys` は literal key を打つだけで送信確定や状態確認をしない。`send-instruction.sh` (`herdr agent prompt --wait --until working`) は実際に `working` へ遷移したことを確認してから成功扱いにする設計。確認せずに離れると、user が新 workspace を開いた時に空プロンプトのまま止まっている事故になる
- **`herdr agent start` の成功判定を `$?` だけに頼らない** — `agent_pane_busy` (worktree 作成直後の pane 初期化中) のようなエラーでも exit code 0 で返ってくることがある。JSON 出力の `.error` を jq で見て判定する(`start-claude-agent.sh` 参照)
- **`INSTRUCTION` に対話フローを含めない** — 「まず X して次に Y」ではなく「X と Y を一気にやって」の形で 1 メッセージにまとめる。段階的な指示なら、そもそもこのスキルではなく元 session で TDD ワークフローを回した方が良い
- **`INSTRUCTION` に「4 エージェントフローで進めて」と明記しないまま複雑タスクを投げない** — delegated Claude は shared CLAUDE.md でフローを知っているが、明示しないと自分で書き始める。「引数 > INSTRUCTION の書き方」の 4 項目を必ず含める
