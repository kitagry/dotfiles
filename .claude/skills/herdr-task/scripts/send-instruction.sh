#!/usr/bin/env bash
# Sends an instruction to an idle Claude agent pane and confirms it was actually
# received (agent transitions to "working"), not just typed into the buffer.
#
# Usage: send-instruction.sh <pane_id> <instruction>
#
# `herdr agent prompt --wait --until working` submits the text and blocks until
# the agent's state changes (it handles the Enter/submit itself, unlike
# `agent send-keys` which only types literal keys).
#
# Right after startup Claude Code reports idle a few seconds before its input box
# accepts keys, and the prompt is dropped (agent_prompt_stalled with nothing on
# screen). Retry only when the text is not visible in the pane: if it is, it was
# submitted, and a retry would send the instruction twice.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <pane_id> <instruction>" >&2
  exit 2
fi

pane_id="$1"
instruction="$2"
script_dir=$(dirname "${BASH_SOURCE[0]}")
# The first line, truncated, so the check survives the TUI wrapping long text.
needle=$(printf '%s' "$instruction" | head -1 | cut -c1-20)

out=""
for _ in 1 2 3 4 5; do
  if out=$(herdr agent prompt "$pane_id" "$instruction" --wait --until working --timeout 20000 2>&1) \
    && ! printf '%s' "$out" | jq -e '.error' > /dev/null 2>&1; then
    exit 0
  fi
  if [ "$(printf '%s' "$out" | jq -r '.error.code' 2>/dev/null)" != "agent_prompt_stalled" ]; then
    break
  fi
  if "$script_dir/read-pane.sh" "$pane_id" 60 | grep -qF -- "$needle"; then
    break
  fi
  sleep 2
done

echo "ERROR: agent did not transition to 'working' after 'herdr agent prompt'" >&2
echo "$out" >&2
"$script_dir/read-pane.sh" "$pane_id" >&2
exit 1
