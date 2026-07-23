#!/bin/sh
# herdr keybind script: focus an existing nvim GinStatus pane in the current
# workspace, or spawn a new one to the right if none exists.
#
# Identifies our pane by label ($LABEL). Set via herdr keybind of type = "shell".
# Depends on: HERDR_SOCKET_PATH, HERDR_WORKSPACE_ID, HERDR_PANE_ID env vars
# (herdr injects these when the keybind fires).

set -e

SOCK="${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}"
WS="${HERDR_ACTIVE_WORKSPACE_ID:?HERDR_ACTIVE_WORKSPACE_ID not set (invoke via herdr keybind)}"
CUR="${HERDR_ACTIVE_PANE_ID:?HERDR_ACTIVE_PANE_ID not set (invoke via herdr keybind)}"
LABEL="gin-status"
NVIM_CMD='nvim -c "autocmd User DenopsPluginPost:gin ++once GinStatus"'

rpc() {
    printf '%s\n' "$1" | nc -U "$SOCK"
}

# 1. Look for an existing pane in the current workspace labeled $LABEL.
existing=$(rpc '{"id":"list","method":"pane.list","params":{}}' \
    | jq -r --arg ws "$WS" --arg label "$LABEL" \
        '.result.panes[]? | select(.label==$label and .workspace_id==$ws) | .pane_id' \
    | head -n1)

if [ -n "$existing" ]; then
    rpc "$(jq -cn --arg id "$existing" \
        '{id:"focus",method:"pane.focus",params:{pane_id:$id}}')" >/dev/null
    exit 0
fi

# 2. Spawn a new pane split-right from the invoking pane, focused.
split_res=$(rpc "$(jq -cn --arg id "$CUR" \
    '{id:"split",method:"pane.split",params:{target_pane_id:$id,direction:"right",focus:true}}')")
new=$(printf '%s' "$split_res" \
    | jq -r '.result.pane.pane_id // .result.pane_id // empty')

if [ -z "$new" ]; then
    echo "gin-focus-or-spawn: pane.split failed: $split_res" >&2
    exit 1
fi

# 3. Tag the new pane so future invocations find it.
rpc "$(jq -cn --arg id "$new" --arg label "$LABEL" \
    '{id:"rename",method:"pane.rename",params:{pane_id:$id,label:$label}}')" >/dev/null

# 4. Send the nvim command (with a trailing newline to actually execute it).
rpc "$(jq -cn --arg id "$new" --arg text "$NVIM_CMD
" '{id:"send",method:"pane.send_text",params:{pane_id:$id,text:$text}}')" >/dev/null
