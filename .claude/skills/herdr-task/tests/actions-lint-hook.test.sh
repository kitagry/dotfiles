#!/usr/bin/env bash
# Tests for actions-lint-hook.sh with a fake `htask` on PATH. HERDR_TASKS_ROOT
# points at a scratch dir, so the real ~/tasks is never read.
# The fake prints "htask $FAKE_HTASK_VERSION" for `version`, and for
# `actions lint <file>` logs the call, prints $FAKE_LINT_OUT and exits
# $FAKE_LINT_EXIT.
# Run: bash tests/actions-lint-hook.test.sh
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../scripts/actions-lint-hook.sh"
fails=0

tmps=()
trap 'rm -rf "${tmps[@]}"' EXIT

setup() {
  tmp=$(mktemp -d)
  tmps+=("$tmp")
  export HERDR_TASKS_ROOT="$tmp/tasks"
  export FAKE_HTASK_LOG="$tmp/htask.log" FAKE_HTASK_VERSION=0.2.0 FAKE_LINT_EXIT=0 FAKE_LINT_OUT=""
  : > "$FAKE_HTASK_LOG"
  mkdir -p "$tmp/bin" "$HERDR_TASKS_ROOT/t1" "$HERDR_TASKS_ROOT/_archive/2026-11/2026-11-01-old"
  touch "$HERDR_TASKS_ROOT/t1/ACTIONS.md" "$HERDR_TASKS_ROOT/t1/TASK.md" \
    "$HERDR_TASKS_ROOT/ACTIONS.md" "$HERDR_TASKS_ROOT/.master-actions.md" \
    "$HERDR_TASKS_ROOT/_archive/2026-11/2026-11-01-old/ACTIONS.md"
  cat > "$tmp/bin/htask" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_HTASK_LOG"
case "$1" in
  version) echo "htask $FAKE_HTASK_VERSION" ;;
  actions)
    [ -n "$FAKE_LINT_OUT" ] && printf '%s\n' "$FAKE_LINT_OUT"
    exit "$FAKE_LINT_EXIT"
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

# Runs the hook with a PostToolUse payload for <tool> on <file_path>; sets $code, $out and $err.
hook() { # <file_path> [tool]
  local payload
  payload=$(jq -n --arg p "$1" --arg t "${2:-Edit}" \
    '{hook_event_name: "PostToolUse", tool_name: $t, tool_input: {file_path: $p}}')
  out=$(bash "$script" <<< "$payload" 2> "$tmp/stderr")
  code=$?
  err=$(cat "$tmp/stderr")
}

linted() { grep -q '^actions lint' "$FAKE_HTASK_LOG"; }
htask_called() { [ -s "$FAKE_HTASK_LOG" ]; }

# 1. A task's ACTIONS.md with no violations: linted, passes silently.
setup
hook "$HERDR_TASKS_ROOT/t1/ACTIONS.md"
check "clean: exit 0" $code
grep -qx "actions lint $HERDR_TASKS_ROOT/t1/ACTIONS.md" "$FAKE_HTASK_LOG"; check "clean: lint ran on the file" $?
[ -z "$out$err" ]; check "clean: no output" $?

# 2. Violations: exit 2 with htask's lines and how to fix them on stderr.
setup
export FAKE_LINT_EXIT=1 FAKE_LINT_OUT="$HERDR_TASKS_ROOT/t1/ACTIONS.md:3: herdr-board#12 is not a link"
hook "$HERDR_TASKS_ROOT/t1/ACTIONS.md" Write
[ "$code" -eq 2 ]; check "violation: exit 2" $?
grep -qF "ACTIONS.md:3: herdr-board#12 is not a link" <<< "$err"; check "violation: htask output on stderr" $?
grep -qF "https://github.com/<owner>/<repo>/pull/N" <<< "$err"; check "violation: how to fix" $?

