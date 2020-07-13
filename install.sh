#!/bin/bash

set -eu

if [ "$(uname)" == "Darwin" ];then
  source ./install_mac.sh
fi

DOT_DIRECTORY=${PWD}
declare -a DIRECTORIES=('.config .vim .zsh')
DOT_CONFIG_DIRECTORY=".config"

for f in .??*
do
    [[ "$f" == ".git" ]] && continue
    [[ "$f" == ".gitignore" ]] && continue
    [[ "$f" == ".DS_Store" ]] && continue
    [[ "${DIRECTORIES[@]}" =~ "$f" ]] && continue

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
