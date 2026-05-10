#!/bin/bash

# tmuxのウィンドウをfzfで選択して切り替える
# プロセスツリーを辿りclaudeの存在をwindowに付与する（nvim-aibo対応）

# claudeが存在するウィンドウIDを検出
# 「ペイン→子孫」の再帰探索ではなく「claudeプロセス→祖先」の逆方向探索に変更
# ps/pgrepの呼び出しを1回にまとめてawkで一括処理
claude_wins_file=$(mktemp)
trap "rm -f $claude_wins_file" EXIT

awk '
NR == FNR {
  parent[$1] = $2
  command[$1] = $3
  next
}
{
  is_pane[$2] = $1
}
END {
  for (pid in command) {
    if (command[pid] ~ /claude/) {
      current = pid
      for (i = 0; i < 30; i++) {
        if (current + 0 <= 1) break
        if (current in is_pane) {
          claude_wins[is_pane[current]] = 1
          break
        }
        if (!(current in parent) || parent[current] == current) break
        current = parent[current]
      }
    }
  }
  for (win in claude_wins) print win
}' <(ps -eo pid=,ppid=,comm= 2>/dev/null) \
  <(tmux list-panes -a -F "#{session_name}:#{window_index} #{pane_pid}" 2>/dev/null) \
  > "$claude_wins_file"

# ウィンドウ一覧にclaudeステータスを付与してfzfに渡す
selected=$(
  tmux list-windows -a -F "#{session_name}:#{window_index} #{window_name} #{pane_current_path}" 2>/dev/null | \
  awk '
  NR == FNR {
    wins[$1] = 1
    next
  }
  { print ($1 in wins) ? $0 "  ✻" : $0 }
  ' "$claude_wins_file" - | \
  fzf --prompt='Window >' \
    --preview 'echo {}' \
    --preview-window down:3:wrap \
    --bind ctrl-d:preview-page-down,ctrl-u:preview-page-up)

if [ -n "$selected" ]; then
  target=$(echo "$selected" | awk '{print $1}')
  tmux switch-client -t "$target"
fi
