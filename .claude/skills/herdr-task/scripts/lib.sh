# Shared helpers for herdr-task scripts. Source it; do not execute.

# HERDR_TASKS_ROOT is overridable so a dry run can use a scratch directory
# without touching the real ~/tasks.
tasks_root() {
  printf '%s' "${HERDR_TASKS_ROOT:-$HOME/tasks}"
}

task_dir() {
  printf '%s/%s' "$(tasks_root)" "$1"
}

validate_task_name() {
  # The task name doubles as the git branch name and the herdr label, so keep
  # it to characters that are safe in both.
  if ! printf '%s' "$1" | grep -Eq '^[a-z0-9][a-z0-9._-]*$'; then
    echo "ERROR: task name must match ^[a-z0-9][a-z0-9._-]*\$ (got: $1)" >&2
    return 1
  fi
}

# Prints the workspace_id whose label equals the task name (empty if none).
find_task_workspace() {
  herdr workspace list \
    | jq -r --arg label "$1" '.result.workspaces[] | select(.label == $label) | .workspace_id' \
    | head -1
}

# Succeeds if Claude Code would open <path> without the trust dialog, i.e. the
# path or one of its parents has been accepted. Claude Code judges a linked
# worktree by its main repo, so that is checked too. Reads ~/.claude.json only:
# writing it races with running Claude sessions that rewrite the same file.
is_trusted() {
  local p common
  common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
  if [ -n "$common" ] && [ "$(basename "$common")" = ".git" ] \
    && [ "$(dirname "$common")" != "$(realpath -m "$1")" ] \
    && is_trusted "$(dirname "$common")"; then
    return 0
  fi
  p=$(realpath -m "$1")
  while :; do
    if jq -e --arg p "$p" '.projects[$p].hasTrustDialogAccepted == true' "$HOME/.claude.json" > /dev/null 2>&1; then
      return 0
    fi
    [ "$p" = "/" ] && return 1
    p=$(dirname "$p")
  done
}

# Appends <line> at the end of the "## Repos" section of TASK.md, so entries
# stay in added order. Blank lines inside the section are held back so the
# line lands above the gap before the next heading.
append_repo_line() {
  local file="$1" line="$2"
  awk -v line="$line" '
    in_repos && /^$/ { blanks++; next }
    in_repos && /^## / { print line; in_repos = 0 }
    { while (blanks > 0) { print ""; blanks-- } print }
    /^## Repos/ { in_repos = 1 }
    END { if (in_repos) print line; while (blanks > 0) { print ""; blanks-- } }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Reports the task's repo tabs as the workspace's $repos sidebar token
# ([ui.sidebar.spaces] rows in herdr's config.toml). Task workspaces sit in a
# non-git dir, so the built-in branch/git_status rows are empty for them.
# Display-only, so a failure is not fatal.
report_repos() {
  local ws_id="$1" repos
  repos=$(herdr tab list --workspace "$ws_id" \
    | jq -r '[.result.tabs[] | select(.label != "task") | .label] | join(" ")')
  herdr workspace report-metadata "$ws_id" --source herdr-task --token "repos=$repos" > /dev/null \
    || echo "WARN: failed to report \$repos for $ws_id" >&2
}

# Worktree dir name for a tab label: "bqls#671" -> "bqls-671".
label_dir() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9._-]/-/g'
}

# Succeeds if <label> is already a tab of the task or its dir exists.
label_taken() {
  local dir="$1" ws_id="$2" label="$3"
  [ -e "$dir/$(label_dir "$label")" ] && return 0
  herdr tab list --workspace "$ws_id" \
    | jq -e --arg l "$label" '.result.tabs | any(.label == $l)' > /dev/null
}

# Moves the "- `<label>`: ..." line from "## Repos" to the end of "## Done"
# (created at the end of the file if missing).
move_repo_line_to_done() {
  local file="$1" label="$2"
  awk -v prefix="- \`$label\`:" '
    index($0, prefix) == 1 && !moved { line = $0; moved = 1; next }
    { lines[++n] = $0 }
    /^## Done/ { has_done = 1; done_at = n }
    END {
      if (!moved) { for (i = 1; i <= n; i++) print lines[i]; exit }
      if (!has_done) { lines[++n] = ""; lines[++n] = "## Done"; done_at = n }
      # End of the Done section: next heading after it, else end of file.
      end_at = n
      for (i = done_at + 1; i <= n; i++) if (lines[i] ~ /^## /) { end_at = i - 1; break }
      while (end_at > done_at && lines[end_at] == "") end_at--
      for (i = 1; i <= n; i++) { print lines[i]; if (i == end_at) print line }
    }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}
