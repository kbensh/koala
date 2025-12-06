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
    gum \
    netcat-traditional \
    toilet \
    boxes

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

echo "Adding kali repository to apt sources"
sudo touch /etc/apt/sources.list.d/kali.list
sudo chmod 666 /etc/apt/sources.list.d/kali.list
sudo echo 'deb https://http.kali.org/kali kali-rolling main non-free contrib' > /etc/apt/sources.list.d/kali.list
sudo chmod 644 /etc/apt/sources.list.d/kali.list
sudo apt install gnupg
wget 'https://archive.kali.org/archive-key.asc'
sudo apt-key add archive-key.asc
rm archive-key.asc
echo "Setting low priority for kali repository"
sudo touch /etc/apt/preferences.d/kali.pref
sudo chmod 666 /etc/apt/preferences.d/kali.pref 
echo 'Package: *'>/etc/apt/preferences.d/kali.pref
echo 'Pin: release a=kali-rolling'>>/etc/apt/preferences.d/kali.pref
echo 'Pin-Priority: 50'>>/etc/apt/preferences.d/kali.pref
sudo chmod 644 /etc/apt/preferences.d/kali.pref

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

# Install Vulners NSE script
echo -e "${blue_color}[-] Installing Vulners NSE script...${end_color}"
if [[ $(which nmap) == */local/* ]]; then
    nmap_scripts_folder="/usr/local/share/nmap/scripts/"
else
    nmap_scripts_folder="/usr/share/nmap/scripts/"
fi

mkdir -p "${nmap_scripts_folder}"
wget -q https://raw.githubusercontent.com/vulnersCom/nmap-vulners/master/vulners.nse -O "${nmap_scripts_folder}vulners.nse" &>> "${log_file}"
sudo nmap --script-updatedb

# Check if SSH server is installed
sudo apt-get update
sudo apt-get install -y openssh-server
sudo apt-get install -y openssh-client

# If not root, re-execute the script as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Re-running as root..."
    sudo "$0" "$@"
    exit $?
fi

# Start SSH service if not running
echo "Starting SSH service..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null
    systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null
elif command -v service >/dev/null 2>&1; then
    service ssh start 2>/dev/null || service sshd start 2>/dev/null
else
    # In Docker, start manually if sshd exists
    if [ -f /usr/sbin/sshd ]; then
        /usr/sbin/sshd
    fi
fi

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
    echo "SSH key generated at $KEY_FILE"
else
    echo "SSH key already exists at $KEY_FILE"
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

echo ""
echo "Setup complete!"
echo "SSH key location: $KEY_FILE"