---
name: herdr-delegate
description: 現在の git repo で新規 worktree + herdr workspace を作成し、そこで別の Claude Code セッションを起動して指示を投げるスキル。「別 worktree で並列に作業させて」「delegate to worktree」「別の Claude に〜させて」「新しい workspace で〜」などのリクエスト時、または /delegate-workspace で起動する。
allowed-tools: Bash(herdr worktree create:*), Bash(herdr worktree list:*), Bash(herdr agent start:*), Bash(herdr agent send:*), Bash(herdr agent wait:*), Bash(herdr pane send-keys:*), Bash(herdr pane send-text:*), Bash(herdr pane run:*), Bash(~/.claude/skills/herdr-delegate/scripts/find-parent-workspace.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/find-agent-pane.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/rename-existing-claude.sh:*), Bash(~/.claude/skills/herdr-delegate/scripts/read-pane.sh:*), Bash(gh pr view:*), Bash(git rev-parse:*), Bash(git symbolic-ref:*), Bash(jq:*), Skill
---

# Delegate work to a new herdr workspace

## 目的

現在の git repo で **新しい worktree + herdr workspace を作り、そこで別の Claude Code を起動して指示を投げる**。呼び出し元の workspace は残るので、並列に別作業を進められる。

## 前提

- herdr の pane から呼ばれること (`herdr` CLI と socket が利用可能)
- 現在の cwd が git repo (linked worktree の中でも OK。parent workspace を自動検出する)
- fish の `claude` wrapper を経由せず `herdr agent start claude` から起動するので、MCP 用に `--mcp-config` を明示する

## 引数

ユーザーの依頼から抽出:

- `BRANCH`: 新しく作るブランチ名。kebab-case 推奨(例: `feature/family-relations-parallel`)。未指定なら会話文脈から推測して確認する
- `INSTRUCTION`: 新 Claude に投げる指示文。**単一の完結した指示にする**(小分けの往復は元 session ではなく新 session でやってもらう)
- `BASE` (optional): 分岐元。未指定なら下記フローで自動検出

## 手順

### 1. base branch 決定

以下の順で解決:

1. **`gh pr view --json baseRefName`** で PR base が取れれば採用(PR がある feature branch から派生する時に有効)
2. `git symbolic-ref --short refs/remotes/origin/HEAD` から `origin/` を剥がす
3. どちらも失敗なら `main` を fallback

**重要**: 検出した base の前に `origin/` を付けて `--base` に渡す(remote-tracking を base にする方が確実)。

### 2. parent workspace の検出

linked worktree (`~/.herdr/worktrees/...`) から呼ばれた場合、`herdr worktree create` は
`linked_worktree_source` エラーで拒否される。**必ず parent (non-linked) workspace を明示指定する**。

`scripts/find-parent-workspace.sh` を使う (中で `herdr workspace list | jq ...` を実行):

```bash
# linked worktree でも parent repo root は git common-dir の親から取れる
REPO_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")

PARENT_WS=$(~/.claude/skills/herdr-delegate/scripts/find-parent-workspace.sh "$REPO_ROOT")
# 失敗時は script が exit 1 する。中断してユーザーに
# 「先に該当 repo の workspace を開いてください」と促す
```

script は 2 段でマッチ: (1) `worktree.repo_root == REPO_ROOT` かつ non-linked、
(2) fallback として `label == basename(REPO_ROOT)`。
`herdr workspace list` は workspace によって `worktree` フィールドが null のことがあるので
label fallback が必要。

### 3. worktree + workspace 作成

```bash
herdr worktree create \
  --workspace "$PARENT_WS" \
  --branch "$BRANCH" \
  --base "origin/$BASE" \
  --focus \
  --json > /tmp/herdr-delegate.json

WS_ID=$(jq -r '.result.workspace.workspace_id' /tmp/herdr-delegate.json)
WT_PATH=$(jq -r '.result.worktree.path' /tmp/herdr-delegate.json)
```

- `--workspace "$PARENT_WS"` を明示することで linked worktree 内からでも呼び出せる
- `--focus` を付けているので、この時点で **新 workspace に focus が移る**
- 検証: `[ -n "$WS_ID" ] && [ -n "$WT_PATH" ]`。失敗なら `/tmp/herdr-delegate.json` の中身を報告して中断

### 4. Claude 起動

**罠 1: agent name の衝突**

`herdr agent start` の name は **session-wide global unique**。既に `claude` 名の agent
が別 workspace で動いている場合 `agent_name_taken` エラーになる。呼び出し元 (自分自身) の
agent 名を一時的に別名にリネームして "claude" を空ける。

`scripts/rename-existing-claude.sh` を使う (中で `agent list | jq ...` + `agent rename` を実行):

```bash
~/.claude/skills/herdr-delegate/scripts/rename-existing-claude.sh
```

script は renamed 対象の pane_id を stdout に出す (rename しなかった場合は空出力)。副作用として
「claude」名が空くので、続けて `herdr agent start claude ...` が通せる。

