# 補完機能を有効にする
zstyle ':completion:*:default' menu select=2
# 補完で小文字でも大文字にマッチさせる
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# 補完候補を詰めて表示
setopt list_packed
# 補完候補一覧をカラー表示
zstyle ':completion:*' list-colors ''

autoload -Uz compinit
compinit

# コマンドのスペルを訂正
setopt correct
# ビープ音を鳴らさない
setopt no_beep
