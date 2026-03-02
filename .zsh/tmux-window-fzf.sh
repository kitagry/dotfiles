#!/bin/bash

# tmuxのウィンドウをfzfで選択して切り替える
# プロセスツリーを辿りclaudeの存在をwindowに付与する（nvim-aibo対応）

# pane PIDの子孫プロセスにclaudeが存在するか確認
has_claude_descendant() {
  local pid=$1
  local children
  children=$(pgrep -P "$pid" 2>/dev/null) || return 1
  for child in $children; do
    local comm
    comm=$(ps -p "$child" -o comm= 2>/dev/null | tr -d ' ')
    if [[ "$comm" == *"claude"* ]]; then
      return 0
    fi
    has_claude_descendant "$child" && return 0
  done
  return 1
}

# claudeが存在するwindow IDをtmpファイルに記録
claude_windows=$(mktemp)
trap "rm -f $claude_windows" EXIT

while IFS=' ' read -r win_id pane_pid; do
  grep -qxF "$win_id" "$claude_windows" && continue
  if has_claude_descendant "$pane_pid"; then
    echo "$win_id" >> "$claude_windows"
  fi
done < <(tmux list-panes -a -F "#{session_name}:#{window_index} #{pane_pid}" 2>/dev/null)

# ウィンドウ一覧にagentステータスを付与してfzfに渡す
selected=$(
  tmux list-windows -a -F "#{session_name}:#{window_index} #{window_name} #{pane_current_path}" | \
    while IFS= read -r line; do
      key=$(echo "$line" | awk '{print $1}')
      if grep -qxF "$key" "$claude_windows" 2>/dev/null; then
        echo "$line  ✻"
      else
        echo "$line"
      fi
    done | \
  fzf --prompt='Window >' \
    --preview 'echo {}' \
    --preview-window down:3:wrap \
    --bind ctrl-d:preview-page-down,ctrl-u:preview-page-up)

if [ -n "$selected" ]; then
  target=$(echo "$selected" | awk '{print $1}')
  tmux switch-client -t "$target"
fi
