function claude --description 'Claude Code with user-scope mcp.json auto-loaded'
    set -l mcp_config "$HOME/.claude/mcp.json"
    set -l extra_args
    if test -f /etc/NIXOS
        set extra_args --settings '{"remoteControlAtStartup": true}'
    end
    # Heavy MCP servers are opt-in per session: CLAUDE_MCP="chrome-devtools mcp-obsidian" claude
    for name in (string split ' ' -- $CLAUDE_MCP)
        test -n "$name"; or continue
        set -l extra "$HOME/.claude/mcp.d/$name.json"
        if test -f "$extra"
            set -a extra_args --mcp-config="$extra"
        else
            echo "claude: unknown MCP '$name' (no $extra)" >&2
        end
    end
    if test -f "$mcp_config"
        command claude --mcp-config="$mcp_config" $extra_args $argv
    else
        command claude $extra_args $argv
    end
end
