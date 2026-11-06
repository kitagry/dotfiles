#!/usr/bin/env bash
# Starts Claude Code in an already-open pane and waits until it's idle (past its
# own startup and at the input prompt).
#
# Usage: start-claude-agent.sh <pane_id> <agent_name> [--continue]
#   <agent_name> must be session-wide unique; use "<task>-<tab label>".
#   --continue resumes the latest Claude session of the pane's cwd (for tabs
#   opened with task-adopt.sh on a directory that already had one).
#
# IMPORTANT: do not pass extra flags like --mcp-config/--settings after `--`. The
# pane's shell is fish, whose `claude` wrapper function
# (~/.config/fish/functions/claude.fish) already injects --mcp-config and (on
# NixOS) --settings '{"remoteControlAtStartup": true}'. Passing them again
# duplicates the command line and Remote Control silently stops working
# (confirmed incident).
#
# `herdr agent start` right after a tab is created can race the new pane's shell
# still initializing (`agent_pane_busy`), and its exit code is not reliable for
# that case (observed exit 0 with an `.error` field), so this checks the JSON body
# and retries instead of trusting $?.
set -uo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <pane_id> <agent_name> [--continue]" >&2
  exit 2
fi

pane_id="$1"
name="$2"
agent_args=()
if [ "${3:-}" = "--continue" ]; then
  agent_args=(-- --continue)
fi

max_attempts=5
attempt=0
start_json=""
while [ "$attempt" -lt "$max_attempts" ]; do
  attempt=$((attempt + 1))
  start_json=$(herdr agent start "$name" --kind claude --pane "$pane_id" "${agent_args[@]}" 2>&1)
  if ! printf '%s' "$start_json" | jq -e '.error' > /dev/null 2>&1; then
    break
  fi
  if [ "$(printf '%s' "$start_json" | jq -r '.error.code' 2>/dev/null)" = "agent_name_taken" ]; then
    holder=$(printf '%s' "$start_json" | jq -r '.error.message' | grep -o 'pane_id=[A-Za-z0-9:]*' | head -1 | cut -d= -f2)
    # An earlier attempt already started it here.
    if [ "$holder" = "$pane_id" ]; then
      start_json='{}'
    fi
    break
  fi
  sleep 1
done

if printf '%s' "$start_json" | jq -e '.error' > /dev/null 2>&1; then
  echo "ERROR: herdr agent start failed after $attempt attempt(s)" >&2
  echo "$start_json" >&2
  exit 1
fi

# The trust dialog never reports idle. task-create.sh / task-add-repo.sh only
# allow trusted paths, so seeing it means the pane's cwd is outside them; fail
# fast instead of waiting out the timeout. Not answered automatically: accepting
# trust is the user's call.
script_dir=$(dirname "${BASH_SOURCE[0]}")
for _ in $(seq 1 30); do
  if "$script_dir/read-pane.sh" "$pane_id" | grep -q "trust this folder"; then
    echo "ERROR: Claude is asking to trust the pane's directory; answer it in the pane" >&2
    exit 1
  fi
  if herdr agent wait "$pane_id" --until idle --timeout 2000 > /dev/null 2>&1; then
    exit 0
  fi
done

echo "ERROR: agent did not become idle within 60s" >&2
"$script_dir/read-pane.sh" "$pane_id" >&2
exit 1
