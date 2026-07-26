---
name: herdr-delegate
description: 現在の git repo で新規 worktree + herdr workspace を作成し、そこで別の Claude Code セッションを起動して指示を投げるスキル。「別 worktree で並列に作業させて」「delegate to worktree」「別の Claude に〜させて」「新しい workspace で〜」などのリクエスト時、または /delegate-workspace で起動する。
allowed-tools: Bash(herdr worktree create:*), Bash(herdr worktree list:*), Bash(herdr agent start:*), Bash(herdr agent send:*), Bash(herdr agent wait:*), Bash(herdr agent list:*), Bash(herdr pane send-keys:*), Bash(herdr pane send-text:*), Bash(herdr pane run:*), Bash(gh pr view:*), Bash(git rev-parse:*), Bash(git symbolic-ref:*), Bash(jq:*), Skill
---

# Delegate work to a new herdr workspace

## 目的

現在の git repo で **新しい worktree + herdr workspace を作り、そこで別の Claude Code を起動して指示を投げる**。呼び出し元の workspace は残るので、並列に別作業を進められる。

## 前提

- herdr の pane から呼ばれること (`herdr` CLI と socket が利用可能)
- 現在の cwd が git repo(worktree base として使う)
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

### 2. worktree + workspace 作成

```bash
herdr worktree create --branch "$BRANCH" --base "origin/$BASE" --focus --json > /tmp/herdr-delegate.json
WS_ID=$(jq -r '.result.workspace.workspace_id' /tmp/herdr-delegate.json)
WT_PATH=$(jq -r '.result.worktree.path' /tmp/herdr-delegate.json)
```

- `--focus` を付けているので、この時点で **新 workspace に focus が移る**
- 検証: `[ -n "$WS_ID" ] && [ -n "$WT_PATH" ]`。失敗なら `/tmp/herdr-delegate.json` の中身を報告して中断

### 3. Claude 起動

```bash
herdr agent start claude --workspace "$WS_ID" --focus --cwd "$WT_PATH" -- --mcp-config "$HOME/.claude/mcp.json"
```

`--cwd` を明示するのは、agent 起動時の cwd が新 worktree ディレクトリになるように保証するため。

### 4. Claude の pane_id を特定 → ready 待ち

```bash
sleep 2   # agent list に載るまでの猶予
TARGET=$(herdr agent list \
  | jq -r --arg ws "$WS_ID" '.result.agents[] | select(.workspace_id==$ws and .agent=="claude") | .pane_id' \
  | head -1)

herdr agent wait "$TARGET" --status idle --timeout 60000
```

- `wait` は idle になるまでブロック(claude が起動 → プロンプト待ちの状態)
- timeout は 60 秒。それを超えるなら env / 認証系の問題を疑って中断報告

### 5. 指示を送信 + Enter で確定

`herdr agent send` は literal text のみ(Enter は付かない)なので、**送信 → send-keys Enter の 2 段**:

```bash
herdr agent send "$TARGET" "$INSTRUCTION"
herdr pane send-keys "$TARGET" Enter
```

指示に改行を含めたい場合は、`INSTRUCTION` 内は `\n` (bash の `$'...\n...'` などで literal newline) を含めても OK。最後の Enter で送信される。

### 6. 完了報告

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
- **`--force` オプションを worktree remove に安易に付けない** — 未 push の commit が消える
- **`herdr agent start` に `--focus` を付け忘れない** — focus が元 workspace のままだと user が新 Claude を確認できない
- **`INSTRUCTION` に対話フローを含めない** — 「まず X して次に Y」ではなく「X と Y を一気にやって」の形で 1 メッセージにまとめる。段階的な指示なら、そもそもこのスキルではなく元 session で TDD ワークフローを回した方が良い
