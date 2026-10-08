function claude-resume -d "fzf で Claude Code のセッションを選び、そのリポに cd して claude --resume する"
    # 引数は claude にそのまま渡す (例: claude-resume --model opus)
    set -l line (~/.claude/scripts/claude-sessions.sh | fzf \
        --delimiter \t \
        --with-nth 2,3,5 \
        --tabstop 4 \
        --prompt 'Claude session >' \
        --header 'date | repo | summary' \
        --preview 'printf "repo:    %s\npath:    %s\nsession: %s\nlast:    %s\n\n%s\n" {3} {4} {1} {2} {5}' \
        --preview-window 'down:6:wrap' \
        --bind ctrl-d:preview-page-down,ctrl-u:preview-page-up)

    if test -z "$line"
        return 1
    end

    set -l parts (string split \t -- $line)
    set -l session_id $parts[1]
    set -l project $parts[4]

    cd $project
    and claude --resume $session_id $argv
end
