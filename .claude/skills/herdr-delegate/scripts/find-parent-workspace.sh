#!/usr/bin/env bash
# Prints the workspace_id of the parent (non-linked) herdr workspace for the given repo root.
#
# Usage: find-parent-workspace.sh <repo_root> [label]
#
# 1st attempt: match workspaces where worktree.repo_root == <repo_root> and is_linked_worktree == false.
# 2nd attempt (fallback): match by workspace label = basename(repo_root) or the provided [label].
#   (some herdr workspaces don't expose worktree info in `workspace list`; label match rescues those.)
#
# Exits with error if no match is found.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <repo_root> [label]" >&2
  exit 2
fi

repo_root="$1"
label="${2:-$(basename "$repo_root")}"

list_json=$(herdr workspace list)

ws_id=$(printf '%s' "$list_json" \
  | jq -r --arg root "$repo_root" '
      .result.workspaces[]
      | select(.worktree.repo_root == $root and .worktree.is_linked_worktree == false)
      | .workspace_id
    ' \
  | head -1)

if [ -z "$ws_id" ]; then
  ws_id=$(printf '%s' "$list_json" \
    | jq -r --arg label "$label" '
        .result.workspaces[]
        | select((.worktree == null) and .label == $label)
        | .workspace_id
      ' \
    | head -1)
fi

if [ -z "$ws_id" ]; then
  echo "ERROR: parent workspace not found for repo_root=$repo_root (label=$label)" >&2
  exit 1
fi

echo "$ws_id"
