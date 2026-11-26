#!/usr/bin/env bash
# Jots down one thing worth knowing next time, as one line in the notebook's
# inbox (<notebook>/notes/<today>.md). The nightly dream job sorts the lines
# into memory, repo notes or pending decisions, so write without judging value.
#
# Usage: note.sh "<text>" [--said] [--applied] [--repo owner/repo]
#   --said     the human said it explicitly (default: inferred)
#   --applied  already written to memory etc. (the dream only checks where it
#              landed and for duplicates)
#   --repo     the note is about this repo
#
# Line format: - HH:MM <text> {src: said|inferred, task: <task>, tab: <tab>, state: waiting|applied[, repo: owner/repo]}
# The trailing {...} is a YAML flow mapping. Where it was written from:
#   in a task:          task: <HERDR_TASK>, tab: <tab label> ("task" for the coordinator)
#   master workspace:   task: master, tab: master
#   anywhere else:      task: none, tab: <basename of cwd>
#
# NOTEBOOK_DIR overrides the notebook location (default ~/notebook).
set -euo pipefail

usage() {
  echo "usage: $0 \"<text>\" [--said] [--applied] [--repo owner/repo]" >&2
  exit 2
}

# Flags may come before or after the text, so a flag is never taken as the
# note itself.
text="" have_text=0 src=inferred state=waiting repo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --said) src=said ;;
    --applied) state=applied ;;
    --repo)
      [ $# -ge 2 ] || usage
      repo="$2"
      shift
      ;;
    --*) usage ;;
    *)
      [ "$have_text" = 0 ] || usage
      text="$1"
      have_text=1
      ;;
  esac
  shift
done
[ "$have_text" = 1 ] || usage

# Newlines (and tabs) would break the one-line-per-note format.
text=$(printf '%s' "$text" | tr '\n\r\t' '   ' | sed -E 's/^ +//; s/ +$//')
if [ -z "$text" ]; then
  echo "ERROR: empty note" >&2
  exit 2
fi
if [ -n "$repo" ] && ! printf '%s' "$repo" | grep -Eq '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'; then
  echo "ERROR: --repo must be owner/repo (got: $repo)" >&2
  exit 2
fi

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

notebook="${NOTEBOOK_DIR:-$HOME/notebook}"
if [ ! -d "$notebook" ]; then
  echo "ERROR: notebook not found: $notebook (create it, or set NOTEBOOK_DIR)" >&2
  exit 1
fi

workspace_label() {
  herdr workspace list \
    | jq -r --arg w "$HERDR_WORKSPACE_ID" '.result.workspaces[] | select(.workspace_id == $w) | .label' \
    | head -1
}

task="" tab=""
if [ -n "${HERDR_TASK:-}" ]; then
  task="$HERDR_TASK"
  if [ -n "${HERDR_WORKSPACE_ID:-}" ] && [ -n "${HERDR_PANE_ID:-}" ]; then
    tab=$(pane_tab_label "$HERDR_WORKSPACE_ID" "$HERDR_PANE_ID" 2> /dev/null || true)
  fi
elif [ -n "${HERDR_WORKSPACE_ID:-}" ] && [ "$(workspace_label 2> /dev/null || true)" = master ]; then
  task=master
  tab=master
else
  task=none
fi
# A note must never be lost to a lookup failure, so fall back to the cwd.
[ -n "$tab" ] || tab=$(basename "$PWD")

# Plain scalars only for values that YAML reads back as the same string.
yaml_value() {
  case "$1" in
    # YAML 1.1 booleans and nulls; '~' is quoted so the pattern is not tilde-expanded.
    y | Y | yes | Yes | YES | n | N | no | No | NO | true | True | TRUE | false | False | FALSE | \
      on | On | ON | off | Off | OFF | null | Null | NULL | '~') ;;
    *)
      if printf '%s' "$1" | grep -Eq '^[A-Za-z_][A-Za-z0-9._/-]*$'; then
        printf '%s' "$1"
        return
      fi
      ;;
  esac
  printf "'%s'" "${1//\'/\'\'}"
}

attrs="src: $src, task: $(yaml_value "$task"), tab: $(yaml_value "$tab"), state: $state"
[ -z "$repo" ] || attrs="$attrs, repo: $(yaml_value "$repo")"
# One clock read, so a note written at midnight lands in the file of its own time.
now=$(date '+%F %H:%M')
line="- ${now#* } $text {$attrs}"

mkdir -p "$notebook/notes"
file="$notebook/notes/${now% *}.md"
exec 9>> "$file"
# macOS has no flock by default; a single small O_APPEND write is still whole.
if command -v flock > /dev/null; then
  flock 9
fi
printf '%s\n' "$line" >&9
