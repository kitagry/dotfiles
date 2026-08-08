#!/usr/bin/env bash
# Creates a new linked worktree + herdr workspace off the given parent workspace,
# and prints the resulting workspace_id / worktree path / root pane_id as shell
# assignments so the caller can `eval` them directly.
#
# Usage: create-worktree.sh <parent_workspace_id> <branch> <base>
#   <base> is the branch to fork from, WITHOUT the "origin/" prefix
#          (this script always forks from the remote-tracking ref "origin/<base>").
#
# On success, prints to stdout (eval-able):
#   WS_ID='...'
#   WT_PATH='...'
#   PANE_ID='...'
#
# Never pass --focus: this must stay a silent background creation so the caller's
# workspace keeps focus.
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "usage: $0 <parent_workspace_id> <branch> <base>" >&2
  exit 2
fi

parent_ws="$1"
branch="$2"
base="$3"

json=$(herdr worktree create \
  --workspace "$parent_ws" \
  --branch "$branch" \
  --base "origin/$base" \
  --json)

ws_id=$(printf '%s' "$json" | jq -r '.result.workspace.workspace_id')
wt_path=$(printf '%s' "$json" | jq -r '.result.worktree.path')
pane_id=$(printf '%s' "$json" | jq -r '.result.root_pane.pane_id')

if [ -z "$ws_id" ] || [ "$ws_id" = "null" ] || [ -z "$wt_path" ] || [ "$wt_path" = "null" ] || [ -z "$pane_id" ] || [ "$pane_id" = "null" ]; then
  echo "ERROR: herdr worktree create did not return workspace_id/worktree.path/root_pane.pane_id" >&2
  echo "$json" >&2
  exit 1
fi

printf "WS_ID=%q\n" "$ws_id"
printf "WT_PATH=%q\n" "$wt_path"
printf "PANE_ID=%q\n" "$pane_id"
