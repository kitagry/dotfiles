if [[ ! -a '.zsh/completion/_git' ]]; then
  wget https://raw.githubusercontent.com/glidenote/hub-zsh-completion/master/_git
  mv _git .zsh/completion/
fi
