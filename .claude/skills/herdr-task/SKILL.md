---
name: herdr-task
description: タスク単位で herdr workspace を作り、関係する repo の git worktree を tab として並べ、コーディネーター Claude と各 repo の実装 Claude を起動して指示を投げるスキル。「タスクを始めて」「bqls と bqls.nvim をまたいで〜」「複数 repo で〜」「worktree で並列に作業させて」「delegate して」などのリクエスト時、または /herdr-task で起動する。repo が1つだけのタスクにも使う。
allowed-tools: Bash(~/.claude/skills/herdr-task/scripts/task-create.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-add-repo.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-adopt.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-status.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-ask.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-reply.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-list.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-loop.sh:*), Bash(~/.claude/skills/herdr-task/scripts/task-report.sh:*), Bash(~/.claude/skills/herdr-task/scripts/note.sh:*), Bash(~/.claude/skills/herdr-task/scripts/reply-state.sh:*), Bash(~/.claude/skills/herdr-task/scripts/start-claude-agent.sh:*), Bash(~/.claude/skills/herdr-task/scripts/send-instruction.sh:*), Bash(~/.claude/skills/herdr-task/scripts/read-pane.sh:*), Bash(ghq get:*), Bash(ghq list:*)
---

# Task workspace on herdr

## 構成

1 タスク = 1 herdr workspace。repo の worktree はその中の tab として並べる。

```
~/tasks/<task>/              ← workspace "<task>" / tab "task" (左 pane: コーディネーター Claude / 右 pane: ACTIONS.md の表示)
  TASK.md                    ← 2行目に created: YYYY-MM-DD。ゴール・repo 一覧・repo をまたぐ決定事項・merge 順
  ACTIONS.md                 ← 人間の判断・作業が要るもの (コーディネーターが更新)。右 pane で `scripts/actions-view.sh ACTIONS.md` (yourturn で表示し、`R` で返事できる。yourturn が無いマシンでは 15 秒ごとに mdcat で描き直す)
  bqls/                      ← tab "bqls"      (branch: <task>)
  bqls.nvim/                 ← tab "bqls.nvim" (branch: <task>)
  bqls-2/                    ← tab "bqls-2"    (同じ repo の2本目, branch: <task>-2)
~/tasks/ACTIONS.md           ← 全タスクの要対応を master がまとめたもの。master の右 pane で actions-view.sh (yourturn)
~/tasks/_archive/YYYY-MM/YYYY-MM-DD-<task>/{TASK.md,ACTIONS.md}
                             ← 閉じたタスク。TASK.md と ACTIONS.md だけ残す (TASK.md の created: の下に closed: が入る)
```

- active なタスクは日付なしの `~/tasks/<task>/` に置く (タスク名を workspace の label や `HERDR_TASK_DIR` にそのまま使うため)。日付で分けるのは溜まっていく archive だけ
- 全 tab の shell に `HERDR_TASK` / `HERDR_TASK_DIR` が入る
- **ACTIONS.md**: 人間はチャットを全部は追えないので、人間に返事や作業を求めるものは ACTIONS.md に番号付きで保ち、tab "task" の右 pane に常に表示しておく。形式は、1 項目 = 1 行目が `- **<状態マーク> <番号> <質問文>**` で、背景・選択肢・期限・URL はその下に字下げした箇条書き。1 行目だけで何を聞かれているか分かるように、質問文は「〜してよい?」「A・B・C のどれ?」「(作業) 〜してください」の形にする。PR / issue は必ず `[repo#N](https://github.com/<owner>/<repo>/pull/N)` (issue は `/issues/N`) のフル URL のリンクで書き、`PR #N`・`repo#N`・素の `#N` だけで書かない (board と ACTIONS の pane で項目番号と紛れずにクリックできるように。素の `#N` は表示側で推測してリンクにしない)。状態マークは 🔴 急ぎ / 🟠 今週 / 🟢 時間があるとき / ⏳ 待ち / ✅ 済み。人間は「1 OK」「2 A」のように番号で返事する。番号は振り直さない (返事がずれるため)。右 pane はスクロールできず、pane の高さを超えた分は下が切れるので、未完了のものを上に置き、済んだもの・watch で起きたときにもう解決している・状況が変わって意味がなくなった項目は ✅ にして下に移し、前の日より古い ✅ は消す

  ```markdown
  - **🔴 1 [repo#239](https://github.com/<org>/<repo>/pull/239) を merge してよい?**
    - merge すると prod に出るが、方策は変わらない
    - 期限: 今日 15 時 (当日中に prod に出すなら)
  - **🟠 2 A・B・C のどれ?**
    - A: 存在チェックを入れて落とす / B: 既存のオプションで代替 / C: 現状維持
  - **🟢 3 (作業) console のアカウントでログインしてください**
    - パスワード入力は Claude ではできない
  ```
