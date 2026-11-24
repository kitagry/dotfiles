#!/usr/bin/env bash
# Tests for task-ask.sh with a fake `herdr` on PATH: one workspace with a
# "task" tab whose coordinator is idle (or working, via FAKE_AGENT_STATUS).
# `agent prompt` logs the text it was given and fails when FAKE_PROMPT_FAIL=1.
# HERDR_TASKS_ROOT points at a scratch dir for .reply-status.
# Run: bash tests/task-ask.test.sh
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../scripts/task-ask.sh"
fails=0

tmps=()
trap 'rm -rf "${tmps[@]}"' EXIT

setup() {
  tmp=$(mktemp -d)
  tmps+=("$tmp")
  export HERDR_TASKS_ROOT="$tmp/tasks"
  unset YOURTURN_REPLY_STATUS
  export FAKE_PROMPT_LOG="$tmp/prompt.log"
  status="$HERDR_TASKS_ROOT/.reply-status"
  unset FAKE_AGENT_STATUS FAKE_PROMPT_FAIL
  mkdir -p "$tmp/bin"
  : > "$FAKE_PROMPT_LOG"
  cat > "$tmp/bin/herdr" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in
  "workspace list") echo '{"result":{"workspaces":[{"workspace_id":"w1","label":"t1"}]}}' ;;
  "tab list") echo '{"result":{"tabs":[{"tab_id":"w1:t1","label":"task"}]}}' ;;
  "pane list") echo '{"result":{"panes":[{"pane_id":"w1:p1","tab_id":"w1:t1","label":"","agent":"claude"}]}}' ;;
  "agent list")
    printf '{"result":{"agents":[{"pane_id":"w1:p1","agent_status":"%s"}]}}\n' "${FAKE_AGENT_STATUS:-idle}" ;;
  "agent prompt")
    if [ "${FAKE_PROMPT_FAIL:-}" = 1 ]; then
      echo '{"error":{"code":"pane_not_found"}}'
      exit 1
    fi
    printf '%s\n' "$4" >> "$FAKE_PROMPT_LOG"
    echo '{"result":{}}' ;;
  "agent wait") echo '{"result":{}}' ;;
  "agent read") echo '' ;;
  *) echo "fake herdr: unexpected $*" >&2; exit 1 ;;
esac
FAKE
  chmod +x "$tmp/bin/herdr"
  export PATH="$tmp/bin:$PATH"
}

check() { # <name> <condition exit code>
  if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

key=r-20261124T103201-a1b2
key2=r-20261124T103305-00ff

# 1. A message with "(reply <key>)" records relayed once it is delivered.
setup
bash "$script" t1 "[yourturn] human reply: t1#2 OK (reply $key)" > /dev/null 2>&1
check "reply: exit 0" $?
grep -qF "[master] [yourturn] human reply: t1#2 OK (reply $key)" "$FAKE_PROMPT_LOG"
check "reply: message delivered with the reply key kept" $?
grep -q "^$key"$'\trelayed\t' "$status" 2>/dev/null; check "reply: relayed recorded" $?

# 2. Same with --no-wait while the coordinator is working (queued prompt).
setup
FAKE_AGENT_STATUS=working bash "$script" t1 "t1#2 OK (reply $key)" --no-wait > /dev/null 2>&1
check "no-wait: exit 0" $?
grep -q "^$key"$'\trelayed\t' "$status" 2>/dev/null; check "no-wait: relayed recorded" $?

# 3. Several replies batched in one message are all recorded.
setup
bash "$script" t1 "t1#1 A (reply $key) / t1#2 B (reply $key2)" --no-wait > /dev/null 2>&1
grep -q "^$key"$'\trelayed\t' "$status" 2>/dev/null \
  && grep -q "^$key2"$'\trelayed\t' "$status" 2>/dev/null
check "batched: every key recorded" $?

# 4. Not delivered: nothing is recorded.
setup
FAKE_PROMPT_FAIL=1 bash "$script" t1 "t1#2 OK (reply $key)" --no-wait > /dev/null 2>&1
[ $? -ne 0 ]; check "undelivered (idle): non-zero exit" $?
[ ! -e "$status" ]; check "undelivered (idle): nothing recorded" $?

setup
FAKE_AGENT_STATUS=working FAKE_PROMPT_FAIL=1 bash "$script" t1 "t1#2 OK (reply $key)" --no-wait > /dev/null 2>&1
[ $? -ne 0 ]; check "undelivered (working): non-zero exit" $?
[ ! -e "$status" ]; check "undelivered (working): nothing recorded" $?

# 5. Refused before sending (working without --no-wait): nothing is recorded.
setup
FAKE_AGENT_STATUS=working bash "$script" t1 "t1#2 OK (reply $key)" > /dev/null 2>&1
[ $? -ne 0 ] && [ ! -e "$status" ]; check "refused: nothing recorded" $?

# 6. A message without a reply key (or with a malformed one) records nothing.
setup
bash "$script" t1 "please rebase (reply r-123)" --no-wait > /dev/null 2>&1
check "no key: exit 0" $?
[ ! -e "$status" ]; check "no key: nothing recorded" $?

exit "$fails"
