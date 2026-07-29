#!/usr/bin/env bash
# Thin wrapper around `herdr agent read` to peek at a pane's recent output.
# Only used when the delegate flow hits a "did not go to working" fallback and we
# need to inspect what the new Claude actually saw.
#
# Usage: read-pane.sh <pane_id> [lines=30]
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <pane_id> [lines]" >&2
  exit 2
fi

pane="$1"
lines="${2:-30}"
herdr agent read "$pane" --lines "$lines"
