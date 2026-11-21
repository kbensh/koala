#!/bin/sh

TOP=$(git rev-parse --show-toplevel)
OS=$("$TOP/.tools/detect-os.sh")

case "$OS" in
    debian)
        sudo apt-get update

        sudo apt-get install -y --no-install-recommends \
            python3 \
            python3-pip \
            python3-venv \
            libgl1 \
            libglib2.0-0 \
            libjpeg-dev \
            zstd \
            ffmpeg \
            procps \
            coreutils findutils wget sed unzip curl jq coreutils findutils sed unzip curl imagemagick
        ;;
    macos)
        # coreutils/findutils/sed come from the PATH shim (main.sh). libgl1/
        # libglib2.0-0 satisfy Linux (X11/Mesa) wheel deps for torch/
        # tensorflow/opencv-python; the macOS wheels don't need them.
        brew install python3 jpeg zstd ffmpeg procps wget unzip curl jq imagemagick
        ;;
    fedora)
        sudo dnf makecache

        sudo dnf install -y \
            python3 \
            python3-pip \
            python3-virtualenv \
            zstd \
            ffmpeg \
            coreutils \
            findutils \
            wget \
            sed \
            unzip \
            curl \
            jq \
            procps-ng \
            mesa-libGL \
            glib2 \
            libjpeg-turbo-devel \
            ImageMagick \
            perl-Digest-SHA
        ;;
esac

pip install --break-system-packages --upgrade pip
pip install --break-system-packages llm
pip install --break-system-packages llm-interpolate
pip install --break-system-packages llm-clap
pip install --break-system-packages llm-ollama==0.19.1

pip install --break-system-packages numpy \
    torch \
    torchvision \
    Pillow \
    segment-anything \
    tensorflow \
    opencv-python \
    transformers==4.57.6

# check if ollama is installed
if ! command -v ollama >/dev/null 2>&1
then
    echo "Ollama could not be found, installing..."
    curl -fsSL https://ollama.com/install.sh | sh
    # On macOS the installer places the CLI at /usr/local/bin/ollama, not on a
    # non-interactive shell's default PATH; harmless to prepend on any OS.
    export PATH="/usr/local/bin:$PATH"
else
    echo "Ollama is already installed."
fi

ollama serve > /dev/null 2>&1 &
sleep 5
ollama pull moondream:latest

ollama_pid=$(pgrep ollama)
if [ -n "$ollama_pid" ]; then
    kill "$ollama_pid"
fi