- worktree は `herdr worktree create` ではなく `git worktree add` で作る(herdr の worktree 機能は 1 workspace = 1 checkout 前提で、tab に並べられないため)。そのため herdr の `remove_worktree` キーバインドは使えず、片付けは `task-close.sh` で行う
- **trust**: Claude Code は trust 済みディレクトリの配下ではダイアログを出さない。`~/tasks` を一度 trust しておけば、task ディレクトリも worktree もダイアログなしで起動できる (下記「初回セットアップ」)
- `~/tasks` は ghq 配下ではないので、path ベースのルール (`**/<org>/**` など) は worktree に効かない
- スクリプトは全て `scripts/` にある。SKILL.md の手順では生の `herdr` / `git worktree` / jq を組み立てず、スクリプトを呼ぶ

## 誰と誰が話すか

```
人間 ⇄ master Claude (dotfiles などで開いているオーケストレーター)
          │ ↓ task-ask.sh / task-reply.sh / task-list.sh     ↑ task-report.sh (~/tasks/.inbox に追記)
          ▼
       tab "task" の Claude (コーディネーター。task-create.sh が起動する)
          │ ↓ send-instruction.sh / read-pane.sh             ↑ task-report.sh ("[<tab label>] ...")
          ▼
       各 repo の tab の Claude (実装担当)
```

