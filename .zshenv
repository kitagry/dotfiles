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

if [ $commands[cargo] ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
  source "$HOME/.cargo/env"
fi

###########################
# unixコマンドのalias
###########################
alias la="ls -a"
alias ll="ls -la"
###########################

###########################
# gitコマンドのalias
###########################
alias git="hub"
alias gs="git status"
alias gpom="git pull origin master"
alias gcb="git switch -c"
alias gbda="git branch --merged | grep -v '*' | grep -v master | grep -v main | xargs -I % git branch -d %"
###########################

###########################
# dockerコマンドのalias
###########################
alias dc="docker-compose"
alias dclean='docker rm $(docker ps -aq)'
alias dct='(){docker-compose run --rm $1 sh -c "curl -L https://github.com/c9s/gomon/releases/download/v1.3.0/gomon_v1.3.0_linux_amd64.tar.gz | tar zx -C /opt && /opt/gomon_v1.3.0_linux_amd64/gomon -R . -- go test ./..."}'
###########################

###########################
# kubernetesコマンドのalias
###########################
alias k='kubectl'
alias kc='kubectx'
alias kn='kubens'
alias sourceenv='(){set -a; source $1; set +a}'

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
      target_container=$(kubectl get pods/$target_pod -o "jsonpath={['..containers','..initContainers'][*].name}" | tr ' ' '\n' | fzf)
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
alias nvimrc="nvim ~/.config/nvim/init.vim"
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

# cdのよく行くところへのalias
alias cdg='cd $(ghq root)/github.com/kitagry'
g() {
  local src=$(ghq list | fzf --preview "bat --color=always --style=header,grid --line-range :80 $(ghq root)/{}/README.*")
  if [ -n "$src" ]; then
    repo=$(ghq list --full-path --exact $src)
    cd $repo
  fi
}

# mkdir and cd
mkcd() {
  mkdir -p "$@" && cd $_
}

[ -f "$HOME/.zshenv.local" ] && source "$HOME/.zshenv.local"
