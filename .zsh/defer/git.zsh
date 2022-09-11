###########################
# gitコマンドのalias
###########################
alias gp="git push -u"
alias gbda="git branch --merged | grep -v '*' | grep -v master | grep -v main | xargs -I % git branch -d %"
alias gcr="git log --oneline | head -n 2 | tail -n 1 | cut -d ' ' -f1 | xargs git reset --hard"
_git_switch_branch() {
  local branch=$(git branch --all | sed -e "s/^[*]* *//g" | ${ZENO_FZF_COMMAND} ${ZENO_FZF_TMUX_OPTIONS} --prompt='Switch Branch >' --preview "git log --color=always {}" | sed -e 's$remotes/origin/$$g')

  if [[ "$branch" == "" ]]; then
    return 1
  fi
  git switch $branch
  zle accept-line
}
###########################
