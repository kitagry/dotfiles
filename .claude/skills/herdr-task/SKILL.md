---
name: herdr-task
description: タスク単位で herdr workspace を作り、関係する repo の git worktree を tab として並べ、コーディネーター Claude と各 repo の実装 Claude を起動して指示を投げるスキル。「タスクを始めて」「bqls と bqls.nvim をまたいで〜」「複数 repo で〜」「worktree で並列に作業させて」「delegate して」などのリクエスト時、または /herdr-task で起動する。repo が1つだけのタスクにも使う。
allowed-tools: Bash(~/.claude/skills/herdr-task/scripts/task-create.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-add-repo.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-adopt.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-status.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-ask.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-reply.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-list.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-loop.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-report.sh:*), Bash(~/.claude/skills/herdr-task/scripts/start-claude-agent.sh:*), Bash(~/.claude/skills/herdr-task/scripts/send-instruction.sh:*), Bash(~/.claude/skills/herdr-task/scripts/read-pane.sh:*), Bash(ghq get:*), Bash(ghq list:*)
---

# Task workspace on herdr

## 構成

1 タスク = 1 herdr workspace。repo の worktree はその中の tab として並べる。

```
~/tasks/<task>/              ← workspace "<task>" / tab "task" (コーディネーター Claude)
  TASK.md                    ← ゴール・repo 一覧・repo をまたぐ決定事項・merge 順
  bqls/                      ← tab "bqls"      (branch: <task>)
  bqls.nvim/                 ← tab "bqls.nvim" (branch: <task>)
  bqls-2/                    ← tab "bqls-2"    (同じ repo の2本目, branch: <task>-2)
```

- 全 tab の shell に `HERDR_TASK` / `HERDR_TASK_DIR` が入る
- worktree は `herdr worktree create` ではなく `git worktree add` で作る(herdr の worktree 機能は 1 workspace = 1 checkout 前提で、tab に並べられないため)。そのため herdr の `remove_worktree` キーバインドは使えず、片付けは `task-close.sh` で行う
- **trust**: Claude Code は trust 済みディレクトリの配下ではダイアログを出さない。`~/tasks` を一度 trust しておけば、task ディレクトリも worktree もダイアログなしで起動できる (下記「初回セットアップ」)
- `~/tasks` は ghq 配下ではないので、path ベースのルール (`**/<org>/**` など) は worktree に効かない
- スクリプトは全て `scripts/` にある。SKILL.md の手順では生の `herdr` / `git worktree` / jq を組み立てず、スクリプトを呼ぶ

## 誰と誰が話すか

```
人間 ⇄ master Claude (dotfiles などで開いているオーケストレーター)
          │ ↓ task-ask.sh / task-reply.sh / task-list.sh     ↑ task-report.sh ("[<task>] ...")
          ▼
       tab "task" の Claude (コーディネーター。task-create.sh が起動する)
          │ ↓ send-instruction.sh / read-pane.sh             ↑ task-report.sh ("[<tab label>] ...")
          ▼
       各 repo の tab の Claude (実装担当)
```

- 人間は基本的に master と話す。master はタスクの状況を `task-list.sh` / `task-reply.sh` で見て、指示や質問は `task-ask.sh` でコーディネーターに渡す
- 人間が tab "task" を直接見て話しかけることもある。master からのメッセージには `[master]` が付くので、コーディネーターはどちらからか区別できる
- master は repo の tab の Claude に直接指示しない。コーディネーターを通す (TASK.md の決定事項とずれないように)
- **節目は下から上へ報告する** (`task-report.sh "<メッセージ>"`)。tab の中で実行すると、repo の tab からはコーディネーターへ、tab "task" からは master へ届く。master の pane は `~/tasks/.master` に登録しておく (master が自分の pane で `task-report.sh --register-master` を1回実行)
- **聞かれるまで待たない**。コーディネーターは `/loop` (`task-loop.sh`) で自分の tab を定期チェックし、master も定期実行 (CronCreate、15 分ごと程度) で `task-list.sh` / `task-reply.sh` を見回って、要対応や節目の変化だけを人間に報告する

## 初回セットアップ (マシンごとに1回)

`~/tasks` が trust されていないと `task-create.sh` が止まって案内を出す。ユーザーに次を実行してもらい、`Yes, I trust this folder` を選んで終了してもらう:

```
! mkdir -p ~/tasks && cd ~/tasks && claude
```

