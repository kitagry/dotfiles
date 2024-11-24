export ZENO_GIT_CAT="cat"
export ZENO_GIT_TREE="tree"
if [[ -n $ZENO_LOADED ]]; then
  bindkey ' ' zeno-auto-snippet
  bindkey '^m' zeno-auto-snippet-and-accept-line
  bindkey '^i' zeno-completion
  bindkey '^r' zeno-history-selection
  bindkey '^x^s' zeno-insert-snippet

  zle -N git-switch-branch _git_switch_branch
  bindkey '^B' git-switch-branch
  bindkey '^b' git-switch-branch


# cdのよく行くところへのalias
alias cdg='cd $(ghq root)/github.com/kitagry'

# ghqで移動
_ghq_cd() {
  local project dir repository session current_session
  dir=$(ghq list -p | sed -e "s|${HOME}|~|" | ${ZENO_FZF_COMMAND} ${ZENO_FZF_TMUX_OPTIONS} --prompt='Project >' --preview "bat --color=always --style=numbers --line-range=:500 \$(eval echo {})/README.md" --bind ctrl-d:preview-page-down,ctrl-u:preview-page-up)

  if [[ $dir == "" ]]; then
    return 1
  fi

  if [[ ! -z ${TMUX} ]]; then
    repository=${dir##*/}
    session=${repository//./-}

    BUFFER="cd ${dir}"
    zle accept-line

    current_session=$(tmux list-sessions | grep 'attached' | cut -d":" -f1)
    if [[ $session -eq $current_session ]]; then
      tmux rename-session "${session}"
    fi
  else
    BUFFER="cd ${dir}"
    zle accept-line
  fi
}
zle -N ghq-cd _ghq_cd
bindkey '^g' ghq-cd
fi
