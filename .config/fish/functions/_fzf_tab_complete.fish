function _fzf_tab_complete
    set -l tokens (commandline -poc)
    if test (count $tokens) -ge 1 && contains -- $tokens[1] v nvim
        set -l query (commandline -t)
        set -l dir_prefix ""
        set -l fzf_query $query

        if string match -qr "/" $query
            set dir_prefix (string replace -r '(.*/).*' '$1' $query)
            set fzf_query (string replace -r '.*/' '' $query)
        end

        set -l search_dir (eval echo "$dir_prefix" 2>/dev/null)
        if test -z "$search_dir" || not test -d "$search_dir"
            set search_dir "."
        end

        set -l result (fd . --base-directory "$search_dir" --hidden \
            --exclude .git \
            --exclude node_modules \
            --exclude target \
            --exclude .venv \
            --exclude __pycache__ \
            --exclude .pytest_cache \
            --exclude .mypy_cache \
            --exclude .ruff_cache \
            --exclude .tox \
            --exclude .next \
            --exclude .cache \
            --exclude dist \
            --exclude build \
            2>/dev/null | fzf --height 40% --reverse --query "$fzf_query")
        if test -n "$result"
            commandline -t -- (string escape "$dir_prefix$result")
        end
        commandline -f repaint
    else
        commandline -f complete
    end
end
