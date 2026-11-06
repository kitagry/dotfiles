#!/usr/bin/env bash
# Creates a task directory (~/tasks/<task>) with a TASK.md skeleton and a herdr
# workspace labeled <task> whose first tab ("task") sits at the task directory
# and runs the coordinator Claude (agent name <task>-task).
# Repos are added later as tabs with task-add-repo.sh.
#
# Usage: task-create.sh <task>
#
# On success, prints to stdout (eval-able):
#   WS_ID='...'
#   PANE_ID='...'   (root pane of the "task" tab, for the coordinator Claude)
#   TASK_DIR='...'
#
# Never pass --focus: creation must not steal the caller's screen.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <task>" >&2
  exit 2
fi

task="$1"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
validate_task_name "$task"

dir=$(task_dir "$task")

# Trusting the tasks root once covers every task dir and worktree under it, so
# Claude never stops at the trust dialog when started in a tab.
root=$(tasks_root)
if ! is_trusted "$root"; then
  echo "ERROR: $root is not trusted by Claude Code. Trust it once by running:" >&2
  echo "  mkdir -p $root && cd $root && claude   (choose 'Yes, I trust this folder', then exit)" >&2
  exit 1
fi

# Refuse to reuse: a half-matching existing task would silently mix two tasks'
# worktrees and TASK.md.
if [ -e "$dir" ]; then
  echo "ERROR: $dir already exists" >&2
  exit 1
fi
if [ -n "$(find_task_workspace "$task")" ]; then
  echo "ERROR: a herdr workspace labeled '$task' already exists" >&2
  exit 1
fi

mkdir -p "$dir"
cat > "$dir/TASK.md" <<EOF
# $task

## Goal

## Repos
<!-- task-add-repo.sh appends here -->

## Decisions
<!-- cross-repo interfaces (command names, API shapes, ...) agreed for this task -->

## Merge order

## Notes

## Done
<!-- task-remove-repo.sh moves finished tabs here -->
EOF

json=$(herdr workspace create --cwd "$dir" --label "$task" \
  --env "HERDR_TASK=$task" --env "HERDR_TASK_DIR=$dir" --no-focus)

ws_id=$(printf '%s' "$json" | jq -r '.result.workspace.workspace_id')
pane_id=$(printf '%s' "$json" | jq -r '.result.root_pane.pane_id')
tab_id=$(printf '%s' "$json" | jq -r '.result.tab.tab_id')

if [ -z "$ws_id" ] || [ "$ws_id" = "null" ] || [ -z "$pane_id" ] || [ "$pane_id" = "null" ]; then
  echo "ERROR: herdr workspace create did not return workspace_id/root_pane.pane_id" >&2
  echo "$json" >&2
  exit 1
fi

herdr tab rename "$tab_id" task > /dev/null

# The task tab always has a coordinator: it is who the master Claude (and a
# human looking at the tab) talks to. stdout is reserved for the eval-able vars.
if ! "$(dirname "${BASH_SOURCE[0]}")/start-claude-agent.sh" "$pane_id" "$task-task" >&2; then
  echo "WARN: coordinator did not start; run start-claude-agent.sh $pane_id $task-task" >&2
fi

printf "WS_ID=%q\n" "$ws_id"
printf "PANE_ID=%q\n" "$pane_id"
printf "TASK_DIR=%q\n" "$dir"
