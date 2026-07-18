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

# mysql-client (keg-only)
if type -q brew
    set -l mysql_client_prefix (brew --prefix mysql-client 2>/dev/null)
    if test -d "$mysql_client_prefix"
        fish_add_path $mysql_client_prefix/bin
        set -gx LDFLAGS "-L$mysql_client_prefix/lib"
        set -gx CPPFLAGS "-I$mysql_client_prefix/include"
        set -gx PKG_CONFIG_PATH "$mysql_client_prefix/lib/pkgconfig"
    end
end

alias k kubectl

# herdr plugins resolve the herdr binary via this var before falling back to
# a PATH lookup; mise-managed herdr isn't on the trimmed PATH plugin scripts use.
set -gx HERDR_BIN_PATH $HOME/.local/share/mise/shims/herdr

if test -f $HOME/.cargo/env.fish
    source $HOME/.cargo/env.fish
end
