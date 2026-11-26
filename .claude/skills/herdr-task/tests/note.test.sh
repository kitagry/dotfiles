#!/usr/bin/env bash
# Tests for note.sh with a fake `herdr` on PATH: workspace "t1" has tabs
# "task" (pane w1:p1) and "bqls#671" (pane w1:p2); workspace "m" is labeled
# "master". NOTEBOOK_DIR points at a scratch dir so the real notebook is never
# written. Lines are parsed with yq when it is installed.
# Run: bash tests/note.test.sh
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../scripts/note.sh"
fails=0

tmps=()
trap 'rm -rf "${tmps[@]}"' EXIT

setup() {
  tmp=$(mktemp -d)
  tmps+=("$tmp")
  export NOTEBOOK_DIR="$tmp/notebook"
  mkdir -p "$NOTEBOOK_DIR"
  notes="$NOTEBOOK_DIR/notes/$(date +%F).md"
  unset HERDR_TASK HERDR_PANE_ID HERDR_WORKSPACE_ID
  mkdir -p "$tmp/bin" "$tmp/cwd/some-repo"
  cat > "$tmp/bin/herdr" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in
  "workspace list") echo '{"result":{"workspaces":[{"workspace_id":"w1","label":"t1"},{"workspace_id":"m","label":"master"}]}}' ;;
  "tab list") echo '{"result":{"tabs":[{"tab_id":"w1:t1","label":"task"},{"tab_id":"w1:t2","label":"bqls#671"}]}}' ;;
  "pane list") echo '{"result":{"panes":[{"pane_id":"w1:p1","tab_id":"w1:t1"},{"pane_id":"w1:p2","tab_id":"w1:t2"}]}}' ;;
  *) echo "fake herdr: unexpected $*" >&2; exit 1 ;;
esac
FAKE
  chmod +x "$tmp/bin/herdr"
  export PATH="$tmp/bin:$PATH"
}

