#!/usr/bin/env bash
# Unloads the watcher job (LaunchAgent on macOS, systemd user timer on Linux)
# and removes its files. Safe to run twice.
# Env: WATCH_SCHEDULER, LAUNCH_AGENTS_DIR, XDG_CONFIG_HOME (see install-watch.sh).
set -uo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lib.sh"
scheduler=$(watch_scheduler) || exit 1

case "$scheduler" in
  launchd)
    label=$WATCH_LAUNCHD_LABEL
    launchctl bootout "gui/$(id -u)/$label" > /dev/null 2>&1 || true
    rm -f "${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}/$label.plist"
    ;;
  systemd)
    label=$WATCH_SYSTEMD_UNIT
    unit_dir=$(systemd_user_unit_dir)
    systemctl --user disable --now "$label.timer" > /dev/null 2>&1 || true
    rm -f "$unit_dir/$label.service" "$unit_dir/$label.timer"
    systemctl --user daemon-reload > /dev/null 2>&1 || true
    # Otherwise a run that failed earlier stays listed by --failed after the unit is gone.
    systemctl --user reset-failed "$label.service" > /dev/null 2>&1 || true
    ;;
esac
echo "removed $label"