`~/.claude.json` をスクリプトで書き換えて trust しない。起動中の Claude セッションも同じファイルを書き換えているので、上書きし合う。

## タスクの粒度 (オーケストレーターが判断する)

タスク = ユーザーが頭を切り替える単位。issue や依頼を受けたら、ユーザーに聞かずに次で振り分ける:

- **独立したタスク** — repo をまたぐ、設計判断がいる、PR が複数になる、のどれかに当たる大きめの作業。1つの作業 = 1つのタスク
- **テーマのまとめタスク** — 小さい issue や、同じ変更を複数の repo に入れる作業。テーマ (例: `ci-maintenance`、`deps-bump`) ごとに1つのタスクを長く使い、issue ごとに tab を足していく
  - `herdr workspace list` の label と各タスクの TASK.md の Goal を見て、合うテーマがあればそこに足す。無ければ新しく作る
  - tab の label は `<repo>#<issue番号>`、branch は issue に合わせた名前 (例: `fix/671-goreleaser-tags`) を `--label` / `--branch` で渡す
  - PR が merge された tab は `task-remove-repo.sh` で1つずつ片付ける。タスク自体は残す

まとめタスクの TASK.md は、`## Goal` にテーマを書き、`## Repos` を issue の一覧として使う (コーディネーターが行末に PR と状態を追記する)。片付けた tab は `## Done` に移る。

## 引数

ユーザーの依頼から抽出する:

- `TASK`: タスク名。branch 名と herdr label を兼ねるので `^[a-z0-9][a-z0-9._-]*$` (例: `bqls-dry-run-command`)。未指定なら依頼から作って確認する
- `REPOS`: 関係する repo のローカルパス。ghq 管理なら `$(ghq root)/github.com/<org>/<repo>`。未 clone なら先に `ghq get <url>`
- `GOAL`: タスクのゴール。TASK.md とコーディネーターへの指示に使う
- `BASE` (optional): repo ごとの分岐元。省略時はその repo の `origin/HEAD`

## 手順

### 1. タスクを作る

```bash
eval "$(~/.claude/skills/herdr-task/scripts/task-create.sh "$TASK")"
# => WS_ID / PANE_ID (tab "task" の pane) / TASK_DIR
```

- tab "task" ではコーディネーターの Claude (agent 名 `<task>-task`) まで起動される。起動に失敗しても WARN を出して続行するので、その場合は手順 4 の `start-claude-agent.sh` で起動し直す
- 同名のディレクトリか workspace が既にあれば exit 1 する。既存タスクに repo を足したいだけなら手順 2 から始める

### 2. repo を足す (repo ごとに繰り返す)

```bash
eval "$(~/.claude/skills/herdr-task/scripts/task-add-repo.sh "$TASK" "$REPO" [--base BASE] [--branch BRANCH] [--label LABEL])"
# => TAB_ID / PANE_ID / WT_PATH / BRANCH
```

- `git fetch origin <base>` → `git worktree add --no-track -b <branch> <task_dir>/<dir> origin/<base>` → tab を作成し、TASK.md の `## Repos` に1行追記する
- `--label` を省略すると `<repo>`、2本目以降は `<repo>-2` のように連番。`--branch` を省略すると `<task>`、`<task>-2`
- `--label` を指定すると tab 名はその label、ディレクトリ名は記号を `-` に置き換えたもの (`bqls#671` → `bqls-671/`)。指定した label / branch が既にあれば連番にせず exit 1 する
- `REPO` に linked worktree のパスを渡しても、その main repo から worktree を作る
- **元の repo が trust されていなければ exit 1 する**。`~/tasks` 配下に置くと trust ダイアログが出ないので、ダイアログが担っていた「知らない repo の `.claude/settings.json` の hooks や `.mcp.json` を確認なしに読み込まない」チェックをここで代わりに行っている。止まったら、ユーザーにその repo の中身を確認してもらい、`cd <repo> && claude` で trust してもらう
- branch は upstream なしで作られる。初回 push は `git push -u origin HEAD`

### 2'. 既存のディレクトリを取り込む (移動しない)

すでに作業中のディレクトリ (repo 本体の checkout、別の場所にある linked worktree、git でないメモのディレクトリなど) を、そのままタスクの tab にしたいとき:

