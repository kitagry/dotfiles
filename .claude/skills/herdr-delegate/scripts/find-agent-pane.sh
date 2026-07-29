#!/usr/bin/env bash
# Prints the pane_id of the herdr agent in the given workspace.
#
# Usage: find-agent-pane.sh <workspace_id> [agent_name=claude]
#
# Retries up to ~5s to wait for the agent to appear in `agent list`.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <workspace_id> [agent_name]" >&2
  exit 2
fi

ws="$1"
name="${2:-claude}"

for _ in 1 2 3 4 5; do
  pane_id=$(herdr agent list \
    | jq -r --arg ws "$ws" --arg name "$name" '
        .result.agents[]
        | select(.workspace_id == $ws and .name == $name)
        | .pane_id
      ' \
    | head -1)
  if [ -n "$pane_id" ]; then
    echo "$pane_id"
    exit 0
  fi
  sleep 1
done

echo "ERROR: agent pane not found for workspace=$ws name=$name" >&2
exit 1
