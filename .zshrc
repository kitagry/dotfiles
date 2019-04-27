# 環境変数
export LANG=ja_JP.UTF-8

# ヒストリの設定
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
# 直前のコマンドの重複を削除
setopt hist_ignore_dups
# 同じコマンドをヒストリに残さない
setopt hist_ignore_all_dups # 同時に起動したzshの間でヒストリを共有 setopt share_history
# ディレクトリ名だけで移動
setopt auto_cd
# キーバインドをviにする
bindkey -v

# 補完機能を有効にする
autoload -Uz compinit
compinit -u
zstyle ':completion:*:default' menu select=2
if [ -e /usr/local/share/zsh-completions ]; then
  fpath=(/usr/local/share/zsh-completions $fpath)
fi
# 補完で小文字でも大文字にマッチさせる
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# 補完候補を詰めて表示
setopt list_packed
# 補完候補一覧をカラー表示
zstyle ':completion:*' list-colors ''

# コマンドのスペルを訂正
setopt correct
# ビープ音を鳴らさない
setopt no_beep

# prompt
autoload -Uz vcs_info
setopt prompt_subst

# lsに色を付ける
export CLICOLOR=1
export LSCOLORS=exfxcxdxbxegedabagacad
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion:*' list-colors 'di=34' 'ln=35' 'so=32' 'ex=31' 'bd=46;34' 'cd=43;34'

case ${OSTYPE} in
  darwin*)
    export ZPLUG_HOME=/usr/local/opt/zplug
    ;;
  linux*)
    export ZPLUG_HOME=~/.zplug
    ;;
esac

if [ -e $ZPLUG_HOME/init.zsh ]; then
  source $ZPLUG_HOME/init.zsh

  # zplug
  zplug 'zplug/zplug', hook-build:'zplug --self-manage'

  zplug "junegunn/fzf-bin", as:command, rename-to:"fzf", from:gh-r
  zplug "b4b4r07/enhancd", use:init.sh
  export ENHANCD_FILTER=fzf

  zplug "zsh-users/zsh-syntax-highlighting"

  zplug "mafredri/zsh-async", from:github
  zplug "sindresorhus/pure", use:pure.zsh, from:github, as:theme

  zplug "zsh-users/zaw", from:github
  if zplug check zsh-users/zaw; then
    bindkey '^R' zaw-history
    bindkey '^B' zaw-git-branches
  fi

  if ! zplug check --verbose; then
    printf 'Install? [y/N]: '
    if read -q; then
      echo; zplug install
    fi
  fi

  zplug load --verbose
fi
