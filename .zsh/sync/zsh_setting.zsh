# ヒストリの設定
export HISTFILE=~/.zsh_history
export HISTSIZE=100000000
export SAVEHIST=100000000
# 直前のコマンドの重複を削除
setopt hist_ignore_dups
# 同じコマンドをヒストリに残さない
setopt hist_ignore_all_dups
# 同時に起動したzshの間でヒストリを共有
setopt share_history
# zenoでの改行問題
setopt hist_reduce_blanks
# ディレクトリ名だけで移動
setopt auto_cd
# キーバインドをviにする
bindkey -v

# prompt
autoload -Uz vcs_info
setopt prompt_subst
# lsに色を付ける
export CLICOLOR=1
export LSCOLORS=exfxcxdxbxegedabagacad
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion:*' list-colors 'di=34' 'ln=35' 'so=32' 'ex=31' 'bd=46;34' 'cd=43;34'

# 不要なヒストリーは保存しないようにする
zshaddhistory() {
    local line="${1%%$'\n'}"
    [[ ! "$line" =~ "^(cd|la|ll|ls|rm|rmdir)($| )" ]]
}
