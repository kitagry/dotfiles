#!/usr/bin/env bash
# Closes a task: closes the herdr workspace, removes its worktrees, and keeps
# only TASK.md (stamped with "closed: <date>") and ACTIONS.md under
# <tasks_root>/_archive/YYYY-MM/YYYY-MM-DD-<task>/ so finished tasks can be
# looked back on without the checkouts taking up space.
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

dest="$(tasks_root)/_archive/$(date +%Y-%m)/$(date +%F)-$task"
if [ -e "$dest" ]; then
  dest="$dest-$(date +%H%M%S)"
fi
mkdir -p "$dest"

if [ -f "$dir/TASK.md" ]; then
  # After "created:" (line 2), or right under the title for tasks made
  # before "created:" existed.
  awk -v line="closed: $(date +%F)" '
    NR == 2 && /^created:/ { print; print line; next }
    NR == 2 { print line }
    { print }
  ' "$dir/TASK.md" > "$dest/TASK.md"
  rm "$dir/TASK.md"
fi
if [ -f "$dir/ACTIONS.md" ]; then
  mv "$dir/ACTIONS.md" "$dest/ACTIONS.md"
fi
rm -f "$dir/.adopted"

# Anything else left (notes the coordinator wrote, ...) is moved along rather
# than deleted: it wasn't created by these scripts, so it may matter.
if ! rmdir "$dir" 2> /dev/null; then
  echo "WARN: kept other files of $task in $dest/rest" >&2
  mv "$dir" "$dest/rest"
fi
echo "archived: $dest" >&2
