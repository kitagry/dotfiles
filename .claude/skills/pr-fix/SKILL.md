---
name: pr-fix
description: PRのレビューコメントを取得し、TDDで修正してcommit+pushする。create-prスキルのループから呼ばれることが多いが単独でも使える。「レビュー対応」「pr-fix」「コメント対応して」などのリクエスト時に使用する。
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(uv run pytest:*), Bash(uv run mypy:*), Bash(uv run ruff:*), Bash(uv run tox:*), Bash(go test:*), Bash(go build:*), Bash(golangci-lint run:*), Bash, Read, Edit, Write, Grep, Glob, Task, TodoWrite, Skill
---

# Fix PR Review Comments (TDD)

1. GitHub MCP `pull_request_read` (method: `get_review_comments`) でレビューコメントを取得
2. 各コメントについて **失敗するテストを先に書く**
3. テストを通す最小限の実装を行う
4. `test-runner` エージェントで全テスト + mypy を実行し全パスを確認
5. 変更内容を要約して提示
6. Semantic Commit Message で commit し、push する
