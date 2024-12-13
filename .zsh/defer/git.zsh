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

# contains(string, substring)
#
# Returns 0 if the specified string contains the specified substring,
# otherwise returns 1.
contains() {
    string="$1"
    substring="$2"
    if [ "${string#*"$substring"}" != "$string" ]; then
        return 0    # $substring is in $string
    else
        return 1    # $substring is not in $string
    fi
}

# PRかMR名からブランチを切り替える
_git_switch_branch_with_remote() {
  local git_origin="$(git remote get-url origin)"
  if [[ "$git_origin" =~ .*github.com.* ]]; then
    # github
    local pr_number=$(gh pr list | ${ZENO_FZF_COMMAND} ${ZENO_FZF_TMUX_OPTIONS} --prompt='Switch Branch >')

    if [[ "$pr_number" =~ ^([0-9]*) ]]; then
      gh pr checkout $match[1]
      zle accept-line
    fi
  else
    # gitlab
    local mr_number=$(glab mr list | ${ZENO_FZF_COMMAND} ${ZENO_FZF_TMUX_OPTIONS} --prompt='Switch Branch >')

    if [[ "$mr_number" =~ \!([0-9]*) ]]; then
      glab mr checkout $match[1]
      zle accept-line
    fi
  fi
}
###########################
