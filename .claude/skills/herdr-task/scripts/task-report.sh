#!/usr/bin/env bash
# Reports upward from inside a task: a repo tab's Claude reports to the task's
# coordinator, and the coordinator (tab "task") reports to the master Claude.
#
# Usage: task-report.sh <message>
#   Run from a pane of a task (HERDR_TASK and HERDR_PANE_ID are set there).
#   The message is prefixed with "[<tab label>]" (or "[<task>]" from the
#   coordinator) so the receiver knows who is talking.
#
# The master's pane is read from <tasks_root>/.master; the master writes it
# with `task-report.sh --register-master` from its own pane.
#
# Delivery does not wait for a reply. If the receiver is mid-turn the message
# is queued; if it is blocked on a prompt, nothing is sent (typing would answer
# the prompt) and this exits 4 so the caller can retry on its next check.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <message> | --register-master" >&2
  exit 2
fi

script_dir=$(dirname "${BASH_SOURCE[0]}")
source "$script_dir/lib.sh"
master_file="$(tasks_root)/.master"

if [ "$1" = "--register-master" ]; then
  : "${HERDR_PANE_ID:?run this inside the herdr pane of the master}"
  printf '%s\n' "$HERDR_PANE_ID" > "$master_file"
  echo "master pane: $HERDR_PANE_ID" >&2
  exit 0
fi

message="$1"
: "${HERDR_TASK:?not inside a task pane (HERDR_TASK is unset)}"
: "${HERDR_PANE_ID:?not inside a herdr pane}"
task="$HERDR_TASK"

coordinator=$(task_pane "$task")
if [ "$HERDR_PANE_ID" = "$coordinator" ]; then
  if [ ! -s "$master_file" ]; then
    echo "ERROR: no master registered ($master_file); the master runs: task-report.sh --register-master" >&2
    exit 1
  fi
  target=$(cat "$master_file")
  from="$task"
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
