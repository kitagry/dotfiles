#!/bin/bash

set -eu

if !(type "brew" > /dev/null 2>&1); then
  xcode-select --install
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

declare -a BREW_INSTALL_PLUGINS=('git go ghq wget')
declare -a BREW_INSTALLED_PLUGINS=$(brew list)

array_check() {
  for installed_item in $BREW_INSTALLED_PLUGINS
  do
    if [ "$installed_item" = "$1" ]; then
      return 1
    fi
  done
  return 0
}

for item in $BREW_INSTALL_PLUGINS
do
  if array_check $item; then
    brew install $item
  fi
done
