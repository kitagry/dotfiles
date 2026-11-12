#!/usr/bin/env bash
# timing-log.sh のテスト。実行: bash .claude/hooks/timing-log_test.sh
set -u

HOOK="$(dirname "$0")/timing-log.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export CLAUDE_TIMING_LOG="$TMP/events.jsonl"

FAILED=0
assert_jq() {
  local name="$1" filter="$2"
  if tail -n1 "$CLAUDE_TIMING_LOG" 2>/dev/null | jq -e "$filter" >/dev/null 2>&1; then
    echo "ok   $name"
  else
    echo "FAIL $name: $(tail -n1 "$CLAUDE_TIMING_LOG" 2>/dev/null)"
    FAILED=1
  fi
}

echo '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"go test"},"tool_response":{"stdout":"huge"},"tool_use_id":"toolu_1","duration_ms":1234}' | bash "$HOOK"
assert_jq "PostToolUse は tool_use_id と duration_ms を残す" \
  '.event == "PostToolUse" and .session_id == "s1" and .tool_use_id == "toolu_1" and .duration_ms == 1234 and (.ts | type) == "number"'
assert_jq "PostToolUse は tool_response を捨てる" '(has("tool_response") | not) and (has("tool_input") | not)'

echo '{"session_id":"s1","hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_use_id":"toolu_2","error":"x","duration_ms":50}' | bash "$HOOK"
assert_jq "PostToolUseFailure も記録する" '.event == "PostToolUseFailure" and .tool_use_id == "toolu_2" and .duration_ms == 50'

echo '{"session_id":"s1","cwd":"/repo/a","hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"rm x","description":"d"},"permission_suggestions":[{"type":"addRules","rules":[{"toolName":"Bash","ruleContent":"rm:*"}],"behavior":"allow","destination":"localSettings"}]}' | bash "$HOOK"
assert_jq "PermissionRequest は入力と提案ルールを残す" \
  '.event == "PermissionRequest" and .tool_name == "Bash" and .tool_input.command == "rm x" and .rules == ["Bash(rm:*)"] and .cwd == "/repo/a"'

out="$(echo 'not json' | bash "$HOOK"; echo "exit=$?")"
if [ "$out" = "exit=0" ]; then echo "ok   壊れた入力でも exit 0 で何も出さない"; else echo "FAIL 壊れた入力: $out"; FAILED=1; fi

exit "$FAILED"
