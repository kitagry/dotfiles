function fdvim
    set file (fd --color=never $argv | fzf)
    if test -n "$file"
        $EDITOR $file
    end
end
