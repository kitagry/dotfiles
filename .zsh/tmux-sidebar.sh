#!/bin/bash

current_session=$(tmux display-message -p '#S')

while true; do
  clear
  tmux list-sessions -F "#{session_name}" 2>/dev/null | while read -r session; do
    if [ "$session" = "$current_session" ]; then
      printf "\033[1;32m[%s]\033[0m\n" "$session"
    else
      printf "\033[1m[%s]\033[0m\n" "$session"
    fi

    tmux list-windows -t "$session" -F "#{window_index} #{window_name} #{window_active}" 2>/dev/null | \
      while read -r idx name active; do
        # そのwindow内のpane titleからClaudeマーカーを拾う
        titles=$(tmux list-panes -t "$session:$idx" -F '#{pane_title}' 2>/dev/null)
        claude_title=$(printf '%s\n' "$titles" | grep -m1 '^✳')
        if [ -z "$claude_title" ]; then
          claude_title=$(printf '%s\n' "$titles" | grep -m1 '^?')
        fi
        if [ -z "$claude_title" ]; then
          claude_title=$(printf '%s\n' "$titles" | grep -m1 '^✓')
        fi

        if [ "$active" = "1" ]; then
          prefix="  \033[33m* $idx: $name\033[0m"
        else
          prefix="    $idx: $name"
        fi

        if [ -n "$claude_title" ]; then
          body="${claude_title:2}"  # 先頭のグリフ+スペースを除く
          body="${body:0:20}"
          glyph="${claude_title:0:1}"
          if [ "$glyph" = "✳" ]; then
            printf "${prefix} \033[32m%s %s\033[0m\n" "$glyph" "$body"
          elif [ "$glyph" = "?" ]; then
            printf "${prefix} \033[33m%s %s\033[0m\n" "$glyph" "$body"
          else
            printf "${prefix} \033[90m%s %s\033[0m\n" "$glyph" "$body"
          fi
        else
          printf "${prefix}\n"
        fi
      done
  done
  sleep 2
done
