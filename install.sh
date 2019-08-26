#!/bin/bash

set -eu

if !(type "brew" > /dev/null 2>&1); then
  xcode-select --install
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

if !(type "/usr/local/bin/zsh" > /dev/null 2>&1); then
  brew install zsh
  echo "/usr/local/bin/zsh" > /etc/shells
  chsh -s /usr/local/bin/zsh
  zsh
fi

declare -a INSTALL_PLUGINS=('vim go fzf ghq')
for item in $INSTALL_PLUGINS
do
  if !(type $item > /dev/null 2>&1); then
    brew install $item
  fi
done

DOT_DIRECTORY=${PWD}
declare -a DIRECTORIES=('.config .vim')
DOT_CONFIG_DIRECTORY=".config"

for f in .??*
do
    [[ "$f" == ".git" ]] && continue
    [[ "$f" == ".gitignore" ]] && continue
    [[ "$f" == ".config" ]] && continue
    [[ "$f" == ".vim" ]] && continue
    [[ "$f" == ".DS_Store" ]] && continue

    ln -snfv ${DOT_DIRECTORY}/$f $HOME/$f
done

for child_directory in $DIRECTORIES; do
  cd ${DOT_DIRECTORY}/${child_directory}

  for directory in `\find . -type d`; do
    mkdir -p ${HOME}/${child_directory}/${directory}
  done

  for file in `\find . -maxdepth 4 -type f`; do
      ln -snfv ${DOT_DIRECTORY}/${child_directory}/${file:2} ${HOME}/${child_directory}/${file:2}
  done
done
