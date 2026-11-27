#!/usr/bin/env bash
# Tests for the ACTIONS.md pane of task-create.sh with a fake `herdr` on PATH.
# Run: bash tests/task-create.test.sh
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
scripts="${TASK_CREATE_SCRIPTS:-$here/../scripts}"
script="$scripts/task-create.sh"
fails=0

tmps=()
trap 'rm -rf "${tmps[@]}"' EXIT

setup() {
  # pwd -P: is_trusted (lib.sh) resolves symlinks before looking the path up in .claude.json,
  # and macOS $TMPDIR is under /var -> /private/var.
  tmp=$(cd "$(mktemp -d)" && pwd -P)
  tmps+=("$tmp")
  export HOME="$tmp/home" HERDR_TASKS_ROOT="$tmp/tasks"
  export FAKE_HERDR_LOG="$tmp/herdr.log"
  : > "$FAKE_HERDR_LOG"
  mkdir -p "$tmp/bin" "$HOME" "$HERDR_TASKS_ROOT"
  jq -n --arg p "$HERDR_TASKS_ROOT" '{projects: {($p): {hasTrustDialogAccepted: true}}}' > "$HOME/.claude.json"
  cat > "$tmp/bin/herdr" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_HERDR_LOG"
case "$1 $2" in
  "workspace list") echo '{"result":{"workspaces":[]}}' ;;
  "workspace create") echo '{"result":{"workspace":{"workspace_id":"w1"},"root_pane":{"pane_id":"p1"},"tab":{"tab_id":"t1"}}}' ;;
  "pane split") echo '{"result":{"pane":{"pane_id":"p2"}}}' ;;
  *) echo '{}' ;;
esac
FAKE
  chmod +x "$tmp/bin/herdr"
  export PATH="$tmp/bin:$PATH"
}

check() { # <name> <condition exit code>
  if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

# 1. The right pane runs actions-view.sh (by absolute path, quoted for fish), not watch.
setup
bash "$script" t1 > /dev/null 2>&1
check "create: exit 0" $?
grep -qx 'pane split p1 --direction right --ratio 0.65 --cwd '"$HERDR_TASKS_ROOT"'/t1 --no-focus' "$FAKE_HERDR_LOG"; check "create: tab split" $?
view=$(cd "$scripts" && pwd)/actions-view.sh
grep -qxF "pane run p2 '$view' ACTIONS.md" "$FAKE_HERDR_LOG"; check "create: actions-view.sh started in the right pane" $?

# 2. Without an executable actions-view.sh (install.sh not re-run yet), the tab is not split,
#    so no pane is left showing "Unknown command".
setup
mkdir "$tmp/scripts"
cp "$scripts"/*.sh "$tmp/scripts/"
rm "$tmp/scripts/actions-view.sh"
err=$(TASK_CREATE_SCRIPTS="$tmp/scripts" bash "$tmp/scripts/task-create.sh" t2 2>&1 > /dev/null)
check "no viewer: exit 0" $?
! grep -q '^pane split' "$FAKE_HERDR_LOG"; check "no viewer: tab not split" $?
grep -q 'actions-view.sh is missing' <<< "$err"; check "no viewer: WARN" $?

exit "$fails"
