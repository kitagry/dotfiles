#!/usr/bin/env bash
# Prints the coordinator's status and its latest reply, e.g. to pick up the
# result of a `task-ask.sh --no-wait` or a turn that outlived the timeout.
#
# Usage: task-reply.sh <task>
#
# Output: a "status: <agent_status>" line, a blank line, then the reply text.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <task>" >&2
  exit 2
fi

task="$1"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
validate_task_name "$task"

pane=$(task_pane "$task")
if [ -z "$pane" ]; then
  echo "ERROR: no 'task' tab in workspace '$task'" >&2
  exit 1
fi
agent=$(pane_agent "$pane")
if [ -z "$agent" ]; then
  echo "ERROR: no Claude in the task tab ($pane)" >&2
  exit 1
fi

echo "status: $(printf '%s' "$agent" | jq -r '.agent_status')"
echo
transcript=$(pane_transcript "$pane")
if [ -n "$transcript" ]; then
  last_assistant_text "$transcript"
fi
