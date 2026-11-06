#!/usr/bin/env bash
# Read-only overview of a task's worktrees: branch, uncommitted changes, and
# commits not on any remote. Use it before task-close.sh.
#
# Usage: task-status.sh <task>
#
# Prints one TSV line per worktree:
#   <name>  <branch>  dirty=<N files>  unpushed=<N commits>
# then one per adopted path (task-adopt.sh), tagged "adopted".
# Exits 1 if any worktree is dirty or has unpushed commits, 0 if all clean.
# Adopted paths don't affect the exit code: task-close.sh never removes them.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <task>" >&2
  exit 2
fi

task="$1"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
validate_task_name "$task"

dir=$(task_dir "$task")
if [ ! -d "$dir" ]; then
  echo "ERROR: $dir does not exist" >&2
  exit 1
fi

git_state() {
  printf 'dirty=%s\tunpushed=%s' \
    "$(git -C "$1" status --porcelain | wc -l)" \
    "$(git -C "$1" rev-list --count HEAD --not --remotes)"
}

unsafe=0
for wt in "$dir"/*/; do
  wt="${wt%/}"
  # A linked worktree has a .git *file*; skip plain directories (notes, _archive...).
  [ -f "$wt/.git" ] || continue
  branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD)
  dirty=$(git -C "$wt" status --porcelain | wc -l)
  # Commits reachable from HEAD but from no remote-tracking ref: these are lost
  # if the worktree and branch go away.
  unpushed=$(git -C "$wt" rev-list --count HEAD --not --remotes)
  printf '%s\t%s\tdirty=%s\tunpushed=%s\n' "$(basename "$wt")" "$branch" "$dirty" "$unpushed"
  if [ "$dirty" -gt 0 ] || [ "$unpushed" -gt 0 ]; then
    unsafe=1
  fi
done

if [ -f "$dir/.adopted" ]; then
  while IFS=$'\t' read -r label path; do
    if git -C "$path" rev-parse > /dev/null 2>&1; then
      printf '%s\t%s\t%s\tadopted:%s\n' "$label" "$(git -C "$path" rev-parse --abbrev-ref HEAD)" "$(git_state "$path")" "$path"
    else
      printf '%s\t-\t-\tadopted:%s\n' "$label" "$path"
    fi
  done < "$dir/.adopted"
fi

exit "$unsafe"
