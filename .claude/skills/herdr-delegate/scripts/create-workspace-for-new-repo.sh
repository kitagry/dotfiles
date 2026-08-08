#!/usr/bin/env bash
# Creates a brand-new herdr workspace at the given directory (for repos that don't
# have any herdr worktree/workspace yet, e.g. a repo just cloned via `ghq get`).
# Prints the resulting workspace_id / root pane_id as shell assignments so the
# caller can `eval` them directly.
#
# Usage: create-workspace-for-new-repo.sh <cwd> <label>
#
# On success, prints to stdout (eval-able):
#   WS_ID='...'
#   PANE_ID='...'
#
# Never pass --focus: this must stay a silent background creation so the caller's
# workspace keeps focus.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <cwd> <label>" >&2
  exit 2
fi

cwd="$1"
label="$2"

json=$(herdr workspace create --cwd "$cwd" --label "$label" --no-focus --json)

ws_id=$(printf '%s' "$json" | jq -r '.result.workspace.workspace_id')
pane_id=$(printf '%s' "$json" | jq -r '.result.root_pane.pane_id')

if [ -z "$ws_id" ] || [ "$ws_id" = "null" ] || [ -z "$pane_id" ] || [ "$pane_id" = "null" ]; then
  echo "ERROR: herdr workspace create did not return workspace_id/root_pane.pane_id" >&2
  echo "$json" >&2
  exit 1
fi

printf "WS_ID=%q\n" "$ws_id"
printf "PANE_ID=%q\n" "$pane_id"
