---
name: pr-fix
description: PRのレビューコメントを取得し、修正してcommit+pushする。「レビュー対応」「pr-fix」「コメント対応して」などのリクエスト時に使用する。
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, TodoWrite, Skill
---

# Fix PR Review Comments

1. GitHub MCP `pull_request_read` (method: `get_review_comments`) でレビューコメントを取得
2. 動作の変更を求めるコメントは `tdd-workflow` に従って修正する。命名・コメント等の修正はそのまま直す
3. 変更内容を要約して提示
4. Semantic Commit Message で commit し、push する
