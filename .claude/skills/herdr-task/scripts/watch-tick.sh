#!/usr/bin/env bash
# One pass of the shared watcher: in every task, runs the common checks
# (watch.common.d/*.sh next to this script) and the task's own
# <tasks_root>/<task>/watch.d/*.sh, and wakes the task's coordinator only when
# a check printed something. Common checks are labeled "common/<name>" in
# messages and the log, so one named like a task's check stays distinct, and
# get their own state dir (watch.state/common) so their files cannot clash.
# launchd (macOS) or a systemd user timer (Linux) starts this every 30 minutes
# (see install-watch.sh); it runs once and exits, so there is no resident loop
# to leak or orphan.
#
# Per task, the outputs of all its checks are folded into one message:
#   task-ask.sh <task> "[watch] <output>" --no-wait
# If that fails (no coordinator running, or it is blocked on a prompt) the
# message is appended to <tasks_root>/.inbox instead, in task-report.sh's format.
#
# Closing a task moves its directory to _archive, so its checks stop running
# without any unregistering step.
#
# Files in <tasks_root>:
#   .watch-disabled  if present, do nothing
#   .watch-last      time of the last completed pass
#   .watch.log       failures and timeouts (capped to WATCH_LOG_MAX_LINES)
#   .watch.lock/     mutex held for the duration of a pass
#
# Env: WATCH_TIMEOUT (seconds per check, default 60), WATCH_LOG_MAX_LINES
# (default 500), WATCH_TASK_ASK (path to task-ask.sh, for tests),
# WATCH_COMMON_DIR (dir of the common checks, for tests).
set -uo pipefail

# launchd gives the job no LANG, so bash would count bytes: truncating a
# Japanese message below would cut a character in half.
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lib.sh"

root=$(tasks_root)
timeout_sec="${WATCH_TIMEOUT:-60}"
max_log_lines="${WATCH_LOG_MAX_LINES:-500}"
ask="${WATCH_TASK_ASK:-$script_dir/task-ask.sh}"
common_dir="${WATCH_COMMON_DIR:-$script_dir/watch.common.d}"
log="$root/.watch.log"
inbox="$root/.inbox"
lock="$root/.watch.lock"
# A message longer than this is cut: it is typed into the coordinator's prompt.
max_message_chars=2000

[ -d "$root" ] || exit 0
[ -e "$root/.watch-disabled" ] && exit 0

log_line() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$log"
}

# macOS has neither flock nor timeout, so mkdir is the atomic lock. The pid
# file lets a pass reclaim a lock left behind by a crash or reboot.
acquire_lock() {
  local holder
  if mkdir "$lock" 2>/dev/null; then
    echo "$$" > "$lock/pid"
    return 0
  fi
  holder=$(cat "$lock/pid" 2>/dev/null || true)
  if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
    return 1
  fi
  # No pid yet: the holder may be between its mkdir and writing the pid, so
  # only a lock that has stayed pid-less for a while counts as abandoned.
  if [ -z "$holder" ] && [ -z "$(find "$lock" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
    return 1
  fi
  rm -rf "$lock"
  mkdir "$lock" 2>/dev/null || return 1
  echo "$$" > "$lock/pid"
}

acquire_lock || exit 0
trap 'rm -rf "$lock"' EXIT

# Runs "$@" with a deadline, in its own process group so a hung check's
# children die with it. Exit 124 on timeout, 128+N if the command died of
# signal N, else the command's own status.
run_with_timeout() {
  perl -e '
    my $t = shift;
    my $pid = fork();
    if (!$pid) { setpgrp(0, 0); exec @ARGV or exit 127 }
    # The child is its own group leader, so killing the group spares this process.
    $SIG{ALRM} = sub { kill "TERM", -$pid; select(undef, undef, undef, 0.2); kill "KILL", -$pid; exit 124 };
    alarm $t;
    waitpid($pid, 0);
    exit(($? & 127) ? 128 + ($? & 127) : $? >> 8);
  ' "$timeout_sec" "$@"
}

wake() { # <task> <message>
  local task="$1" message="$2"
  # task-ask retries internally for up to ~2 minutes, so it gets a longer
  # deadline than a check; without one a hung herdr would hold the lock forever.
  if timeout_sec=180 run_with_timeout "$ask" "$task" "$message" --no-wait > /dev/null 2>&1; then
    return 0
  fi
  printf '%s\t%s\t%s\n' "$(date '+%F %T')" "$task" "$message" >> "$inbox"
}

# Has <dir> any *.sh in it?
has_checks() { # <dir>
  local f
  for f in "$1"/*.sh; do
    [ -f "$f" ] && return 0
  done
  return 1
}

run_task() { # <task dir>
  local dir="$1" task out msg="" check label state rc n=0
  local names=() outs=()
  task=$(basename "$dir")
  # Common checks first, then the task's own. Bash 3.2 (launchd's /bin/bash)
  # has no associative arrays, so the label prefix rides along in the loop.
  for check in "$common_dir"/*.sh "$dir"/watch.d/*.sh; do
    [ -f "$check" ] || continue
    label=$(basename "$check")
    state="$dir/watch.state"
    # Match on the glob's own prefix: comparing dirname with $common_dir
    # misses when WATCH_COMMON_DIR ends in "/".
    case "$check" in
      "$common_dir"/*)
        label="common/$label"
        state="$dir/watch.state/common"
        ;;
    esac
    if ! mkdir -p "$state" 2>> "$log"; then
      log_line "$task/$label skipped: cannot create $state"
      continue
    fi
    out=$(cd "$dir" && HERDR_TASK="$task" HERDR_TASK_DIR="$dir" WATCH_STATE_DIR="$state" \
      run_with_timeout bash "$check" 2>>"$log")
    rc=$?
    if [ "$rc" -ne 0 ]; then
      # Output of a check that failed or timed out is unreliable, so it is not forwarded.
      log_line "$task/$label exited $rc"
      continue
    fi
    [ -n "$out" ] || continue
    # One line per message, as the inbox and the coordinator's prompt expect.
    # Tabs would also break the inbox's tab-separated fields.
    out=$(printf '%s' "$out" | tr '\n\r\t' '   ' | sed 's/  */ /g; s/ *$//')
    n=$((n + 1))
    names[n]="${label%.sh}"
    outs[n]="$out"
  done
  # The check name is only worth showing when several checks report at once.
  local i
  for ((i = 1; i <= n; i++)); do
    if [ "$n" -gt 1 ]; then
      msg="${msg:+$msg | }${names[i]}: ${outs[i]}"
    else
      msg="${outs[i]}"
    fi
  done
  [ -n "$msg" ] || return 0
  if [ "${#msg}" -gt "$max_message_chars" ]; then
    msg="${msg:0:$max_message_chars}... (truncated)"
  fi
  wake "$task" "[watch] $msg"
}

has_common=0
has_checks "$common_dir" && has_common=1
for dir in "$root"/*/; do
  dir="${dir%/}"
  case "$(basename "$dir")" in _*|.*) continue ;; esac
  [ "$has_common" -eq 1 ] || has_checks "$dir/watch.d" || continue
  run_task "$dir"
done

if [ -f "$log" ] && [ "$(wc -l < "$log")" -gt "$max_log_lines" ]; then
  tail -n "$max_log_lines" "$log" > "$log.tmp" && mv "$log.tmp" "$log"
fi
date '+%F %T' > "$root/.watch-last"
