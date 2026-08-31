#!/bin/sh

TOP=$(git rev-parse --show-toplevel)
OS=$("$TOP/.tools/detect-os.sh")

VENV_DIR="$TOP/venv"
. "$VENV_DIR/bin/activate"

case "$OS" in
    debian)
        sudo apt-get update

        sudo apt-get install -y --no-install-recommends \
            wget \
            unzip \
            git \
            libgl1 \
            libglib2.0-0 \
            libjpeg-dev \
            zstd \
            ffmpeg \
            imagemagick \
            parallel \
            python3 \
            python3-pip \
            python3-venv
        ;;
    macos)
        # libgl1/libglib2.0-0 satisfy Linux (X11/Mesa) wheel deps for
        # scikit-learn's dependency chain; the macOS wheels don't need them.
        brew install wget unzip git jpeg zstd ffmpeg imagemagick parallel python3 openblas
        openblas_prefix="$(brew --prefix openblas)"
        export PKG_CONFIG_PATH="$openblas_prefix/lib/pkgconfig:$PKG_CONFIG_PATH"
        ;;
    fedora)
        sudo dnf makecache

        sudo dnf install -y \
            wget \
            unzip \
            git \
            zstd \
            ffmpeg \
            python3 \
            python3-pip \
            python3-virtualenv \
            python3-devel \
            gcc \
            gcc-c++ \
            mesa-libGL \
            glib2 \
            libjpeg-turbo-devel \
            ImageMagick \
            parallel
        ;;
esac

pip install --break-system-packages --upgrade pip

pip install --break-system-packages \
    joblib==1.4.2 \
    numpy==1.26.4 \
    scikit-learn==1.5.0 \
    scipy==1.13.1 \
    threadpoolctl==3.5.0 \
    imbalanced-learn==0.13.0