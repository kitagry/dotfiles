#!/usr/bin/env bash
# Sends a message from the master Claude to a task's coordinator (the Claude in
# the "task" tab), waits for it to finish, and prints its reply.
#
# Usage: task-ask.sh <task> <message> [--timeout SEC] [--no-wait]
#   --timeout  how long to wait for the turn to finish (default 600)
#   --no-wait  only send; read the result later with task-reply.sh
#
# The message is prefixed with "[master]" so the coordinator can tell it from
# a human typing in the task tab directly.
#
# The reply is read from the Claude Code transcript rather than the screen:
# the pane only shows what fits and wraps long lines.
#
# Exit codes: 0 replied, 1 error, 3 still working at timeout (the message was
# delivered; check later with task-reply.sh), 4 blocked on a permission prompt
# or question in the task tab.
set -euo pipefail

usage() {
  echo "usage: $0 <task> <message> [--timeout SEC] [--no-wait]" >&2
  exit 2
}
[ $# -ge 2 ] || usage

task="$1"
message="$2"
shift 2
timeout=600
wait=1
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) timeout="${2:?}"; shift 2 ;;
    --no-wait) wait=0; shift ;;
    *) usage ;;
  esac
done

script_dir=$(dirname "${BASH_SOURCE[0]}")
source "$script_dir/lib.sh"
validate_task_name "$task"

pane=$(task_pane "$task")
if [ -z "$pane" ]; then
  echo "ERROR: no 'task' tab in workspace '$task'" >&2
  exit 1
fi
agent=$(pane_agent "$pane")
if [ -z "$agent" ]; then
  echo "ERROR: no Claude in the task tab ($pane); start it with start-claude-agent.sh $pane $task-task" >&2
  exit 1
fi
status=$(printf '%s' "$agent" | jq -r '.agent_status')
if [ "$status" = "blocked" ]; then
  echo "ERROR: the coordinator is blocked on a prompt; answer it in the task tab first" >&2
  "$script_dir/read-pane.sh" "$pane" >&2
  exit 4
fi
# Claude queues input typed mid-turn, but then the wait below would return at
# the end of the current turn with the wrong reply.
if [ "$status" = "working" ] && [ "$wait" -eq 1 ]; then
  echo "ERROR: the coordinator is working; retry later, or pass --no-wait to queue the message" >&2
  exit 1
fi

transcript=$(pane_transcript "$pane")
before=0
if [ -n "$transcript" ]; then
  before=$(wc -l < "$transcript")
fi

if [ "$status" = "working" ]; then
  herdr agent prompt "$pane" "[master] $message" > /dev/null
else
  "$script_dir/send-instruction.sh" "$pane" "[master] $message"
fi
[ "$wait" -eq 1 ] || exit 0

if ! herdr agent wait "$pane" --timeout "$((timeout * 1000))" > /dev/null 2>&1; then
  echo "STILL WORKING after ${timeout}s; check later with task-reply.sh $task" >&2
  exit 3
fi

# The session id can change mid-turn (e.g. /clear), so look it up again.
after=$(pane_transcript "$pane")
if [ "$after" != "$transcript" ]; then
  before=0
fi
if [ -n "$after" ]; then
  last_assistant_text "$after" "$before"
fi

if [ "$(pane_agent "$pane" | jq -r '.agent_status')" = "blocked" ]; then
  echo "BLOCKED: the coordinator is waiting on a prompt in the task tab ($pane)" >&2
  exit 4
fi
