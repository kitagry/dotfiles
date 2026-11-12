#!/usr/bin/env bash
# PermissionRequest / PostToolUse / PostToolUseFailure を ~/.claude/timing/events.jsonl に 1 行ずつ追記する。
# claude_timing.py が transcript と突き合わせて「権限確認の待ち時間」を出すための補助データ。
#
# PostToolUse の duration_ms は権限確認の待ちを含まない実行時間なので、transcript 上の
# tool_use→tool_result の時間から引けば待ち時間になる。PermissionRequest には tool_use_id が
# 無いため、session_id + tool_name + tool_input で後から紐づける。
#
# hook の失敗で Claude の動作を止めないよう、常に exit 0。
LOG="${CLAUDE_TIMING_LOG:-$HOME/.claude/timing/events.jsonl}"
mkdir -p "$(dirname "$LOG")" 2>/dev/null

# tool_response はファイル内容等で巨大になるので必要なフィールドだけ残す
jq -c '
  {ts: now, event: .hook_event_name, session_id, cwd} +
  if .hook_event_name == "PermissionRequest" then
    {tool_name, tool_input,
     rules: [.permission_suggestions[]? | select(.type == "addRules") | .rules[]?
             | .toolName + (if .ruleContent then "(" + .ruleContent + ")" else "" end)]}
  else
    {tool_name, tool_use_id, duration_ms}
  end
' >>"$LOG" 2>/dev/null

exit 0
