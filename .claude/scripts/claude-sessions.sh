#!/usr/bin/env bash
# Claude Code の全セッションを「最終更新日 / リポ / 要約」の TSV で出力する (fzf 用)。
#
# 一次ソースは ~/.claude/history.jsonl。理由: ~/.claude/projects/*/sessions-index.json は
# 一部プロジェクトにしか生成されず内容も古いことがあるが、history.jsonl は全セッションの
# プロンプトを網羅している。AI 生成の要約が sessions-index.json にあればそちらを優先する。
#
# 出力 (タブ区切り): sessionId \t 最終更新日 \t リポ表示名 \t プロジェクトパス \t 要約
set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HISTORY="$CLAUDE_DIR/history.jsonl"
GHQ_ROOT="${GHQ_ROOT:-$(ghq root 2>/dev/null || echo "$HOME/go/src")}"

[[ -f "$HISTORY" ]] || { echo "history.jsonl not found: $HISTORY" >&2; exit 1; }

# sessions-index.json が 1 つも無くても slurpfile が空配列になるように /dev/null を混ぜる
index_files=("$CLAUDE_DIR"/projects/*/sessions-index.json)
[[ -e "${index_files[0]}" ]] || index_files=(/dev/null)

jq -rn \
  --slurpfile hist "$HISTORY" \
  --slurpfile idx <(cat "${index_files[@]}") \
  --arg home "$HOME" \
  --arg ghq "$GHQ_ROOT" '
  # sessionId -> AI 要約
  ([$idx[] | .entries[]? | select(.summary != null and .summary != "")
    | {key: .sessionId, value: .summary}] | from_entries) as $summaries
  |
  def oneline: gsub("\\s+"; " ") | ltrimstr(" ") | .[:120];
  def repo_name:
    if startswith($ghq + "/") then ltrimstr($ghq + "/")
    elif startswith($home + "/") then "~/" + ltrimstr($home + "/")
    else . end;

  $hist
  | map(select(.sessionId != null and .project != null))
  | group_by(.sessionId)
  | map(
      (sort_by(.timestamp)) as $msgs
      # /clear や <local-command-caveat> 等のメタ入力は要約候補から外す
      | ([$msgs[] | .display | select(test("^\\s*[/<]") | not)] | first // $msgs[0].display) as $first
      | {
          id: $msgs[0].sessionId,
          project: $msgs[-1].project,
          last: ($msgs | map(.timestamp) | max),
          summary: ($summaries[$msgs[0].sessionId] // $first | oneline)
        })
  | sort_by(-.last)
  | .[]
  | [ .id,
      (.last / 1000 | strflocaltime("%Y-%m-%d %H:%M")),
      (.project | repo_name),
      .project,
      .summary
    ] | @tsv
' | while IFS=$'\t' read -r id date repo project summary; do
  # cd できないセッションは出しても使えないので除外する
  [[ -d "$project" ]] || continue
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$date" "$repo" "$project" "$summary"
done
