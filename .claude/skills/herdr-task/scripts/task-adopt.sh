#!/usr/bin/env bash
# Opens an existing directory (a repo checkout, a linked worktree made elsewhere,
# any work dir) as a tab of the task, without moving it.
#
# Usage: task-adopt.sh <task> <path> [label]
#   [label]  tab label. Default: basename of <path>
#
# Moving would be tidier, but Claude Code keys session history by cwd, so a moved
# directory loses `claude --continue`. Adopted paths are recorded in
# <task_dir>/.adopted; task-close.sh leaves them in place.
#
# On success, prints to stdout (eval-able):
#   TAB_ID='...'  PANE_ID='...'
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <task> <path> [label]" >&2
  exit 2
fi

task="$1"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
validate_task_name "$task"

if [ ! -d "$2" ]; then
  echo "ERROR: $2 is not a directory" >&2
  exit 1
fi
path=$(realpath "$2")
label="${3:-$(basename "$path")}"

dir=$(task_dir "$task")
if [ ! -d "$dir" ]; then
  echo "ERROR: $dir does not exist; run task-create.sh first" >&2
  exit 1
fi
ws_id=$(find_task_workspace "$task")
if [ -z "$ws_id" ]; then
  echo "ERROR: no herdr workspace labeled '$task'" >&2
  exit 1
fi
if [ -f "$dir/.adopted" ] && cut -f2 "$dir/.adopted" | grep -qxF -- "$path"; then
  echo "ERROR: $path is already adopted by $task" >&2
  exit 1
fi

# Outside the trusted tasks root, an untrusted path would stop Claude at the
# trust dialog; say so now rather than when the agent is started.
if ! is_trusted "$path"; then
  echo "ERROR: $path is not trusted by Claude Code." >&2
  echo "  Review its .claude/ and .mcp.json, then trust it once: cd $path && claude" >&2
  exit 1
fi

json=$(herdr tab create --workspace "$ws_id" --cwd "$path" --label "$label" \
  --env "HERDR_TASK=$task" --env "HERDR_TASK_DIR=$dir" --no-focus)
tab_id=$(printf '%s' "$json" | jq -r '.result.tab.tab_id')
pane_id=$(printf '%s' "$json" | jq -r '.result.root_pane.pane_id')

if [ -z "$tab_id" ] || [ "$tab_id" = "null" ] || [ -z "$pane_id" ] || [ "$pane_id" = "null" ]; then
  echo "ERROR: herdr tab create did not return tab_id/root_pane.pane_id" >&2
  echo "$json" >&2
  exit 1
fi

printf '%s\t%s\n' "$label" "$path" >> "$dir/.adopted"

if [ -f "$dir/TASK.md" ]; then
  branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "-")
  append_repo_line "$dir/TASK.md" "- \`$label\`: $path (adopted, branch: \`$branch\`)"
fi

printf "TAB_ID=%q\n" "$tab_id"
printf "PANE_ID=%q\n" "$pane_id"
