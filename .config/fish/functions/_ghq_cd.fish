function _ghq_cd
    set dir (ghq list -p | fzf --prompt='Project >' \
        --preview "bat --color=always --style=numbers --line-range=:500 {}/README.md" \
        --bind ctrl-d:preview-page-down,ctrl-u:preview-page-up)

    if test -z "$dir"
        commandline -f repaint
        return
    end

    set session (string replace -a '.' '-' (basename $dir))

    if set -q TMUX
        commandline -r "cd $dir && tmux rename-window $session"
    else
        commandline -r "cd $dir"
    end
    commandline -f execute
end
