export ZENO_GIT_CAT="cat"
export ZENO_GIT_TREE="tree"
if [[ -n $ZENO_LOADED ]]; then
  bindkey ' ' zeno-auto-snippet
  bindkey '^m' zeno-auto-snippet-and-accept-line
  bindkey '^i' zeno-completion
  bindkey '^r' zeno-history-selection
  bindkey '^x^s' zeno-insert-snippet

  zle -N git-switch-branch _git_switch_branch
  zle -N git-switch-branch-with-origin _git_switch_branch_with_remote
  bindkey '^k' git-switch-branch-with-origin
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

    BUFFER="cd ${dir} && tmux rename-window \"${session}\""
    zle accept-line
  else
    BUFFER="cd ${dir}"
    zle accept-line
  fi
}
zle -N ghq-cd _ghq_cd
bindkey '^g' ghq-cd
fi
