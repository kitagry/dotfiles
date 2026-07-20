#!/bin/bash
# Installs the herdr plugins this setup uses. Idempotent (safe to re-run).
#
# Not wired into install.sh on purpose: herdr is an optional tool, and if it's
# ever dropped, everything related to it should stay self-contained under
# .config/herdr/ instead of needing cleanup somewhere else. Run this by hand
# whenever adopting herdr on a new machine:
#
#   bash .config/herdr/setup-plugins.sh

set -eu

if ! command -v herdr >/dev/null 2>&1; then
    echo "herdr not found on PATH" >&2
    exit 1
fi

install_plugin() {
    local id="$1" source="$2"
    local already
    already=$(herdr plugin list --json 2>/dev/null | jq -r --arg id "$id" '.result.plugins[]? | select(.plugin_id == $id) | .plugin_id')
    if [ -n "$already" ]; then
        echo "already installed: $id"
    else
        echo "installing: $source"
        herdr plugin install "$source" --yes
    fi
}

install_plugin "persiyanov.reviewr" "persiyanov/herdr-reviewr"
