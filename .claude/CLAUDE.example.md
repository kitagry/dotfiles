# ~/.claude/CLAUDE.md テンプレート

このファイルは `dotfiles/.claude/CLAUDE.example.md` から `~/.claude/CLAUDE.example.md` にsymlinkされる。
新しいマシンでセットアップする際の起点として使う:

```bash
# 既存の symlink (旧 ~/.claude/CLAUDE.md → dotfiles/.claude/CLAUDE.md) を削除
rm ~/.claude/CLAUDE.md
# テンプレートをコピーして人格別ファイルを作成
cp ~/.claude/CLAUDE.example.md ~/.claude/CLAUDE.md
# 編集して人格別の内容を追記
$EDITOR ~/.claude/CLAUDE.md
```

`~/.claude/CLAUDE.md` 自体は dotfiles 管理外 (マシン/人格ごとに異なる)。
共通ルールは `@~/.claude/CLAUDE.shared.md` で import する。

---

## 共通ルール (dotfiles 管理)

@~/.claude/CLAUDE.shared.md

## プロダクト横断ナレッジ

プロジェクトを跨いで思い出したい情報をここに溜める。tdd-workflow のリファクタリングフェーズで自然に追記される。

例:
- プロダクトX は Y を使っており、BigQuery の Z dataset に接続している
- プロダクトA と B は同じ認証基盤を共有
- 社内 OSS の foo は bar コマンドで起動

## この人格固有のルール

(会社人格/個人人格などに応じてここを書き分ける)
