#!/bin/bash
[ -z "$TMUX" ] && exit 0

data=$(cat)

# Try to get ai-title from transcript (Claude-generated session summary)
transcript=$(echo "$data" | jq -r '.transcript_path // empty')
label=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  label=$(jq -rs '[ .[] | select(.type=="ai-title") | .aiTitle ] | last // empty | gsub("\\s+";" ") | .[0:60]' "$transcript" 2>/dev/null)
fi

# Fall back to last stored prompt label
if [ -z "$label" ]; then
  label=$(tmux display-message -t "$TMUX_PANE" -p '#{@claude_label}')
fi

if [ -n "$label" ]; then
  tmux set-option -p -t "$TMUX_PANE" @claude_label "$label"
fi

tmux select-pane -t "$TMUX_PANE" -T "✓ ${label:-Claude Code}"