- 人間は基本的に master と話す。master はタスクの状況を `task-list.sh` / `task-reply.sh` で見て、指示や質問は `task-ask.sh` でコーディネーターに渡す
- 人間が tab "task" を直接見て話しかけることもある。master からのメッセージには `[master]` が付くので、コーディネーターはどちらからか区別できる
- master は repo の tab の Claude に直接指示しない。コーディネーターを通す (TASK.md の決定事項とずれないように)
- **節目は下から上へ報告する** (`task-report.sh "<メッセージ>"`)。tab の中で実行すると、repo の tab からはコーディネーターの pane に直接届く。tab "task" からは master の pane には送らず、`~/tasks/.inbox` に1行 (`<日時>\t<task>\t<メッセージ>`) 追記する。master は人間が話しているセッションなので、そこに打ち込むと人間の入力を邪魔するため
- master は定期チェックで `~/tasks/.inbox` を読み、人間に報告したら空にする
- **要対応は ACTIONS.md に集める**。master は定期チェックで各タスクの `~/tasks/<task>/ACTIONS.md` を読み、未完了 (✅ 以外) のものを `~/tasks/ACTIONS.md` にタスクをまたいで 🔴/🟠/🟢/⏳ ごとにまとめる。項目の形式は各タスクと同じ (1 行目 `- **<状態マーク> <task>#<番号> <質問文>**`、その下に字下げした背景・選択肢・期限・URL)。番号はタスクごとに 1 から振られて重なるので `<task>#<番号>` にし、人間も「<task>#1 OK」のように返事する。close されたタスクの項目が残らないよう、`~/tasks/ACTIONS.md` は毎回作り直す (差分更新しない)。master の右 pane で `~/.claude/skills/herdr-task/scripts/actions-view.sh ~/tasks/ACTIONS.md` を表示しておけば、人間はそこを見るだけで何に返事すればよいか分かる。人間の返事 (番号付き) は master が `task-ask.sh` で該当タスクに渡す。yourturn の `R` で返した返事も `~/tasks/.inbox` に `[yourturn] human reply: <task>#<番号> <返事> (reply <key>)` として届くので、同じように渡す
- **返事の状態** (yourturn の `R` で返した返事がどこまで届いたか): `~/tasks/.reply-status` に 1 行 1 イベント (`<key>\t<state>\t<RFC3339>`) で追記され、yourturn が項目の下に `↳ sent … · relayed … · acked …` と表示する (actions-view.sh が `YOURTURN_REPLY_STATUS` で場所を渡す)。`sent` は yourturn-reply.sh、`relayed` は `task-ask.sh` (渡すメッセージに `(reply <key>)` があれば、届いた後に自動で書く。master は `(reply <key>)` を消さずに渡す)、`acked` はコーディネーターが `reply-state.sh <key> acked` で書く。`done` は書かない (項目が ✅ になった・消えたことから yourturn が判断する)
- **気づいたことは書き留める** (`note.sh "<文>" [--said] [--applied] [--repo owner/repo]`)。master・コーディネーター・実装担当の誰でも、次に同じ場面で知っていたら得をすることを価値を選ばずに 1 行。`${NOTEBOOK_DIR:-~/notebook}/notes/<今日>.md` に `- HH:MM <文> {src, task, tab, state[, repo]}` (行末は YAML の flow mapping) で追記され、夜の夢のジョブが memory や repo の心得に振り分ける。task / tab は自動で入る (タスクの外は master なら `master`、それ以外は `task: none` と cwd の名前)
- **聞かれるまで待たない**。コーディネーターは `/loop` (`task-loop.sh`) で自分の tab を定期チェックし、master も定期実行 (CronCreate、15 分ごと程度) で `task-list.sh` / `task-reply.sh` を見回って、要対応や節目の変化だけを人間に報告する

## 変化があったときだけコーディネーターを起こす (共通の見張り)

PR のレビューや CI のように「外で変わるもの」を待つとき、コーディネーターが `sleep` や `/loop` で張り付く代わりに、**チェックスクリプトを置くだけ**で共通の見張りが拾う。

- 30 分ごとに `scripts/watch-tick.sh` を 1 回走らせて終了する。macOS は launchd の LaunchAgent、Linux は systemd の user timer (oneshot service + timer) が起動する (常駐ループではないので、ゾンビも孤児も出ず、再起動後も自動で動く)
- `~/tasks/<task>/watch.d/*.sh` を全部走らせ、**標準出力が空でなければ** `task-ask.sh <task> "[watch] <出力>" --no-wait` でそのタスクのコーディネーターを起こす。1 タスクの複数チェックは 1 通にまとめる (複数が出力したときだけ `<チェック名>:` が付く)。コーディネーターが起動していない・プロンプトで止まっているときは `~/tasks/.inbox` に追記する
- 登録は `watch.d/` にスクリプトを置くだけ。タスクを閉じるとディレクトリごと `_archive` に移るので、登録も自動で消える
- 二重起動は `~/tasks/.watch.lock/` (mkdir ロック。クラッシュ後の古いロックは回収する)、各チェックは 60 秒 (`WATCH_TIMEOUT`) で打ち切る。終了コードが 0 でない・タイムアウトしたチェックの出力は転送せず `~/tasks/.watch.log` に書く (上限 `WATCH_LOG_MAX_LINES`、既定 500 行)
- `~/tasks/.watch-last` に最後に完走した時刻が入る。止めたいときは `touch ~/tasks/.watch-disabled` (消せば再開)

```bash
~/.claude/skills/herdr-task/scripts/install-watch.sh      # 登録 (再実行で更新。PATH が変わったときも)
~/.claude/skills/herdr-task/scripts/uninstall-watch.sh    # 解除
```

