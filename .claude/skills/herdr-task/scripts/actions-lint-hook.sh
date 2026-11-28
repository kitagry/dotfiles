#!/usr/bin/env bash
# Claude Code PostToolUse hook (Edit / Write / MultiEdit): when the edited file
# is a task's ACTIONS.md or the master's .master-actions.md, runs
# `htask actions lint` on it and, on violations, exits 2 so the Claude that
# wrote it gets the lines back and fixes them.
#
# Reads the hook payload (JSON) on stdin. Everything else passes with exit 0,
# and so does any failure of the hook itself: a broken hook must not block edits.
# Machines without htask, or with one older than HTASK_MIN_VERSION, are skipped.
set -uo pipefail

input=$(cat)
# Runs on every Edit / Write in every session, so drop unrelated files before
# starting any process (jq, htask). Match the end of a JSON string value: the
# payload also carries the file's content, which may mention ACTIONS.md.
case "$input" in
  *'/ACTIONS.md"'* | *'/.master-actions.md"'*) ;;
  *) exit 0 ;;
esac
command -v jq > /dev/null || exit 0
file=$(jq -r '.tool_input.file_path // empty' <<< "$input" 2> /dev/null) || exit 0
case "$file" in
  /*/ACTIONS.md | /*/.master-actions.md) ;;
  *) exit 0 ;;
esac

script_dir=$(dirname "${BASH_SOURCE[0]}")
source "$script_dir/lib.sh"

# Compare resolved paths: the tasks root or the file may be reached through a
# symlink (on macOS $TMPDIR is under /var -> /private/var).
root=$(abs_path "$(tasks_root)") || exit 0
path=$(abs_path "$file") || exit 0
rel=${path#"$root"/}
[ "$rel" != "$path" ] || exit 0
# Only <root>/<task>/ACTIONS.md and <root>/.master-actions.md. The aggregated
# <root>/ACTIONS.md and closed tasks under _archive/ are not linted.
case "$rel" in
  .master-actions.md) ;;
  _archive/*) exit 0 ;;
  */*/*) exit 0 ;;
  */ACTIONS.md) ;;
  *) exit 0 ;;
esac

version=$(htask_version) || exit 0
if ! version_at_least "$version" "$HTASK_MIN_VERSION"; then
  # On exit 0 Claude Code shows neither stdout nor stderr to anyone;
  # systemMessage is the field it surfaces to the user.
  jq -cn --arg m "actions-lint-hook: htask $version is older than $HTASK_MIN_VERSION, so ACTIONS.md is not linted. Run: mise up github:kitagry/htask" \
    '{systemMessage: $m}'
  exit 0
fi

out=$(htask actions lint "$file" 2>&1)
case $? in
  1)
    {
      printf '%s\n' "$out"
      echo "Write PR / issue references as links: [repo#N](https://github.com/<owner>/<repo>/pull/N) (issues: /issues/N)."
    } >&2
    exit 2
    ;;
  *) exit 0 ;;
esac