check() { # <name> <condition exit code>
  if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

# Prints the {...} of the last line of the notes file as JSON. <text> is the
# note's text, cut off by length since it may itself contain braces.
attrs() { # <text>
  local line
  line=$(tail -1 "$notes")
  # Bash substrings count characters like ${#1} does; cut -c counts bytes.
  printf '%s' "${line:$((9 + ${#1}))}" | yq -o=json -I=0 '.'
}

have_yq=0
command -v yq > /dev/null && have_yq=1

# 1. From a repo tab of a task: task and tab label, inferred, waiting.
setup
(cd "$tmp/cwd/some-repo" && HERDR_TASK=t1 HERDR_WORKSPACE_ID=w1 HERDR_PANE_ID=w1:p2 \
  bash "$script" "helpers should follow the existing ones") > /dev/null 2>&1
check "repo tab: exit 0" $?
grep -Eq '^- [0-9]{2}:[0-9]{2} helpers should follow the existing ones \{.*\}$' "$notes" 2>/dev/null
check "repo tab: '- HH:MM <text> {...}' line" $?
if [ "$have_yq" = 1 ]; then
  [ "$(attrs "helpers should follow the existing ones")" = '{"src":"inferred","task":"t1","tab":"bqls#671","state":"waiting"}' ]
  check "repo tab: attrs parse as YAML with a quoted '#'" $?
fi

# 2. From the coordinator: tab is "task".
setup
HERDR_TASK=t1 HERDR_WORKSPACE_ID=w1 HERDR_PANE_ID=w1:p1 bash "$script" "x" > /dev/null 2>&1
grep -q '{src: inferred, task: t1, tab: task, state: waiting}$' "$notes" 2>/dev/null
check "coordinator: tab: task" $?

# 3. From the master workspace (outside a task).
setup
HERDR_WORKSPACE_ID=m HERDR_PANE_ID=m:p1 bash "$script" "x" > /dev/null 2>&1
grep -q '{src: inferred, task: master, tab: master, state: waiting}$' "$notes" 2>/dev/null
check "master: task: master, tab: master" $?

# 4. Outside herdr and not master: task none, tab is the cwd basename.
setup
(cd "$tmp/cwd/some-repo" && bash "$script" "x") > /dev/null 2>&1
grep -q '{src: inferred, task: none, tab: some-repo, state: waiting}$' "$notes" 2>/dev/null
check "elsewhere: task: none, tab: cwd basename" $?

# 5. Flags.
setup
(cd "$tmp/cwd/some-repo" && bash "$script" "x" --said --applied --repo kitagry/bqls) > /dev/null 2>&1
grep -q '{src: said, task: none, tab: some-repo, state: applied, repo: kitagry/bqls}$' "$notes" 2>/dev/null
check "flags: said, applied, repo" $?

setup
(cd "$tmp/cwd/some-repo" && bash "$script" --said --repo kitagry/bqls "y") > /dev/null 2>&1
grep -q ' y {src: said, task: none, tab: some-repo, state: waiting, repo: kitagry/bqls}$' "$notes" 2>/dev/null
check "flags: may come before the text" $?

setup
(cd "$tmp/cwd/some-repo" && bash "$script" --applied) > /dev/null 2>&1
[ $? -ne 0 ] && [ ! -e "$notes" ]; check "flags: a flag alone is not written as a note" $?

setup
(cd "$tmp/cwd/some-repo" && bash "$script" "x" --repo not-a-repo) > /dev/null 2>&1
[ $? -ne 0 ] && [ ! -e "$notes" ]; check "flags: malformed --repo is refused" $?

# 6. Newlines in the text become spaces; braces in the text are kept.
setup
(cd "$tmp/cwd/some-repo" && bash "$script" $'first line\nsecond {a: b}') > /dev/null 2>&1
[ "$(wc -l < "$notes")" -eq 1 ]; check "newline: one line written" $?
grep -q ' first line second {a: b} {src:' "$notes" 2>/dev/null; check "newline: replaced by a space" $?
if [ "$have_yq" = 1 ]; then
  [ "$(attrs "first line second {a: b}" | jq -r .tab)" = some-repo ]; check "braces in text: attrs still parse" $?
fi

# 7. Values with YAML-special characters are quoted.
setup
mkdir -p "$tmp/cwd/it's: {x}"
(cd "$tmp/cwd/it's: {x}" && bash "$script" "x") > /dev/null 2>&1
if [ "$have_yq" = 1 ]; then
  [ "$(attrs x | jq -r .tab)" = "it's: {x}" ]; check "quoting: special chars round-trip" $?
fi
setup
mkdir -p "$tmp/cwd/null"
(cd "$tmp/cwd/null" && bash "$script" "x") > /dev/null 2>&1
if [ "$have_yq" = 1 ]; then
  [ "$(attrs x | jq -c .tab)" = '"null"' ]; check "quoting: YAML keywords stay strings" $?
fi
setup
mkdir -p "$tmp/cwd/YES"
(cd "$tmp/cwd/YES" && bash "$script" "x") > /dev/null 2>&1
grep -q "tab: 'YES'" "$notes" 2>/dev/null; check "quoting: upper-case YAML 1.1 booleans are quoted" $?

# 8. Concurrent writers do not lose or interleave lines.
setup
for i in $(seq 1 30); do
  (cd "$tmp/cwd/some-repo" && bash "$script" "note $i") > /dev/null 2>&1 &
done
wait
[ "$(grep -c '^- [0-9:]* note [0-9]* {src: inferred, task: none, tab: some-repo, state: waiting}$' "$notes")" -eq 30 ]
check "concurrent: 30 whole lines" $?

# 9. Errors.
setup
rm -rf "$NOTEBOOK_DIR"
out=$( (cd "$tmp/cwd/some-repo" && bash "$script" "x") 2>&1)
[ $? -ne 0 ]; check "no notebook: non-zero exit" $?
printf '%s' "$out" | grep -q "$NOTEBOOK_DIR"; check "no notebook: error names the path" $?

setup
(cd "$tmp/cwd/some-repo" && bash "$script" "") > /dev/null 2>&1
[ $? -ne 0 ]; check "empty text: non-zero exit" $?

exit "$fails"
