#!/usr/bin/env bash
# Shows a Markdown file (ACTIONS.md) in a pane. With yourturn installed, it
# runs yourturn (scrolling, opening items, replying with R). Otherwise it
# redraws the file every <interval> seconds, rendered with mdcat so Markdown
# links are clickable (OSC 8). This replaces `watch -t -n 15 cat`: watch passes
# through only colour escapes, so OSC 8 links would not survive it. Without
# mdcat (or if it fails to run) the file is shown with cat.
#
# Usage: actions-view.sh <file> [interval]   (interval defaults to 15; unused
#        with yourturn)
#
# Test knobs: ACTIONS_VIEW_ONCE=1 draws one frame and exits;
# ACTIONS_VIEW_COLUMNS/ROWS override the pane size; ACTIONS_VIEW_MDCAT and
# ACTIONS_VIEW_YOURTURN override the mdcat and yourturn commands.
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
yourturn="${ACTIONS_VIEW_YOURTURN:-yourturn}"

# yourturn >= 0.2.0 ships contrib/herdr/yourturn-reply.sh next to its binary.
yourturn_reply_script() {
  local bin script
  bin=$(command -v "$yourturn") || return 1
  # Through a mise shim (or any symlink) the script sits next to the real
  # binary, which only `mise which` knows for a shim.
  script="$(dirname "$(readlink -f "$bin")")/contrib/herdr/yourturn-reply.sh"
  if [ ! -x "$script" ]; then
    bin=$(mise which "$yourturn" 2> /dev/null) || return 1
    script="$(dirname "$bin")/contrib/herdr/yourturn-reply.sh"
    [ -x "$script" ] || return 1
  fi
  printf '%s' "$script"
}

# The interval is for the fallback loop only: yourturn redraws on file change.
if command -v "$yourturn" > /dev/null 2>&1; then
  # Set through YOURTURN_REPLY_CMD rather than --reply-cmd: 0.1.0 refuses the
  # unknown flag but ignores the variable, so no version check is needed, and
  # a command the user already set is kept. Sh-quoted since yourturn runs it
  # with sh -c.
  if [ -z "${YOURTURN_REPLY_CMD:-}" ] && script=$(yourturn_reply_script); then
    export YOURTURN_REPLY_CMD="'${script//\'/\'\\\'\'}'"
  fi
  exec "$yourturn" "$file"
fi

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
