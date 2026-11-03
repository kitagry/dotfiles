#!/usr/bin/env bash
# /code-review --fix の採用率 (指摘のうち実際に直した割合) を集計する。
# ReportFindings は code-review から呼ばれず hook で拾えないため、
# サブエージェントの transcript を読む。transcript は cleanupPeriodDays (既定30日) で
# 消えるので、取り込んだ結果は LOG に貯めておき、週1程度で実行する。
set -euo pipefail

PROJECTS="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
LOG="${REVIEW_LOG:-$HOME/.claude/review-log.jsonl}"
touch "$LOG"

# 件数を直接数えさせると合計が合わないことがあるため、指摘ごとに判定させて件数は jq で数える
SCHEMA='{"type":"object","properties":{"findings":{"type":"array","items":{"type":"object","properties":{"summary":{"type":"string"},"outcome":{"type":"string","enum":["fixed","skipped"]},"reason":{"type":"string"}},"required":["summary","outcome"]}}},"required":["findings"]}'
PROMPT='stdin はコードレビューの出力。指摘一覧に載っている指摘を1件ずつ漏れなく findings に入れ、最終報告をもとに直したなら fixed、直さなかったなら skipped とする。1つの修正で複数の指摘が解消された場合はそれぞれ fixed。skipped の場合は直さなかった理由を短い日本語で reason に入れる。'

new=0
found=0
for marker in "$PROJECTS"/*/*/subagents/agent-*.forked-skill.json; do
  [[ -e "$marker" ]] || continue
  [[ "$(jq -r .skillName "$marker")" == "code-review" ]] || continue
  transcript="${marker%.forked-skill.json}.jsonl"
  [[ -f "$transcript" ]] || continue
  grep -q '## Applying fixes (--fix)' "$transcript" || continue
  found=$((found + 1))

  id="$(basename "$transcript" .jsonl)"
  grep -q "\"id\":\"$id\"" "$LOG" && continue

  report="$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' "$transcript" | tail -c 20000)"
  [[ -n "$report" ]] || continue

  counts="$(printf '%s' "$report" | claude -p --model haiku --no-session-persistence \
    --setting-sources "" --strict-mcp-config --disable-slash-commands --tools "" \
    --system-prompt 'You extract counts from code review reports.' \
    --output-format json --json-schema "$SCHEMA" "$PROMPT" \
    | jq -c '.structured_output.findings // empty
      | {total: length, fixed: map(select(.outcome == "fixed")) | length,
         skipped: map(select(.outcome == "skipped")) | length,
         skipped_reasons: map(select(.outcome == "skipped") | .reason // "")}')"
  if [[ -z "$counts" ]]; then
    echo "warn: $id の集計に失敗" >&2
    continue
  fi

  jq -cn \
    --arg id "$id" \
    --arg effort "$(jq -r '.effort // "unknown"' "$marker")" \
    --argjson first "$(head -1 "$transcript")" \
    --arg ts "$(tail -1 "$transcript" | jq -r .timestamp)" \
    --argjson counts "$counts" \
    '{id: $id, ts: $ts, effort: $effort, cwd: $first.cwd,
      target: (($first.message.content | if type == "string" then . else (.[0].text // "") end)
               | capture("Review target: `(?<t>[^`]+)`").t // null)}
     + $counts' >> "$LOG"
  new=$((new + 1))
done

if [[ "$found" -eq 0 ]]; then
  echo "warn: code-review --fix の transcript が 0 件。transcript の形式が変わった可能性がある" >&2
fi
echo "取り込み: 新規 $new 件 (transcript 上の対象 $found 件)"
echo

jq -rs 'map(select(.excluded | not)) |
  def rate: if .total == 0 then "-" else "\((.fixed * 100 / .total) | floor)%" end;
  def summarize: {n: length, total: (map(.total) | add // 0), fixed: (map(.fixed) | add // 0)};
  if length == 0 then "記録なし" else
    (summarize | "全体: レビュー \(.n) 回 / 指摘 \(.total) 件 / 修正 \(.fixed) 件 / 採用率 \(rate)"),
    "指摘 0 件のレビュー: \(map(select(.total == 0)) | length) 回",
    "",
    "effort 別:",
    (group_by(.effort)[] | (summarize) as $s | "  \(.[0].effort): \($s.n) 回 / 採用率 \($s | rate)"),
    "",
    "対象別:",
    (group_by(.target // .cwd)[] | (summarize) as $s | "  \(.[0].target // .[0].cwd): \($s.n) 回 / 採用率 \($s | rate)"),
    "",
    "見送り理由:",
    (map(.skipped_reasons[]) | if length == 0 then "  (なし)" else .[] | "  - \(.)" end)
  end
' "$LOG"
