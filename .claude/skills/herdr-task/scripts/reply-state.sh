#!/usr/bin/env bash
# Records how far a human reply sent from yourturn (R) has travelled, for
# yourturn to show next to the item ("↳ sent … · relayed … · acked …").
#
# Usage: reply-state.sh <key> <relayed|acked>
#   relayed  master handed the reply to the task (task-ask.sh does this itself)
#   acked    the coordinator received it
#
# Appends "<key>\t<state>\t<RFC3339>" to $YOURTURN_REPLY_STATUS if set (the
# file actions-view.sh points yourturn at, so a user-set path is honoured on
# both sides), else $HERDR_TASKS_ROOT/.reply-status (default ~/tasks). The
# file is append-only, one event per line: readers take the furthest state
# per key. "sent" is written by yourturn-reply.sh, and
# "done" is never written (yourturn infers it from ACTIONS.md).
#
# Exit codes: 0 recorded, 2 invalid arguments (nothing is written).
set -euo pipefail

usage() {
  echo "usage: $0 <key> <relayed|acked>  (key: r-YYYYMMDDTHHMMSS-xxxx)" >&2
  exit 2
}
[ $# -eq 2 ] || usage
key="$1"
state="$2"
# [[ =~ ]] rather than grep: grep matches per line, so a key with a newline
# would pass and split the event over two lines.
[[ "$key" =~ ^r-[0-9]{8}T[0-9]{6}-[0-9a-f]{4}$ ]] || usage
case "$state" in
  relayed|acked) ;;
  *) usage ;;
esac

script_dir=$(dirname "${BASH_SOURCE[0]}")
source "$script_dir/lib.sh"
file="${YOURTURN_REPLY_STATUS:-$(tasks_root)/.reply-status}"
mkdir -p "$(dirname "$file")"
# One short write in append mode, so concurrent writers do not interleave.
printf '%s\t%s\t%s\n' "$key" "$state" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$file"
