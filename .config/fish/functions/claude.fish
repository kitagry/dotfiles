function claude --description 'Claude Code with user-scope mcp.json auto-loaded'
    set -l mcp_config "$HOME/.claude/mcp.json"
    if test -f "$mcp_config"
        command claude --mcp-config="$mcp_config" $argv
    else
        command claude $argv
    end
end
