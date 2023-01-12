# 環境変数
export LANG=ja_JP.UTF-8

### Added by zinit's installer
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
