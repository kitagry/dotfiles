autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit;
else
  compinit -C;
fi;

if [ -d $HOME/google-cloud-sdk ]; then
  source $HOME/google-cloud-sdk/path.zsh.inc
  source $HOME/google-cloud-sdk/completion.zsh.inc
fi

if command -v lab 1>/dev/null 2>&1; then
  eval "$(lab completion zsh)"
fi

if command -v pyenv 1>/dev/null 2>&1; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/shims:$PATH"
  eval "$(pyenv init -)"
fi

if command -v rbenv 1>/dev/null 2>&1; then
  eval "$(rbenv init -)"
fi
