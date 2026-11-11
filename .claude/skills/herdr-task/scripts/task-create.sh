#!/usr/bin/env bash
# Creates a task directory (~/tasks/<task>) with TASK.md and ACTIONS.md
# skeletons and a herdr workspace labeled <task> whose first tab ("task") sits
# at the task directory and runs the coordinator Claude (agent name <task>-task)
# in its left pane. The right pane watches ACTIONS.md, the list of things
# waiting on a human, since humans cannot keep up with the chat.
# Repos are added later as tabs with task-add-repo.sh.
#
# Usage: task-create.sh <task>
#
# On success, prints to stdout (eval-able):
#   WS_ID='...'
#   PANE_ID='...'   (root pane of the "task" tab, for the coordinator Claude)
#   TASK_DIR='...'
#
# Never pass --focus: creation must not steal the caller's screen.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <task>" >&2
  exit 2
fi

task="$1"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
validate_task_name "$task"

dir=$(task_dir "$task")

# Trusting the tasks root once covers every task dir and worktree under it, so
# Claude never stops at the trust dialog when started in a tab.
root=$(tasks_root)
if ! is_trusted "$root"; then
  echo "ERROR: $root is not trusted by Claude Code. Trust it once by running:" >&2
  echo "  mkdir -p $root && cd $root && claude   (choose 'Yes, I trust this folder', then exit)" >&2
  exit 1
fi

# Refuse to reuse: a half-matching existing task would silently mix two tasks'
# worktrees and TASK.md.
if [ -e "$dir" ]; then
  echo "ERROR: $dir already exists" >&2
  exit 1
fi
if [ -n "$(find_task_workspace "$task")" ]; then
  echo "ERROR: a herdr workspace labeled '$task' already exists" >&2
  exit 1
fi

mkdir -p "$dir"
cat > "$dir/TASK.md" <<EOF
# $task
created: $(date +%F)

## Goal

## Repos
<!-- task-add-repo.sh appends here -->

## Decisions
<!-- cross-repo interfaces (command names, API shapes, ...) agreed for this task -->

## Merge order

## Notes

## Done
<!-- task-remove-repo.sh moves finished tabs here -->
EOF
cat > "$dir/ACTIONS.md" <<EOF
# $task 要対応 (コーディネーターが更新)

各項目: - **<🔴/🟠/🟢/⏳/✅> <番号> <〜してよい? / A・B・C のどれ? / (作業) 〜してください>**
その下に字下げして背景・選択肢・期限・URL。返事は「1 OK」「2 A」のように番号で。

(現在なし)
EOF

json=$(herdr workspace create --cwd "$dir" --label "$task" \
  --env "HERDR_TASK=$task" --env "HERDR_TASK_DIR=$dir" --no-focus)

ws_id=$(printf '%s' "$json" | jq -r '.result.workspace.workspace_id')
pane_id=$(printf '%s' "$json" | jq -r '.result.root_pane.pane_id')
tab_id=$(printf '%s' "$json" | jq -r '.result.tab.tab_id')

if [ -z "$ws_id" ] || [ "$ws_id" = "null" ] || [ -z "$pane_id" ] || [ "$pane_id" = "null" ]; then
  echo "ERROR: herdr workspace create did not return workspace_id/root_pane.pane_id" >&2
  echo "$json" >&2
  exit 1
fi

herdr tab rename "$tab_id" task > /dev/null

# Split before starting the coordinator so Claude starts at its final width.
# --ratio is the share of the original (left) pane. The relative path keeps the
# command free of shell quoting, as the pane's shell is fish, not bash.
# Display-only, so a failure is not fatal. macOS ships no `watch`; skip the
# split rather than leave a pane showing "command not found".
# stderr is not captured: herdr may log there even on success, which would
# break the jq parse.
if ! command -v watch > /dev/null; then
  echo "WARN: watch is not installed; no ACTIONS.md pane (brew install watch)" >&2
elif ! watch_json=$(herdr pane split "$pane_id" --direction right --ratio 0.65 \
  --cwd "$dir" --no-focus) \
  || ! watch_pane=$(printf '%s' "$watch_json" | jq -er '.result.pane.pane_id // empty' 2>/dev/null); then
  echo "WARN: failed to split the task tab for the ACTIONS.md pane: ${watch_json:-}" >&2
else
  # The label lets task_pane tell this pane from the coordinator's without
  # relying on list order or on Claude currently running.
  herdr pane rename "$watch_pane" "$ACTIONS_PANE_LABEL" > /dev/null \
    || echo "WARN: failed to label the ACTIONS.md pane $watch_pane" >&2
  # herdr can exit 0 with an .error body (see start-claude-agent.sh), so the
  # exit code alone does not tell whether the command was sent.
  if ! run_json=$(herdr pane run "$watch_pane" "watch -t -n 15 cat ACTIONS.md") \
    || printf '%s' "$run_json" | jq -e '.error' > /dev/null 2>&1; then
    echo "WARN: failed to start watch in pane $watch_pane: ${run_json:-}" >&2
    # Same reason as skipping the split without `watch`: an idle shell pane
    # next to the coordinator only looks like the ACTIONS.md view.
    herdr pane close "$watch_pane" > /dev/null 2>&1 || true
  fi
fi

# The task tab always has a coordinator: it is who the master Claude (and a
# human looking at the tab) talks to. stdout is reserved for the eval-able vars.
if ! "$(dirname "${BASH_SOURCE[0]}")/start-claude-agent.sh" "$pane_id" "$task-task" >&2; then
  echo "WARN: coordinator did not start; run start-claude-agent.sh $pane_id $task-task" >&2
fi

printf "WS_ID=%q\n" "$ws_id"
printf "PANE_ID=%q\n" "$pane_id"
printf "TASK_DIR=%q\n" "$dir"
