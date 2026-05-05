function gb
    set branch (git branch --all | grep -v '* ' | fzf --prompt='Switch Branch> ' | string trim)
    if test -n "$branch"
        git switch (string replace -r '^remotes/[^/]+/' '' $branch)
    end
end
