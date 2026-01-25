# git-wt shell integration
# https://github.com/k1LoW/git-wt
if (( $+commands[git-wt] )); then
  eval "$(git wt --init zsh)"
fi
