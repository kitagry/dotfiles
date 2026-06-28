#!/bin/bash
[ -z "$TMUX" ] && exit 0

data=$(cat)
label=$(echo "$data" | jq -r '.prompt // empty' | tr '\n' ' ' | sed 's/^ *//;s/ *$//' | cut -c1-60)
label="${label:-Claude Code}"

tmux set-option -p -t "$TMUX_PANE" @claude_label "$label"
tmux select-pane -t "$TMUX_PANE" -T "✳ $label"
