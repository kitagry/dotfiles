#!/bin/bash

# ghq + gh でリポジトリを選択し、tmux windowを開く
# ローカルにないリポジトリは選択時にclone
# 環境変数 GHQ_REMOTE_ORGS で複数の組織を指定可能（スペース区切り、デフォルト: kitagry）

REMOTE_ORGS=${GHQ_REMOTE_ORGS:-kitagry}

selected=$(
  (
    ghq list -p
    for org in $REMOTE_ORGS; do
      gh repo list "$org" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null | \
        while IFS= read -r repo; do
          path=$(ghq root)/github.com/$repo
          [ ! -d "$path" ] && echo "$path [remote]"
        done
    done
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
