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
    check \
    iputils-ping
