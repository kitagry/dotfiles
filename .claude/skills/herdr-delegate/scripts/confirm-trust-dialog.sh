#!/usr/bin/env bash
# Checks whether a freshly-started Claude agent pane is showing the first-run
# "trust this folder?" dialog, and if so, selects "Yes, I trust this folder"
# and waits for the agent to settle back to idle.
# No-ops (exit 0) if the dialog isn't showing.
#
# Only needed for brand-new repos that Claude Code has never seen before (see
# "現在の repo ではなく、新規 repo に対して使う場合" in SKILL.md). Linked worktrees
# of an already-trusted repo don't hit this dialog, so this step is unnecessary
# for the normal worktree-delegate flow.
#
# The dialog's default selection is "No, exit" in current Claude Code, so a bare
# Enter quits the agent (observed incident). Move the cursor onto the Yes option
# and confirm only after the pane shows it selected. Key names are lowercase
# (`down`, `enter`); `Down` / `Enter` are not recognized by `herdr agent send-keys`.
#
# Usage: confirm-trust-dialog.sh <pane_id>
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <pane_id>" >&2
  exit 2
fi

pane_id="$1"
script_dir=$(dirname "${BASH_SOURCE[0]}")

if ! "$script_dir/read-pane.sh" "$pane_id" | grep -q "trust this folder"; then
  exit 0
fi

selected_yes() {
  "$script_dir/read-pane.sh" "$pane_id" | grep "❯" | grep -q "Yes, I trust this folder"
}

for _ in 1 2 3 4; do
  selected_yes && break
  herdr agent send-keys "$pane_id" down > /dev/null
  sleep 0.5
done

if ! selected_yes; then
  echo "ERROR: could not select 'Yes, I trust this folder'; confirm the dialog manually" >&2
  "$script_dir/read-pane.sh" "$pane_id" >&2
  exit 1
fi

herdr agent send-keys "$pane_id" enter > /dev/null
herdr agent wait "$pane_id" --until idle --timeout 15000
