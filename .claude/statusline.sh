#!/usr/bin/env bash
# Minimal footer, inspired by pi-minimal-footer:
# https://github.com/ogulcancelik/pi-extensions/tree/main/packages/pi-minimal-footer
# repo/branch already shown in herdr's sidebar, so line 1 is just:
# model, effort, context usage bar, cost, duration, rate limit quotas
# PRs and issues (when there are any) each get their own following line.

# git remote URL (ssh / https) -> owner/repo. Empty for hosts other than github.com.
github_repo_from_remote() {
  printf '%s' "$1" | sed -nE 's#^(git@github\.com:|https://github\.com/)([^/]+/[^/]+)$#\2#p' | sed -E 's/\.git$//'
}

# Guess the related issue URL from a branch name. $2 = owner/repo of the current repo.
# A trailing number alone (fix/foo-2) is likely a sequence number, so it is ignored; so is a leading date (2026-11-update).
branch_issue_url() {
  local branch="$1" repo="$2" leaf="${1##*/}"
  [ -n "$repo" ] || return 0
  local owner="${repo%%/*}"
  if [[ "$leaf" =~ ^(.+)-issue-([0-9]+)$ ]]; then
    printf 'https://github.com/%s/%s/issues/%s\n' "$owner" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  elif [[ "$leaf" =~ ^[0-9]{4}-[0-9]{2}- ]]; then
    return 0
  elif [[ "$leaf" =~ ^issue-([0-9]+) ]] || [[ "$leaf" =~ ^([0-9]+)- ]]; then
    printf 'https://github.com/%s/issues/%s\n' "$repo" "${BASH_REMATCH[1]}"
  fi
}

