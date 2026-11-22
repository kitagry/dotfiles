#!/usr/bin/env bash
# Tests for actions-view.sh with a fake `mdcat` (and `yourturn`) on PATH. ACTIONS_VIEW_ONCE=1
# draws a single frame, and ACTIONS_VIEW_COLUMNS/ROWS stand in for the pane
# size, which `stty` cannot read without a terminal.
# Run: bash tests/actions-view.test.sh
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/../scripts/actions-view.sh"
fails=0

tmps=()
trap 'rm -rf "${tmps[@]}"' EXIT

ESC=$'\e'

setup() {
  tmp=$(mktemp -d)
  tmps+=("$tmp")
  mkdir -p "$tmp/bin"
  cat > "$tmp/bin/mdcat" <<'FAKE'
#!/usr/bin/env bash
echo "mdcat $*"
cat "${@: -1}"
FAKE
  chmod +x "$tmp/bin/mdcat"
  export PATH="$tmp/bin:$PATH"
  export ACTIONS_VIEW_ONCE=1 ACTIONS_VIEW_COLUMNS=42 ACTIONS_VIEW_ROWS=10
  # The mdcat loop is the fallback; a real yourturn on PATH must not take over.
  export ACTIONS_VIEW_YOURTURN=no-such-yourturn
  unset ACTIONS_VIEW_MDCAT YOURTURN_REPLY_CMD
  printf '# t1\n\n- [PR](https://example.com/pr/1)\n' > "$tmp/ACTIONS.md"
}

# Strips the cursor/clear escapes and OSC 8 closers that frame each line.
plain() { sed -E $'s/\e\\[[0-9;?]*[A-Za-z]//g; s/\e\\]8;;\e\\\\//g'; }

