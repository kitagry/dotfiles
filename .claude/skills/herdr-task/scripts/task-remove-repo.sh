#!/usr/bin/env bash
# Finishes one tab of a task, e.g. an issue whose PR got merged in a theme task:
# closes the tab, removes its worktree (the branch is kept), moves its TASK.md
# line to "## Done", and refreshes the sidebar's $repos.
#
# Usage: task-remove-repo.sh <task> <label> [--force]
#   Without --force, refuses if the worktree is dirty or has unpushed commits.
#   --force discards uncommitted changes.
#
# A tab opened with task-adopt.sh is only closed and dropped from .adopted;
# its directory is never touched.
#
# Intentionally NOT in the skill's allowed-tools: run only after the user
# confirmed, since it removes a checkout.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <task> <label> [--force]" >&2
  exit 2
fi

task="$1"
label="$2"
force="${3:-}"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
validate_task_name "$task"

dir=$(task_dir "$task")
if [ ! -d "$dir" ]; then
  echo "ERROR: $dir does not exist" >&2
  exit 1
fi
ws_id=$(find_task_workspace "$task")

adopted_path=""
if [ -f "$dir/.adopted" ]; then
  adopted_path=$(awk -F'\t' -v l="$label" '$1 == l { print $2; exit }' "$dir/.adopted")
fi
wt="$dir/$(label_dir "$label")"

if [ -z "$adopted_path" ]; then
  if [ ! -f "$wt/.git" ]; then
    echo "ERROR: no worktree for '$label' at $wt" >&2
    exit 1
  fi
  dirty=$(git -C "$wt" status --porcelain | wc -l)
  unpushed=$(git -C "$wt" rev-list --count HEAD --not --remotes)
  if { [ "$dirty" -gt 0 ] || [ "$unpushed" -gt 0 ]; } && [ "$force" != "--force" ]; then
    echo "ERROR: $label has dirty=$dirty unpushed=$unpushed; push it or re-run with --force" >&2
    exit 1
  fi
fi

# Close the tab first so its shell doesn't keep the removed dir as cwd.
if [ -n "$ws_id" ]; then
  tab_id=$(herdr tab list --workspace "$ws_id" \
    | jq -r --arg l "$label" '.result.tabs[] | select(.label == $l) | .tab_id' | head -1)
  if [ -n "$tab_id" ]; then
    herdr tab close "$tab_id" > /dev/null
  fi
fi

if [ -n "$adopted_path" ]; then
  awk -F'\t' -v l="$label" '$1 != l' "$dir/.adopted" > "$dir/.adopted.tmp" \
    && mv "$dir/.adopted.tmp" "$dir/.adopted"
  echo "kept (adopted): $adopted_path" >&2
else
  repo_root=$(dirname "$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir)")
  git -C "$repo_root" worktree remove --force "$wt"
fi

if [ -f "$dir/TASK.md" ]; then
  move_repo_line_to_done "$dir/TASK.md" "$label"
fi

if [ -n "$ws_id" ]; then
  report_repos "$ws_id"
fi
