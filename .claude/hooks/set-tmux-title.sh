#!/bin/bash
[ -z "$TMUX" ] && exit 0

data=$(cat)
transcript=$(echo "$data" | jq -r '.transcript_path')
title=$(jq -rs '
  ([ .[] | select(.type=="ai-title")   | .aiTitle   ] | last)   //
  ([ .[] | select(.type=="last-prompt") | .lastPrompt ] | last) //
  empty
  | gsub("\\s+";" ") | .[0:60]
' "$transcript" 2>/dev/null)

tmux select-pane -T "✳ ${title:-Claude Code}"
