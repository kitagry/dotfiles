set -gx LANG ja_JP.UTF-8
set -gx LC_TYPE ja_JP.UTF-8

set -gx GOPATH $HOME/go
set -gx GOBIN $GOPATH/bin

set -gx EDITOR nvim
set -gx NVIM_PROFILE_PATH $HOME/.local/state/nvim/nvim.profile
set -gx NVIM_STARTUPTIME_PATH $HOME/.local/state/nvim/startuptime.log

set -gx XDG_CONFIG_HOME $HOME/.config

fish_add_path $HOME/.local/bin
fish_add_path $HOME/.cargo/bin
fish_add_path $GOPATH/bin
fish_add_path /usr/local/bin /usr/local/sbin
# texlive
fish_add_path /usr/local/texlive/2017/bin/x86_64-darwin

if test -f $HOME/.cargo/env.fish
    source $HOME/.cargo/env.fish
end
