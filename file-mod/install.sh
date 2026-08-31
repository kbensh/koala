#!/bin/sh

set -eu

TOP=$(git rev-parse --show-toplevel)
OS=$("$TOP/.tools/detect-os.sh")

LEGACY_BIN="/usr/local/legacy-bin"

FFMPEG_VERSION="5.1.9"
FFMPEG_PREFIX="/usr/local/ffmpeg-${FFMPEG_VERSION}"

LIBJPEG_VERSION="2.1.5"
LIBJPEG_PREFIX="/usr/local/libjpeg-${LIBJPEG_VERSION}"

LIBPNG_VERSION="1.6.39"
LIBPNG_PREFIX="/usr/local/libpng-${LIBPNG_VERSION}"

IMAGEMAGICK_VERSION="6.9.11-60"
IMAGEMAGICK_PREFIX="/usr/local/imagemagick-${IMAGEMAGICK_VERSION}"


# Detect whether we are running inside a container.
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    IN_CONTAINER=true
else
    IN_CONTAINER=false
fi


install_dependencies() {
    echo "Installing dependencies for $OS"

    if $IN_CONTAINER; then
        echo "Container detected; installing system packages"

        case "$OS" in
            debian)
                apt-get update

                apt-get install -y \
                    sudo \
                    coreutils \
                    wget \
                    unzip \
                    gzip \
                    gawk \
                    sed \
                    git \
                    openssl \
                    curl \
                    ffmpeg \
                    unrtf \
                    imagemagick \
                    zstd \
                    xz-utils
                ;;

            fedora)
                dnf makecache

                dnf install -y \
                    sudo \
                    coreutils \
                    wget \
                    unzip \
                    gzip \
                    gawk \
                    sed \
                    git \
                    openssl \
                    curl \
                    ffmpeg \
                    unrtf \
                    zstd \
                    ImageMagick \
                    xz
                ;;

            *)
                echo "Unsupported OS in container: $OS" >&2
                exit 1
                ;;
        esac

        return 0
    fi


    echo "Bare-metal environment detected; installing build dependencies"

    case "$OS" in
        debian)
            sudo apt-get update

            sudo apt-get install -y \
                sudo coreutils wget unzip gzip gawk sed git openssl curl \
                unrtf zstd xz-utils \
                gcc g++ make nasm yasm pkg-config \
                cmake perl bzip2 \
                autoconf automake libtool \
                zlib1g-dev \
                libtiff-dev libwebp-dev libxml2-dev \
                libfreetype6-dev fontconfig \
                libgs-dev librsvg2-dev \
                libltdl-dev \
                lame libmp3lame-dev
            ;;

        fedora)
            sudo dnf makecache

            sudo dnf install -y \
                sudo coreutils wget unzip gzip gawk sed git openssl curl \
                unrtf zstd xz \
                gcc gcc-c++ make nasm yasm pkgconf-pkg-config \
                cmake perl bzip2 \
                autoconf automake libtool libtool-ltdl-devel \
                zlib-devel \
                libtiff-devel libwebp-devel libxml2-devel \
                freetype-devel fontconfig-devel \
                ghostscript-devel librsvg2-devel \
                lame lame-devel
            ;;

        macos)
            brew install \
                wget unzip gzip git openssl curl ffmpeg unrtf \
                imagemagick zstd xz
            ;;

        *)
            echo "Unsupported OS: $OS" >&2
            exit 1
            ;;
    esac
}


