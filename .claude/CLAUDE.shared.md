NEVER: パスワードやAPIキーをハードコーディングしない
NEVER: ユーザーの確認なしにデータを削除しない
YOU MUST: モックは外部依存のみ使用

## コード作成ルール
1. **必ずTodo生成後にチェックを受ける** - 実装前にTodoを出力
2. **TDDで実装** - `tdd-workflow` スキルと `/tdd:*` コマンド参照
3. **コメントはWHYのみ** - 可読性に響く場合のみWHATも記述

## コード知識
プロジェクトの知識は `CLAUDE.local.md` に記録。定期的に見直して古い情報を削除。

## GitHub操作ルール
GitHubのPR/Issue/レビューコメント等を読み取る際は、`gh api` や `gh pr view` ではなく **必ず GitHub MCP ツールを使う**こと。
- PR本体・レビュー・インラインコメント取得: `mcp__github__pull_request_read`
- Issue取得: `mcp__github__issue_read`
- 一覧: `mcp__github__list_pull_requests` / `list_issues` / `list_commits` / `list_branches` / `list_releases` / `list_tags` / `list_issue_types`
- 検索: `mcp__github__search_pull_requests` / `search_issues` / `search_code` / `search_repositories` / `search_users`
- その他: `mcp__github__get_file_contents` / `get_commit` / `get_me` / `get_label` / `get_latest_release` / `get_release_by_tag` / `get_tag` / `get_team_members` / `get_teams`

settings.json で許可済みは個別ツール名のみ（**ワイルドカードは効かない** ので注意）。許可されていない読み取り系MCPを使いたい場合は明示的に追加すること。理由: `gh api` を許可するとPOST等の書き込みも通ってしまうため、settings.jsonではMCPの読み取り系のみを個別許可している。

### PR / MR 作成時は自分を assignee に追加
PR / MR を作成したら、必ず自分を assignee に追加すること。draft でも ready-for-review でも同じ。理由: 自分の担当 PR/MR がダッシュボード (GitHub Pulls / GitLab To-do) や `gh pr list --assignee @me` に出るようになり、レビュー返し・CI 失敗通知・QA 依頼のキャッチアップが早くなる。draft 期間中に忘れがちなので `gh pr create` / `create_merge_request` の直後にセットで叩く。
- GitHub: `gh pr create ...` の直後に `gh pr edit <URL or number> --add-assignee "@me"`
- GitLab: `mcp__mcp-gitlab__create_merge_request` の args に `assignee_ids: [<自分のID>]` を入れる (作成後なら `mcp__mcp-gitlab__update_merge_request` で追加)。自分の ID は `mcp__mcp-gitlab__whoami` で取得

## Google Workspace操作ルール
Google Drive / Sheets / Docs / Gmail / Calendar / Slides 等のGoogle Workspaceリソースを操作する際は、MCPではなく **`gws` コマンド (Google Workspace CLI)** を使うこと。
- 使い方: `gws <service> <resource> [sub-resource] <method> [flags]`
- 例:
  - `gws drive files list --params '{"pageSize": 10}'`
  - `gws drive files get --params '{"fileId": "abc123"}'`
  - `gws sheets spreadsheets get --params '{"spreadsheetId": "..."}'`
  - `gws docs documents get --params '{"documentId": "..."}'`
  - `gws gmail users messages list --params '{"userId": "me"}'`
- スキーマ確認: `gws schema <service.resource.method> [--resolve-refs]`
- ヘルプ: `gws --help` / `gws <service> --help`

サービス一覧: `drive`, `sheets`, `gmail`, `calendar`, `docs`, `slides`, `tasks`, `people`, `chat`, `classroom`, `forms`, `keep`, `meet`, `admin-reports`, `events`, `workflow`, `script`。

書き込み系 (POST/PATCH/PUT/DELETE 相当の method) を実行する場合はユーザー確認を取ること。

## セッション開始時
公式チュートリアルやベストプラクティスを一つ紹介して。
