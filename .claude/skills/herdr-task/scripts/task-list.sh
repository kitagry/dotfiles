#!/usr/bin/env bash
# Lists the open tasks for the master Claude: one TSV line per task.
#   <task>  <workspace_id>  coordinator=<agent_status|none>  <repo tabs>
#
# Usage: task-list.sh
#
# A task is a directory under the tasks root with a herdr workspace of the
# same label; _archive and directories without a workspace are skipped.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

root=$(tasks_root)
[ -d "$root" ] || exit 0

workspaces=$(herdr workspace list)
agents=$(herdr agent list)

for d in "$root"/*/; do
  task=$(basename "$d")
  [ "$task" = "_archive" ] && continue
  ws=$(printf '%s' "$workspaces" | jq -c --arg l "$task" '.result.workspaces[] | select(.label == $l)' | head -1)
  [ -n "$ws" ] || continue
  ws_id=$(printf '%s' "$ws" | jq -r '.workspace_id')
  pane=$(task_pane "$task")
  status=$(printf '%s' "$agents" | jq -r --arg p "$pane" '[.result.agents[] | select(.pane_id == $p)][0].agent_status // "none"')
  repos=$(printf '%s' "$ws" | jq -r '.tokens.repos // ""')
  printf '%s\t%s\tcoordinator=%s\t%s\n' "$task" "$ws_id" "$status" "$repos"
done
