#!/usr/bin/env bash
# Creates a new linked worktree + herdr workspace off the given parent workspace,
# and prints the resulting workspace_id / worktree path / root pane_id as shell
# assignments so the caller can `eval` them directly.
#
# Usage: create-worktree.sh <parent_workspace_id> <branch> <base>
#   <base> is the branch to fork from, WITHOUT the "origin/" prefix
#          (this script always forks from the remote-tracking ref "origin/<base>").
#
# On success, prints to stdout (eval-able):
#   WS_ID='...'
#   WT_PATH='...'
#   PANE_ID='...'
#
# Never pass --focus: this must stay a silent background creation so the caller's
# workspace keeps focus.
#
# NOTE (2026-10-03): this environment's herdr has no `--json` flag on either
# `workspace list` or `worktree create` -- both already emit JSON on stdout, and
# passing `--json` makes them exit 2 with a usage error. Under `set -euo pipefail`
# that killed this script with an empty message. Do not re-add `--json`.
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "usage: $0 <parent_workspace_id> <branch> <base>" >&2
  exit 2
fi

parent_ws="$1"
branch="$2"
base="$3"

# If the parent workspace lives under `ghq root`, place the worktree at
# `<ghq root>/<host>/<org>/<repo>-wt/<branch>` so it stays alongside the source
# repo (ghq/fzf can see it, and rules with `paths: "**/<org>/**"` still match).
# Fall back to herdr's default (~/.herdr/worktrees/<repo>/<branch>) otherwise.
path_arg=()
ghq_root=$(ghq root 2>/dev/null || true)
if [ -n "$ghq_root" ]; then
  ws_json=$(herdr workspace list 2>/dev/null || true)
  repo_root=$(printf '%s' "$ws_json" \
    | jq -r --arg ws "$parent_ws" '
        .result.workspaces[]
        | select(.workspace_id == $ws)
        | .worktree.repo_root // empty
      ' 2>/dev/null || true)

  # Some herdr versions omit worktree info from `workspace list`. Recover by
  # using the current repo root, but only when the parent workspace's label
  # matches its basename -- otherwise we could point at an unrelated repo.
  if [ -z "$repo_root" ]; then
    cur_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
    ws_label=$(printf '%s' "$ws_json" \
      | jq -r --arg ws "$parent_ws" '
          .result.workspaces[]
          | select(.workspace_id == $ws)
          | .label // empty
        ' 2>/dev/null || true)
    if [ -n "$cur_root" ] && [ -n "$ws_label" ] && [ "$(basename "$cur_root")" = "$ws_label" ]; then
      repo_root="$cur_root"
    fi
  fi

  if [ -n "$repo_root" ] && [ "${repo_root#$ghq_root/}" != "$repo_root" ]; then
    rel="${repo_root#$ghq_root/}"
    host="${rel%%/*}"
    rest="${rel#*/}"
    org="${rest%%/*}"
    repo="${rest##*/}"
    if [ -n "$host" ] && [ -n "$org" ] && [ -n "$repo" ] && [ "$rest" = "$org/$repo" ]; then
      path_arg=(--path "$ghq_root/$host/$org/${repo}-wt/$branch")
    fi
  fi
fi

json=$(herdr worktree create \
  --workspace "$parent_ws" \
  --branch "$branch" \
  --base "origin/$base" \
  "${path_arg[@]}" \
  --no-focus)

ws_id=$(printf '%s' "$json" | jq -r '.result.workspace.workspace_id')
wt_path=$(printf '%s' "$json" | jq -r '.result.worktree.path')
pane_id=$(printf '%s' "$json" | jq -r '.result.root_pane.pane_id')

if [ -z "$ws_id" ] || [ "$ws_id" = "null" ] || [ -z "$wt_path" ] || [ "$wt_path" = "null" ] || [ -z "$pane_id" ] || [ "$pane_id" = "null" ]; then
  echo "ERROR: herdr worktree create did not return workspace_id/worktree.path/root_pane.pane_id" >&2
  echo "$json" >&2
  exit 1
fi

printf "WS_ID=%q\n" "$ws_id"
printf "WT_PATH=%q\n" "$wt_path"
printf "PANE_ID=%q\n" "$pane_id"
