#!/bin/bash

# ghq + gh でリポジトリを選択し、tmux windowを開く
# ローカルにないリポジトリは選択時にclone
# 環境変数 GHQ_REMOTE_ORGS で複数の組織を指定可能（スペース区切り、デフォルト: kitagry）

REMOTE_ORGS=${GHQ_REMOTE_ORGS:-kitagry}
CACHE_DIR="${HOME}/.cache/ghq-fzf"
CACHE_FILE="${CACHE_DIR}/remote-repos.cache"
CACHE_DURATION=${GHQ_CACHE_DURATION:-86400}  # デフォルト1時間

# キャッシュが有効かチェック
is_cache_valid() {
  # GHQ_CACHE_CLEAR=1 が設定されている場合は無効
  [ -n "$GHQ_CACHE_CLEAR" ] && return 1

  # キャッシュファイルが存在しない場合は無効
  [ ! -f "$CACHE_FILE" ] && return 1

  # キャッシュの更新時刻を取得
  local cache_time=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  local current_time=$(date +%s)
  local age=$((current_time - cache_time))

  # 有効期限内かチェック
  [ $age -lt $CACHE_DURATION ]
}

# リモートリポジトリ一覧を取得（キャッシュまたはAPI）
get_remote_repos() {
  if is_cache_valid; then
    # キャッシュから読み込み
    cat "$CACHE_FILE"
  else
    # APIから取得してキャッシュに保存
    mkdir -p "$CACHE_DIR"
    for org in $REMOTE_ORGS; do
      gh repo list "$org" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null | \
        while IFS= read -r repo; do
          path=$(ghq root)/github.com/$repo
          [ ! -d "$path" ] && echo "$path [remote]"
        done
    done | tee "$CACHE_FILE"
  fi
}

selected=$(
  (
    ghq list -p
    get_remote_repos
  ) | fzf --prompt='Project >' \
    --preview 'if echo {} | grep -q "\[remote\]"; then
                 echo "Remote repository (will be cloned on selection)"
               else
                 bat --color=always --style=numbers --line-range=:500 {}/README.md 2>/dev/null || echo "No README.md found"
               fi' \
    --bind ctrl-d:preview-page-down,ctrl-u:preview-page-up
)

if [ -n "$selected" ]; then
  if echo "$selected" | grep -q '\[remote\]'; then
    # リモートリポジトリの場合はclone
    dir=$(echo "$selected" | sed 's/ \[remote\]$//')
    repo=$(echo "$dir" | sed 's|.*/github.com/||')
    ghq get "$repo" && dir=$(ghq list -p -e "$repo")
  else
    dir="$selected"
  fi

  if [ -n "$dir" ] && [ -d "$dir" ]; then
    session=$(basename "$dir" | sed 's/\./-/g')
    if tmux list-windows -F "#{window_name}" | grep -q "^$session$"; then
      tmux select-window -t ":$session"
    else
      tmux new-window -c "$dir" -n "$session"
    fi
  fi
fi
