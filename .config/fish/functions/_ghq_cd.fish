function _ghq_cd
    set dir (ghq list -p | fzf --prompt='Project >' \
        --preview "bat --color=always --style=numbers --line-range=:500 {}/README.md" \
        --bind ctrl-d:preview-page-down,ctrl-u:preview-page-up)

    if test -z "$dir"
        commandline -f repaint
        return
    end

    commandline -r "cd $dir"
    commandline -f execute
end
