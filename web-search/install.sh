#!/bin/sh

TOP=$(git rev-parse --show-toplevel)
OS=$("$TOP/.tools/detect-os.sh")

case "$OS" in
    debian)
        pkgs="p7zip-full curl wget unzip"

        sudo apt-get update
        for pkg in $pkgs; do
          if ! dpkg -s "$pkg" > /dev/null 2>&1 ; then
            sudo apt-get install -y --no-install-recommends "$pkg"
          fi
        done

        # Install pandoc if not installed
        if ! dpkg -s pandoc > /dev/null 2>&1 ; then
          # since pandoc v.2.2.1 does not support arm64, we use v.3.5
          arch=$(dpkg --print-architecture)
          wget https://github.com/jgm/pandoc/releases/download/3.5/pandoc-3.5-1-"${arch}".deb
          sudo dpkg -i pandoc-3.5-1-"${arch}".deb || sudo apt-get install -f -y --no-install-recommends
          rm pandoc-3.5-1-"${arch}".deb
        fi

        # Install Node.js 18.x locally for the benchmark
        NODE_VERSION=18.20.8
        NODE_DIR="$TOP/.tools/nodejs18"

        if [ ! -x "$NODE_DIR/bin/node" ]; then
          arch=$(dpkg --print-architecture)

          case "$arch" in
            amd64)
              node_arch="x64"
              ;;
            arm64)
              node_arch="arm64"
              ;;
            *)
              echo "Unsupported architecture: $arch"
              exit 1
              ;;
          esac

          tmp=$(mktemp -d)

          wget -q \
            "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
            -O "$tmp/node.tar.xz"

          rm -rf "$NODE_DIR"
          mkdir -p "$NODE_DIR"

          tar -xJf "$tmp/node.tar.xz" \
            --strip-components=1 \
            -C "$NODE_DIR"

          rm -rf "$tmp"
        fi

        # Use the benchmark's Node.js installation
        export PATH="$NODE_DIR/bin:$PATH"

        # Verify node and npm installation
        if ! command -v node > /dev/null 2>&1 ; then
          echo "Node.js installation failed."
          exit 1
        fi

        NODE_MAJOR=18

        node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)

        if [ "$node_major" != "$NODE_MAJOR" ]; then
          echo "Node.js 18.x installation failed."
          echo "Found: $(node --version)"
          exit 1
        fi
        ;;

    macos)
        # brew's node formula bundles npm; pandoc and p7zip are direct formulae,
        # no arch-specific download dance needed the way the .deb release requires.
        brew install p7zip curl wget unzip node pandoc

        if ! command -v node > /dev/null 2>&1 ; then
          echo "Node.js installation failed."
          exit 1
        fi
        ;;

    fedora)
        pkgs="p7zip curl wget unzip"

        sudo dnf makecache
        for pkg in $pkgs; do
          if ! rpm -q "$pkg" > /dev/null 2>&1 ; then
            sudo dnf install -y "$pkg"
          fi
        done

        # Install pandoc if not installed
        if ! command -v pandoc > /dev/null 2>&1 ; then
          sudo dnf install -y pandoc
        fi

        # Install Node.js 18.x locally for the benchmark
        NODE_VERSION=18.20.8
        NODE_DIR="$TOP/.tools/nodejs18"

        if [ ! -x "$NODE_DIR/bin/node" ]; then
          arch=$(uname -m)

          case "$arch" in
            x86_64)
              node_arch="x64"
              ;;
            aarch64)
              node_arch="arm64"
              ;;
            *)
              echo "Unsupported architecture: $arch"
              exit 1
              ;;
          esac

          tmp=$(mktemp -d)

          wget -q \
            "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
            -O "$tmp/node.tar.xz"

          rm -rf "$NODE_DIR"
          mkdir -p "$NODE_DIR"

          tar -xJf "$tmp/node.tar.xz" \
            --strip-components=1 \
            -C "$NODE_DIR"

          rm -rf "$tmp"
        fi

        # Use the benchmark's Node.js installation
        export PATH="$NODE_DIR/bin:$PATH"

        # Verify node and npm installation
        if ! command -v node > /dev/null 2>&1 ; then
          echo "Node.js installation failed."
          exit 1
        fi

        NODE_MAJOR=18

        node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)

        if [ "$node_major" != "$NODE_MAJOR" ]; then
          echo "Node.js 18.x installation failed."
          echo "Found: $(node --version)"
          exit 1
        fi

        if ! command -v npm > /dev/null 2>&1 ; then
          echo "npm installation failed."
          exit 1
        fi
        ;;
esac

cd "$(dirname "$0")/scripts" || exit 1

rm -rf node_modules package-lock.json

npm install --save-exact \
  html-to-text@9.0.5 \
  jsdom@15.2.1 \
  natural@5.2.0 \
  afinn-165@1.0.2

cd - || exit 1