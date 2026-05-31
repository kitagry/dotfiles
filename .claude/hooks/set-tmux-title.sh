#!/bin/bash
[ -z "$TMUX" ] && exit 0

data=$(cat)
transcript=$(echo "$data" | jq -r '.transcript_path')
title=$(jq -r '[.[] | select(.role=="user")] | last | .content | if type=="array" then .[0].text else . end' "$transcript" 2>/dev/null | head -c 60 | tr '\n' ' ')

tmux select-pane -T "✳ ${title:-Claude Code}"
