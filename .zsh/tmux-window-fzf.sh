#!/bin/bash

# tmuxのウィンドウをfzfで選択して切り替える

selected=$(tmux list-windows -a -F "#{session_name}:#{window_index} #{window_name} #{pane_current_path}" | \
  fzf --prompt='Window >' \
    --preview 'echo {}' \
    --preview-window down:3:wrap \
    --bind ctrl-d:preview-page-down,ctrl-u:preview-page-up)

if [ -n "$selected" ]; then
  target=$(echo "$selected" | awk '{print $1}')
  tmux switch-client -t "$target"
fi
