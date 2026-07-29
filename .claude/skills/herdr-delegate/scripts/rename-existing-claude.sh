#!/usr/bin/env bash
# Renames the existing "claude" agent (if any) so the name is available for a new spawn.
#
# `herdr agent start` requires the agent name to be session-wide unique. Since the caller
# session is itself named "claude", we rename it to "claude-caller-<epoch>" and put the
# name back in the pool.
#
# Prints the pane_id that was renamed (empty line if there was no existing "claude").
set -euo pipefail

existing=$(herdr agent list \
  | jq -r '.result.agents[] | select(.name == "claude") | .pane_id' \
  | head -1)

if [ -n "$existing" ]; then
  herdr agent rename "$existing" "claude-caller-$(date +%s)" > /dev/null
  echo "$existing"
fi
