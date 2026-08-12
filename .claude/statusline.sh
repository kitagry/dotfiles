#!/usr/bin/env bash
# Minimal footer, inspired by pi-minimal-footer:
# https://github.com/ogulcancelik/pi-extensions/tree/main/packages/pi-minimal-footer
# repo/branch already shown in herdr's sidebar, so this stays to one line:
# model, effort, context usage bar, cost, duration, rate limit quotas, PR

input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path // empty')
CWD=$(echo "$input" | jq -r '.cwd // empty')

# 1 session で複数 PR を作ることがあるので、transcript から触った PR を全部拾って重複除去。
# herdr の workspace worktree だと配下の別リポの PR (m3pay-project + api-definitions 等) も拾う。
PR_URLS=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  PR_URLS=$(grep -F '"gitOperation"' "$TRANSCRIPT" 2>/dev/null | \
    jq -r 'select(.toolUseResult.gitOperation.pr.url) | .toolUseResult.gitOperation.pr.url' 2>/dev/null | \
    awk '!seen[$0]++ { print }')
fi

fmt_reset() {
  TZ=Asia/Tokyo date -d "@$1" +%H:%M 2>/dev/null || TZ=Asia/Tokyo date -r "$1" +%H:%M
}

fmt_reset_day() {
  TZ=Asia/Tokyo date -d "@$1" '+%m/%d %H:%M' 2>/dev/null || TZ=Asia/Tokyo date -r "$1" '+%m/%d %H:%M'
}

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; DIM='\033[2m'; RESET='\033[0m'

EFFORT_SEG=""
[ -n "$EFFORT" ] && EFFORT_SEG=" ${DIM}(${EFFORT})${RESET}"

BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /█}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

COST_FMT=$(printf '$%.2f' "$COST")
MINS=$((DURATION_MS / 60000))

RL_SEG=""
if [ -n "$FIVE_H" ]; then
  RL_SEG="5h:$(printf '%.0f' "$FIVE_H")%"
  [ -n "$FIVE_H_RESET" ] && RL_SEG="${RL_SEG}($(fmt_reset "$FIVE_H_RESET")JST)"
fi
if [ -n "$WEEK" ]; then
  WEEK_SEG="7d:$(printf '%.0f' "$WEEK")%"
  [ -n "$WEEK_RESET" ] && WEEK_SEG="${WEEK_SEG}($(fmt_reset_day "$WEEK_RESET")JST)"
  RL_SEG="${RL_SEG:+$RL_SEG }${WEEK_SEG}"
fi

PR_SEG=""
if [ -n "$PR_URLS" ]; then
  # 表示は owner/repo#num に短縮しつつ OSC 8 で full URL を貼り込む。
  # herdr は URL 形状の text を pane 内でクリック対象として拾うので、
  # OSC 8 で URL を仕込めば Ctrl+click (macOS でも Cmd ではなく Ctrl) で発火する。
  PR_LINKS=""
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    short=$(printf '%s' "$url" | sed -E 's|https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+)|\1/\2#\3|')
    link=$(printf '\033]8;;%s\007%s\033]8;;\007' "$url" "$short")
    PR_LINKS="${PR_LINKS:+$PR_LINKS }$link"
  done <<< "$PR_URLS"
  PR_SEG=" | $PR_LINKS"
fi

echo -e "${CYAN}[${MODEL}]${RESET}${EFFORT_SEG} ${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} ${MINS}m${RL_SEG:+ | ${RL_SEG}}${PR_SEG}"
