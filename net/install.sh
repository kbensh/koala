#!/bin/bash

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list

sudo apt-get update -y

sudo apt-get install -y \
    build-essential \
    git \
    curl \
    wget \
    gpg \
    automake \
    flex \
    tar \
    libpq-dev \
    libpcre3-dev \
    libssl-dev \
    libpcap-dev \
    libltdl-dev \
    bison \
    python3 \
    python3-pip \
    python3-venv \
    net-tools \
    xsltproc \
    bind9-dnsutils \
    netcat-traditional

sudo apt-get install -y \
    nmap \
    lolcat \
    toilet \
    boxes \
    masscan \
    bind9-host \
    geoip-bin \
    hwinfo \
    autoconf \
    iproute2 \
    iptables \
    ipset \
    masscan \
    postgresql \
    postgresql-contrib \
    check

cd /tmp
git clone https://github.com/ofalk/libdnet
cd libdnet
./configure
make
sudo make install
cd /tmp

sudo apt-get update -y
sudo apt-get install unicornscan -t kali-rolling

service postgresql start
sleep 3
if ! sudo -u postgres psql -t -c '\du' | cut -d \| -f 1 | grep -qw unicorn; then
    echo "Creating PostgreSQL user 'unicorn'..."
    sudo -u postgres createuser -S -D -R unicorn
else
    echo "User 'unicorn' already exists."
fi

if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw unicornscan; then
    echo "Creating 'unicornscan' database..."
    sudo -u postgres createdb -O unicorn unicornscan
else
    echo "Database 'unicornscan' already exists."
fi


# Install Masscan
if ! command -v masscan >/dev/null 2>&1; then
    cd /tmp
    git clone https://github.com/robertdavidgraham/masscan
    cd masscan
    make -j"$(nproc)"
    sudo make install
fi

# Update locate database if available
sudo updatedb || true
