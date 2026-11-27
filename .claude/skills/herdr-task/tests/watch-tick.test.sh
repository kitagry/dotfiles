#!/usr/bin/env bash
# Tests for watch-tick.sh, install-watch.sh and uninstall-watch.sh. Everything
# runs in a scratch dir: HERDR_TASKS_ROOT points there, task-ask.sh is replaced
# by a stub, and launchctl / systemctl are fakes on PATH, so no real LaunchAgent
# or systemd unit is touched.
# Run: bash tests/watch-tick.test.sh
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tick="$here/../scripts/watch-tick.sh"
install="$here/../scripts/install-watch.sh"
uninstall="$here/../scripts/uninstall-watch.sh"
fails=0
# plutil only exists on macOS. Elsewhere a no-op fake stands in so the launchd
# branch is still exercised (without the plist lint).
have_plutil=0
command -v plutil > /dev/null 2>&1 && have_plutil=1

tmps=()
trap 'rm -rf "${tmps[@]}"' EXIT

setup() {
  tmp=$(mktemp -d)
  tmps+=("$tmp")
  export HERDR_TASKS_ROOT="$tmp/tasks"
  export WATCH_TASK_ASK="$tmp/task-ask-stub"
  export FAKE_ASK_LOG="$tmp/ask.log"
  export FAKE_LAUNCHCTL_LOG="$tmp/launchctl.log"
  export FAKE_SYSTEMCTL_LOG="$tmp/systemctl.log"
  export LAUNCH_AGENTS_DIR="$tmp/LaunchAgents"
  export XDG_CONFIG_HOME="$tmp/config"
  # Empty by default, so the real watch.common.d (which runs htask) is never used.
  export WATCH_COMMON_DIR="$tmp/common"
  unset FAKE_ASK_EXIT WATCH_TIMEOUT WATCH_SCHEDULER
  : > "$FAKE_ASK_LOG"
  : > "$FAKE_LAUNCHCTL_LOG"
  : > "$FAKE_SYSTEMCTL_LOG"
  mkdir -p "$tmp/bin" "$HERDR_TASKS_ROOT" "$LAUNCH_AGENTS_DIR" "$WATCH_COMMON_DIR"
  # Stub: record "<task>|<message>|<flags>" and exit with FAKE_ASK_EXIT.
  cat > "$WATCH_TASK_ASK" <<'STUB'
#!/usr/bin/env bash
printf '%s|%s|%s\n' "$1" "$2" "${3:-}" >> "$FAKE_ASK_LOG"
exit "${FAKE_ASK_EXIT:-0}"
STUB
  cat > "$tmp/bin/launchctl" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_LAUNCHCTL_LOG"
FAKE
  cat > "$tmp/bin/systemctl" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_SYSTEMCTL_LOG"
FAKE
  chmod +x "$WATCH_TASK_ASK" "$tmp/bin/launchctl" "$tmp/bin/systemctl"
  if [ "$have_plutil" -eq 0 ]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/plutil"
    chmod +x "$tmp/bin/plutil"
  fi
  export PATH="$tmp/bin:$PATH"
}

# add_check <task> <name> <script body>
add_check() {
  mkdir -p "$HERDR_TASKS_ROOT/$1/watch.d"
  printf '#!/usr/bin/env bash\n%s\n' "$3" > "$HERDR_TASKS_ROOT/$1/watch.d/$2.sh"
  chmod +x "$HERDR_TASKS_ROOT/$1/watch.d/$2.sh"
}

# add_common <name> <script body>: a check every task runs.
add_common() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "$WATCH_COMMON_DIR/$1.sh"
  chmod +x "$WATCH_COMMON_DIR/$1.sh"
}