- OS で分岐する (`WATCH_SCHEDULER=launchd|systemd` で上書きできる)。どちらも実行したシェルの PATH を焼き込むので、`gh` / `jq` / `herdr` が見えるシェルから実行する
- **macOS**: `~/Library/LaunchAgents/com.herdr-task.watch.plist` を書いて `launchctl bootstrap` する。ログは `~/tasks/.watch-launchd.log`
- **Linux**: `~/.config/systemd/user/herdr-task-watch.{service,timer}` (`$XDG_CONFIG_HOME` を尊重) を書いて `systemctl --user enable` + `restart` する。home-manager では管理しない (skill を Mac と共用するため、スクリプトで書く)。timer は毎時 0 分と 30 分 (`OnCalendar=*:0/30`、`Persistent=true` なのでサスペンド中に逃した回は復帰時に走る)
  - 状態: `systemctl --user list-timers herdr-task-watch.timer`、ログ: `journalctl --user -u herdr-task-watch.service`
  - ログアウト中も動かしたいなら `loginctl enable-linger $USER` (しないと user manager はログイン中だけ動く)
  - `--no-load` で unit を書くだけにして `systemd-analyze --user verify <service> <timer>` で検証できる

### チェックスクリプトの書き方

チェックは「**前回の状態と比べて、変わった分だけを出力する。変化が無ければ何も出さない**」スクリプト。空でない出力 = コーディネーターを起こす理由、なので、毎回同じ内容を出すと 30 分ごとに起こしてしまう。

- 状態は `$WATCH_STATE_DIR` (= `~/tasks/<task>/watch.state/`) に置く。cwd はタスクのディレクトリで、`HERDR_TASK` / `HERDR_TASK_DIR` も入っている
- 出力に使うのは「次に何をすべきか判断できる 1 行」(PR の URL・状態・失敗した check など)。複数行でも 1 行にまとめて送られる。出力はそのままコーディネーターのプロンプトに打ち込まれるので、PR タイトルやコメント本文のような第三者が書ける自由文は含めない (プロンプトインジェクションの経路になる)
- 外部 API は**まとめて 1 回**で呼ぶ。PR が 10 本あるなら `gh pr view` を 10 回ではなく GraphQL の alias で 1 クエリにする。30 分ごとでもレート制限を食わない
- API の取得に失敗 (空の応答) したときは何も出さず、**状態も上書きしない**。次回に差分として拾える
- スクリプトは冪等に。途中で打ち切られても (60 秒 timeout) 次回やり直せば同じ結果になるよう、状態は最後に一度だけ書く

```bash
#!/usr/bin/env bash
# watch.d/prs.sh: print only the PRs whose state changed since the last pass.
set -uo pipefail
STATE="$WATCH_STATE_DIR/prs.state"
LIST="$HERDR_TASK_DIR/watch.d/prs.list"   # one "owner/repo#number" per line

query=""; i=0
while read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  owner=${line%%/*}; repo=${line#*/}; repo=${repo%%#*}; num=${line##*#}
  query+="p$i: repository(owner:\"$owner\", name:\"$repo\") { pullRequest(number:$num) { url state headRefOid } } "
  i=$((i + 1))
done < "$LIST"
[ -z "$query" ] && exit 0

now=$(gh api graphql -f query="query { $query }" \
  | jq -r '.data | to_entries | sort_by(.key)[] | .value.pullRequest | select(. != null) | "\(.url) \(.state) \(.headRefOid[0:7])"')
[ -z "$now" ] && exit 0                     # fetch failed: keep the old state

touch "$STATE"
diff <(sort "$STATE") <(printf '%s\n' "$now" | sort) | sed -n 's/^> //p'
printf '%s\n' "$now" > "$STATE"
```

## 初回セットアップ (マシンごとに1回)

`~/tasks` が trust されていないと `task-create.sh` が止まって案内を出す。ユーザーに次を実行してもらい、`Yes, I trust this folder` を選んで終了してもらう:

