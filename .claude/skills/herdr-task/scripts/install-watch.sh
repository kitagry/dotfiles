#!/usr/bin/env bash
# Installs the scheduler job that runs watch-tick.sh every 30 minutes: a
# LaunchAgent on macOS, a systemd user timer (oneshot service + timer) on Linux.
#
# Usage: install-watch.sh [--no-load]
#   --no-load  only write the plist / units; do not register them
#
# The job runs with the PATH of the shell that ran this script, so the
# tools the checks call (gh, jq, herdr, ...) resolve the same way. Run it again
# after that PATH changes; it replaces the job in place.
#
# Env: WATCH_SCHEDULER (launchd or systemd; default from uname),
# LAUNCH_AGENTS_DIR (default ~/Library/LaunchAgents), XDG_CONFIG_HOME (units go
# to $XDG_CONFIG_HOME/systemd/user, default ~/.config), HERDR_TASKS_ROOT (baked
# into the job when set, otherwise ~/tasks is used).
set -euo pipefail

load=1
case "${1:-}" in
  "") ;;
  --no-load) load=0 ;;
  *) echo "usage: $0 [--no-load]" >&2; exit 2 ;;
esac

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lib.sh"
scheduler=$(watch_scheduler)
root=$(tasks_root)
mkdir -p "$root"

install_launchd() {
  local label=$WATCH_LAUNCHD_LABEL agents_dir plist tasks_root_env=""
  agents_dir="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
  plist="$agents_dir/$label.plist"
  mkdir -p "$agents_dir"

  xml_escape() {
    printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
  }

  if [ -n "${HERDR_TASKS_ROOT:-}" ]; then
    tasks_root_env="    <key>HERDR_TASKS_ROOT</key><string>$(xml_escape "$HERDR_TASKS_ROOT")</string>"
  fi

  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$(xml_escape "$script_dir/watch-tick.sh")</string>
  </array>
  <key>StartInterval</key><integer>1800</integer>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$(xml_escape "$PATH")</string>
    <key>LANG</key><string>en_US.UTF-8</string>
$tasks_root_env
  </dict>
  <key>StandardOutPath</key><string>$(xml_escape "$root/.watch-launchd.log")</string>
  <key>StandardErrorPath</key><string>$(xml_escape "$root/.watch-launchd.log")</string>
</dict>
</plist>
PLIST
  plutil -lint "$plist" > /dev/null

  echo "wrote $plist"
  [ "$load" -eq 1 ] || return 0

  local domain attempt
  domain="gui/$(id -u)"
  # bootstrap fails if the label is already loaded, so unload first to make a re-run an update.
  launchctl bootout "$domain/$label" > /dev/null 2>&1 || true
  # bootout returns before the job is fully gone, so the first bootstrap can fail with an I/O error.
  for attempt in 1 2 3 4 5; do
    launchctl bootstrap "$domain" "$plist" && break
    [ "$attempt" -lt 5 ] || { echo "ERROR: launchctl bootstrap failed" >&2; exit 1; }
    sleep 1
  done
  echo "loaded $label (every 30 minutes); disable with: touch $root/.watch-disabled"
}

install_systemd() {
  local unit=$WATCH_SYSTEMD_UNIT unit_dir service timer tasks_root_env=""
  unit_dir=$(systemd_user_unit_dir)
  service="$unit_dir/$unit.service"
  timer="$unit_dir/$unit.timer"
  mkdir -p "$unit_dir"

  # A double-quoted word in a unit file: '%' starts a specifier everywhere, so
  # it is doubled. '$' is literal in Environment= and only special in ExecStart=.
  systemd_quote() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//%/%%}
    printf '"%s"' "$s"
  }
  systemd_exec_quote() {
    systemd_quote "${1//\$/\$\$}"
  }

  if [ -n "${HERDR_TASKS_ROOT:-}" ]; then
    tasks_root_env="Environment=$(systemd_quote "HERDR_TASKS_ROOT=$HERDR_TASKS_ROOT")"
  fi

  cat > "$service" <<UNIT
[Unit]
Description=herdr-task watcher: run watch.d checks and wake coordinators on change

[Service]
Type=oneshot
ExecStart=$(systemd_exec_quote "$script_dir/watch-tick.sh")
Environment=$(systemd_quote "PATH=$PATH")
$tasks_root_env
UNIT

  # A wall-clock schedule rather than OnUnitActiveSec: the monotonic clock
  # stops during suspend, and Persistent= runs a slot missed while asleep on
  # resume, like launchd's StartInterval does on wake.
  cat > "$timer" <<UNIT
[Unit]
Description=Run herdr-task watcher every 30 minutes

[Timer]
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target
UNIT
  if command -v systemd-analyze > /dev/null 2>&1; then
    systemd-analyze --user verify "$service" "$timer" > /dev/null
  fi

  echo "wrote $service and $timer"
  [ "$load" -eq 1 ] || return 0

  systemctl --user daemon-reload
  systemctl --user enable "$unit.timer"
  # restart rather than start, so a re-run picks up the rewritten timer.
  systemctl --user restart "$unit.timer"
  echo "enabled $unit.timer (every 30 minutes); disable with: touch $root/.watch-disabled"
  echo "logs: journalctl --user -u $unit.service"
}

case "$scheduler" in
  launchd) install_launchd ;;
  systemd) install_systemd ;;
esac
