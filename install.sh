#!/usr/bin/env bash

set -eu

if !(type "mise" > /dev/null 2>&1); then
  curl https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

source ./download_file.sh

DOT_DIRECTORY=${PWD}
declare -a DIRECTORIES=('.config' '.vim' '.zsh' '.claude')

for f in .??*
do
    [[ "$f" == ".git" ]] && continue
    [[ "$f" == ".gitignore" ]] && continue
    [[ "$f" == ".DS_Store" ]] && continue
    [[ "${DIRECTORIES[@]}" =~ "$f" ]] && continue

    ln -snfv "${DOT_DIRECTORY}/$f" "$HOME/$f"
done

for child_directory in "${DIRECTORIES[@]}"; do
  cd "${DOT_DIRECTORY}/${child_directory}"

  for directory in $(find . -type d); do
    mkdir -p "${HOME}/${child_directory}/${directory}"
  done

  for file in $(find . -type f | grep -v "\.git"); do
      # .claude/settings.json is a merged output (public + private via jq deep-merge)
      # written by the private dotfiles install.sh. Skip symlinking to avoid clobbering it.
      [[ "${child_directory}/${file:2}" == ".claude/settings.json" ]] && continue
      ln -snfv "${DOT_DIRECTORY}/${child_directory}/${file:2}" "${HOME}/${child_directory}/${file:2}"
  done
done

# Clean up after files deleted from the repo. Only dangling symlinks that point
# into this repo are removed, and only directories emptied by that removal are
# deleted, so anything under $HOME that this script did not create is kept.
for child_directory in "${DIRECTORIES[@]}"; do
  root="${HOME}/${child_directory}"
  [[ -d "$root" ]] || continue

  while IFS= read -r -d '' link; do
    [[ -e "$link" ]] && continue
    [[ "$(readlink "$link")" == "${DOT_DIRECTORY}/"* ]] || continue
    rm -v "$link"

    dir=$(dirname "$link")
    # rmdir -v reports even failed attempts, so echo only after a real removal.
    while [[ "$dir" != "$root" ]] && rmdir "$dir" 2>/dev/null; do
      echo "removed directory '$dir'"
      dir=$(dirname "$dir")
    done
  done < <(find "$root" -type l -print0)
done

if type "fish" > /dev/null 2>&1; then
  fish -c '
    if not functions -q fisher
      curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
      fisher install jorgebucaran/fisher
    end
    fisher update
  '
fi
