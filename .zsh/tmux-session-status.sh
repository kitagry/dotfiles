#!/usr/bin/env bash
# tmux status-right 用: 全session を常時一覧表示する
# 各session に window数 と Claude が付けた pane タイトルを併記し、状態で色分けする。
#   ✳ = 実行中(緑) / ? = 許可待ち・長時間アイドル(黄) / ✓ = 完了・入力待ち(グレー)
# カレント client の session は反転表示する。
# 使い方(.tmux.conf): set -g status-right '#(~/.zsh/tmux-session-status.sh #{client_session})'
current="$1"
title_max=24

# tmux 書式として再解釈されるため、ユーザー由来文字列の '#' はエスケープする
esc() { printf '%s' "${1//#/##}"; }

tmux list-sessions -F '#{session_name}	#{session_windows}' 2>/dev/null | \
while IFS=$'\t' read -r name windows; do
  # session 内の pane タイトルから Claude マーカーを拾う(実行中 ✳ を優先、次に ? 、無ければ ✓)
  titles=$(tmux list-panes -s -t "$name" -F '#{pane_title}' 2>/dev/null)
  title=$(printf '%s\n' "$titles" | grep -m1 '^✳')
  state=run
  if [ -z "$title" ]; then
    title=$(printf '%s\n' "$titles" | grep -m1 '^?')
    state=wait
  fi
  if [ -z "$title" ]; then
    title=$(printf '%s\n' "$titles" | grep -m1 '^✓')
    state=idle
  fi

  marker=""
  if [ -n "$title" ]; then
    glyph=${title:0:1}           # 先頭の状態グリフ
    body=${title#"$glyph"}; body=${body# }
    [ "${#body}" -gt "$title_max" ] && body="${body:0:$title_max}…"
    marker=" $(esc "$glyph")$(esc "$body")"
  else
    state=none
  fi
  base="$(esc "$name")($windows)$marker"

  if [ "$name" = "$current" ]; then
    printf '#[fg=black,bg=green,bold] %s #[default]' "$base"
  elif [ "$state" = run ]; then
    printf '#[fg=green] %s #[default]' "$base"
  elif [ "$state" = wait ]; then
    printf '#[fg=yellow] %s #[default]' "$base"
  else
    printf '#[fg=brightblack] %s #[default]' "$base"
  fi
done
