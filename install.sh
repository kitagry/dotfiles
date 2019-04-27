#!/bin/bash

set -eu

DOT_DIRECTORY=${PWD}
DOT_CONFIG_DIRECTORY=".config"

for f in .??*
do
    [[ "$f" == ".git" ]] && continue
    [[ "$f" == ".gitignore" ]] && continue
    [[ "$f" == ".config" ]] && continue
    [[ "$f" == ".DS_Store" ]] && continue

    ln -snfv ${DOT_DIRECTORY}/$f $HOME/$f
done

cd ./${DOT_CONFIG_DIRECTORY}

for directory in `\find . -type d`; do
  mkdir -p ${HOME}/${DOT_CONFIG_DIRECTORY}/${directory}
done

for file in `\find . -maxdepth 4 -type f`; do
    ln -snfv ${DOT_DIRECTORY}/${DOT_CONFIG_DIRECTORY}/${file:2} ${HOME}/${DOT_CONFIG_DIRECTORY}/${file:2}
done
