#!/usr/bin/env bash
# Starts a new Claude Code agent in an already-open pane and waits until it's idle
# (i.e. past its own startup and at the input prompt).
#
# Usage: start-claude-agent.sh <pane_id>
#
# Frees up the "claude" agent name first (session-wide unique) by renaming any
# existing "claude" agent out of the way, then starts bare `claude` in the pane.
#
# IMPORTANT: do not pass extra flags like --mcp-config/--settings after `--`. The
# pane's shell is fish, whose `claude` wrapper function
# (~/.config/fish/functions/claude.fish) already injects --mcp-config and (on
# NixOS) --settings '{"remoteControlAtStartup": true}'. Passing them again here
# duplicates the command line and breaks argument parsing (confirmed incident:
# Remote Control silently stopped working because of this).
#
# `herdr agent start` right after `herdr worktree create` can race the new pane's
# shell still initializing, returning an `agent_pane_busy` error. Its exit code is
# not reliable for this case (observed exit 0 with an `.error` field present), so
# this checks the JSON body directly and retries a few times instead of trusting $?.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <pane_id>" >&2
  exit 2
fi

pane_id="$1"
script_dir=$(dirname "${BASH_SOURCE[0]}")

"$script_dir/rename-existing-claude.sh" > /dev/null

max_attempts=5
attempt=0
start_json=""
while [ "$attempt" -lt "$max_attempts" ]; do
  attempt=$((attempt + 1))
  start_json=$(herdr agent start claude --kind claude --pane "$pane_id" 2>&1)
  if ! printf '%s' "$start_json" | jq -e '.error' > /dev/null 2>&1; then
    break
  fi
  sleep 1
done

if printf '%s' "$start_json" | jq -e '.error' > /dev/null 2>&1; then
  echo "ERROR: herdr agent start failed after $max_attempts attempts" >&2
  echo "$start_json" >&2
  exit 1
fi

herdr agent wait "$pane_id" --until idle --timeout 60000