```
! mkdir -p ~/tasks && cd ~/tasks && claude
```

`~/.claude.json` をスクリプトで書き換えて trust しない。起動中の Claude セッションも同じファイルを書き換えているので、上書きし合う。

ACTIONS.md の右 pane (`scripts/actions-view.sh`) は `yourturn` (ACTIONS.md の TUI ビューア。dotfiles の mise config に入っている) があればそれを起動する。項目を開く・リンクを開く・`R` で返事する、ができる。`R` の返事は yourturn に同梱の `contrib/herdr/yourturn-reply.sh` (yourturn の実体の隣にある) に渡され、`~/tasks/.inbox` に追記される (master が拾ってタスクに渡す)。返事のコマンドは `--reply-cmd` ではなく環境変数 `YOURTURN_REPLY_CMD` で渡す (v0.1.0 は知らないフラグで落ちるが、環境変数は無視するのでバージョンを見なくてよい)。自分で `YOURTURN_REPLY_CMD` を設定していればそちらが使われる。v0.2.0 より前の yourturn や同梱スクリプトが見つからないときは `R` だけ使えない。`[interval]` は yourturn では使わない (ファイルの変更で描き直す)。

yourturn が無いマシンでは、15 秒ごとに描き直すループで表示する。`mdcat` があれば使う (これも mise config に入っている)。`watch` を使わないのは、色以外のエスケープシーケンスを通さず、mdcat のリンク (OSC 8) がクリックできなくなるため。mdcat が無い・動かないマシンでは `cat` で表示する。master の右 pane はスクリプトでは作らないので、master の pane を右に分割して `~/.claude/skills/herdr-task/scripts/actions-view.sh ~/tasks/ACTIONS.md` を一度動かしておく (ファイルが無くてもできるまで待つ)。

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

- TASK.md と ACTIONS.md の雛形を作り、tab "task" を左右に分割する。右 (幅 35%、pane の label は `ACTIONS`) で `actions-view.sh ACTIONS.md` (yourturn があれば yourturn) を動かし、focus は奪わない。分割や actions-view.sh の起動に失敗しても WARN を出して続行する。`PANE_ID` はこれまでどおり左のコーディネーターの pane
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
- master 側の定期チェックがまだ無ければ、CronCreate で仕込む (`~/tasks/.inbox` を読んで空にする + 各タスクの ACTIONS.md を `~/tasks/ACTIONS.md` に集約する + 前回の返答を scratchpad に保存して差分だけ見る。報告は「確認したいこと」/ blocked / merge などの節目だけ)

repo の tab の Claude は、コーディネーターに起動・指示させるのが基本。master や自分で起動するときは:

```bash
~/.claude/skills/herdr-task/scripts/start-claude-agent.sh "$PANE_ID" "$TASK-<tab label>"
~/.claude/skills/herdr-task/scripts/send-instruction.sh "$PANE_ID" "$INSTRUCTION"
```

