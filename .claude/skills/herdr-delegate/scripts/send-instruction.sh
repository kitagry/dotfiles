#!/usr/bin/env bash
# Sends an instruction to an idle Claude agent pane and confirms it was actually
# received (agent transitions to "working"), not just typed into the buffer.
#
# Usage: send-instruction.sh <pane_id> <instruction>
#
# `herdr agent prompt --wait --until working` submits the text and blocks until
# the agent's state changes (it handles the Enter/submit itself, unlike
# `agent send-keys` which only types literal keys). If it doesn't reach "working"
# within the timeout, this dumps the pane's recent output to stderr and exits 1
# so the caller can report the stuck state instead of assuming success.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <pane_id> <instruction>" >&2
  exit 2
fi

pane_id="$1"
instruction="$2"
script_dir=$(dirname "${BASH_SOURCE[0]}")

if herdr agent prompt "$pane_id" "$instruction" --wait --until working --timeout 20000 > /dev/null 2>&1; then
  exit 0
fi

echo "ERROR: agent did not transition to 'working' after 'herdr agent prompt'" >&2
"$script_dir/read-pane.sh" "$pane_id" >&2
exit 1
