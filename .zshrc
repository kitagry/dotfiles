# 環境変数
export LANG=ja_JP.UTF-8

if command -v $HOME/.cargo/bin/mise 1>/dev/null 2>&1; then
  eval "$($HOME/.cargo/bin/mise activate zsh)"
fi

### Added by zinit's installer
eval "$(mise activate zsh)"
if [ ! $commands[sheldon] ]; then
  curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh \
    | bash -s -- --repo rossmacarthur/sheldon --to ~/.local/bin
  export PATH="~/.local/bin:$PATH"
fi
export XDG_CONFIG_HOME="$HOME/.config"
eval "$(sheldon source)"

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
if (which zprof > /dev/null 2>&1) ;then
  zprof
fi
