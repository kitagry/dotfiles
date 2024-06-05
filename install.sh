#!/bin/bash

set -eu

if !(type "mise" > /dev/null 2>&1); then
  curl https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

declare -a MISE_INSTALL_PLUGINS=('git go ghq')
declare -a MISE_INSTALLED_PLUGINS=$(mise list | cut -d ' ' -f 1)

array_check() {
  for installed_item in $MISE_INSTALLED_PLUGINS
  do
    if [ "$installed_item" = "$1" ]; then
      return 1
    fi
  done
  return 0
}

for item in $MISE_INSTALL_PLUGINS
do
  if !(mise list | grep $item > /dev/null 2>&1); then
    mise install "$item@latest"
    mise use -g "$item@latest"
  fi
done

source ./download_file.sh

DOT_DIRECTORY=${PWD}
declare -a DIRECTORIES=('.config .vim .zsh')

for f in .??*
do
    [[ "$f" == ".git" ]] && continue
    [[ "$f" == ".gitignore" ]] && continue
    [[ "$f" == ".DS_Store" ]] && continue
    [[ "${DIRECTORIES[@]}" =~ "$f" ]] && continue

    ln -snfv "${DOT_DIRECTORY}/$f" "$HOME/$f"
done

for child_directory in $DIRECTORIES; do
  cd "${DOT_DIRECTORY}/${child_directory}"

  for directory in $(find . -type d); do
    mkdir -p "${HOME}/${child_directory}/${directory}"
  done

  for file in $(find . -type f | grep -v "\.git"); do
      ln -snfv "${DOT_DIRECTORY}/${child_directory}/${file:2}" "${HOME}/${child_directory}/${file:2}"
  done
done
