# 環境変数
export LANG=ja_JP.UTF-8
if [ -d $HOME/google-cloud-sdk ]; then
  source $HOME/google-cloud-sdk/path.zsh.inc
  source $HOME/google-cloud-sdk/completion.zsh.inc
fi

### Added by zinit's installer
if [ ! $commands[sheldon] ]; then
  curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh \
    | bash -s -- --repo rossmacarthur/sheldon --to ~/.local/bin
  export PATH="~/.local/bin:$PATH"
fi
export XDG_CONFIG_HOME="$HOME/.config"
eval "$(sheldon source)"

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
