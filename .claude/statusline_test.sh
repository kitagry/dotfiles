#!/usr/bin/env bash
# Tests for the pure functions in statusline.sh. Run: bash .claude/statusline_test.sh
set -u

# shellcheck source=statusline.sh
source "$(dirname "$0")/statusline.sh"

FAILED=0
assert_eq() {
  local name="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: want='$want' got='$got'"
    FAILED=1
  fi
}

assert_eq "repo-issue-N is an issue in another repo" \
  "https://github.com/example-org/releases/issues/577" \
  "$(branch_issue_url 'review/releases-issue-577' 'example-org/workspace')"
assert_eq "issue-N is an issue in the current repo" \
  "https://github.com/kitagry/dotfiles/issues/12" \
  "$(branch_issue_url 'fix/issue-12' 'kitagry/dotfiles')"
assert_eq "N-xxx is an issue in the current repo" \
  "https://github.com/kitagry/dotfiles/issues/34" \
  "$(branch_issue_url 'feature/34-add-foo' 'kitagry/dotfiles')"
assert_eq "N-xxx without a prefix" \
  "https://github.com/kitagry/dotfiles/issues/5" \
  "$(branch_issue_url '5-bar' 'kitagry/dotfiles')"
assert_eq "ignores a trailing number alone" \
  "" \
  "$(branch_issue_url 'fix/foo-2' 'kitagry/dotfiles')"
assert_eq "no number" \
  "" \
  "$(branch_issue_url 'feature/patient-api-go-chat' 'kitagry/dotfiles')"
assert_eq "a leading date is not an issue number" \
  "" \
  "$(branch_issue_url 'chore/2026-11-update' 'kitagry/dotfiles')"
assert_eq "empty when owner/repo is unknown" \
  "" \
  "$(branch_issue_url 'fix/issue-12' '')"

assert_eq "owner/repo from an ssh remote URL" \
  "kitagry/dotfiles" \
  "$(github_repo_from_remote 'git@github.com:kitagry/dotfiles.git')"
assert_eq "owner/repo from an https remote URL" \
  "example-org/project" \
  "$(github_repo_from_remote 'https://github.com/example-org/project')"
assert_eq "empty for hosts other than github" \
  "" \
  "$(github_repo_from_remote 'https://gitlab.example.com/group/foo.git')"

PR_JSON='{"url":"https://github.com/o/r/pull/9","state":"OPEN","isDraft":false,
  "closingIssuesReferences":[{"url":"https://github.com/o/r/issues/1"}],
  "body":"## Related issues\n- [x] https://github.com/o/releases/issues/633\n- see https://github.com/o/r/pull/3 and https://github.com/o/r/issues/1#issuecomment-5"}'
assert_eq "PR row + closing issue + issue URLs in the body (PR URLs excluded)" \
  "$(printf 'PR\tOPEN\tfalse\thttps://github.com/o/r/pull/9\nISSUE\thttps://github.com/o/r/issues/1\nISSUE\thttps://github.com/o/releases/issues/633\nISSUE\thttps://github.com/o/r/issues/1')" \
  "$(printf '%s' "$PR_JSON" | jq -r "$PR_ROW_JQ")"
assert_eq "does not fail on a null body" \
  "$(printf 'PR\tMERGED\ttrue\thttps://github.com/o/r/pull/9')" \
  "$(printf '{"url":"https://github.com/o/r/pull/9","state":"MERGED","isDraft":true,"closingIssuesReferences":[],"body":null}' | jq -r "$PR_ROW_JQ")"

strip_esc() { perl -pe 's/\e\]8;;[^\a]*\a//g; s/\e\[[0-9;]*m//g'; }
assert_eq "shows OPEN issues (empty stateReason) too" \
  "○ o/r#1  ○ o/r#2" \
  "$(render_issue_line "$(printf 'OPEN\t\thttps://github.com/o/r/issues/1\nCLOSED\tCOMPLETED\thttps://github.com/o/r/issues/2')" | strip_esc)"
assert_eq "OPEN is green" \
  "1" \
  "$(render_issue_line "$(printf 'OPEN\t\thttps://github.com/o/r/issues/1')" | grep -c $'\033\\[32m')"

exit "$FAILED"
