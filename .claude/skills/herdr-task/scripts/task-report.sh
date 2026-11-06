#!/usr/bin/env bash
# Reports upward from inside a task: a repo tab's Claude reports to the task's
# coordinator, and the coordinator (tab "task") reports to the master Claude.
#
# The master is not typed into: it is the session the human talks to, and a
# message landing there would interrupt them mid-typing. Coordinator reports
# go to <tasks_root>/.inbox instead (one line each), which the master reads on
# its periodic check.
#
# Usage: task-report.sh <message>
#   Run from a pane of a task (HERDR_TASK and HERDR_PANE_ID are set there).
#   The message is prefixed with "[<tab label>]" (or "[<task>]" from the
#   coordinator) so the receiver knows who is talking.
#
# Delivery does not wait for a reply. If the receiver is mid-turn the message
# is queued; if it is blocked on a prompt, nothing is sent (typing would answer
# the prompt) and this exits 4 so the caller can retry on its next check.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <message>" >&2
  exit 2
fi

script_dir=$(dirname "${BASH_SOURCE[0]}")
source "$script_dir/lib.sh"
inbox="$(tasks_root)/.inbox"

message="$1"
: "${HERDR_TASK:?not inside a task pane (HERDR_TASK is unset)}"
: "${HERDR_PANE_ID:?not inside a herdr pane}"
task="$HERDR_TASK"

coordinator=$(task_pane "$task")
if [ "$HERDR_PANE_ID" = "$coordinator" ]; then
  # Newlines would break the one-line-per-report format.
  printf '%s\t%s\t%s\n' "$(date '+%F %T')" "$task" "$(printf '%s' "$message" | tr '\n' ' ')" >> "$inbox"
  exit 0
else
  target="$coordinator"
  from=$(herdr pane list --workspace "$HERDR_WORKSPACE_ID" \
    | jq -r --arg p "$HERDR_PANE_ID" '.result.panes[] | select(.pane_id == $p) | .tab_id' \
    | head -1)
  from=$(herdr tab list --workspace "$HERDR_WORKSPACE_ID" \
    | jq -r --arg t "$from" '.result.tabs[] | select(.tab_id == $t) | .label')
fi

if [ -z "$target" ] || [ -z "$(pane_agent "$target")" ]; then
  echo "ERROR: no Claude to report to (pane '${target:-?}')" >&2
  exit 1
fi

status=$(pane_agent "$target" | jq -r '.agent_status')
case "$status" in
  blocked)
    echo "NOT SENT: $target is blocked on a prompt; retry on the next check" >&2
    exit 4
    ;;
  working)
    herdr agent prompt "$target" "[$from] $message" > /dev/null
    ;;
  *)
    "$script_dir/send-instruction.sh" "$target" "[$from] $message"
    ;;
esac