# 3. MultiEdit and .master-actions.md are covered too.
setup
export FAKE_LINT_EXIT=1 FAKE_LINT_OUT="x:1: #3 is not a link"
hook "$HERDR_TASKS_ROOT/.master-actions.md" MultiEdit
[ "$code" -eq 2 ]; check ".master-actions.md: exit 2" $?

# 4. Usage errors and other failures of htask do not block the edit.
for c in 2 3 127; do
  setup
  export FAKE_LINT_EXIT=$c FAKE_LINT_OUT="boom"
  hook "$HERDR_TASKS_ROOT/t1/ACTIONS.md"
  check "lint exit $c: exit 0" $code
done

# 5. Files outside the scope exit before htask is ever started.
# Paths are relative to the scratch dir, which setup creates anew each time.
for name in tasks/ACTIONS.md \
  tasks/_archive/ACTIONS.md \
  tasks/_archive/2026-11/2026-11-01-old/ACTIONS.md \
  tasks/t1/TASK.md \
  tasks/t1/sub/ACTIONS.md \
  tasks/t1/ACTIONS.md.bak \
  elsewhere/ACTIONS.md \
  elsewhere/.master-actions.md \
  other.md; do
  setup
  hook "$tmp/$name"
  check "out of scope ($name): exit 0" $code
  ! htask_called; check "out of scope ($name): htask not run" $?
done

# 6. Paths are compared after resolving symlinks, on both sides
#    (macOS $TMPDIR is under /var -> /private/var).
setup
ln -s "$HERDR_TASKS_ROOT" "$tmp/link"
hook "$tmp/link/t1/ACTIONS.md"
linted; check "symlinked file path: linted" $?
setup
ln -s "$HERDR_TASKS_ROOT" "$tmp/link"
real_root=$HERDR_TASKS_ROOT
HERDR_TASKS_ROOT="$tmp/link" hook "$real_root/t1/ACTIONS.md"
linted; check "symlinked tasks root: linted" $?

# 7. Relative paths are not guessed at; the payload's file_path is absolute.
setup
(cd "$HERDR_TASKS_ROOT/t1" && hook "ACTIONS.md")
check "relative path: exit 0" $code

# 8. No htask: nothing happens.
setup
# A PATH with only what the hook needs, so a real htask installed on the machine is not found.
mkdir "$tmp/min"
for c in bash cat dirname basename jq; do ln -s "$(command -v "$c")" "$tmp/min/$c"; done
PATH="$tmp/min" hook "$HERDR_TASKS_ROOT/t1/ACTIONS.md"
check "no htask: exit 0" $code
[ -z "$out$err" ]; check "no htask: no output" $?

# 9. htask older than HTASK_MIN_VERSION: a hint to upgrade, no lint, exit 0.
#    The hint goes in systemMessage: on exit 0 Claude Code shows no stderr.
for v in 0.1.0 0.1.99; do
  setup
  export FAKE_HTASK_VERSION=$v
  hook "$HERDR_TASKS_ROOT/t1/ACTIONS.md"
  check "old htask $v: exit 0" $code
  ! linted; check "old htask $v: lint not run" $?
  jq -e '.systemMessage | contains("mise up github:kitagry/htask")' <<< "$out" > /dev/null
  check "old htask $v: upgrade hint in systemMessage" $?
done

# 10. Newer and unparsable versions (a local `go build` says "dev") are linted.
for v in 0.2.1 0.10.0 1.0.0 0.2.1-0.20261127-abcdef dev; do
  setup
  export FAKE_HTASK_VERSION=$v
  hook "$HERDR_TASKS_ROOT/t1/ACTIONS.md"
  linted; check "htask $v: linted" $?
done

# 11. A payload without tool_input.file_path, or not JSON at all, passes.
setup
err=$(bash "$script" <<< '{"tool_name":"Bash","tool_input":{"command":"ls"}}' 2>&1 > /dev/null)
check "no file_path: exit 0" $?
err=$(bash "$script" <<< 'not json ACTIONS.md' 2>&1 > /dev/null)
check "bad json: exit 0" $?

exit "$fails"
