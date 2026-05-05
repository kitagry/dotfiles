if status is-interactive
    if not functions -q fisher
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        fisher install jorgebucaran/fisher
    end

    bind \cg _ghq_cd
    bind \t _fzf_tab_complete

    # Aliases
    alias v nvim
    alias la "ls -a"
    alias ll "ls -la"
    alias ls eza
    alias awk gawk
    alias tf terraform
    alias nvimrc "nvim ~/.config/nvim/init.lua"

    # Abbreviations (from zeno snippets)
    abbr -a gs 'git status --short --branch'
    abbr -a gd 'git diff'
    abbr -a gcim "git commit -m ''"

    if test -f ~/.config/fish/config.local.fish
        source ~/.config/fish/config.local.fish
    end
end
