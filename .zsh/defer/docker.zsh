###########################
# dockerコマンドのalias
###########################
alias dc="docker compose"
alias dclean='docker rm $(docker ps -aq)'
alias dct='(){docker-compose run --rm $1 sh -c "curl -L https://github.com/c9s/gomon/releases/download/v1.3.0/gomon_v1.3.0_linux_amd64.tar.gz | tar zx -C /opt && /opt/gomon_v1.3.0_linux_amd64/gomon -R . -- go test ./..."}'
###########################
