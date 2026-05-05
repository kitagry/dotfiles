function _fzf_tab_complete
    set -l tokens (commandline -poc)
    if test (count $tokens) -ge 1 && contains -- $tokens[1] v nvim
        set -l query (commandline -t)
        set -l result (fzf --height 40% --reverse --query $query)
        if test -n "$result"
            commandline -t -- (string escape $result)
        end
        commandline -f repaint
    else
        commandline -f complete
    end
end