```bash
eval "$(~/.claude/skills/herdr-task/scripts/task-adopt.sh "$TASK" "$PATH_TO_DIR" [LABEL])"
# => TAB_ID / PANE_ID
```

- `~/tasks/<task>/` には移動しない。Claude Code の会話履歴は cwd ごとに保存されるので、移動すると `claude --continue` で続きを再開できなくなるため
- 取り込んだパスは `~/tasks/<task>/.adopted` に記録される。`task-status.sh` には `adopted:` 付きで表示され、`task-close.sh` は**削除しない** (tab を閉じるだけ)
- そのパス (linked worktree なら main repo) が trust されていなければ exit 1 する
- 前回の Claude の会話の続きから再開するなら、`start-claude-agent.sh "$PANE_ID" "$TASK-<label>" --continue`。ただし**同じディレクトリで古い Claude がまだ動いているなら、先にその workspace を閉じてから**起動する

### 3. TASK.md の Goal を書く

`$TASK_DIR/TASK.md` の `## Goal` にゴールを書く。repo をまたぐ決定事項 (command 名、API の形など) が既に分かっていれば `## Decisions` にも書く。

### 4. Claude を起動して指示を送る

コーディネーターには `task-ask.sh` で最初の指示 (下記) を送る:

```bash
~/.claude/skills/herdr-task/scripts/task-ask.sh "$TASK" "$INSTRUCTION" --no-wait
~/.claude/skills/herdr-task/scripts/task-loop.sh "$TASK" [10m]   # コーディネーターに定期チェックの /loop を仕込む
```

- `task-loop.sh` は `/loop <interval> <定期チェックの指示>` をそのまま送る (`[master]` を付けるとスラッシュコマンドとして解釈されないので task-ask.sh は使わない)。全 tab の PR が merge されたらコーディネーター自身が loop を止める
- master 側の定期チェックがまだ無ければ、CronCreate で仕込む (前回の返答を scratchpad に保存して差分だけ見る。報告は「確認したいこと」/ blocked / merge などの節目だけ)

repo の tab の Claude は、コーディネーターに起動・指示させるのが基本。master や自分で起動するときは:

```bash
~/.claude/skills/herdr-task/scripts/start-claude-agent.sh "$PANE_ID" "$TASK-<tab label>"
~/.claude/skills/herdr-task/scripts/send-instruction.sh "$PANE_ID" "$INSTRUCTION"
```

- agent 名は session 全体で一意である必要があるので `<task>-<tab label>` にする (例: `bqls-dry-run-command-task`、`bqls-dry-run-command-bqls`)
- `start-claude-agent.sh` は idle になるまで待つ。trust ダイアログが出たら自動では答えず exit 1 する (trust するかどうかはユーザーが判断することなので)
- `send-instruction.sh` は起動直後に入力が取りこぼされるケースを、画面に指示文が出ていないことを確かめた上で再送する。二重送信はしない

#### コーディネーターへの指示

```
タスク <TASK> のコーディネーターをお願いします。TASK.md を読んでください。

- 各 repo の tab の Claude を herdr-task スキルの start-claude-agent.sh で起動し、send-instruction.sh で指示を出して。進み具合は read-pane.sh で確認して。
- repo をまたぐ決定事項 (インターフェイス、merge 順) と各 tab の状況 (PR、状態) は TASK.md に書いて。
- 別の repo や issue が必要になったら task-add-repo.sh で足して。
- [master] が付いたメッセージは master Claude 経由の人間の指示。付いていなければ人間がこの tab で直接話している。
- 人間に確認したいことは、返答の最後に「確認したいこと」として書いて (master が人間に聞く)。
- 返答の最後には、毎回タスク全体の状況を数行で要約して。
- 節目 (tab の PR が merge された、全 tab が終わった、人間の判断が要る、詰まった) では task-report.sh で master に報告して。各 tab の Claude にも、同じ節目で task-report.sh であなたに報告するよう指示に含めて。
- スコープ外の問題を見つけたら別 issue にして。
```

#### 各 repo の実装担当への指示

repo 単体で完結する形にする:

1. **ゴール** — この repo で何を実装するか (1-3 文)
2. **TASK.md の参照** — `$HERDR_TASK_DIR/TASK.md` の Decisions に従うこと
3. **PR 方針** — 「PR 作成 → `/loop` でレビュー監視 → `pr-fix` で対応」まで回すか、draft 止まりか。他 repo の merge を待つ必要があれば draft にする
4. **報告** — 「PR を作った、merge された、レビューで人間の判断が要る、詰まった、のどれかになったら herdr-task スキルの task-report.sh でコーディネーターに報告して」
5. **スコープ外** — 「スコープ外の問題を見つけたら別 issue にして」

