#!/usr/bin/env bash
# Adds a git worktree of <repo> to the task and opens it as a new tab in the
# task's herdr workspace.
#
# Usage: task-add-repo.sh <task> <repo> [base]
#   <repo>  path to the repo (a linked worktree path is fine; its main repo is used)
#   [base]  branch to fork from, without "origin/". Default: the repo's origin/HEAD
#
# Layout: the first worktree of a repo is <task_dir>/<repo_name> on branch <task>;
# further ones are <repo_name>-2, -3, ... on branch <task>-2, -3, ...
#
# On success, prints to stdout (eval-able):
#   TAB_ID='...'  PANE_ID='...'  WT_PATH='...'  BRANCH='...'
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <task> <repo> [base]" >&2
  exit 2
fi

task="$1"
repo="$2"
base="${3:-}"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
validate_task_name "$task"

dir=$(task_dir "$task")
if [ ! -d "$dir" ]; then
  echo "ERROR: $dir does not exist; run task-create.sh first" >&2
  exit 1
fi
ws_id=$(find_task_workspace "$task")
if [ -z "$ws_id" ]; then
  echo "ERROR: no herdr workspace labeled '$task'" >&2
  exit 1
fi

# --git-common-dir resolves to the main repo's .git even from a linked worktree,
# so worktrees are always added off the main checkout.
common_dir=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)
repo_root=$(dirname "$common_dir")
repo_name=$(basename "$repo_root")

# The worktree lands under the trusted tasks root, which would let the repo's
# .claude/settings.json hooks and .mcp.json load unreviewed. Require that the
# repo itself was trusted already, so the dialog's check is not bypassed.
if ! is_trusted "$repo_root"; then
  echo "ERROR: $repo_root is not trusted by Claude Code." >&2
  echo "  Review its .claude/ and .mcp.json, then trust it once: cd $repo_root && claude" >&2
  exit 1
fi

if [ -z "$base" ]; then
  base=$(git -C "$repo_root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)
  base="${base:-main}"
fi

# Without this fetch the worktree forks from a stale origin/<base> and misses
# PRs merged elsewhere. Best-effort: offline still works from the local ref.
if ! git -C "$repo_root" fetch origin "$base" --quiet; then
  echo "WARN: git fetch origin $base failed; using the local ref" >&2
fi
start_point="origin/$base"
if ! git -C "$repo_root" rev-parse --verify --quiet "$start_point" > /dev/null; then
  start_point="$base"
fi

n=1
name="$repo_name"
branch="$task"
while [ -e "$dir/$name" ] || git -C "$repo_root" rev-parse --verify --quiet "refs/heads/$branch" > /dev/null; do
  n=$((n + 1))
  name="$repo_name-$n"
  branch="$task-$n"
done
wt_path="$dir/$name"

# --no-track: otherwise the branch tracks origin/<base> and a bare `git push`
# targets the wrong remote branch.
git -C "$repo_root" worktree add --quiet --no-track -b "$branch" "$wt_path" "$start_point" >&2

json=$(herdr tab create --workspace "$ws_id" --cwd "$wt_path" --label "$name" \
  --env "HERDR_TASK=$task" --env "HERDR_TASK_DIR=$dir" --no-focus)
tab_id=$(printf '%s' "$json" | jq -r '.result.tab.tab_id')
pane_id=$(printf '%s' "$json" | jq -r '.result.root_pane.pane_id')

if [ -z "$tab_id" ] || [ "$tab_id" = "null" ] || [ -z "$pane_id" ] || [ "$pane_id" = "null" ]; then
  echo "ERROR: herdr tab create did not return tab_id/root_pane.pane_id (worktree $wt_path was created)" >&2
  echo "$json" >&2
  exit 1
fi

if [ -f "$dir/TASK.md" ]; then
  append_repo_line "$dir/TASK.md" "- \`$name\`: $repo_root (branch: \`$branch\`, base: \`$base\`)"
fi

report_repos "$ws_id"

printf "TAB_ID=%q\n" "$tab_id"
printf "PANE_ID=%q\n" "$pane_id"
printf "WT_PATH=%q\n" "$wt_path"
printf "BRANCH=%q\n" "$branch"
