#!/bin/sh

sudo apt-get update
sudo apt-get install -y \
    dc \
    coreutils \
    gawk \
    libfuse3-dev \
    fuse3 \
    pkg-config

cd /tmp
git clone https://github.com/rpodgorny/unionfs-fuse.git
cd /tmp/unionfs-fuse
make -j$(nproc)
sudo make install
