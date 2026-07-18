#!/bin/bash
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
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
PR_NUM=$(echo "$input" | jq -r '.pr.number // empty')

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
[ -n "$FIVE_H" ] && RL_SEG="5h:$(printf '%.0f' "$FIVE_H")%"
[ -n "$WEEK" ] && RL_SEG="${RL_SEG:+$RL_SEG }7d:$(printf '%.0f' "$WEEK")%"

PR_SEG=""
[ -n "$PR_NUM" ] && PR_SEG=" | #${PR_NUM}"

echo -e "${CYAN}[${MODEL}]${RESET}${EFFORT_SEG} ${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} ${MINS}m${RL_SEG:+ | ${RL_SEG}}${PR_SEG}"