### 5. 完了報告

ユーザーに以下を報告する:

- workspace (`$TASK`、`$WS_ID`) と tab の一覧 (label / branch / worktree path)
- 各 tab に投げた指示の要約
- focus は元の workspace のまま。見るときは workspace picker (`prefix+w`) で `$TASK` を選ぶ

## 状態確認と片付け

master がタスクの様子を見るとき:

```bash
~/.claude/skills/herdr-task/scripts/task-list.sh                 # 全タスク: <task> <ws> coordinator=<状態> <repo tabs>
~/.claude/skills/herdr-task/scripts/task-reply.sh "$TASK"        # コーディネーターの状態と最新の返答
~/.claude/skills/herdr-task/scripts/task-ask.sh "$TASK" "<質問>"  # 質問して返答を待つ (既定 600 秒)
```

- `task-ask.sh` の返答は Claude Code の会話ログ (`~/.claude/projects/*/<session>.jsonl`) から読む。画面の読み取りではないので、長い返答も欠けない
- 終了コード: 0 返答あり / 3 タイムアウト (指示は届いているので後で `task-reply.sh`) / 4 tab "task" で権限確認や質問が出て止まっている (人間に tab を見てもらう)
- コーディネーターが作業中なら `task-ask.sh` は拒否する。待たずに積むなら `--no-wait`

worktree の状態を見るとき:

```bash
~/.claude/skills/herdr-task/scripts/task-status.sh "$TASK"
# <name> <branch> dirty=<N> unpushed=<N>   (どれかが 0 でなければ exit 1)
```

tab を1つだけ片付ける (まとめタスクで issue の PR が merge されたときなど)。ユーザーに確認した上で:

```bash
~/.claude/skills/herdr-task/scripts/task-remove-repo.sh "$TASK" "$LABEL"          # dirty / unpushed があれば拒否
~/.claude/skills/herdr-task/scripts/task-remove-repo.sh "$TASK" "$LABEL" --force  # 未コミットの変更を捨てて削除
```

- tab を閉じる → worktree を削除 (branch は残す) → TASK.md の行を `## Done` に移す → sidebar の `$repos` を更新
- adopt した tab なら、tab を閉じて `.adopted` から外すだけ。ディレクトリには触らない

タスク全体を閉じる (PR が全部 merge されたら)。ユーザーに確認した上で:

```bash
~/.claude/skills/herdr-task/scripts/task-close.sh "$TASK"          # dirty / unpushed があれば拒否
~/.claude/skills/herdr-task/scripts/task-close.sh "$TASK" --force  # 未コミットの変更を捨てて削除
```

- workspace を close → worktree を削除 → 残ったディレクトリ (TASK.md など) を `~/tasks/_archive/<task>` に移す。adopt したディレクトリはそのまま残る
- local branch は消さない (未 merge の commit を後から救出できるように)
- `task-remove-repo.sh` と `task-close.sh` は allowed-tools に入れていない。毎回パーミッション確認が出る。**ユーザーの確認なしに実行しない**

## やってはいけないこと

- **`herdr worktree create` でタスクの repo を足さない** — 別 workspace ができてしまい、タスクの tab に並ばない。必ず `task-add-repo.sh` を使う
- **`task-add-repo.sh` の fetch を飛ばすような手作業の `git worktree add` をしない** — 他の session で merge された PR が origin/<base> に反映されず、古い base から派生する
- **`start-claude-agent.sh` に `--mcp-config` / `--settings` を足さない** — pane の fish の `claude` wrapper が注入済みで、二重に渡すと Remote Control が効かなくなる
- **`herdr agent send-keys` で指示を打って完了扱いにしない** — 送信確定も状態確認もしない。`send-instruction.sh` を使う
- **`--focus` を付けない** — 呼び出し元の画面を奪わない
- **`task-remove-repo.sh` / `task-close.sh` を確認なしで実行しない**
- **小さい issue ごとに独立したタスクを作らない** — テーマのまとめタスクに tab として足す
- **trust ダイアログをキー操作で通過させない / `~/.claude.json` を書き換えて trust しない** — trust の判断はユーザーがする
