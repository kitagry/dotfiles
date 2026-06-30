set -gx SHELL (which fish)

if status is-interactive
    fish_vi_key_bindings

    if not functions -q fisher
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        fisher install jorgebucaran/fisher
    end

    bind -M insert \cg _ghq_cd
    bind -M insert \t _fzf_tab_complete
    bind -M insert \cl accept-autosuggestion

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

end
