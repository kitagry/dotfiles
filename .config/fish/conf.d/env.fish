set -gx LANG ja_JP.UTF-8
set -gx LC_TYPE ja_JP.UTF-8

set -gx GOPATH $HOME/go
set -gx GOBIN $GOPATH/bin

set -gx EDITOR nvim
set -gx NVIM_PROFILE_PATH $HOME/.local/state/nvim/nvim.profile
set -gx NVIM_STARTUPTIME_PATH $HOME/.local/state/nvim/startuptime.log

set -gx XDG_CONFIG_HOME $HOME/.config

set -gx PATH $HOME/.local/bin $HOME/.cargo/bin $GOPATH/bin /opt/homebrew/bin /usr/local/bin /usr/local/sbin $PATH
# texlive
fish_add_path /usr/local/texlive/2017/bin/x86_64-darwin

alias k kubectl

if test -f $HOME/.cargo/env.fish
    source $HOME/.cargo/env.fish
end
