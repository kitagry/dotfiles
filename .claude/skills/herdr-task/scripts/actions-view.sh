#!/usr/bin/env bash
# Shows a Markdown file (ACTIONS.md) in a pane and redraws it every <interval>
# seconds, rendered with mdcat so Markdown links are clickable (OSC 8). This
# replaces `watch -t -n 15 cat`: watch passes through only colour escapes, so
# OSC 8 links would not survive it. Without mdcat (or if it fails to run) the
# file is shown with cat.
#
# Usage: actions-view.sh <file> [interval]   (interval defaults to 15)
#
# Test knobs: ACTIONS_VIEW_ONCE=1 draws one frame and exits;
# ACTIONS_VIEW_COLUMNS/ROWS override the pane size; ACTIONS_VIEW_MDCAT
# overrides the mdcat command.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <file> [interval]" >&2
  exit 2
fi

file="$1"
interval="${2:-15}"
# A failing `sleep` would turn the loop into a busy redraw.
if ! [[ "$interval" =~ ^[1-9][0-9]*$ ]]; then
  echo "interval must be a positive number of seconds: $interval" >&2
  exit 2
fi
mdcat="${ACTIONS_VIEW_MDCAT:-mdcat}"

# Read the size on every frame so a resized pane is followed. stty reads the
# terminal itself; $COLUMNS/$LINES would be stale in a child process.
pane_size() {
  local size
  size=$(stty size 2>/dev/null < /dev/tty) || size=""
  rows="${ACTIONS_VIEW_ROWS:-${size% *}}"
  cols="${ACTIONS_VIEW_COLUMNS:-${size#* }}"
  [[ "$rows" =~ ^[1-9][0-9]*$ ]] || rows=24
  [[ "$cols" =~ ^[1-9][0-9]*$ ]] || cols=80
}

render() {
  if [ ! -e "$file" ]; then
    echo "($file not found; waiting for it)"
    return
  fi
  # --ansi because the output is captured (not a tty), where mdcat would drop
  # all styling. mdcat still emits OSC 8 links in ANSI mode. Captured first so
  # a failing mdcat's partial output is not shown above the cat fallback.
  local out
  if command -v "$mdcat" > /dev/null 2>&1 \
    && out=$("$mdcat" --ansi --columns "$cols" "$file" 2>/dev/null); then
    printf '%s\n' "$out"
    return
  fi
  cat "$file"
}

# Draws over the previous frame instead of `clear`ing first, so the pane does
# not flicker. Autowrap is off (see the trap) so one line is one screen row,
# and output taller than the pane keeps the top, where unfinished items are.
draw() {
  local out="$1" frame=$'\e[H' line n=0 total
  total=$(printf '%s\n' "$out" | awk 'END { print NR }')
  while IFS= read -r line; do
    n=$((n + 1))
    if [ "$total" -gt "$rows" ] && [ "$n" -eq "$rows" ]; then
      line="… $((total - rows + 1)) more lines"
    fi
    # Reset styles and close any OSC 8 link left open at a cut line, then
    # clear what the previous frame left to the right.
    frame+="$line"$'\e[0m\e]8;;\e\\\e[K'
    [ "$n" -ge "$rows" ] && break
    [ "$n" -lt "$total" ] && frame+=$'\n'
  done <<< "$out"
  printf '%s\e[J' "$frame"
}

sleeper=""
printf '\e[?7l\e[?25l'
trap 'printf "\e[?7h\e[?25h"; [ -n "$sleeper" ] && kill "$sleeper" 2>/dev/null' EXIT
trap 'exit 0' INT TERM
# A resize redraws at once, as watch did. Sleeping in the background lets
# `wait` return on any trapped signal; a foreground sleep would hold off the
# redraw (and INT/TERM) until the interval ends.
trap ':' WINCH

while :; do
  pane_size
  draw "$(render)"
  [ "${ACTIONS_VIEW_ONCE:-}" = 1 ] && break
  sleep "$interval" &
  sleeper=$!
  wait "$sleeper"
  kill "$sleeper" 2>/dev/null
  sleeper=""
done
