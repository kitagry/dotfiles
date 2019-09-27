export PATH="/usr/local/bin:/usr/local/sbin:/sbin/:$PATH"
export PATH="/usr/local:$PATH"
export PATH="$HOME/.nodebrew/current/bin:$PATH"
export PATH="/usr/local/lib/:/usr/local/texlive/2017/bin/x86_64-darwin/tlmgr:$PATH"
export GOROOT="/usr/local/opt/go/libexec"
export GOPATH="$HOME/go/"
export GO111MODULE=on

export PATH="$GOPATH/bin:$PATH"
export NVIM_LISTEN_ADDRESS="/tmp/nvimsocket"

export PATH="/usr/local/opt/llvm/bin:$PATH"
export QT_HOMEBREW=true

export NVIM_PYTHON_LOG_FILE="$HOME/.config/nvim/logs/python.log"

export PATH="$HOME/.cargo/bin:$PATH"

###########################
# unixコマンドのalias
###########################
alias la="ls -a"
alias ll="ls -la"
###########################

###########################
# gitコマンドのalias
###########################
alias gs="git status"
alias gpom="git pull origin master"
alias gcb="git switch -c"
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

kubectl_command_get() {
  if [ $2 ]; then
    resource=$2
  else
    resource=$(echo "pods\ndeployment\njob\ncronjob" | fzf)
  fi

  resource_name=$(kubectl get $resource | sed -e '1d' | fzf | cut -d ' ' -f 1)
  if [ $resource_name ]; then
    kubectl $1 $resource $resource_name
  fi
}

kubectl_delete_all() {
  if [ $1 ]; then
    resource=$1
  else
    resource=$(echo "pods\ndeployment\njob\ncronjob" | fzf)
  fi

  if [ $resource ]; then
    echo -e "You really delete all \e[31;1m${resource}\e[m?(Y/n): "
    if read -q; then
      kubectl delete $(kubectl get $resource -o name)
    fi
  fi
}

alias kaf='kubectl_command_f apply'
alias kdf='kubectl_command_f delete'
alias kai='kubectl apply -f -'
alias kdi='kubectl delete -f -'
alias kdr='kubectl_command_get delete'
alias kda='kubectl_delete_all'

kubectl_log() {
  target_pod=$(kubectl get pods | sed -e '1d' | fzf | cut -d ' ' -f 1)
  if [ $target_pod ]; then
    result="$(kubectl logs $target_pod $1 |& xargs echo)"
    if [ "`echo $result | grep 'a container name must be specified for'`" ]; then
      target_container=$(echo $result | cut -d '[' -f 2 | cut -d ']' -f1 | tr ' ' '\n' | fzf)
      kubectl logs $target_pod $target_container
    else
      # TODO: NOT RERUN COMMAND
      kubectl logs $target_pod $1
    fi
  fi
}
alias klog='kubectl_log'

kubectl_describe() {
  if [ $1 ]; then
    resource=$1
  else
    resource=$(echo "pods\ndeployment\nservice" | fzf)
  fi

  if [ $resource ]; then
    target=$(kubectl get $resource | sed -e '1d' | fzf | cut -d ' ' -f 1)
    if [ $target ]; then
      kubectl describe $resource $target
    fi
  fi
}
alias kdes='kubectl_describe'

kubectl_stern() {
  target_pod=$(kubectl get pods | sed -e '1d' | fzf | cut -d ' ' -f 1)
  if [ $target_pod ]; then
    stern $target_pod
  fi
}
alias kstern='kubectl_stern'
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
