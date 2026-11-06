#!/usr/bin/env bash
# Closes a task: removes its worktrees, closes the herdr workspace, and moves
# the remaining task directory (TASK.md and notes) to <tasks_root>/_archive/.
# Local branches are kept so unmerged work can still be recovered. Paths opened
# with task-adopt.sh are left untouched.
#
# Usage: task-close.sh <task> [--force]
#   Without --force, refuses if task-status.sh reports dirty or unpushed work.
#   --force discards uncommitted changes in the worktrees.
#
# Intentionally NOT in the skill's allowed-tools: run only after the user
# confirmed, since it removes checkouts.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <task> [--force]" >&2
  exit 2
fi

task="$1"
force="${2:-}"
script_dir=$(dirname "${BASH_SOURCE[0]}")
source "$script_dir/lib.sh"
validate_task_name "$task"

dir=$(task_dir "$task")
if [ ! -d "$dir" ]; then
  echo "ERROR: $dir does not exist" >&2
  exit 1
fi

if ! "$script_dir/task-status.sh" "$task" >&2; then
  if [ "$force" != "--force" ]; then
    echo "ERROR: dirty or unpushed work above; push it or re-run with --force" >&2
    exit 1
  fi
fi

# Close the workspace first so no pane keeps a removed directory as its cwd.
ws_id=$(find_task_workspace "$task")
if [ -n "$ws_id" ]; then
  herdr workspace close "$ws_id" > /dev/null
fi

for wt in "$dir"/*/; do
  wt="${wt%/}"
  [ -f "$wt/.git" ] || continue
  repo_root=$(dirname "$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir)")
  git -C "$repo_root" worktree remove --force "$wt"
done

if [ -f "$dir/.adopted" ]; then
  cut -f2 "$dir/.adopted" | sed 's/^/kept (adopted): /' >&2
fi

archive="$(tasks_root)/_archive"
mkdir -p "$archive"
dest="$archive/$task"
if [ -e "$dest" ]; then
  dest="$archive/$task-$(date +%Y%m%d%H%M%S)"
fi
mv "$dir" "$dest"
echo "archived: $dest" >&2
