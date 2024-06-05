if [[ ! -a '.zsh/completion/_git' ]]; then
  curl -o _git https://raw.githubusercontent.com/glidenote/hub-zsh-completion/master/_git
  mv _git .zsh/completion/
fi
