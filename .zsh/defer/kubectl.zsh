if [ ! $commands[kubectl] ]; then
  return
fi

source <(kubectl completion zsh)
function right_prompt() {
  local color="blue"

  if [[ "$ZSH_KUBECTL_CONTEXT" != "docker-for-desktop" && "$ZSH_KUBECTL_CONTEXT" != "raspi" ]]; then
    color="red"
  fi

  local gcloud_config="$(cat $HOME/.config/gcloud/active_config)"
  local kube_context="$(cat $HOME/.kube/kubectx)"

  echo "%F{$color}($gcloud_config)($kube_context)%f"
}

RPROMPT='$(right_prompt)'

###########################
# kubernetesコマンドのalias
###########################
alias k='kubectl'
alias kc='kubectl ctx'
alias kn='kubectl ns'
alias sourceenv='(){set -a; source $1; set +a}'

kjf() {
  kubectl get cronjobs --all-namespaces | tr -s ' ' | cut -d ' ' -f 1,2 | tail -n +2 | fzf | xargs kj
}

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
  while getopts d:f OPT
  do
      case $OPT in
          f)  FOLLOW="-f"
            ;;
      esac
  done
# オプション部分を切り捨てる。
  shift `expr $OPTIND - 1`
  target_pod=$(kubectl get pods | sed -e '1d' | fzf | cut -d ' ' -f 1)
  if [ $target_pod ]; then
    result="$(kubectl logs $target_pod $1 |& xargs echo)"
    if [ "`echo $result | grep 'a container name must be specified for'`" ]; then
      target_container=$(kubectl get pods/$target_pod -o "jsonpath={['..containers','..initContainers'][*].name}" | tr ' ' '\n' | fzf)
      kubectl logs $FOLLOW $target_pod -c $target_container
    else
      # TODO: NOT RERUN COMMAND
      kubectl logs $FOLLOW $target_pod $1
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

kubectl_output_yaml() {
  if [ $1 ]; then
    resource=$1
  else
    resource=$(echo "pods\ndeployment\nservice" | fzf)
  fi

  if [ $resource ]; then
    target=$(kubectl get $resource | sed -e '1d' | fzf | cut -d ' ' -f 1)
    if [ $target ]; then
      kubectl get -o yaml $resource $target
    fi
  fi
}
alias kyaml='kubectl_output_yaml'

kubectl_stern() {
  target_pod=$(kubectl get pods | sed -e '1d' | fzf | cut -d ' ' -f 1)
  if [ $target_pod ]; then
    stern $target_pod
  fi
}

kubectl_exec() {
  target_pod=$(kubectl get pods | sed -e '1d' | fzf | cut -d ' ' -f 1)
  kubectl exec $target_pod -it -- bash
}
alias kexec='kubectl_exec'
alias kstern='kubectl_stern'
###########################
