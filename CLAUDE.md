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
