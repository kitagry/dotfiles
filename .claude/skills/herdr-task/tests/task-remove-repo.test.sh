#!/usr/bin/env bash
# Tests for task-remove-repo.sh with a fake `herdr` on PATH.
# Worktrees have no remote here, so every call passes --force to skip the unpushed check.
# Run: bash tests/task-remove-repo.test.sh
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../scripts/task-remove-repo.sh"
fails=0

tmps=()
trap 'rm -rf "${tmps[@]}"' EXIT

setup() {
  tmp=$(mktemp -d)
  tmps+=("$tmp")
  export HERDR_TASKS_ROOT="$tmp/tasks"
  export FAKE_HERDR_LOG="$tmp/herdr.log"
  : > "$FAKE_HERDR_LOG"
  mkdir -p "$tmp/bin" "$HERDR_TASKS_ROOT/t1"
  cat > "$tmp/bin/herdr" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in
  "workspace list") echo '{"result":{"workspaces":[{"workspace_id":"w1","label":"t1"}]}}' ;;
  "tab list") echo '{"result":{"tabs":[{"tab_id":"tab-task","label":"task"},{"tab_id":"tab-ex","label":"example#123"},{"tab_id":"tab-plain","label":"plain"}]}}' ;;
  "tab close") echo "close $3" >> "$FAKE_HERDR_LOG" ;;
  *) ;;
esac
FAKE
  chmod +x "$tmp/bin/herdr"
  export PATH="$tmp/bin:$PATH"

  # A repo with a linked worktree named after the label.
  git init -q "$tmp/repo"
  git -C "$tmp/repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  git -C "$tmp/repo" worktree add -q -b ex "$HERDR_TASKS_ROOT/t1/example-123"
  git -C "$tmp/repo" worktree add -q -b pl "$HERDR_TASKS_ROOT/t1/plain"
  printf '# t1\n\n## Repos\n- `example#123`: x\n\n## Done\n' > "$HERDR_TASKS_ROOT/t1/TASK.md"
}

check() { # <name> <condition exit code>
  if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

# 1. The directory name (what task-status.sh prints) closes the tab.
setup
bash "$script" t1 example-123 --force > /dev/null 2>&1
check "dir name: exit 0" $?
grep -q "close tab-ex" "$FAKE_HERDR_LOG"; check "dir name: tab closed" $?
[ ! -e "$HERDR_TASKS_ROOT/t1/example-123" ]; check "dir name: worktree removed" $?
grep -q '^- `example#123`' <(sed -n '/## Done/,$p' "$HERDR_TASKS_ROOT/t1/TASK.md"); check "dir name: TASK.md moved to Done" $?

# 2. The exact label still works.
setup
bash "$script" t1 'example#123' --force > /dev/null 2>&1
check "label: exit 0" $?
grep -q "close tab-ex" "$FAKE_HERDR_LOG"; check "label: tab closed" $?

# 3. A label without special characters still works.
setup
bash "$script" t1 plain --force > /dev/null 2>&1
grep -q "close tab-plain" "$FAKE_HERDR_LOG"; check "plain: tab closed" $?

# 4. Unknown tab: error and nothing removed.
setup
bash "$script" t1 nope --force > /dev/null 2>&1
[ $? -ne 0 ]; check "unknown: non-zero exit" $?
[ -e "$HERDR_TASKS_ROOT/t1/plain" ] && [ -e "$HERDR_TASKS_ROOT/t1/example-123" ]; check "unknown: nothing removed" $?

# 5. Tab missing but worktree exists: error before removing the worktree.
setup
git -C "$tmp/repo" worktree add -q -b orphan "$HERDR_TASKS_ROOT/t1/orphan"
bash "$script" t1 orphan --force > /dev/null 2>&1
[ $? -ne 0 ] && [ -e "$HERDR_TASKS_ROOT/t1/orphan" ]; check "no tab: worktree kept" $?

# 6. No workspace for the task: the dir name still moves the TASK.md line to Done.
setup
cat > "$tmp/bin/herdr" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in
  "workspace list") echo '{"result":{"workspaces":[]}}' ;;
  *) ;;
esac
FAKE
bash "$script" t1 example-123 --force > /dev/null 2>&1
check "no workspace: exit 0" $?
[ ! -e "$HERDR_TASKS_ROOT/t1/example-123" ]; check "no workspace: worktree removed" $?
grep -q '^- `example#123`' <(sed -n '/## Done/,$p' "$HERDR_TASKS_ROOT/t1/TASK.md"); check "no workspace: TASK.md moved to Done" $?

exit "$fails"
