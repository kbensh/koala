#!/bin/sh

sudo apt-get update -y
sudo apt-get install dc coreutils gawk libfuse3-dev -y

cd /tmp
git clone https://github.com/rpodgorny/unionfs-fuse.git
cd /tmp/unionfs-fuse
make -j$(nproc)
sudo make install