check() { # <name> <condition exit code>
  if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

# 1. Silent checks do not wake the coordinator.
setup
add_check t1 quiet 'exit 0'
bash "$tick" > /dev/null 2>&1
check "silent: exit 0" $?
[ ! -s "$FAKE_ASK_LOG" ]; check "silent: no wake" $?
[ -f "$HERDR_TASKS_ROOT/.watch-last" ]; check "silent: .watch-last written" $?

# 2. Output wakes the coordinator with --no-wait and a [watch] prefix.
setup
add_check t1 prs 'echo "PR 1 changed"'
bash "$tick" > /dev/null 2>&1
grep -qx 't1|\[watch\] PR 1 changed|--no-wait' "$FAKE_ASK_LOG"; check "output: task-ask called" $?
[ "$(wc -l < "$FAKE_ASK_LOG")" -eq 1 ]; check "output: exactly one wake" $?

# 3. Several checks of one task are folded into one wake; other tasks wake separately.
setup
add_check t1 a 'echo from-a'
add_check t1 b 'echo from-b'
add_check t2 c 'echo from-c'
bash "$tick" > /dev/null 2>&1
[ "$(grep -c '^t1|' "$FAKE_ASK_LOG")" -eq 1 ]; check "fold: one wake for t1" $?
grep '^t1|' "$FAKE_ASK_LOG" | grep -q 'from-a' && grep '^t1|' "$FAKE_ASK_LOG" | grep -q 'from-b'; check "fold: both outputs in it" $?
grep -q '^t2|' "$FAKE_ASK_LOG"; check "fold: t2 woken separately" $?

# 4. A message stays on one line even if a check prints several.
setup
add_check t1 multi 'printf "line1\nline2\n"'
bash "$tick" > /dev/null 2>&1
[ "$(wc -l < "$FAKE_ASK_LOG")" -eq 1 ] && grep -q 'line1.*line2' "$FAKE_ASK_LOG"; check "multiline: flattened" $?

# 5. No coordinator (task-ask fails): the report goes to the inbox instead.
setup
add_check t1 prs 'echo "PR 1 changed"'
FAKE_ASK_EXIT=1 bash "$tick" > /dev/null 2>&1
grep -q "$(printf 't1\t\\[watch\\] PR 1 changed')" "$HERDR_TASKS_ROOT/.inbox"; check "no coordinator: inbox line" $?
setup
add_check t1 prs 'echo "PR 1 changed"'
bash "$tick" > /dev/null 2>&1
[ ! -e "$HERDR_TASKS_ROOT/.inbox" ]; check "coordinator ok: inbox untouched" $?

# 6. .watch-disabled turns the whole thing off.
setup
add_check t1 prs 'echo changed'
touch "$HERDR_TASKS_ROOT/.watch-disabled"
bash "$tick" > /dev/null 2>&1
check "disabled: exit 0" $?
[ ! -s "$FAKE_ASK_LOG" ] && [ ! -e "$HERDR_TASKS_ROOT/.watch-last" ]; check "disabled: nothing ran" $?

# 7. A hanging check is killed after the timeout and does not block the others.
setup
add_check t1 hang 'sleep 30'
add_check t1 ok 'echo still-works'
start=$SECONDS
WATCH_TIMEOUT=1 bash "$tick" > /dev/null 2>&1
[ $((SECONDS - start)) -lt 15 ]; check "timeout: returns promptly" $?
grep -q 'still-works' "$FAKE_ASK_LOG"; check "timeout: other check still reported" $?

# 7b. A timeout is logged as 124, and a check killed by a signal is a failure too.
grep -q 'hang.sh exited 124' "$HERDR_TASKS_ROOT/.watch.log"; check "timeout: logged as 124" $?
setup
add_check t1 killed 'echo partial; kill -9 $$'
bash "$tick" > /dev/null 2>&1
[ ! -s "$FAKE_ASK_LOG" ]; check "signal: output not forwarded" $?
grep -q 'killed.sh exited 137' "$HERDR_TASKS_ROOT/.watch.log"; check "signal: logged as 137" $?

# 7c. Tabs in a check's output do not leak into the message.
setup
add_check t1 tabs 'printf "a\tb\n"'
bash "$tick" > /dev/null 2>&1
grep -q '^t1|\[watch\] a b|' "$FAKE_ASK_LOG"; check "tabs: flattened" $?

# 8. A failing check's output is not forwarded and is logged.
setup
add_check t1 bad 'echo partial; exit 3'
bash "$tick" > /dev/null 2>&1
[ ! -s "$FAKE_ASK_LOG" ]; check "failure: no wake" $?
grep -q 'bad.sh' "$HERDR_TASKS_ROOT/.watch.log"; check "failure: logged" $?

# 9. A live lock makes the tick a no-op; a stale lock is reclaimed.
setup
add_check t1 prs 'echo changed'
mkdir "$HERDR_TASKS_ROOT/.watch.lock"
echo "$$" > "$HERDR_TASKS_ROOT/.watch.lock/pid"
bash "$tick" > /dev/null 2>&1
[ ! -s "$FAKE_ASK_LOG" ]; check "live lock: skipped" $?
echo 999999 > "$HERDR_TASKS_ROOT/.watch.lock/pid"
bash "$tick" > /dev/null 2>&1
grep -q changed "$FAKE_ASK_LOG"; check "stale lock: reclaimed" $?
[ ! -e "$HERDR_TASKS_ROOT/.watch.lock" ]; check "lock: released after run" $?

# 10. Archived and hidden dirs are ignored; closing a task (dir moved) drops its checks.
setup
add_check _archive/2026-11/old prs 'echo archived'
add_check .hidden prs 'echo hidden'
bash "$tick" > /dev/null 2>&1
[ ! -s "$FAKE_ASK_LOG" ]; check "ignored dirs: no wake" $?

# 11. Checks get the task context and a state dir.
setup
add_check t1 env 'echo "$HERDR_TASK $(basename "$PWD") $(basename "$WATCH_STATE_DIR")"'
bash "$tick" > /dev/null 2>&1
grep -q 't1 t1 watch.state' "$FAKE_ASK_LOG"; check "env: task context passed" $?

# 12. The log is capped.
setup
add_check t1 quiet 'exit 0'
yes 'old log line' | head -n 5000 > "$HERDR_TASKS_ROOT/.watch.log"
WATCH_LOG_MAX_LINES=100 bash "$tick" > /dev/null 2>&1
[ "$(wc -l < "$HERDR_TASKS_ROOT/.watch.log")" -le 101 ]; check "log: capped" $?

# 12b. Common checks run in every task, even one without watch.d, with the same context.
setup
mkdir -p "$HERDR_TASKS_ROOT/t1" "$HERDR_TASKS_ROOT/_archive/old"
add_common env 'echo "$HERDR_TASK $(basename "$PWD") ${WATCH_STATE_DIR#"$HERDR_TASK_DIR/"}"'
bash "$tick" > /dev/null 2>&1
grep -qx 't1|\[watch\] t1 t1 watch.state/common|--no-wait' "$FAKE_ASK_LOG"; check "common: runs without watch.d" $?
[ -d "$HERDR_TASKS_ROOT/t1/watch.state/common" ]; check "common: own state dir" $?
! grep -q '_archive' "$FAKE_ASK_LOG"; check "common: archived tasks skipped" $?

# 12c. Labels: common checks are "common/<name>", so one named like a task's check stays distinct.
setup
add_common prs 'echo from-common'
add_check t1 prs 'echo from-task'
bash "$tick" > /dev/null 2>&1
grep -q '^t1|\[watch\] common/prs: from-common | prs: from-task|' "$FAKE_ASK_LOG"; check "common: both run, common first, labeled" $?
[ "$(wc -l < "$FAKE_ASK_LOG")" -eq 1 ]; check "common: folded into one wake" $?

# 12c2. A WATCH_COMMON_DIR with a trailing slash still marks its checks as common.
setup
mkdir -p "$HERDR_TASKS_ROOT/t1"
add_common env 'echo "${WATCH_STATE_DIR#"$HERDR_TASK_DIR/"}"'
WATCH_COMMON_DIR="$WATCH_COMMON_DIR/" bash "$tick" > /dev/null 2>&1
grep -qx 't1|\[watch\] watch.state/common|--no-wait' "$FAKE_ASK_LOG"; check "common: trailing slash in WATCH_COMMON_DIR" $?

# 12d. A failing common check is logged as common/<name> and not forwarded.
setup
mkdir -p "$HERDR_TASKS_ROOT/t1"
add_common bad 'echo partial; exit 3'
bash "$tick" > /dev/null 2>&1
[ ! -s "$FAKE_ASK_LOG" ]; check "common failure: no wake" $?
grep -q 't1/common/bad.sh exited 3' "$HERDR_TASKS_ROOT/.watch.log"; check "common failure: logged" $?

# 12e. A task dir with neither watch.d nor common checks is left alone.
setup
mkdir -p "$HERDR_TASKS_ROOT/t1"
bash "$tick" > /dev/null 2>&1
[ ! -e "$HERDR_TASKS_ROOT/t1/watch.state" ]; check "nothing to run: no state dir" $?

# 13. install-watch.sh writes a valid plist and loads it via launchctl.
setup
export WATCH_SCHEDULER=launchd
bash "$install" > /dev/null 2>&1
check "install: exit 0" $?
plist="$LAUNCH_AGENTS_DIR/com.herdr-task.watch.plist"
[ -f "$plist" ] && plutil -lint "$plist" > /dev/null 2>&1; check "install: valid plist" $?
grep -q '<integer>1800</integer>' "$plist"; check "install: StartInterval 1800" $?
grep -q 'watch-tick.sh' "$plist"; check "install: runs watch-tick.sh" $?
grep -q 'bootstrap' "$FAKE_LAUNCHCTL_LOG"; check "install: launchctl bootstrap" $?
bash "$install" > /dev/null 2>&1
check "install: idempotent" $?

# 14. --no-load only writes the plist.
setup
export WATCH_SCHEDULER=launchd
bash "$install" --no-load > /dev/null 2>&1
[ -f "$LAUNCH_AGENTS_DIR/com.herdr-task.watch.plist" ] && [ ! -s "$FAKE_LAUNCHCTL_LOG" ]; check "install --no-load: no launchctl" $?

# 15. uninstall-watch.sh unloads and removes the plist; a second run is fine.
setup
export WATCH_SCHEDULER=launchd
bash "$install" --no-load > /dev/null 2>&1
bash "$uninstall" > /dev/null 2>&1
check "uninstall: exit 0" $?
[ ! -e "$LAUNCH_AGENTS_DIR/com.herdr-task.watch.plist" ]; check "uninstall: plist removed" $?
grep -q 'bootout' "$FAKE_LAUNCHCTL_LOG"; check "uninstall: launchctl bootout" $?
bash "$uninstall" > /dev/null 2>&1
check "uninstall: idempotent" $?

# 16. On systemd, install writes a oneshot service and a 30-minute timer under
# $XDG_CONFIG_HOME/systemd/user and enables the timer.
setup
export WATCH_SCHEDULER=systemd
unit_dir="$XDG_CONFIG_HOME/systemd/user"
service="$unit_dir/herdr-task-watch.service"
timer="$unit_dir/herdr-task-watch.timer"
bash "$install" > /dev/null 2>&1
check "systemd install: exit 0" $?
[ -f "$service" ] && [ -f "$timer" ]; check "systemd install: units written" $?
grep -qx 'Type=oneshot' "$service"; check "systemd install: oneshot service" $?
grep -q '^ExecStart=.*watch-tick\.sh' "$service"; check "systemd install: runs watch-tick.sh" $?
grep -qx 'OnCalendar=\*:0/30' "$timer"; check "systemd install: every 30 minutes" $?
# Persistent= catches up on a slot missed during suspend, as launchd does on wake.
grep -qx 'Persistent=true' "$timer"; check "systemd install: catches up after suspend" $?
grep -q '^Environment="PATH=' "$service"; check "systemd install: PATH baked in" $?
grep -q 'daemon-reload' "$FAKE_SYSTEMCTL_LOG" && grep -q -- '--user enable herdr-task-watch.timer' "$FAKE_SYSTEMCTL_LOG"; check "systemd install: timer enabled" $?
grep -q -- '--user restart herdr-task-watch.timer' "$FAKE_SYSTEMCTL_LOG"; check "systemd install: timer (re)started" $?
if command -v systemd-analyze > /dev/null 2>&1; then
  systemd-analyze --user verify "$service" "$timer" > /dev/null 2>&1; check "systemd install: units verify" $?
fi
bash "$install" > /dev/null 2>&1
check "systemd install: idempotent" $?

# 17. HERDR_TASKS_ROOT is baked in, escaped for systemd ('%' is a specifier).
setup
export WATCH_SCHEDULER=systemd
export HERDR_TASKS_ROOT="$tmp/tasks 100%"
bash "$install" --no-load > /dev/null 2>&1
grep -qF "Environment=\"HERDR_TASKS_ROOT=$tmp/tasks 100%%\"" "$XDG_CONFIG_HOME/systemd/user/herdr-task-watch.service"; check "systemd install: tasks root escaped" $?
[ ! -s "$FAKE_SYSTEMCTL_LOG" ]; check "systemd install --no-load: no systemctl" $?

# 17b. '$' has no special meaning in Environment=, so it must not be doubled there.
setup
export WATCH_SCHEDULER=systemd
export HERDR_TASKS_ROOT="$tmp/ta\$ks"
bash "$install" --no-load > /dev/null 2>&1
grep -qF "Environment=\"HERDR_TASKS_ROOT=$tmp/ta\$ks\"" "$XDG_CONFIG_HOME/systemd/user/herdr-task-watch.service"; check "systemd install: '\$' kept literal in Environment=" $?

# 18. On systemd, uninstall disables the timer and removes both units.
setup
export WATCH_SCHEDULER=systemd
bash "$install" --no-load > /dev/null 2>&1
bash "$uninstall" > /dev/null 2>&1
check "systemd uninstall: exit 0" $?
[ ! -e "$XDG_CONFIG_HOME/systemd/user/herdr-task-watch.service" ] && [ ! -e "$XDG_CONFIG_HOME/systemd/user/herdr-task-watch.timer" ]; check "systemd uninstall: units removed" $?
grep -q -- '--user disable --now herdr-task-watch.timer' "$FAKE_SYSTEMCTL_LOG"; check "systemd uninstall: timer disabled" $?
grep -q -- '--user reset-failed herdr-task-watch.service' "$FAKE_SYSTEMCTL_LOG"; check "systemd uninstall: failed state cleared" $?
bash "$uninstall" > /dev/null 2>&1
check "systemd uninstall: idempotent" $?

# 19. An unknown scheduler is rejected.
setup
WATCH_SCHEDULER=cron bash "$install" --no-load > /dev/null 2>&1
[ $? -ne 0 ]; check "install: unknown scheduler rejected" $?

exit "$fails"
