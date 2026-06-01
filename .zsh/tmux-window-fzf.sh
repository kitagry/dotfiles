#!/bin/bash

# tmuxのウィンドウをfzfで選択して切り替える
# tcmuxでclaudeのステータス（タスク名・Idle/Running/Waiting）を取得してウィンドウに付与する

agent_file=$(mktemp)
trap "rm -f $agent_file" EXIT

tcmux list-windows -a -A -F "#{session_name}:#{window_index} #{agent_status}" --color never 2>/dev/null > "$agent_file"

selected=$(
  tmux list-windows -a -F "#{session_name}:#{window_index} #{window_name} #{pane_current_path}" 2>/dev/null | \
  awk '
  NR == FNR {
    id = $1; $1 = ""; sub(/^ /, "", $0)
    if ($0 != "") status[id] = $0
    next
  }
  {
    id = $1
    print (id in status) ? $0 "  " status[id] : $0
  }
  ' "$agent_file" - | \
  fzf --prompt='Window >' \
    --preview 'echo {}' \
    --preview-window down:3:wrap \
    --bind ctrl-d:preview-page-down,ctrl-u:preview-page-up)

if [ -n "$selected" ]; then
  target=$(echo "$selected" | awk '{print $1}')
  tmux switch-client -t "$target"
fi