install_libjpeg_2_1_5() {
    echo "Installing libjpeg-turbo ${LIBJPEG_VERSION}"

    src_dir="/tmp/libjpeg-turbo-${LIBJPEG_VERSION}"
    tarball="/tmp/libjpeg-turbo-${LIBJPEG_VERSION}.tar.gz"
    prefix="$LIBJPEG_PREFIX"
    libdir="$prefix/lib64"

    if [ -x "$prefix/bin/cjpeg" ]; then
        actual="$("$prefix/bin/cjpeg" -version 2>&1 | head -n 1 || true)"

        if printf '%s\n' "$actual" | grep -Fq "$LIBJPEG_VERSION"; then
            echo "libjpeg-turbo ${LIBJPEG_VERSION} already installed; skipping rebuild"
            return 0
        fi
    fi

    rm -rf "$src_dir" "$tarball"

    curl -L --fail \
        "https://downloads.sourceforge.net/libjpeg-turbo/${LIBJPEG_VERSION}/libjpeg-turbo-${LIBJPEG_VERSION}.tar.gz" \
        -o "$tarball"

    tar -xzf "$tarball" -C /tmp

    cmake -S "$src_dir" -B "$src_dir/build" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DENABLE_SHARED=ON \
        -DENABLE_STATIC=OFF \
        -DWITH_JPEG8=1 \
        -DWITH_TURBOJPEG=OFF

    cmake --build "$src_dir/build" -j"$(nproc)"
    sudo cmake --install "$src_dir/build"

    # libjpeg-turbo uses lib64 on some platforms.
    # Keep a stable $prefix/lib path for the consumers we build below.
    if [ -d "$libdir" ]; then
        sudo ln -sfn "$libdir" "$prefix/lib"
    fi

    actual="$("$prefix/bin/cjpeg" -version 2>&1 | head -n 1)"

    echo "libjpeg-turbo installed: $actual"

    if ! printf '%s\n' "$actual" | grep -Fq "$LIBJPEG_VERSION"; then
        echo "libjpeg-turbo installation failed: expected ${LIBJPEG_VERSION}" >&2
        exit 1
    fi
}


install_libpng_1_6_39() {
    echo "Installing libpng ${LIBPNG_VERSION}"

    src_dir="/tmp/libpng-${LIBPNG_VERSION}"
    tarball="/tmp/libpng-${LIBPNG_VERSION}.tar.gz"
    prefix="$LIBPNG_PREFIX"

    if [ -x "$prefix/bin/pngfix" ]; then
        actual="$("$prefix/bin/pngfix" -V 2>&1 | head -n 1 || true)"

        if printf '%s\n' "$actual" | grep -Fq "$LIBPNG_VERSION"; then
            echo "libpng ${LIBPNG_VERSION} already installed; skipping rebuild"
            return 0
        fi
    fi

    rm -rf "$src_dir" "$tarball"

    curl -L --fail \
        "https://download.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz" \
        -o "$tarball"

    tar -xzf "$tarball" -C /tmp

    cd "$src_dir"

    ./configure \
        --prefix="$prefix" \
        --enable-shared \
        --disable-static

    make -j"$(nproc)"
    sudo make install

    actual="$("$prefix/bin/pngfix" -V 2>&1 | head -n 1)"

    echo "libpng installed: $actual"

    if ! printf '%s\n' "$actual" | grep -Fq "$LIBPNG_VERSION"; then
        echo "libpng installation failed: expected ${LIBPNG_VERSION}" >&2
        exit 1
    fi
}


install_imagemagick_6_9_11_60() {
    echo "Installing ImageMagick ${IMAGEMAGICK_VERSION} from source"

    install_libjpeg_2_1_5
    install_libpng_1_6_39

    src_dir="/tmp/ImageMagick-${IMAGEMAGICK_VERSION}"
    tarball="/tmp/ImageMagick-${IMAGEMAGICK_VERSION}.tar.xz"
    prefix="$IMAGEMAGICK_PREFIX"
    convert_bin="$prefix/bin/convert"

    if [ -x "$convert_bin" ]; then
        actual="$("$convert_bin" -version 2>&1 | head -n 1 || true)"

        if printf '%s\n' "$actual" | grep -Fq \
            "Version: ImageMagick ${IMAGEMAGICK_VERSION}"; then
            echo "ImageMagick ${IMAGEMAGICK_VERSION} already installed; skipping rebuild"
            return 0
        fi
    fi

    rm -rf "$src_dir"

    curl -L --fail \
        "https://download.imagemagick.org/archive/releases/ImageMagick-${IMAGEMAGICK_VERSION}.tar.xz" \
        -o "$tarball"

    tar -xJf "$tarball" -C /tmp

    cd "$src_dir"

    JPEG_LIB="$LIBJPEG_PREFIX/lib64"

    if [ ! -d "$JPEG_LIB" ]; then
        JPEG_LIB="$LIBJPEG_PREFIX/lib"
    fi

    PNG_LIB="$LIBPNG_PREFIX/lib"

    PKG_CONFIG_PATH="$JPEG_LIB/pkgconfig:$PNG_LIB/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" \
    CPPFLAGS="-I$LIBJPEG_PREFIX/include -I$LIBPNG_PREFIX/include" \
    LDFLAGS="-L$JPEG_LIB \
        -L$PNG_LIB \
        -Wl,-rpath,$JPEG_LIB \
        -Wl,-rpath,$PNG_LIB \
        -Wl,-rpath,$prefix/lib" \
    ./configure \
        --prefix="$prefix" \
        --disable-dependency-tracking \
        --with-modules \
        --without-perl \
        --without-magick-plus-plus

    make -j"$(nproc)"
    sudo make install

    actual="$("$convert_bin" -version 2>&1 | head -n 1)"

    echo "ImageMagick installed: $actual"

    if ! printf '%s\n' "$actual" | grep -Fq \
        "Version: ImageMagick ${IMAGEMAGICK_VERSION}"; then
        echo "ImageMagick installation failed: expected ${IMAGEMAGICK_VERSION}" >&2
        exit 1
    fi
}


