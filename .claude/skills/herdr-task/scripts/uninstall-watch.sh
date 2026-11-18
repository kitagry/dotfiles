#!/usr/bin/env bash
# Unloads the watcher LaunchAgent and removes its plist. Safe to run twice.
# Env: LAUNCH_AGENTS_DIR (default ~/Library/LaunchAgents).
set -uo pipefail

label=com.herdr-task.watch
plist="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}/$label.plist"

launchctl bootout "gui/$(id -u)/$label" > /dev/null 2>&1 || true
rm -f "$plist"
echo "removed $label"
