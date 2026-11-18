#!/usr/bin/env bash
# Tests for watch-tick.sh, install-watch.sh and uninstall-watch.sh. Everything
# runs in a scratch dir: HERDR_TASKS_ROOT points there, task-ask.sh is replaced
# by a stub, and launchctl is a fake on PATH, so no real LaunchAgent is touched.
# Run: bash tests/watch-tick.test.sh
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tick="$here/../scripts/watch-tick.sh"
install="$here/../scripts/install-watch.sh"
uninstall="$here/../scripts/uninstall-watch.sh"
fails=0

tmps=()
trap 'rm -rf "${tmps[@]}"' EXIT

setup() {
  tmp=$(mktemp -d)
  tmps+=("$tmp")
  export HERDR_TASKS_ROOT="$tmp/tasks"
  export WATCH_TASK_ASK="$tmp/task-ask-stub"
  export FAKE_ASK_LOG="$tmp/ask.log"
  export FAKE_LAUNCHCTL_LOG="$tmp/launchctl.log"
  export LAUNCH_AGENTS_DIR="$tmp/LaunchAgents"
  unset FAKE_ASK_EXIT WATCH_TIMEOUT
  : > "$FAKE_ASK_LOG"
  : > "$FAKE_LAUNCHCTL_LOG"
  mkdir -p "$tmp/bin" "$HERDR_TASKS_ROOT" "$LAUNCH_AGENTS_DIR"
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
  chmod +x "$WATCH_TASK_ASK" "$tmp/bin/launchctl"
  export PATH="$tmp/bin:$PATH"
}

# add_check <task> <name> <script body>
add_check() {
  mkdir -p "$HERDR_TASKS_ROOT/$1/watch.d"
  printf '#!/usr/bin/env bash\n%s\n' "$3" > "$HERDR_TASKS_ROOT/$1/watch.d/$2.sh"
  chmod +x "$HERDR_TASKS_ROOT/$1/watch.d/$2.sh"
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

# 13. install-watch.sh writes a valid plist and loads it via launchctl.
setup
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
bash "$install" --no-load > /dev/null 2>&1
[ -f "$LAUNCH_AGENTS_DIR/com.herdr-task.watch.plist" ] && [ ! -s "$FAKE_LAUNCHCTL_LOG" ]; check "install --no-load: no launchctl" $?

# 15. uninstall-watch.sh unloads and removes the plist; a second run is fine.
setup
bash "$install" --no-load > /dev/null 2>&1
bash "$uninstall" > /dev/null 2>&1
check "uninstall: exit 0" $?
[ ! -e "$LAUNCH_AGENTS_DIR/com.herdr-task.watch.plist" ]; check "uninstall: plist removed" $?
grep -q 'bootout' "$FAKE_LAUNCHCTL_LOG"; check "uninstall: launchctl bootout" $?
bash "$uninstall" > /dev/null 2>&1
check "uninstall: idempotent" $?

exit "$fails"
