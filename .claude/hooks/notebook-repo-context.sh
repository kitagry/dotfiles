#!/usr/bin/env bash
# SessionStart hook: puts the notebook's notes for the session's repo into
# context. The repo is named by its origin remote (owner/repo), so the same
# notes reach the main checkout and every worktree, which have no shared
# untracked files such as CLAUDE.local.md.
#
# Reads ${NOTEBOOK_DIR:-~/notebook}/repos/<owner>__<repo>.md (each / of the
# path becomes __). Prints nothing when there is no such file, no origin, or
# no git repo. Always exits 0: a broken hook must not block the session from
# starting.
set -u

input=$(cat 2> /dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2> /dev/null)
[ -n "$cwd" ] || cwd="$PWD"

url=$(git -C "$cwd" remote get-url origin 2> /dev/null) || exit 0
# The whole path after the host, not just its last two segments: GitLab
# subgroups (group/sub/repo) would otherwise share notes across groups.
# Handles scheme://[user@]host[:port]/path and scp-like [user@]host:path.
slug=$(printf '%s' "$url" | sed -E 's#\.git/?$##; s#/$##; s#^[A-Za-z][A-Za-z0-9+.-]*://[^/]*/##; /:\/\//!s#^[^/:]*:##')
case "$slug" in
  [!/]*/*) ;;
  *) exit 0 ;;
esac

file="${NOTEBOOK_DIR:-$HOME/notebook}/repos/${slug//\//__}.md"
[ -f "$file" ] || exit 0

printf 'Notes on %s from the notebook (%s):\n\n' "$slug" "$file"
cat "$file" 2> /dev/null
exit 0
