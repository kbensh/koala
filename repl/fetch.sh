#!/bin/sh


URL="${KOALA_DATA_URL:-https://atlas.cs.brown.edu/data}/"

TOP=$(git rev-parse --show-toplevel)

eval_dir="${TOP}/repl"
INPUT_DIR="${eval_dir}/inputs"
CHROMIUM_DIR="${INPUT_DIR}/chromium"
COMMITS_DIR="${INPUT_DIR}/commits"

mkdir -p "$CHROMIUM_DIR" "$COMMITS_DIR"

if [ ! -d "$CHROMIUM_DIR/.git" ]; then
    wget -q "${URL}git/chromium.tar.gz" -O - | tar -xz -C "$INPUT_DIR"
    if [ $? -ne 0 ]; then
        echo "Failed to download or extract chromium data."
        exit 1
    fi
    cd "$CHROMIUM_DIR" || exit 1
    git config --global --add safe.directory $CHROMIUM_DIR
    echo "Chromium data downloaded and extracted to $CHROMIUM_DIR."
else
    echo "Chromium data already exists in $CHROMIUM_DIR."
fi

# No inputs required for the vps-audit scripts