install_ffmpeg_5_1_9() {
    echo "Installing FFmpeg ${FFMPEG_VERSION} from source"

    src_dir="/tmp/ffmpeg-${FFMPEG_VERSION}"
    tarball="/tmp/ffmpeg-${FFMPEG_VERSION}.tar.gz"
    prefix="$FFMPEG_PREFIX"
    ffmpeg_bin="$prefix/bin/ffmpeg"

    if [ -x "$ffmpeg_bin" ]; then
        actual="$("$ffmpeg_bin" -version 2>&1 | head -n 1 || true)"

        if printf '%s\n' "$actual" | grep -Fq "ffmpeg version ${FFMPEG_VERSION}" &&
           "$ffmpeg_bin" -hide_banner -encoders 2>/dev/null |
               grep -q 'libmp3lame'; then
            echo "FFmpeg ${FFMPEG_VERSION} with MP3 support already installed; skipping rebuild"
            return 0
        fi

        echo "FFmpeg ${FFMPEG_VERSION} is present but MP3 support is missing; rebuilding"
    fi

    rm -rf "$src_dir"

    curl -L --fail \
        "https://www.ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz" \
        -o "$tarball"

    tar -xzf "$tarball" -C /tmp

    cd "$src_dir"

    ./configure \
        --prefix="$prefix" \
        --disable-doc \
        --disable-debug \
        --enable-gpl \
        --enable-version3 \
        --enable-shared \
        --enable-libmp3lame \
        --extra-ldflags="-Wl,-rpath,$prefix/lib"

    make -j"$(nproc)"
    sudo make install

    actual="$("$ffmpeg_bin" -version 2>&1 | head -n 1)"

    echo "FFmpeg installed: $actual"

    if ! printf '%s\n' "$actual" | grep -Fq \
        "ffmpeg version ${FFMPEG_VERSION}"; then
        echo "FFmpeg installation failed: expected ${FFMPEG_VERSION}" >&2
        exit 1
    fi

    if ! "$ffmpeg_bin" -hide_banner -encoders 2>/dev/null |
        grep -q 'libmp3lame'; then
        echo "FFmpeg installation failed: libmp3lame encoder is missing" >&2
        exit 1
    fi
}


install_legacy_tool_links() {
    echo "Installing isolated legacy tool links"

    sudo mkdir -p "$LEGACY_BIN"

    sudo ln -sfn \
        "$FFMPEG_PREFIX/bin/ffmpeg" \
        "$LEGACY_BIN/ffmpeg"

    sudo ln -sfn \
        "$FFMPEG_PREFIX/bin/ffprobe" \
        "$LEGACY_BIN/ffprobe"

    sudo ln -sfn \
        "$IMAGEMAGICK_PREFIX/bin/convert" \
        "$LEGACY_BIN/convert"

    sudo ln -sfn \
        "$IMAGEMAGICK_PREFIX/bin/mogrify" \
        "$LEGACY_BIN/mogrify"

    sudo ln -sfn \
        "$IMAGEMAGICK_PREFIX/bin/identify" \
        "$LEGACY_BIN/identify"

    echo "Legacy tools available under: $LEGACY_BIN"
}


case "$OS" in
    debian|fedora)
        install_dependencies

        if $IN_CONTAINER; then
            echo "Using system FFmpeg/ImageMagick inside container"
        else
            install_imagemagick_6_9_11_60
            install_ffmpeg_5_1_9
            install_legacy_tool_links
        fi
        ;;

    macos)
        install_dependencies
        ;;

    *)
        echo "Unsupported OS: $OS" >&2
        exit 1
        ;;
esac