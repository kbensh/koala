#!/bin/sh

sudo apt-get update -y

mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --yes --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list > /dev/null

sudo apt-get update -y

sudo apt-get install -y \
    iproute2 \
    build-essential \
    git \
    curl \
    wget \
    gpg \
    tar \
    libpcre3-dev \
    libssl-dev \
    libpcap-dev \
    net-tools \
    xsltproc \
    bind9-dnsutils \
    netcat-traditional \
    toilet \
    boxes \
    lolcat \
    automake \
    nmap \
    lolcat \
    toilet \
    boxes \
    masscan \
    gum \
    bind9-host \
    geoip-bin \
    hwinfo \
    autoconf \
    python3 \
    python3-pip \
    python3-venv \
    postgresql libdnet-dev libpq-dev libpcap-dev bison flex

if ! command -v unicornscan >/dev/null 2>&1; then
    wget http://sourceforge.net/projects/osace/files/unicornscan/unicornscan%20-%200.4.7%20source/unicornscan-0.4.7-2.tar.bz2/download -O unicornscan-0.4.7-2.tar.bz2
    tar jxvf unicornscan-0.4.7-2.tar.bz2
    cd unicornscan-0.4.7/
    ./configure CFLAGS=-D_GNU_SOURCE
    make
    sudo make install
fi
# Install Masscan
if ! command -v masscan >/dev/null 2>&1; then
    cd /tmp
    git clone https://gitlab.com/kalilinux/packages/unicornscan
    cd unicornscan
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-bundled-ltdl
    make -j"$(nproc)"
    make install
fi

# Install Nmap
if ! command -v nmap >/dev/null 2>&1; then
    cd /tmp
    rm -rf nmap-7.95
    wget https://nmap.org/dist/nmap-7.95.tar.bz2
    tar xvjf nmap-7.95.tar.bz2
    cd nmap-7.95
    ./configure --without-zenmap --without-nping --without-ndiff --without-ncat
    make -j"$(nproc)"
    make install
fi

# Update locate database if available
if command -v updatedb >/dev/null 2>&1; then
    updatedb || true
fi

# Install Vulners NSE script
echo -e "${blue_color}[-] Installing Vulners NSE script...${end_color}"
if [[ $(which nmap) == */local/* ]]; then
    nmap_scripts_folder="/usr/local/share/nmap/scripts/"
else
    nmap_scripts_folder="/usr/share/nmap/scripts/"
fi

mkdir -p "${nmap_scripts_folder}"
wget -q https://raw.githubusercontent.com/vulnersCom/nmap-vulners/master/vulners.nse -O "${nmap_scripts_folder}vulners.nse" &>> "${log_file}"
nmap --script-updatedb

# Check if SSH server is installed
sudo apt-get update
sudo apt-get install -y openssh-server
sudo apt-get install -y openssh-client

echo ""
echo "Starting SSH service..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl start ssh || systemctl start sshd
    systemctl enable ssh || systemctl enable sshd
elif command -v service >/dev/null 2>&1; then
    service ssh start || service sshd start
else
    # In Docker, start manually
    /usr/sbin/sshd
fi

# Generate SSH key if it doesn't exist
CURRENT_USER=$(whoami)
SSH_DIR="$HOME/.ssh"
KEY_FILE="$SSH_DIR/id_rsa_ip_ssh"

echo ""
echo "Checking SSH keys for $CURRENT_USER..."

if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
fi

if [ ! -f "$KEY_FILE" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 2048 -f "$KEY_FILE" -N "" -q
    echo "SSH key generated"
else
    echo "SSH key already exists"
fi

AUTH_KEYS="$SSH_DIR/authorized_keys"

if [ ! -f "$AUTH_KEYS" ]; then
    touch "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
fi

if ! grep -q "$(cat ${KEY_FILE}.pub)" "$AUTH_KEYS" 2>/dev/null; then
    echo "Adding key to authorized_keys..."
    cat "${KEY_FILE}.pub" >> "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    echo "Key added to authorized_keys"
else
    echo "Key already in authorized_keys"
fi