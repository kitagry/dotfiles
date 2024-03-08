# # uncommennt the following code in order to measure time.
# zmodload zsh/zprof && zprof
export LANG=ja_JP.UTF-8
export LC_TYPE=ja_JP.UTF-8
export PATH="/usr/local/bin:/usr/local/sbin:/sbin/:$PATH"
export PATH="/usr/local/opt/python@3/bin:$PATH"
export PATH="/usr/local/lib:/usr/local/texlive/2017/bin/x86_64-darwin/tlmgr:$PATH"
export GOPATH="$HOME/go/"
export GO111MODULE=on

export PATH="$GOPATH/bin:$PATH"
export NVIM_LISTEN_ADDRESS="/tmp/nvimsocket"

export PATH="/usr/local/opt/llvm/bin:$PATH"
export QT_HOMEBREW=true

export NVIM_PROFILE_PATH="$HOME/.local/state/nvim/nvim.profile"
export EDITOR="nvim --startuptime $NVIM_PROFILE_PATH"
alias nvim=$EDITOR

export PATH="$HOME/.cargo/bin:$PATH"
source "$HOME/.cargo/env"

###########################
# unixコマンドのalias
###########################
alias la="ls -a"
alias ll="ls -la"
###########################

###########################
# neovimコマンドのalias
###########################
rgvim() {
  file=$(rg --color=never --no-heading -n $@ | fzf)
  if [ $file ]; then
    file_name=$(echo $file | cut -d ':' -f 1)
    line=$(echo $file | cut -d ':' -f 2)
    $EDITOR $file_name -c ":${line}"
  fi
}
fdvim() {
  file=$(fd --color=never $@ | fzf)
  if [ $file ]; then
    $EDITOR $file
  fi
}
###########################

###########################
# 便利系
###########################
alias zshrc="$EDITOR ~/.zshrc"
alias zshenv="$EDITOR ~/.zshenv"
alias vimrc="$EDITOR ~/.vimrc"
alias nvimrc="$EDITOR ~/.config/nvim/init.lua"
alias ls="eza"
###########################

# viとvimを紐づける
vi() {
  if [ $1 ]; then
    count=$(ls $* | wc -l)
    if [ $count -gt 1 ]; then
      vim -O2 $*
    else
      vim $*
    fi
  else
    vim
  fi
}

# awkをgawkにする
alias awk="gawk"
alias tf="terraform"

# see nvim startup probe
export NVIM_STARTUPTIME_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/nvim/startuptime.log"
alias nvim="nvim --startuptime $NVIM_STARTUPTIME_PATH"

# mkdir and cd
mkcd() {
  mkdir -p "$@" && cd $_
}

[ -f "$HOME/.zshenv.local" ] && source "$HOME/.zshenv.local"
