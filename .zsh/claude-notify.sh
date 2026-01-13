#!/bin/bash

# Claude Code用の通知スクリプト
# 引数: $1 = メッセージ

MESSAGE="${1:-通知}"

if [ -n "$TMUX" ]; then
  WINDOW_NAME=$(tmux display-message -p -t "$TMUX_PANE" '#W')
  osascript -e "display notification \"${MESSAGE} (${WINDOW_NAME})\" with title \"Claude Code\""
else
  osascript -e "display notification \"${MESSAGE}\" with title \"Claude Code\""
fi
