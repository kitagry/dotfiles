# 環境変数
export LANG=ja_JP.UTF-8
if [ -d $HOME/google-cloud-sdk ]; then
  source $HOME/google-cloud-sdk/path.zsh.inc
  source $HOME/google-cloud-sdk/completion.zsh.inc
fi

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
zstyle ':completion:*:default' menu select=2
if [ -e $HOME/.zsh/completion ]; then
  export FPATH="/home/kitagry/.zsh/completion/:$FPATH"
  autoload _git
  compdef hub=git
fi
# 補完で小文字でも大文字にマッチさせる
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# 補完候補を詰めて表示
setopt list_packed
# 補完候補一覧をカラー表示
zstyle ':completion:*' list-colors ''

autoload -Uz compinit
compinit -u

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

### Added by Zplugin's installer
if [ ! -e "$HOME/.zinit/bin/zinit.zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zinit/master/doc/install.sh)"
fi

source "$HOME/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

zinit light b4b4r07/enhancd
export ENHANCD_FILTER=fzf

zinit light zsh-users/zsh-autosuggestions
bindkey '^l' autosuggest-accept
zinit light zsh-users/zsh-syntax-highlighting

zinit ice pick"async.zsh" src"pure.zsh"
zinit light sindresorhus/pure
export PURE_GIT_PULL=1
export PURE_GIT_UNTRACKED_DIRTY=1

zinit ice from"gh"
zinit light zsh-users/zaw
bindkey '^R' zaw-history
bindkey '^B' zaw-git-branches

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

## kubernetes completes
if [ $commands[kubectl] ]; then
  zinit ice pick"gh" src"kubectl.zsh"
  zinit light superbrothers/zsh-kubectl-prompt
  RPROMPT='%F{blue}($ZSH_KUBECTL_PROMPT)%f'
  source <(kubectl completion zsh)
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
