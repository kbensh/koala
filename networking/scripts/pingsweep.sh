#!/bin/bash
# https://github.com/CYBWithFlourish/IP-Sweeper-Script/blob/main/ip_sweeper.sh
SUBNET="127.0.0"

echo "Pinging subnet $SUBNET.0/24..."

for ip in $(seq 1 254); do
    if ping -c 1 -W 1 $SUBNET.$ip > /dev/null 2>&1; then
        echo "Host $SUBNET.$ip is UP"
    fi
done