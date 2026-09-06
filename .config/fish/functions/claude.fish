function claude --description 'Claude Code with user-scope mcp.json auto-loaded'
    set -l mcp_config "$HOME/.claude/mcp.json"
    set -l extra_args
    if test -f /etc/NIXOS
        set extra_args --settings '{"remoteControlAtStartup": true}'
    end
    if test -f "$mcp_config"
        command claude --mcp-config="$mcp_config" $extra_args $argv
    else
        command claude $extra_args $argv
    end
end
