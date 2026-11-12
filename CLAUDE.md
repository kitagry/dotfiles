# CLAUDE.md

個人の dotfiles。リポジトリ内のファイルを `install.sh` で $HOME に symlink する。

## 変更後の反映
- 新しいファイルを追加したら `./install.sh` で symlink を張り直す（既存ファイルの編集は不要）
- macOS は `./install_mac.sh`

## mise config の分割ルール
mise は `~/.config/mise/conf.d/*.toml` を自動でマージするので、用途別にファイルを分ける:
- `dotfiles/.config/mise/config.toml` → 全マシン共通のツールのみ（dotfiles で symlink 管理）
- `~/.config/mise/conf.d/work.toml` → 仕事用（dotfiles 管理外）。社内ツール (`bee`, `mcp-obsidian` など)
- `~/.config/mise/conf.d/private.toml` → 個人用（dotfiles 管理外）

新しいツールは「全マシンで使うか？」で置き場所を決める。実際に読まれている設定は `mise config` で確認できる。

## Non-obvious Conventions

- Neovim uses a custom lazy loading system (`kitagry.lazy`), not lazy.nvim. Config is modularized through Lua requires under `.config/nvim/lua/`
- Machine-local overrides live outside the repo: `init.local.vim` (Neovim) and `.zshrc.local` (zsh)
- Where Claude Code spends time (tool calls, subagents, polling, waiting on the user) is measured after the fact from the transcripts, not from hooks: `.claude/scripts/claude_timing.py --since 7d [--project <substr>] [--json]`. It pairs `tool_use`/`tool_result` timestamps in `~/.claude/projects/**.jsonl` and reads `subagents/agent-*.meta.json` for `agentType`. Transcript time includes permission-prompt waits, so `.claude/hooks/timing-log.sh` (PermissionRequest / PostToolUse / PostToolUseFailure) appends `duration_ms` and suggested allow rules to `~/.claude/timing/events.jsonl`; the script joins them by `tool_use_id` (PermissionRequest has none, so by session + tool input). `cleanupPeriodDays` is raised in `.claude/settings.json` so the history survives. Tests: `python3 .claude/scripts/claude_timing_test.py`, `bash .claude/hooks/timing-log_test.sh`
- Zsh plugins are managed by sheldon (`.config/sheldon/plugins.toml`), not by hand-written `source` lines
- kubectl / k9s / flux are never run against the global current-context (it is kept unset). Each context has a split kubeconfig in `~/.kube/ctx/<alias>.yaml`, plus generated sh executables `~/.kube/ctx/bin/<alias>-{kubectl,k9s,flux}` that pin `KUBECONFIG` to it (so they work from `watch`, `xargs`, bash, tmux, not just fish). `.config/fish/conf.d/kube.fish` puts that bin on PATH and defines the generic `kc <alias> <cmd>`. Regenerate after changing kubeconfig with `kube-ctx-sync` (`.config/fish/functions/kube-ctx-sync.fish`), which also rewrites the cobra fish completions so cluster-aware completion hits the pinned context (`--wraps` can't, fish rewrites the command name before completing). Fallback without the wrappers: `KUBECONFIG=~/.kube/ctx/<alias>.yaml kubectl ...`