check() { # <name> <condition exit code>
  if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

# 1. mdcat renders with --ansi (its output is captured, not a tty) at the pane width.
setup
out=$(bash "$script" "$tmp/ACTIONS.md" 2>&1)
check "mdcat: exit 0" $?
grep -q -- "mdcat --ansi --columns 42 $tmp/ACTIONS.md" <<< "$out"; check "mdcat: --ansi --columns <pane width>" $?
grep -q 'example.com/pr/1' <<< "$out"; check "mdcat: content shown" $?

# 2. The frame is drawn over the previous one instead of after `clear`, so the pane does not flicker.
setup
out=$(bash "$script" "$tmp/ACTIONS.md" 2>/dev/null)
[[ "$out" == *"$ESC[H"* ]]; check "frame: cursor home" $?
[[ "$out" == *"$ESC[J"* ]]; check "frame: rest of screen cleared" $?
[[ "$out" != *"$ESC[2J"* ]]; check "frame: no full clear" $?

# 3. Without mdcat, the file is shown with cat.
setup
out=$(ACTIONS_VIEW_MDCAT=no-such-mdcat bash "$script" "$tmp/ACTIONS.md" 2>&1 | plain)
check "no mdcat: exit 0" $?
grep -q '^# t1' <<< "$out"; check "no mdcat: raw markdown shown" $?
! grep -q 'mdcat --ansi' <<< "$out"; check "no mdcat: mdcat not run" $?

# 4. A broken mdcat (e.g. missing shared libraries) falls back to cat.
setup
printf '#!/usr/bin/env bash\necho partial\necho broken >&2\nexit 127\n' > "$tmp/bin/mdcat"
out=$(bash "$script" "$tmp/ACTIONS.md" 2>&1 | plain)
grep -q '^# t1' <<< "$out"; check "broken mdcat: raw markdown shown" $?
! grep -q 'partial' <<< "$out"; check "broken mdcat: its partial output dropped" $?

# 5. A missing file shows a message instead of exiting, so the pane recovers once it appears.
setup
out=$(bash "$script" "$tmp/nope.md" 2>&1)
check "missing file: exit 0" $?
grep -q 'nope.md' <<< "$out"; check "missing file: message" $?

# 6. Output taller than the pane keeps the top (unfinished items) and says how much is hidden,
#    instead of scrolling the top out of view.
setup
seq 1 30 > "$tmp/ACTIONS.md"
out=$(ACTIONS_VIEW_MDCAT=no-such-mdcat bash "$script" "$tmp/ACTIONS.md" 2>/dev/null | plain)
lines=$(printf '%s' "$out" | awk 'END { print NR }')
[ "$lines" -eq 10 ]; check "tall: exactly <rows> lines (got $lines)" $?
grep -q '^1' <<< "$out" && ! grep -q '^10' <<< "$out"; check "tall: top kept" $?
grep -q '21 more lines' <<< "$out"; check "tall: hidden line count" $?

# 7. Long lines are cut, not wrapped, so the line count above matches the screen rows.
setup
out=$(bash "$script" "$tmp/ACTIONS.md" 2>/dev/null)
[[ "$out" == *"$ESC[?7l"* ]]; check "wrap: autowrap disabled while drawing" $?

# 8. An interval sleep cannot use is refused instead of turning the loop into a busy redraw.
setup
bash "$script" "$tmp/ACTIONS.md" abc > /dev/null 2>&1
[ $? -eq 2 ]; check "interval: non-numeric refused" $?
bash "$script" "$tmp/ACTIONS.md" 0 > /dev/null 2>&1
[ $? -eq 2 ]; check "interval: zero refused" $?

# 9. A resize (SIGWINCH) redraws at once instead of after the interval.
setup
unset ACTIONS_VIEW_ONCE
bash "$script" "$tmp/ACTIONS.md" 60 > "$tmp/out" 2>/dev/null &
pid=$!
sleep 0.5
kill -WINCH "$pid"
sleep 0.5
frames=$(grep -o "$ESC\\[H" "$tmp/out" | wc -l)
kill -TERM "$pid"
wait "$pid"
check "signal: exit 0 on TERM during the interval" $?
[ "$frames" -eq 2 ]; check "resize: redrawn at once (frames $frames)" $?

# Fake yourturn in <dir>: prints its args, and with FAKE_YOURTURN_REPLY=1
# (v0.2.0; v0.1.0 has no replies) runs $YOURTURN_REPLY_CMD the way yourturn
# does (sh -c) so the quoting is tested too.
fake_yourturn() { # <dir> [with reply script: 1]
  mkdir -p "$1"
  cat > "$1/yourturn" <<'FAKE'
#!/usr/bin/env bash
echo "yourturn $*"
[ "${FAKE_YOURTURN_REPLY:-}" = 1 ] && [ -n "${YOURTURN_REPLY_CMD:-}" ] && sh -c "$YOURTURN_REPLY_CMD"
exit 0
FAKE
  chmod +x "$1/yourturn"
  if [ "${2:-}" = 1 ]; then
    mkdir -p "$1/contrib/herdr"
    printf '#!/bin/sh\necho reply-script-ran\n' > "$1/contrib/herdr/yourturn-reply.sh"
    chmod +x "$1/contrib/herdr/yourturn-reply.sh"
  fi
}

# 10. With yourturn >= 0.2.0 (reply script next to the binary), it replaces the loop
#     and R replies go through contrib/herdr/yourturn-reply.sh.
setup
fake_yourturn "$tmp/yt dir's" 1
out=$(FAKE_YOURTURN_REPLY=1 ACTIONS_VIEW_YOURTURN="$tmp/yt dir's/yourturn" bash "$script" "$tmp/ACTIONS.md" 2>&1)
check "yourturn 0.2: exit 0" $?
grep -qx "yourturn $tmp/ACTIONS.md" <<< "$out"; check "yourturn 0.2: only the file passed (no flag 0.1 would refuse)" $?
grep -qx 'reply-script-ran' <<< "$out"; check "yourturn 0.2: reply command runs under sh -c (quoted path)" $?
! grep -q 'mdcat' <<< "$out"; check "yourturn 0.2: mdcat loop not run" $?

# 11. yourturn 0.1.0 ignores YOURTURN_REPLY_CMD: the viewer still starts (R is off).
setup
fake_yourturn "$tmp/yt" 1
out=$(ACTIONS_VIEW_YOURTURN="$tmp/yt/yourturn" bash "$script" "$tmp/ACTIONS.md" 2>&1)
grep -qx "yourturn $tmp/ACTIONS.md" <<< "$out"; check "yourturn 0.1: started with just the file" $?

# 12. The reply script not shipped next to the binary: no reply command set.
setup
fake_yourturn "$tmp/yt"
out=$(FAKE_YOURTURN_REPLY=1 ACTIONS_VIEW_YOURTURN="$tmp/yt/yourturn" bash "$script" "$tmp/ACTIONS.md" 2>&1)
grep -qx "yourturn $tmp/ACTIONS.md" <<< "$out" && ! grep -q 'reply-script-ran' <<< "$out"
check "no reply script: no reply command" $?

# 13. Found on PATH through a symlink: the reply script is looked up next to the real binary.
setup
fake_yourturn "$tmp/yt" 1
mkdir -p "$tmp/links"
ln -s "$tmp/yt/yourturn" "$tmp/links/yourturn"
out=$(PATH="$tmp/links:$PATH" FAKE_YOURTURN_REPLY=1 ACTIONS_VIEW_YOURTURN=yourturn bash "$script" "$tmp/ACTIONS.md" 2>&1)
grep -qx 'reply-script-ran' <<< "$out"; check "symlinked yourturn: reply script found" $?

# 14. A YOURTURN_REPLY_CMD the user set is kept.
setup
fake_yourturn "$tmp/yt" 1
out=$(YOURTURN_REPLY_CMD='echo user-cmd-ran' FAKE_YOURTURN_REPLY=1 ACTIONS_VIEW_YOURTURN="$tmp/yt/yourturn" bash "$script" "$tmp/ACTIONS.md" 2>&1)
grep -qx 'user-cmd-ran' <<< "$out" && ! grep -q 'reply-script-ran' <<< "$out"
check "user's YOURTURN_REPLY_CMD kept" $?

exit "$fails"
