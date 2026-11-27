#!/usr/bin/env bash
# Common watch check (run by watch-tick.sh in every task): lints the task's
# ACTIONS.md with `htask actions lint` and prints only the violations that are
# new since the last pass. The PostToolUse hook (actions-lint-hook.sh) catches
# Edit / Write; this catches edits made through Bash (sed -i, heredocs).
#
# A violation is remembered as "<ref> + the text of its line", not by line
# number, so adding items above it does not report it again. The first pass
# (no state yet) only remembers: existing violations are returned by the hook
# on the next edit, so they are not reported twice.
#
# The output names only line numbers and refs, never the line's text: it is
# typed into the coordinator's prompt, and the text may come from third parties.
#
# Exit 0 without output when there is no ACTIONS.md, no htask, or one older
# than HTASK_MIN_VERSION. When lint itself fails, exits 1 (watch-tick.sh logs
# it) and keeps the state. Must run on bash 3.2: launchd starts watch-tick.sh
# with /bin/bash.
set -uo pipefail

file=ACTIONS.md
[ -f "$file" ] || exit 0

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/../lib.sh"

version=$(htask_version) || exit 0
version_at_least "$version" "$HTASK_MIN_VERSION" || exit 0

lint=$(htask actions lint "$file")
rc=$?
case "$rc" in
  0 | 1) ;;
  *)
    echo "actions-lint: htask actions lint exited $rc" >&2
    exit 1
    ;;
esac

# One row per violation: "<line>\t<ref>\t<text of the line>".
rows=$(printf '%s\n' "$lint" | awk -v f="$file" '
  FILENAME == ARGV[1] { text[FNR] = $0; next }
  index($0, f ":") == 1 && / is not a link$/ {
    rest = substr($0, length(f ":") + 1)
    n = substr(rest, 1, index(rest, ":") - 1) + 0
    ref = substr(rest, index(rest, ": ") + 2)
    sub(/ is not a link$/, "", ref)
    t = text[n]
    gsub(/\t/, " ", t)
    print n "\t" ref "\t" t
  }' "$file" -)

state="$WATCH_STATE_DIR/actions-lint"
if [ -f "$state" ]; then
  new=$(printf '%s\n' "$rows" | awk -F '\t' -v f="$file" '
    FILENAME == ARGV[1] { seen[$0] = 1; next }
    NF && !(($2 "\t" $3) in seen) { printf "%s%s:%s: %s", (c++ ? ", " : ""), f, $1, $2 }
  ' "$state" -)
  if [ -n "$new" ]; then
    echo "$file has PR / issue references that are not links: $new. Rewrite them as [repo#N](https://github.com/<owner>/<repo>/pull/N) (issues: /issues/N) with Edit / Write."
  fi
fi

# Written once, at the end, so a pass that dies halfway leaves the old state.
# LC_ALL=C: watch-tick.sh runs checks under en_US.UTF-8, where sort -u
# treats lines differing only in emoji (the status marks) as equal and keeps
# one, so the dropped one would be reported as new on every pass.
tmp=$(mktemp "$state.XXXXXX") || exit 1
printf '%s\n' "$rows" | awk 'NF' | cut -f 2- | LC_ALL=C sort -u > "$tmp" && mv "$tmp" "$state" \
  || { rm -f "$tmp"; exit 1; }
