autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit;
else
  compinit -C;
fi;

# This is very slow
# if [ -d $HOME/google-cloud-sdk ]; then
#   source $HOME/google-cloud-sdk/path.zsh.inc
#   source $HOME/google-cloud-sdk/completion.zsh.inc
# fi

if command -v lab 1>/dev/null 2>&1; then
  eval "$(lab completion zsh)"
fi

if command -v $HOME/.cargo/bin/mise 1>/dev/null 2>&1; then
  eval "$($HOME/.cargo/bin/mise activate zsh)"
fi
