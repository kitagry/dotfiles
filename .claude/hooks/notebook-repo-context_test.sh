#!/usr/bin/env bash
# Tests for notebook-repo-context.sh. Run: bash .claude/hooks/notebook-repo-context_test.sh
set -u

HOOK="$(cd "$(dirname "$0")" && pwd)/notebook-repo-context.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export NOTEBOOK_DIR="$TMP/notebook"
mkdir -p "$NOTEBOOK_DIR/repos"
printf '%s\n' '- run make test before pushing' > "$NOTEBOOK_DIR/repos/acme__widget.md"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
git init -q "$TMP/widget"
git -C "$TMP/widget" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
git -C "$TMP/widget" remote add origin git@github.com:acme/widget.git
git -C "$TMP/widget" worktree add -q "$TMP/widget-wt" -b wt
mkdir -p "$TMP/widget/sub" "$TMP/plain"

FAILED=0
check() { # <name> <condition exit code>
  if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; FAILED=1; fi
}
run() { # <cwd> -> stdout, and the exit code in $rc
  out=$(printf '{"hook_event_name":"SessionStart","cwd":"%s"}' "$1" | bash "$HOOK")
  rc=$?
}

run "$TMP/widget"
[ $rc -eq 0 ] && printf '%s' "$out" | grep -q 'run make test before pushing'
check "repo root: prints the repo notes" $?
printf '%s' "$out" | grep -q 'acme/widget'; check "repo root: names the repo" $?

run "$TMP/widget/sub"
printf '%s' "$out" | grep -q 'run make test before pushing'; check "subdirectory: prints the repo notes" $?

run "$TMP/widget-wt"
printf '%s' "$out" | grep -q 'run make test before pushing'; check "worktree: prints the repo notes" $?

for url in https://github.com/acme/widget.git https://github.com/acme/widget ssh://git@github.com/acme/widget.git; do
  git -C "$TMP/widget" remote set-url origin "$url"
  run "$TMP/widget"
  printf '%s' "$out" | grep -q 'run make test before pushing'; check "remote url $url" $?
done

printf '%s\n' '- subgroup notes' > "$NOTEBOOK_DIR/repos/group__sub__widget.md"
for url in git@gitlab.example.com:group/sub/widget.git https://gitlab.example.com/group/sub/widget.git; do
  git -C "$TMP/widget" remote set-url origin "$url"
  run "$TMP/widget"
  printf '%s' "$out" | grep -q 'subgroup notes' && ! printf '%s' "$out" | grep -q 'run make test'
  check "subgroup remote $url: uses the full path" $?
done

git -C "$TMP/widget" remote set-url origin git@gitlab.example.com:other/widget.git
run "$TMP/widget"
[ $rc -eq 0 ] && [ -z "$out" ]; check "same repo name under another group: silent" $?

git -C "$TMP/widget" remote set-url origin git@github.com:acme/other.git
run "$TMP/widget"
[ $rc -eq 0 ] && [ -z "$out" ]; check "no notes for the repo: silent, exit 0" $?

git -C "$TMP/widget" remote remove origin
run "$TMP/widget"
[ $rc -eq 0 ] && [ -z "$out" ]; check "no origin: silent, exit 0" $?

run "$TMP/plain"
[ $rc -eq 0 ] && [ -z "$out" ]; check "outside git: silent, exit 0" $?

out=$(echo 'not json' | (cd "$TMP/plain" && bash "$HOOK")); rc=$?
[ $rc -eq 0 ] && [ -z "$out" ]; check "broken input: silent, exit 0" $?

git -C "$TMP/widget" remote add origin git@github.com:acme/widget.git
out=$(echo '{}' | (cd "$TMP/widget-wt" && bash "$HOOK")); rc=$?
[ $rc -eq 0 ] && printf '%s' "$out" | grep -q 'run make test before pushing'
check "no cwd in input: falls back to the working directory" $?

exit "$FAILED"