呼び出し元の名前が変わることによる副作用: 呼び出し元 session を name で参照している他の
自動化は影響を受ける可能性あり。通常は pane_id 参照が主流なので実害はほぼ無い。

**罠 2: `-- <argv>` の書き方**

`herdr agent start <name> ... -- <argv...>` の `<argv>` は **実行 binary からのフル argv**。
`-- --mcp-config /path` だけ書くと `--mcp-config` を binary として spawn しようとして
`No viable candidates found in PATH` で失敗する。必ず先頭に binary 名 (`claude`) を含める:

```bash
herdr agent start claude \
  --workspace "$WS_ID" \
  --focus \
  --cwd "$WT_PATH" \
  -- claude --mcp-config "$HOME/.claude/mcp.json"
```

`--cwd` を明示するのは、agent 起動時の cwd が新 worktree ディレクトリになるように保証するため。

### 5. Claude の pane_id を特定 → ready 待ち

`scripts/find-agent-pane.sh` を使う (中で `herdr agent list | jq ...` を実行、最大 5s リトライ):

```bash
TARGET=$(~/.claude/skills/herdr-delegate/scripts/find-agent-pane.sh "$WS_ID")

herdr agent wait "$TARGET" --status idle --timeout 60000
```

- `wait` は idle になるまでブロック(claude が起動 → プロンプト待ちの状態)
- timeout は 60 秒。それを超えるなら env / 認証系の問題を疑って中断報告

### 6. 指示を送信 + Enter で確定

`herdr agent send` は literal text のみ(Enter は付かない)なので、**送信 → send-keys Enter の 2 段**:

```bash
herdr agent send "$TARGET" "$INSTRUCTION"
herdr pane send-keys "$TARGET" Enter
```

指示に改行を含めたい場合は、`INSTRUCTION` 内は `\n` (bash の `$'...\n...'` などで literal newline) を含めても OK。最後の Enter で送信される。

### 7. 送信確認 (Claude が受け取って処理を開始したか)

Enter を送っただけでは「Claude の input buffer に文字が入った」ところまでしか保証できない。
**新 Claude が実際にプロンプトを受け取って処理を開始した (= status が `working` に遷移した)**
ことを確認してから delegate 完了とする:

```bash
herdr agent wait "$TARGET" --status working --timeout 15000
```

- 15 秒待って `working` に遷移しなければ、Enter が届いていない / 入力が queue に残っている
  可能性がある。**まず `herdr pane send-keys "$TARGET" Enter` を 1 回だけ再送**して同じ wait
  を掛け直す。それでもダメなら `~/.claude/skills/herdr-delegate/scripts/read-pane.sh "$TARGET"`
  で pane の見た目を確認してからユーザーに状況を報告する
- `working` に入った時点で「Claude が指示を受理して動き始めた」ことが確定するので、
  ここで delegate 側は手を離してよい。後続 (`idle` / `blocked` への遷移) を待つ必要は無い

### 8. 完了報告

ユーザーに以下を報告:

- **新 workspace ID**: `$WS_ID`
- **worktree path**: `$WT_PATH`
- **branch name**: `$BRANCH`
- **投げた指示の要約**
- 「新 workspace に focus が移りました。この session (元 workspace) に戻るには `prefix + shift + a` などで agent 切替してください」

## 失敗時の後始末

`herdr worktree create` は成功したが後段が失敗した場合、放置すると空の worktree が残る。

- 対処: **ユーザーに確認**した上で `herdr worktree remove --workspace $WS_ID --force` で削除
- **自動削除しない**(ユーザーが手動で救出したいケースがある)

## やってはいけないこと

- **`herdr worktree create` を引数なしで実行しない** — ランダム名の worktree が生成されて掃除が面倒
- **linked worktree 内から `herdr worktree create` を `--workspace` 無しで呼ばない** — `linked_worktree_source` エラーで拒否される。必ず parent (non-linked) workspace の ID を明示する
- **`--force` オプションを worktree remove に安易に付けない** — 未 push の commit が消える
- **`herdr agent start` に `--focus` を付け忘れない** — focus が元 workspace のままだと user が新 Claude を確認できない
- **`herdr agent start ... -- <argv>` の argv 先頭に binary 名 (`claude`) を省略しない** — herdr は argv 先頭を spawn 対象として扱うので、`-- --mcp-config /path` だけ書くと `--mcp-config` を PATH で探して失敗する
- **Enter 送信直後に delegate を完了扱いにしない** — `herdr agent wait --status working` で新 Claude が実際に処理を開始したことを確認してから完了報告する。しないと、Enter が届いてなくても「送った気」になって離れてしまい、user が新 workspace を開いた時に空プロンプトのまま止まっている事故になる
- **`INSTRUCTION` に対話フローを含めない** — 「まず X して次に Y」ではなく「X と Y を一気にやって」の形で 1 メッセージにまとめる。段階的な指示なら、そもそもこのスキルではなく元 session で TDD ワークフローを回した方が良い
