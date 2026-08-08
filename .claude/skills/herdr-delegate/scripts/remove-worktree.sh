#!/usr/bin/env bash
# Removes a linked worktree + its herdr workspace. Destructive: --force discards
# any uncommitted/unpushed changes in that worktree.
#
# Usage: remove-worktree.sh <workspace_id>
#
# Intentionally NOT in this skill's allowed-tools: only run this after explicit
# user confirmation, since it can discard unpushed commits.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <workspace_id>" >&2
  exit 2
fi

herdr worktree remove --workspace "$1" --force
