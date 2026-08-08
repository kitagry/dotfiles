#!/usr/bin/env bash
# Resolves the base branch name (without the "origin/" prefix) to branch off of.
#
# Usage: resolve-base.sh
#
# Resolution order:
#   1. `gh pr view --json baseRefName` (useful when branching off a feature branch with an open PR)
#   2. `git symbolic-ref --short refs/remotes/origin/HEAD` (repo's default branch)
#   3. fallback: "main"
set -euo pipefail

base=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null || true)

if [ -z "$base" ]; then
  base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)
fi

if [ -z "$base" ]; then
  base="main"
fi

echo "$base"
