export PATH="/usr/local/bin:/usr/local/sbin:/sbin/:$PATH"
export PATH="/usr/local:$PATH"
export PATH="$HOME/.nodebrew/current/bin:$PATH"
export PATH="/usr/local/lib/:/usr/local/texlive/2017/bin/x86_64-darwin/tlmgr:$PATH"
export GOROOT="/usr/local/opt/go/libexec"
export GOPATH="$HOME/go/"
export GO111MODULE=on

export ANT_HOME="/usr/local/bin/ant/"
export PATH="$PATH:$ANT_HOME/bin"

export PATH="$GOPATH/bin:$PATH"
export NVIM_LISTEN_ADDRESS="/tmp/nvimsocket"

export PATH="/usr/local/opt/llvm/bin:$PATH"
export QT_HOMEBREW=true

export NVIM_PYTHON_LOG_FILE="$HOME/.config/nvim/logs/python.log"

export PATH="${HOME}/.cargo/bin:${PATH}"

###########################
# unixコマンドのalias
###########################
alias la="ls -a"
alias ll="ls -la"
###########################

###########################
# gitコマンドのalias
###########################
# alias gb="git branch"
alias gc="git checkout"
alias gs="git status"
alias gcm="git checkout master"
alias gpom="git pull origin master"
alias gcb="git checkout -b"
alias gbda="git branch --merged | grep -v '*' | xargs -I % git branch -d %"
###########################

###########################
# dockerコマンドのalias
###########################
alias dc="docker-compose"
alias dcu="docker-compose up"
alias dcr="docker-compose run --rm"
###########################

###########################
# 便利系
###########################
alias zshrc="vim ~/.zshrc"
alias zshenv="vim ~/.zshenv"
alias vimrc="vim ~/.vimrc"
###########################

# viとvimを紐づける
alias vi="vim"

# redis-serverのあとターミナルが占拠されないようにする
alias redis-server='redis-server /usr/local/etc/redis.conf &'

# awkをgawkにする
alias awk="gawk"

# cdのよく行くところへのalias
alias g='cd $(ghq root)/$(ghq list | fzf)'

# mkdir and cd
mkcd() {
  mkdir -p "$@" && cd $_
}

[ -f "$HOME/.zshenv.local" ] && source "$HOME/.zshenv.local"
