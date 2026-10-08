---
name: stacked-prs
description: GitHub の Stacked PRs (依存チェーンになった複数 PR) と `gh stack` 拡張の使い方。大きな変更を小さい PR に分割して積む、下の PR に依存する PR を作る、stack をまとめて rebase / push / merge する時に使う。「stacked PR」「PR を積む」「スタック PR」「gh stack」「依存 PR」「PR を分割」等で起動。
---

# GitHub Stacked PRs

出典: <https://docs.github.com/ja/pull-requests/get-started/about-stacked-prs> / CLI リファレンス <https://docs.github.com/ja/pull-requests/reference/stacked-prs-cli-commands> (2026-10 時点)

## 概念

- **同じリポ内**の 2 つ以上の PR が依存チェーンを作ったもの。最下位 PR は default branch (trunk) を base にし、上の PR はその直下 PR のブランチを base にする
- GitHub 本体の機能。Web では PR 上部に stack アイコンと番号付きのレイヤーが出て、merge box に stack 全体の状態が表示される
- **マージは下から順**。上位 PR をマージすると、下の PR を含めて stack 全体を一度にマージできる
- 下位 PR がマージされると、**残りのブランチは自動 rebase、上位 PR の base は自動で付け替え (retarget)** される。手で `gh pr edit --base` する必要はない
- merge / squash / rebase のいずれのマージ方式も使える

## 制限

- 全ブランチが同じリポにある必要がある。**fork をまたぐ stack は不可**
- GitHub Desktop は非対応 (CLI / Web / Mobile / REST / GraphQL / Webhook は対応)
- API でマージする場合は**非同期マージ API** を使う必要がある

## `gh stack` 拡張

導入済み (`gh extension list` で `github/gh-stack` を確認)。未導入なら `gh extension install github/gh-stack`。要件は gh 2.0+ / Git 2.36+。

### 基本フロー

```shell
gh stack init feature-model             # trunk から stack 開始 (--base develop で trunk 変更)
# ... 実装 ...
gh stack add -Am "Add user model"       # 既存ブランチにコミット
gh stack add feature-api                # 上に新しいブランチを積む
gh stack add -Am "Add login endpoint"
gh stack submit                         # push + 各 PR を作成/更新して stack として紐付け (既定は draft)
gh stack view                           # stack の状態確認 (--short / --json)
```

- `gh stack submit --open` で draft ではなく ready-for-review で作る。`--auto` でエディタを開かずタイトル自動生成
- 既存 PR / ブランチを後から stack にまとめる: `gh stack link 10 20 30` (下から順に指定)

### レビュー指摘を下位 PR に入れた後

```shell
gh stack down / gh stack switch         # 修正したいレイヤーへ移動
git commit ...
gh stack rebase --upstack               # 現在より上のブランチをカスケード rebase
gh stack push                           # または gh stack sync (fetch + rebase + push を一括)
```

- trunk が進んだ時は `gh stack sync`。マージ済みブランチを消すなら `--prune`
- コンフリクト時は解消して `gh stack rebase --continue` (やめるなら `--abort`)。終了コード 3 が rebase 競合
- 並べ替え・統合・挿入・リネームは `gh stack modify` (対話 UI)

### マージ

```shell
gh stack merge --squash                 # stack 全体をまとめてマージ (-y で確認スキップ)
```

### ナビゲーション

`gh stack up [n]` / `down [n]` / `top` / `bottom` / `trunk` / `switch` / `checkout <stack番号|PR番号|URL|branch>`

### その他

- `gh stack unstack` は stack の解除 (`--local` でローカル追跡のみ削除)
- git worktree 間でも状態を共有して動く。変更系コマンドは clone 全体で直列化され、他プロセスが操作中だと終了コード 8 (lock)
- `gh stack view --json` は機械可読なのでスクリプトから使う時はこちら

## 運用メモ

- PR を作ったら自分を assignee に付けるルールは stack でも同じ。`gh stack submit` の後に各 PR へ `gh pr edit <num> --add-assignee "@me"`
- herdr-delegate で worktree を切る運用と併用する場合、stack のブランチは同じ clone の worktree 群で共有されるので、同じ stack を複数セッションから同時に rebase しない
- GitHub 公式の agent 向け skill (`gh skill install github/gh-stack`) もあるが、`gh skill` は preview。この skill で足りなければ検討する