# One gh pr list/view JSON object -> a PR row and ISSUE rows.
# Some teams link issues by URL in the PR body instead of "Closes #N", so issue URLs in
# the body are picked up as well as closingIssuesReferences (the caller dedupes).
PR_ROW_JQ='"PR\t\(.state)\t\(.isDraft)\t\(.url)",
  (.closingIssuesReferences[]? | "ISSUE\t\(.url)"),
  ((.body // "") | scan("https://github\\.com/[^/\\s]+/[^/\\s]+/issues/[0-9]+") | "ISSUE\t\(.)")'

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; MAGENTA='\033[35m'; GRAY='\033[90m'; DIM='\033[2m'; RESET='\033[0m'

# "<state>\t<stateReason>\t<url>" lines -> one issue line (escapes expanded).
# OPEN issues have an empty stateReason, i.e. two tabs in a row. read with IFS=$'\t' would
# collapse them and shift the columns, so the fields are cut with parameter expansion.
# ○ to tell issues from PRs (●). Colors: OPEN=green / CLOSED as completed=magenta / not planned etc.=gray
render_issue_line() {
  local line state reason url short color link out=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    state=${line%%$'\t'*}
    url=${line##*$'\t'}
    reason=${line#*$'\t'}; reason=${reason%%$'\t'*}
    short=$(printf '%s' "$url" | sed -E 's|https://github\.com/([^/]+)/([^/]+)/issues/([0-9]+)|\1/\2#\3|')
    case "$state:$reason" in
      OPEN:*)            color="$GREEN" ;;
      CLOSED:COMPLETED)  color="$MAGENTA" ;;
      *)                 color="$GRAY" ;;
    esac
    link=$(printf '\033]8;;%s\007%s\033]8;;\007' "$url" "$short")
    out="${out:+$out  }${color}○ ${link}${RESET}"
  done <<< "$1"
  [ -n "$out" ] && printf '%b\n' "$out"
  return 0
}

# When sourced from statusline_test.sh, load only the function definitions and stop here
[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0

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

# PRs shown are the union of two sources:
#  1. gitOperation in the transcript (Claude ran gh pr create in this session)
#  2. gh pr list --head <branch> in CWD (or each repo of a workspace worktree) (only pushed to an existing PR)
# gh is slow (~500ms/repo) and every call spends the shared GraphQL quota (5000/h across all sessions),
# so results are cached for 5 minutes per CWD and transcript.
# (source 1 is per session, so two sessions in the same CWD must not share a cache).
PR_CACHE_TTL=300
PR_CACHE_KEY=$(printf '%s\n%s' "$CWD" "$TRANSCRIPT" | { shasum 2>/dev/null || cksum; } | cut -c1-16 | tr -d ' ')
# v2: PR and ISSUE rows mixed. Renamed so an old-format cache is never misread
PR_CACHE_FILE="${TMPDIR:-/tmp}/claude-statusline-v2-${PR_CACHE_KEY}"

pr_cache_fresh() {
  [ -f "$PR_CACHE_FILE" ] || return 1
  local mtime now
  # GNU first: GNU `stat -f` means --file-system and prints multi-line output before failing,
  # while BSD `stat -c` fails with nothing on stdout.
  mtime=$(stat -c %Y "$PR_CACHE_FILE" 2>/dev/null || stat -f %m "$PR_CACHE_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  [ $((now - mtime)) -lt "$PR_CACHE_TTL" ]
}

fetch_prs_with_state_from_gh() {
  command -v gh >/dev/null 2>&1 || return
  [ -n "$CWD" ] || return
  local -a repo_dirs=()
  # Look at every repos/*/ under a workspace worktree
  if [ -d "$CWD/repos" ]; then
    for d in "$CWD/repos"/*/; do
      git -C "${d%/}" rev-parse --git-dir >/dev/null 2>&1 && repo_dirs+=("${d%/}")
    done
  fi
  # Also look at CWD itself when it is a git repo (a normal worktree)
  git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 && repo_dirs+=("$CWD")
  [ ${#repo_dirs[@]} -eq 0 ] && return
  local repo
  for repo in "${repo_dirs[@]}"; do
    (
      branch=$(git -C "$repo" branch --show-current 2>/dev/null)
      # Skip main / master / develop: they are not work branches (develop would pick up many
      # develop->master release PRs). Fork PRs are not supported for now
      case "$branch" in ''|main|master|develop) exit ;; esac
      slug=$(github_repo_from_remote "$(git -C "$repo" remote get-url origin 2>/dev/null)")
      branch_issue_url "$branch" "$slug" | sed 's/^/ISSUE\t/'
      # --head matches the branch name in any fork, so keep only PRs whose head lives in origin's owner
      owner_filter=""
      [ -n "$slug" ] && owner_filter="select((.headRepositoryOwner.login // \"\" | ascii_downcase) == (\"${slug%%/*}\" | ascii_downcase)) | "
      cd "$repo" && gh pr list --head "$branch" --state all \
        --json url,state,isDraft,closingIssuesReferences,body,headRepositoryOwner \
        --jq ".[] | ${owner_filter}${PR_ROW_JQ}" 2>/dev/null
    ) &
  done
  wait
}

# If gh fails (offline, rate limited, not installed) still show the transcript PR, with an UNKNOWN
# state. A non-empty placeholder is needed: read with IFS=$'\t' would collapse an empty field.
fetch_pr_state_for_url() {
  local out
  out=$(gh pr view "$1" --json url,state,isDraft,closingIssuesReferences,body --jq "$PR_ROW_JQ" 2>/dev/null)
  if [ -n "$out" ]; then
    printf '%s\n' "$out"
  else
    printf 'PR\tUNKNOWN\tfalse\t%s\n' "$1"
  fi
}

# Issues that do not exist (e.g. a wrong guess from the branch name) make gh fail and print nothing, so they drop out
fetch_issue_states() {
  local url
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    gh issue view "$url" --json url,state,stateReason \
      --jq '"\(.state)\t\(.stateReason)\t\(.url)"' 2>/dev/null &
  done
  wait
}

# Output: a mix of "PR\t<state>\t<isDraft>\t<url>" and "ISSUE\t<state>\t<stateReason>\t<url>" rows
fetch_all_state() {
  local raw
  raw=$(fetch_all_pr_rows)
  printf '%s\n' "$raw" | grep "^PR"$'\t' | cut -f2- | awk -F'\t' 'NF==3 && !seen[$3]++ {
      # Left to right: draft -> OPEN -> MERGED -> others -> CLOSED
      # CLOSED always goes last to keep it out of the way; a closed draft counts as CLOSED.
      if ($1 == "CLOSED") key = 4
      else if ($2 == "true") key = 0
      else if ($1 == "OPEN")   key = 1
      else if ($1 == "MERGED") key = 2
      else key = 3
      print key "\tPR\t" $0
    }' | sort -k1,1n | cut -f2-
  # Issues: OPEN on the left, CLOSED on the right
  printf '%s\n' "$raw" | grep "^ISSUE"$'\t' | cut -f2 | awk '!seen[$0]++' | fetch_issue_states | \
    awk -F'\t' 'NF==3 { print ($1 == "OPEN" ? 0 : 1) "\tISSUE\t" $0 }' | sort -k1,1n | cut -f2-
}

# Parsing the transcript grows with the session, so only do it on a cache miss.
transcript_pr_urls() {
  [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || return 0
  grep -F '"gitOperation"' "$TRANSCRIPT" 2>/dev/null | \
    jq -r 'select(.toolUseResult.gitOperation.pr.url) | .toolUseResult.gitOperation.pr.url' 2>/dev/null
}

fetch_all_pr_rows() {
  local PR_URLS_FROM_TRANSCRIPT
  PR_URLS_FROM_TRANSCRIPT=$(transcript_pr_urls)
  {
    fetch_prs_with_state_from_gh
    # Transcript URLs may be missing from gh pr list (e.g. another branch), so fetch their
    # state with gh pr view in parallel; duplicates are removed by URL afterwards.
    if [ -n "$PR_URLS_FROM_TRANSCRIPT" ]; then
      while IFS= read -r url; do
        [ -z "$url" ] && continue
        fetch_pr_state_for_url "$url" &
      done <<< "$PR_URLS_FROM_TRANSCRIPT"
      wait
    fi
  }
}

STATE_TSV=""
if pr_cache_fresh; then
  STATE_TSV=$(cat "$PR_CACHE_FILE")
else
  STATE_TSV=$(fetch_all_state)
  # Write then rename so a concurrent refresh never reads a truncated (empty) cache
  printf '%s' "$STATE_TSV" > "$PR_CACHE_FILE.$$" 2>/dev/null && mv -f "$PR_CACHE_FILE.$$" "$PR_CACHE_FILE" 2>/dev/null
fi
PR_TSV=$(printf '%s\n' "$STATE_TSV" | grep "^PR"$'\t' | cut -f2-)
ISSUE_TSV=$(printf '%s\n' "$STATE_TSV" | grep "^ISSUE"$'\t' | cut -f2-)

fmt_reset() {
  TZ=Asia/Tokyo date -d "@$1" +%H:%M 2>/dev/null || TZ=Asia/Tokyo date -r "$1" +%H:%M
}

fmt_reset_day() {
  TZ=Asia/Tokyo date -d "@$1" '+%m/%d %H:%M' 2>/dev/null || TZ=Asia/Tokyo date -r "$1" '+%m/%d %H:%M'
}


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

PR_LINE=""
if [ -n "$PR_TSV" ]; then
  # 表示は owner/repo#num に短縮しつつ OSC 8 で full URL を貼り込む。
  # herdr は URL 形状の text を pane 内でクリック対象として拾うので、
  # OSC 8 で URL を仕込めば Ctrl+click (macOS でも Cmd ではなく Ctrl) で発火する。
  # Color by state: OPEN=green / MERGED=magenta / CLOSED=red / Draft=gray
  PR_ITEMS=""
  while IFS=$'\t' read -r state is_draft url; do
    [ -z "$url" ] && continue
    short=$(printf '%s' "$url" | sed -E 's|https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+)|\1/\2#\3|')
    # A closed draft counts as CLOSED, matching the sort order in fetch_all_state
    if [ "$is_draft" = "true" ] && [ "$state" != "CLOSED" ]; then
      color="$GRAY"
    else
      case "$state" in
        OPEN)   color="$GREEN" ;;
        MERGED) color="$MAGENTA" ;;
        CLOSED) color="$RED" ;;
        *)      color="$DIM" ;;
      esac
    fi
    link=$(printf '\033]8;;%s\007%s\033]8;;\007' "$url" "$short")
    PR_ITEMS="${PR_ITEMS:+$PR_ITEMS  }${color}● ${link}${RESET}"
  done <<< "$PR_TSV"
  PR_LINE="$PR_ITEMS"
fi

ISSUE_LINE=$(render_issue_line "$ISSUE_TSV")

echo -e "${CYAN}[${MODEL}]${RESET}${EFFORT_SEG} ${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} ${MINS}m${RL_SEG:+ | ${RL_SEG}}"
if [ -n "$PR_LINE" ]; then
  echo -e "$PR_LINE"
fi
if [ -n "$ISSUE_LINE" ]; then
  echo -e "$ISSUE_LINE"
fi
