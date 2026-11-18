#!/usr/bin/env bash
# Installs the LaunchAgent that runs watch-tick.sh every 30 minutes.
#
# Usage: install-watch.sh [--no-load]
#   --no-load  only write the plist; do not register it with launchd
#
# The agent runs with the PATH of the shell that ran this script, so the
# tools the checks call (gh, jq, herdr, ...) resolve the same way. Run it again
# after that PATH changes; it replaces the agent in place.
#
# Env: LAUNCH_AGENTS_DIR (default ~/Library/LaunchAgents), HERDR_TASKS_ROOT
# (baked into the plist when set, otherwise ~/tasks is used).
set -euo pipefail

load=1
case "${1:-}" in
  "") ;;
  --no-load) load=0 ;;
  *) echo "usage: $0 [--no-load]" >&2; exit 2 ;;
esac

label=com.herdr-task.watch
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lib.sh"
agents_dir="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
plist="$agents_dir/$label.plist"
root=$(tasks_root)
mkdir -p "$agents_dir" "$root"

xml_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

tasks_root_env=""
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
[ "$load" -eq 1 ] || exit 0

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
