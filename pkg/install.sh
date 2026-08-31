#!/bin/sh

TOP=$(git rev-parse --show-toplevel)
OS=$("$TOP/.tools/detect-os.sh")

case "$OS" in
    debian)
        sudo apt-get update

        sudo apt-get install -y --no-install-recommends  gpg \
            wget \
            git \
            unzip \
            zip \
            zstd \
            libncurses5-dev \
            libncursesw5-dev \
            zstd \
            liblzma-dev \
            libbz2-dev \
            zip \
            unzip \
            nodejs \
            libarchive-tools \
            ffmpeg \
            unrtf \
            imagemagick \
            tcpdump \
            cmake \
            build-essential \
            libssl-dev \
            qtcreator qtbase5-dev qt5-qmake gcc libtirpc-dev \
            make \
            libncurses-dev \
            libsm-dev \
            libice-dev \
            libxt-dev \
            libx11-dev \
            libxdmcp-dev \
            libselinux-dev \
            libtool \
            libtool-bin \
            libreadline-dev \
            npm

        wget -qO - 'https://proget.makedeb.org/debian-feeds/makedeb.pub' | gpg --dearmor | sudo tee /usr/share/keyrings/makedeb-archive-keyring.gpg > /dev/null
        echo 'deb [signed-by=/usr/share/keyrings/makedeb-archive-keyring.gpg arch=all] https://proget.makedeb.org/ makedeb main' | sudo tee /etc/apt/sources.list.d/makedeb.list > /dev/null

        sudo apt-get update
        sudo apt-get install -y --no-install-recommends makedeb

        # makedeb is installed; the repository is no longer needed.
        sudo rm -f /etc/apt/sources.list.d/makedeb.list
        sudo rm -f /usr/share/keyrings/makedeb-archive-keyring.gpg

        # Install Node.js (18.x) and npm via NodeSource, if the earlier apt install
        # of nodejs somehow didn't take
        if ! command -v node > /dev/null 2>&1 ; then
          curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
          sudo apt-get install -y --no-install-recommends nodejs
        fi

        sudo apt-get install -y --no-install-recommends  default-jdk
        ;;
    macos)
        # Qt/X11/ncurses/SELinux/RPC libs and makedeb itself are only for
        # pacaur.sh, which needs makedeb (no macOS support); omitted. The
        # only other script here, proginf.sh, just needs Node.js.
        brew install node
        ;;
    fedora)
        # makedeb has no Fedora support either; same reasoning as macos above.
        sudo dnf makecache

        sudo dnf install -y \
            gpg \
            wget \
            git \
            unzip \
            zip \
            zstd \
            nodejs \
            ffmpeg \
            unrtf \
            tcpdump \
            cmake \
            gcc \
            gcc-c++ \
            make \
            libtool \
            npm \
            ncurses-devel \
            xz-devel \
            bzip2-devel \
            libarchive \
            ImageMagick \
            openssl-devel \
            qt-creator \
            qt5-qtbase-devel \
            libtirpc-devel \
            libSM-devel \
            libICE-devel \
            libXt-devel \
            libX11-devel \
            libXdmcp-devel \
            libselinux-devel \
            readline-devel \
            java-latest-openjdk-devel

        # Install Node.js, if the earlier dnf install of nodejs somehow didn't take
        if ! command -v node > /dev/null 2>&1 ; then
          sudo dnf install -y nodejs
        fi
        ;;
esac

TOP=$(git rev-parse --show-toplevel)
URL="https://atlas.cs.brown.edu/data"
installdir="$TOP/pkg/inputs"

mkdir -p "$installdir"
cd "$installdir" || exit 1
# Install mir-sa
if [ ! -d mir-sa ]; then
  wget "$URL/prog-inf/mir-sa.tar.gz" -O mir-sa.tar.gz
  tar xf mir-sa.tar.gz --no-same-owner
  rm mir-sa.tar.gz
fi

cd mir-sa/@andromeda/mir-sa || exit 1
if [ ! -d node_modules ]; then
  npm install
fi
