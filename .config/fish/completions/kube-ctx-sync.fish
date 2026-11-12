complete -c kube-ctx-sync -f
complete -c kube-ctx-sync -s h -l help -d 'show usage'
complete -c kube-ctx-sync -l list -d 'show alias -> context'
complete -c kube-ctx-sync -l rm -d 'remove split kubeconfig + completions'
complete -c kube-ctx-sync -n '__fish_seen_argument -l rm' -a '(__kube_ctx_names)'
complete -c kube-ctx-sync -n 'not __fish_seen_argument -l rm -l list' -a '(kubectl config get-contexts -o name 2>/dev/null)' -d context
