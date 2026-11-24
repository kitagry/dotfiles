#!/usr/bin/env bash
# Tests for reply-state.sh. HERDR_TASKS_ROOT points at a scratch dir so the
# real ~/tasks/.reply-status is never touched.
# Run: bash tests/reply-state.test.sh
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../scripts/reply-state.sh"
fails=0

tmps=()
trap 'rm -rf "${tmps[@]}"' EXIT

setup() {
  tmp=$(mktemp -d)
  tmps+=("$tmp")
  export HERDR_TASKS_ROOT="$tmp/tasks"
  unset YOURTURN_REPLY_STATUS
  status="$HERDR_TASKS_ROOT/.reply-status"
}

check() { # <name> <condition exit code>
  if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

key=r-20261124T103201-a1b2

# 1. A valid key and state append "<key>\t<state>\t<RFC3339>", creating the root if needed.
setup
bash "$script" "$key" relayed
check "relayed: exit 0" $?
line=$(cat "$status")
[[ "$line" =~ ^$key$'\t'relayed$'\t'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})$ ]]
check "relayed: line is <key>\\t<state>\\t<RFC3339> (got: $line)" $?

# 2. Events are appended, never rewritten.
bash "$script" "$key" acked
check "acked: exit 0" $?
[ "$(wc -l < "$status" | tr -d ' ')" -eq 2 ]; check "acked: appended as a second line" $?
sed -n 2p "$status" | grep -q "^$key"$'\tacked\t'; check "acked: second line is the acked event" $?

# 3. Invalid input exits 2 and writes nothing.
for args in \
  "r-20261124T1032-a1b2 relayed" \
  "r-20261124T103201-A1B2 relayed" \
  "r-20261124T103201-a1b2x relayed" \
  "x$key relayed" \
  "$key sent" \
  "$key done" \
  "$key" \
  "" \
  "$key relayed extra"; do
  setup
  # shellcheck disable=SC2086 # split on purpose: each case is a word list
  bash "$script" $args > /dev/null 2>&1
  code=$?
  [ "$code" -eq 2 ] && [ ! -e "$status" ]
  check "invalid '$args': exit 2 (got $code), nothing written" $?
done

# 4. A key with a newline cannot smuggle in a second line.
setup
bash "$script" "$key"$'\n'"$key" relayed > /dev/null 2>&1
code=$?
[ "$code" -eq 2 ] && [ ! -e "$status" ]; check "newline in key: exit 2, nothing written" $?

# 5. A YOURTURN_REPLY_STATUS (the file yourturn reads) takes precedence over the tasks root.
setup
YOURTURN_REPLY_STATUS="$tmp/elsewhere/status" bash "$script" "$key" acked
check "YOURTURN_REPLY_STATUS: exit 0" $?
grep -q "^$key"$'\tacked\t' "$tmp/elsewhere/status" 2>/dev/null && [ ! -e "$status" ]
check "YOURTURN_REPLY_STATUS: written there, not under the tasks root" $?

exit "$fails"
