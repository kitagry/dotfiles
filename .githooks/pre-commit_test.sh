#!/usr/bin/env bash
# Tests for .githooks/pre-commit. Run: bash .githooks/pre-commit_test.sh
set -u

HOOK="$(cd "$(dirname "$0")" && pwd)/pre-commit"
fails=0

# The developer's own git config (commit.gpgsign, diff.mnemonicPrefix, ...) must not
# change the outcome; cases that need a setting configure it per repo.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

setup() {
  WORK=$(mktemp -d)
  git -C "$WORK" init -q
  git -C "$WORK" config user.email test@example.com
  git -C "$WORK" config user.name test
  mkdir -p "$WORK/.githooks"
  cp "$HOOK" "$WORK/.githooks/pre-commit"
  chmod +x "$WORK/.githooks/pre-commit"
  git -C "$WORK" config core.hooksPath .githooks
  PATTERNS="$WORK/../deny-patterns-$$"
  printf '%s\n' '# comment lines are ignored' '' 'acme-corp' 'secret\.example\.com' > "$PATTERNS"
  export DOTFILES_DENY_PATTERNS="$PATTERNS"
}

teardown() {
  rm -rf "$WORK" "$PATTERNS"
}

# commit_ok <description>: expects the commit in $WORK to succeed
commit_ok() {
  if git -C "$WORK" commit -q -m test >/dev/null 2>"$WORK/.err"; then
    echo "ok   - $1"
  else
    echo "FAIL - $1 (commit was blocked)"; cat "$WORK/.err"; fails=$((fails + 1))
  fi
}

# commit_blocked <description> <expected text in stderr>
commit_blocked() {
  if git -C "$WORK" commit -q -m test >/dev/null 2>"$WORK/.err"; then
    echo "FAIL - $1 (commit went through)"; fails=$((fails + 1))
  elif ! grep -qF -- "$2" "$WORK/.err"; then
    echo "FAIL - $1 (stderr lacks '$2')"; cat "$WORK/.err"; fails=$((fails + 1))
  else
    echo "ok   - $1"
  fi
}

# --- clean change passes
setup
echo "hello world" > "$WORK/a.txt"; git -C "$WORK" add a.txt
commit_ok "clean change passes"
teardown

# --- added line with a deny pattern is blocked, and the match is reported
setup
printf 'line1\nrepo: github.com/Acme-Corp/foo\n' > "$WORK/a.txt"; git -C "$WORK" add a.txt
commit_blocked "added line matching pattern (case-insensitive) is blocked" "a.txt"
teardown

# --- regex patterns work
setup
echo "url https://secret.example.com/x" > "$WORK/b.txt"; git -C "$WORK" add b.txt
commit_blocked "regex pattern is blocked" "secret"
teardown

# --- removing a line that contains a pattern is allowed (that's the cleanup we want)
setup
echo "acme-corp" > "$WORK/c.txt"; git -C "$WORK" add c.txt
git -C "$WORK" commit -q --no-verify -m seed
: > "$WORK/c.txt"; git -C "$WORK" add c.txt
commit_ok "deleting a matching line passes"
teardown

# --- file name matching a pattern is blocked
setup
echo "nothing here" > "$WORK/acme-corp-notes.txt"; git -C "$WORK" add acme-corp-notes.txt
commit_blocked "file name matching pattern is blocked" "acme-corp-notes.txt"
teardown

# --- unstaged changes are not checked
setup
echo "clean" > "$WORK/d.txt"; git -C "$WORK" add d.txt
echo "acme-corp" >> "$WORK/d.txt"
commit_ok "unstaged matching change is ignored"
teardown

# --- missing pattern file: warn but pass
setup
rm -f "$PATTERNS"
echo "acme-corp" > "$WORK/e.txt"; git -C "$WORK" add e.txt
commit_ok "missing pattern file passes"
if ! grep -qi "warn" "$WORK/.err"; then echo "FAIL - missing pattern file should warn"; fails=$((fails + 1)); else echo "ok   - missing pattern file warns"; fi
teardown

# --- an added line starting with "++ " is content, not a header that hides later lines
setup
printf '++ x\nacme-corp\n' > "$WORK/g.txt"; git -C "$WORK" add g.txt
commit_blocked "line after a '++ ' line is still checked" "g.txt:2"
teardown

# --- quoted file names (non-ASCII with core.quotePath, or a '"' in the name)
setup
git -C "$WORK" config core.quotePath true
echo "acme-corp" > "$WORK/日本語.txt"; git -C "$WORK" add .
commit_blocked "non-ASCII file name with core.quotePath is checked" "日本語.txt:1"
teardown
setup
echo "acme-corp" > "$WORK/q\"uote.txt"; git -C "$WORK" add .
commit_blocked "file name with a quote is checked" "q\"uote.txt:1"
teardown

# --- diff prefix settings don't hide content
for setting in diff.mnemonicPrefix diff.noprefix; do
  setup
  git -C "$WORK" config "$setting" true
  echo "acme-corp" > "$WORK/h.txt"; git -C "$WORK" add h.txt
  commit_blocked "$setting does not hide content" "h.txt:1"
  teardown
done

# --- symlink replaced by a regular file (type change) is checked
setup
ln -s target "$WORK/i.txt"; git -C "$WORK" add i.txt
git -C "$WORK" commit -q --no-verify -m seed
rm "$WORK/i.txt"; echo "acme-corp" > "$WORK/i.txt"; git -C "$WORK" add i.txt
commit_blocked "symlink turned into a file is checked" "i.txt:1"
teardown

# --- an invalid regex fails closed instead of letting everything through
setup
printf '%s\n' 'acme-(' > "$PATTERNS"
echo "clean" > "$WORK/j.txt"; git -C "$WORK" add j.txt
commit_blocked "invalid pattern blocks the commit" "invalid pattern"
teardown

# --- --no-verify bypasses
setup
echo "acme-corp" > "$WORK/f.txt"; git -C "$WORK" add f.txt
if git -C "$WORK" commit -q --no-verify -m test >/dev/null 2>&1; then echo "ok   - --no-verify bypasses"; else echo "FAIL - --no-verify bypasses"; fails=$((fails + 1)); fi
teardown

if [ "$fails" -gt 0 ]; then echo "$fails test(s) failed"; exit 1; fi
echo "all tests passed"
