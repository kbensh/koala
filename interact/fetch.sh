#!/bin/sh
set -e

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/interact"
input_dir="${eval_dir}/inputs"
cd "$(realpath "$(dirname "$0")")" || exit 1

ZSH_TARGET="${input_dir}/ohmyzsh"

# Default settings
REPO=${REPO:-ohmyzsh/ohmyzsh}
REMOTE=${REMOTE:-https://github.com/${REPO}.git}
BRANCH=${BRANCH:-master}

python3 utils/create_inputs.py

download_ohmyzsh() {
  echo "Downloading Oh My Zsh to $ZSH_TARGET..."

  mkdir -p "$input_dir"

  if [ -d "$ZSH_TARGET" ]; then
    echo "Directory $ZSH_TARGET already exists."
    echo "Please remove it first if you want to re-download:"
    exit 0
  fi

  # Clone the repository
  git init --quiet "$ZSH_TARGET" && cd "$ZSH_TARGET" \
  && git config core.eol lf \
  && git config core.autocrlf false \
  && git config fsck.zeroPaddedFilemode ignore \
  && git config fetch.fsck.zeroPaddedFilemode ignore \
  && git config receive.fsck.zeroPaddedFilemode ignore \
  && git config oh-my-zsh.remote origin \
  && git config oh-my-zsh.branch "$BRANCH" \
  && git remote add origin "$REMOTE" \
  && git fetch --depth=1 origin \
  && git checkout -b "$BRANCH" "origin/$BRANCH" || {
    [ ! -d "$ZSH_TARGET" ] || {
      cd -
      rm -rf "$ZSH_TARGET" 2>/dev/null
    }
    echo "git clone of oh-my-zsh repo failed"
    exit 1
  }
  cd -

}

download_ohmyzsh
