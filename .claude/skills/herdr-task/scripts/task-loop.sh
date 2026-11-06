#!/usr/bin/env bash
# Starts a /loop in the task's coordinator so it checks its repo tabs on its own
# instead of waiting to be asked.
#
# Usage: task-loop.sh <task> [interval]
#   [interval]  /loop interval, e.g. 10m (default)
#
# Sent raw rather than through task-ask.sh: the "[master]" prefix would stop
# Claude Code from reading the text as a slash command.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <task> [interval]" >&2
  exit 2
fi

task="$1"
interval="${2:-10m}"
script_dir=$(dirname "${BASH_SOURCE[0]}")
source "$script_dir/lib.sh"
validate_task_name "$task"

pane=$(task_pane "$task")
if [ -z "$pane" ] || [ -z "$(pane_agent "$pane")" ]; then
  echo "ERROR: no coordinator Claude in the task tab of '$task'" >&2
  exit 1
fi

"$script_dir/send-instruction.sh" "$pane" "/loop $interval タスク $task の定期チェック。各 repo の tab の状況を herdr-task スキルの read-pane.sh と task-status.sh で確認して。止まっている tab (確認待ち、エラー、指示待ち、レビュー対応漏れ) があれば対応し、TASK.md の Repos の行末の状況 (PR、状態) を更新して。人間の判断が要ることは返答の最後に「確認したいこと」として書いて。変化がなければ短く「変化なし」とだけ返して。全 tab の PR が merge されたら報告して loop を止めて。"
