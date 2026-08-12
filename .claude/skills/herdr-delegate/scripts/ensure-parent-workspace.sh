#!/usr/bin/env bash
# Prints the workspace_id of the parent herdr workspace for the given repo root.
# If none exists, creates one after refreshing the repo:
#   - `git fetch origin` (always)
#   - if working tree is clean: `git switch <default>` + `git pull --ff-only`
#   - if dirty: skip switch/pull and emit a warn to stderr
# Then `herdr workspace create --cwd <repo_root> --no-focus --json` and returns the new id.
#
# Usage: ensure-parent-workspace.sh <repo_root> [label]
#
# stdout: workspace_id (existing or newly created)
# stderr: progress / warnings / errors
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <repo_root> [label]" >&2
  exit 2
fi

repo_root="$1"
label="${2:-$(basename "$repo_root")}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Existing workspace? Return it.
if ws_id=$("$here/find-parent-workspace.sh" "$repo_root" "$label" 2>/dev/null); then
  echo "$ws_id"
  exit 0
fi

# 2. Validate repo_root is a git repo.
if ! git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: not a git repo: $repo_root" >&2
  exit 1
fi

# 3. Determine default branch (origin/HEAD → strip 'origin/').
default_branch=$(git -C "$repo_root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)
if [ -z "$default_branch" ]; then
  # Ask remote as a fallback (works even when local origin/HEAD is not set).
  default_branch=$(git -C "$repo_root" ls-remote --symref origin HEAD 2>/dev/null \
    | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2; exit}' || true)
fi
if [ -z "$default_branch" ]; then
  default_branch=main
  echo "WARN: could not resolve default branch, falling back to '$default_branch'" >&2
fi

echo "INFO: refreshing $repo_root (default=$default_branch)" >&2

# 4. Fetch is always safe.
if ! git -C "$repo_root" fetch origin --quiet 2>&1; then
  echo "WARN: 'git fetch origin' failed in $repo_root, continuing" >&2
fi

# 5. Only switch + pull when working tree is clean.
if [ -z "$(git -C "$repo_root" status --porcelain)" ]; then
  current_branch=$(git -C "$repo_root" symbolic-ref --short HEAD 2>/dev/null || true)
  if [ "$current_branch" != "$default_branch" ]; then
    if ! git -C "$repo_root" switch "$default_branch" --quiet 2>&1; then
      echo "WARN: 'git switch $default_branch' failed in $repo_root" >&2
    fi
  fi
  if ! git -C "$repo_root" pull --ff-only --quiet 2>&1; then
    echo "WARN: 'git pull --ff-only' failed in $repo_root" >&2
  fi
else
  echo "WARN: $repo_root has uncommitted changes; skipping switch+pull" >&2
fi

# 6. Create the herdr workspace at the (now up-to-date) repo root.
create_json=$(herdr workspace create --cwd "$repo_root" --label "$label" --no-focus --json)
new_ws_id=$(printf '%s' "$create_json" | jq -r '.result.workspace.workspace_id // empty')

if [ -z "$new_ws_id" ]; then
  echo "ERROR: workspace create failed for $repo_root" >&2
  echo "$create_json" >&2
  exit 1
fi

echo "INFO: created workspace $new_ws_id for $repo_root" >&2
echo "$new_ws_id"
