#!/usr/bin/env bash
# Checks whether a freshly-started Claude agent pane is showing the first-run
# "trust this folder?" dialog, and if so, confirms the default option
# ("1. Yes, I trust this folder") and waits for the agent to settle back to idle.
# No-ops (exit 0) if the dialog isn't showing.
#
# Only needed for brand-new repos that Claude Code has never seen before (see
# "現在の repo ではなく、新規 repo に対して使う場合" in SKILL.md). Linked worktrees
# of an already-trusted repo don't hit this dialog, so this step is unnecessary
# for the normal worktree-delegate flow.
#
# Usage: confirm-trust-dialog.sh <pane_id>
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <pane_id>" >&2
  exit 2
fi

pane_id="$1"
script_dir=$(dirname "${BASH_SOURCE[0]}")

output=$("$script_dir/read-pane.sh" "$pane_id")

if ! printf '%s' "$output" | grep -q "trust this folder"; then
  exit 0
fi

herdr pane send-keys "$pane_id" Enter
herdr agent wait "$pane_id" --until idle --timeout 15000