- `start-claude-agent.sh <pane> <name> [--continue] [-- <claude の引数>...]`。`--` の後ろはそのまま claude に渡る (例: `... "$TASK-<label>" -- --model sonnet`、`--continue` と併用なら `--continue -- --model sonnet`)。未知の引数は usage を出して exit 2。`--mcp-config` / `--settings` は拒否される
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
- メッセージに `(reply <key>)` が付いていたら (人間が yourturn で返した返事)、受け取った時点で herdr-task スキルの reply-state.sh <key> acked を key ごとに呼んで (人間の画面に「受け取った」と表示される)。
- 人間に確認したいことは、返答の最後に「確認したいこと」として書いて (master が人間に聞く)。
- 人間の判断・作業が要るものは $HERDR_TASK_DIR/ACTIONS.md に番号付きで保って (tab の右 pane に表示されていて、master も集約する)。形式: 各項目の 1 行目は「- **<状態マーク> <番号> <質問文>**」で、1 行目だけで何を聞かれているか分かるように質問文は「〜してよい?」「A・B・C のどれ?」「(作業) 〜してください」の形にする。背景・選択肢・期限・URL はその下に字下げした箇条書きで書く。状態マークは 🔴 急ぎ / 🟠 今週 / 🟢 時間があるとき / ⏳ 待ち / ✅ 済み。済んだもの・watch で起きたときにもう解決している・状況が変わって意味がなくなった項目は ✅ にして下に移し、前の日より古い ✅ は消す (右 pane はスクロールできない)。番号は振り直さない。
- PR / issue は ACTIONS.md・TASK.md・返答・報告のどこでも必ず [repo#N](https://github.com/<owner>/<repo>/pull/N) (issue は /issues/N) のフル URL のリンクで書いて。PR #N・repo#N・素の #N だけで書かない (board と ACTIONS の pane で項目番号と紛れずにクリックできるように。素の #N は表示側でリンクにしない)。各 tab の Claude への指示にも同じ 1 行を含めて。
- 返答の最後には、毎回タスク全体の状況を数行で要約して。
- 節目 (tab の PR が merge された、全 tab が終わった、人間の判断が要る、詰まった) では task-report.sh で master に報告して (master の受信箱に入り、master の定期チェックで人間に伝わる)。各 tab の Claude にも、同じ節目で task-report.sh であなたに報告するよう指示に含めて。
- スコープ外の問題を見つけたら別 issue にして。
- 気づいたことは herdr-task スキルの note.sh で 1 行書き留めて (選ばずに。memory には書かない)。各 tab の Claude への指示にも同じ 1 行を含めて。
```

#### 各 repo の実装担当への指示

repo 単体で完結する形にする:

1. **ゴール** — この repo で何を実装するか (1-3 文)
2. **TASK.md の参照** — `$HERDR_TASK_DIR/TASK.md` の Decisions に従うこと
3. **PR 方針** — 「PR 作成 → `/loop` でレビュー監視 → `pr-fix` で対応」まで回すか、draft 止まりか。他 repo の merge を待つ必要があれば draft にする
4. **報告** — 「PR を作った、merge された、レビューで人間の判断が要る、詰まった、のどれかになったら herdr-task スキルの task-report.sh でコーディネーターに報告して。報告や返答では PR / issue を必ず [repo#N](https://github.com/<owner>/<repo>/pull/N) (issue は /issues/N) のフル URL のリンクで書いて。PR #N・repo#N・素の #N だけで書かない」(board と ACTIONS の pane で項目番号と紛れずにクリックできるように。素の `#N` は表示側でリンクにしない)
5. **スコープ外** — 「スコープ外の問題を見つけたら別 issue にして」
6. **書き留め** — 「気づいたことは herdr-task スキルの note.sh で 1 行書き留めて (選ばずに。memory には書かない)」

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

- `$LABEL` は tab の label でもディレクトリ名 (`task-status.sh` の出力) でもよい。該当する tab が無ければ何も消さずにエラーで止まる
- tab を閉じる → worktree を削除 (branch は残す) → TASK.md の行を `## Done` に移す → sidebar の `$repos` を更新
- adopt した tab なら、tab を閉じて `.adopted` から外すだけ。ディレクトリには触らない

タスク全体を閉じる (PR が全部 merge されたら)。ユーザーに確認した上で:

```bash
~/.claude/skills/herdr-task/scripts/task-close.sh "$TASK"          # dirty / unpushed があれば拒否
~/.claude/skills/herdr-task/scripts/task-close.sh "$TASK" --force  # 未コミットの変更を捨てて削除
```

- workspace を close → worktree を削除 → TASK.md に `closed: YYYY-MM-DD` を書き足して ACTIONS.md と一緒に `~/tasks/_archive/YYYY-MM/YYYY-MM-DD-<task>/` に移す。adopt したディレクトリはそのまま残る
- TASK.md / ACTIONS.md 以外に残っていたファイル (コーディネーターのメモなど) は消さずに archive の `rest/` に移す
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
