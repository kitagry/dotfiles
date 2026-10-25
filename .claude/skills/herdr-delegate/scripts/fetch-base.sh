#!/usr/bin/env bash
# Refreshes the remote-tracking ref of the base branch before create-worktree.sh
# forks from `origin/<base>`. Skipping this makes new worktrees branch off a
# stale base after PRs were merged from other sessions.
#
# Best-effort: a fetch failure (offline, auth) is reported but does not fail the
# delegate flow.
#
# Usage: fetch-base.sh <repo_root> <base>
set -uo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <repo_root> <base>" >&2
  exit 2
fi

repo_root="$1"
base="$2"

if ! git -C "$repo_root" fetch origin "$base" --quiet; then
  echo "WARN: git fetch origin $base failed; continuing with the existing origin/$base" >&2
fi
exit 0
