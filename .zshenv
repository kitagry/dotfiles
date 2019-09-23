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
# kubernetesコマンドのalias
###########################
alias k='kubectl'
alias kc='kubectx'
alias kn='kubens'

kustomize_build() {
  kustomize_file_path=$(find . -name kustomization.yaml -o -name kustomization.yml -o -name Kustomization -type f | fzf)
  if [ $kustomize_file_path ]; then
    kustomize build $(dirname $kustomize_file_path)
  fi
}
alias kb='kustomize_build'

kubectl_command_f() {
  yaml_file=$(find . -name \*.yaml -o -name \*.yml | fzf)
  if [ $yaml_file ]; then
    kubectl $1 -f $yaml_file
  fi
}

alias kaf='kubectl_command_f apply'
alias kdf='kubectl_command_f delete'
alias kai='kubectl apply -f -'
alias kdi='kubectl delete -f -'

kubectl_log() {
  target_pod=$(kubectl get pods | sed -e '1d' | cut -d ' ' -f 1 | fzf)
  if [ $target_pod ]; then
    kubectl logs $target_pod
  fi
}
alias klog='kubectl_log'

kubectl_describe() {
  target=$(kubectl get $1 | sed -e '1d' | cut -d ' ' -f 1 | fzf)
  if [ $target ]; then
    kubectl describe $1 $target
  fi
}
alias kdes='kubectl_describe'
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
alias cdg='cd $(ghq root)/github.com/kitagry'
alias g='cd $(ghq root)/$(ghq list | fzf)'

# mkdir and cd
mkcd() {
  mkdir -p "$@" && cd $_
}

[ -f "$HOME/.zshenv.local" ] && source "$HOME/.zshenv.local"
