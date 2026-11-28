#!/usr/bin/env bash
# Tests for watch.common.d/actions-lint.sh with a fake `htask` on PATH. It runs
# the way watch-tick.sh runs it: cwd is a scratch task dir, with HERDR_TASK,
# HERDR_TASK_DIR and WATCH_STATE_DIR set.
# The fake's `actions lint <file>` treats every whitespace-separated word of the
# form `repo#N` / `#N` as a violation (a linked `[repo#N](...)` is not such a
# word), printing htask's `<file>:<line>: <ref> is not a link` and exiting 1.
# FAKE_LINT_EXIT overrides the exit code; FAKE_HTASK_VERSION sets `version`.
# Run: bash tests/actions-lint.test.sh
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../scripts/watch.common.d/actions-lint.sh"
fails=0

tmps=()
trap 'rm -rf "${tmps[@]}"' EXIT

setup() {
  tmp=$(mktemp -d)
  tmps+=("$tmp")
  export HERDR_TASK=t1 HERDR_TASK_DIR="$tmp/t1" WATCH_STATE_DIR="$tmp/t1/watch.state/common"
  export FAKE_HTASK_VERSION=0.2.0
  unset FAKE_LINT_EXIT
  mkdir -p "$tmp/bin" "$WATCH_STATE_DIR"
  cat > "$tmp/bin/htask" <<'FAKE'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "version ") echo "htask $FAKE_HTASK_VERSION" ;;
  "actions lint")
    if [ -n "${FAKE_LINT_EXIT:-}" ]; then echo "lint broke" >&2; exit "$FAKE_LINT_EXIT"; fi
    awk -v f="$3" '{ for (i = 1; i <= NF; i++) if ($i ~ /^[a-z-]*#[0-9]+$/) { printf "%s:%d: %s is not a link\n", f, NR, $i; bad = 1 } }
      END { exit bad ? 1 : 0 }' "$3"
    ;;
  *) exit 2 ;;
esac
FAKE
  chmod +x "$tmp/bin/htask"
  export PATH="$tmp/bin:$PATH"
}

check() { # <name> <condition exit code>
  if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

write_actions() { printf '%s\n' "$@" > "$HERDR_TASK_DIR/ACTIONS.md"; }

# Runs the check; sets $code, $out and $err.
run() {
  out=$(cd "$HERDR_TASK_DIR" && bash "$script" 2> "$tmp/stderr")
  code=$?
  err=$(cat "$tmp/stderr")
}

# 1. First run (no state): remembers the current violations, prints nothing.
setup
write_actions '- **🔴 1 merge herdr-board#12 ?**' '  - see #5'
run
check "first run: exit 0" $code
[ -z "$out" ]; check "first run: silent" $?
[ -s "$WATCH_STATE_DIR/actions-lint" ]; check "first run: state written" $?

# 2. Nothing changed: silent.
run
check "unchanged: exit 0" $code
[ -z "$out" ]; check "unchanged: silent" $?

# 3. A new violation: only that one is printed, with its current line number and a fix.
write_actions '- **🔴 1 merge herdr-board#12 ?**' '  - see #5' '- **🟢 2 look at htask#7 secret-text**'
run
check "new: exit 0" $code
grep -qF 'ACTIONS.md:3: htask#7' <<< "$out"; check "new: line and ref" $?
! grep -qF 'herdr-board#12' <<< "$out" && ! grep -qF '#5' <<< "$out"; check "new: old ones not repeated" $?
grep -qF '[repo#N](https://github.com/<owner>/<repo>/pull/N)' <<< "$out"; check "new: how to fix" $?
! grep -qF 'secret-text' <<< "$out"; check "new: line content not printed" $?
[ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ]; check "new: one line" $?

# 4. Items added above shift every line: nothing new, so silent.
write_actions '- **🟠 3 added on top**' '' '- **🔴 1 merge herdr-board#12 ?**' '  - see #5' '- **🟢 2 look at htask#7 secret-text**'
run
[ -z "$out" ]; check "shifted lines: silent" $?

# 5. Fixing violations is silent; one that comes back later is reported again.
write_actions '- **🔴 1 merge [herdr-board#12](https://github.com/kitagry/herdr-board/pull/12) ?**'
run
check "fixed: exit 0" $code
[ -z "$out" ]; check "fixed: silent" $?
write_actions '- **🔴 1 merge herdr-board#12 ?**'
run
grep -qF 'ACTIONS.md:1: herdr-board#12' <<< "$out"; check "came back: reported" $?

# 6. Two new violations go on the same line.
setup
write_actions 'nothing here'
run
write_actions 'a#1 and' 'b#2'
run
grep -qF 'ACTIONS.md:1: a#1' <<< "$out" && grep -qF 'ACTIONS.md:2: b#2' <<< "$out"; check "two new: both listed" $?
[ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ]; check "two new: one line" $?

# 6b. Lines that differ only in their status mark are both remembered, even
# under the UTF-8 locale watch-tick.sh exports (its sort -u would merge them).
setup
write_actions '- **🟠 1 x#1 ?**' '- **🟢 1 x#1 ?**'
LC_ALL=en_US.UTF-8 run
LC_ALL=en_US.UTF-8 run
[ -z "$out" ]; check "emoji-only difference: silent on the second run" $?

# 7. lint fails (exit 2 etc.): exit non-zero so watch-tick logs it, state kept.
setup
write_actions 'x#1'
run
cp "$WATCH_STATE_DIR/actions-lint" "$tmp/before"
write_actions 'x#1' 'y#2'
FAKE_LINT_EXIT=2 run
[ "$code" -ne 0 ]; check "lint failure: non-zero exit" $?
[ -z "$out" ]; check "lint failure: nothing on stdout" $?
cmp -s "$tmp/before" "$WATCH_STATE_DIR/actions-lint"; check "lint failure: state kept" $?
run
grep -qF 'y#2' <<< "$out"; check "lint failure: reported on the next good run" $?

# 8. No htask, or one older than HTASK_MIN_VERSION: silent, exit 0, no state.
setup
write_actions 'x#1'
rm "$tmp/bin/htask"
mkdir "$tmp/min"
for c in bash cat dirname basename awk sed grep sort mv mktemp rm; do
  p=$(command -v "$c") && ln -s "$p" "$tmp/min/$c"
done
out=$(cd "$HERDR_TASK_DIR" && PATH="$tmp/min" bash "$script" 2>&1)
check "no htask: exit 0" $?
[ -z "$out" ]; check "no htask: silent" $?
[ ! -e "$WATCH_STATE_DIR/actions-lint" ]; check "no htask: no state" $?
setup
write_actions 'x#1'
FAKE_HTASK_VERSION=0.1.0 run
check "old htask: exit 0" $code
[ -z "$out$err" ]; check "old htask: silent" $?
[ ! -e "$WATCH_STATE_DIR/actions-lint" ]; check "old htask: no state" $?

# 9. No ACTIONS.md: silent, exit 0.
setup
mkdir -p "$HERDR_TASK_DIR"
run
check "no ACTIONS.md: exit 0" $code
[ -z "$out" ]; check "no ACTIONS.md: silent" $?

exit "$fails"
