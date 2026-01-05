#!/bin/bash
set -e

cd "$(realpath "$(dirname "$0")")" || exit 1

TOP=$(git rev-parse --show-toplevel)
sudo apt-get update
sudo apt-get install -y  git procps autoconf automake libtool build-essential cloc time gawk jq strace lsof python3 python3-pip python3-venv
VENV_DIR="$TOP/venv"
rm -rf "$VENV_DIR"
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

pip install --upgrade pip
pip install --break-system-packages -r "$TOP/.tools/requirements.txt"
