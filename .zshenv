export PATH="/usr/local/bin:/usr/local/sbin:/sbin/:$PATH"
export PATH="/usr/local:$PATH"
export PATH="$HOME/.nodebrew/current/bin:$PATH"
export PATH="/usr/local/lib/:/usr/local/texlive/2017/bin/x86_64-darwin/tlmgr:$PATH"
export PATH="$HOME/.goenv/bin:$PATH"
export GOROOT="/usr/local/opt/go/libexec"
export GOPATH="$HOME/go/"
alias cdg="cd $GOPATH/src/github.com/kitagry/"

export PATH="$GOPATH/bin:$PATH"

export QT_HOMEBREW=true

export NVIM_PYTHON_LOG_FILE="$HOME/.config/nvim/logs/python.log"

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

# viとnvimを紐づける
alias vi="nvim"

# redis-serverのあとターミナルが占拠されないようにする
alias redis-server='redis-server /usr/local/etc/redis.conf &'

# awkをgawkにする
alias awk="gawk"
