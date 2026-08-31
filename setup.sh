#!/bin/sh
set -e

TOP=$(git rev-parse --show-toplevel)
OS=$("$TOP/.tools/detect-os.sh")

# Python itself comes from uv below, not the OS package manager — see
# .tools/ensure-uv.sh. These lists are everything else setup.sh needs.
case "$OS" in
    debian)
        sudo apt-get update
        sudo apt-get install -y  git procps autoconf automake libtool build-essential cloc time gawk jq strace lsof curl
        ;;
    macos)
        if ! xcode-select -p >/dev/null 2>&1; then
            echo "Xcode Command Line Tools required: run 'xcode-select --install' first." >&2
            exit 1
        fi
        brew install autoconf automake libtool cloc gnu-time gawk jq
        ;;
    fedora)
        sudo dnf makecache
        sudo dnf install -y git procps-ng autoconf automake libtool \
            gcc gcc-c++ make \
            cloc time gawk jq strace lsof curl
        ;;
esac

. "$TOP/.tools/macos-path.sh"

cd "$(dirname "$0")" || exit 1
cd "$(pwd -P)" || exit 1

. "$TOP/.tools/ensure-uv.sh"
uv python install 3.11

VENV_DIR="$TOP/venv"
rm -rf "$VENV_DIR"
uv venv --python 3.11 --seed "$VENV_DIR"

. "$VENV_DIR/bin/activate"

uv pip install -r "$TOP/.tools/requirements.txt"
