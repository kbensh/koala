#!/bin/bash
# https://github.com/CYBWithFlourish/IP-Sweeper-Script/blob/main/ip_sweeper.sh
SUBNET="$1"
OUTPUT_FILE="${2:-ip_sweeper_output.txt}"

echo "Pinging subnet $SUBNET.0/24..." > "$OUTPUT_FILE"
for ip in $(seq 1 254); do
    if ping -c 1 -W 1 $SUBNET.$ip >> "$OUTPUT_FILE" 2>&1; then
        echo "Host $SUBNET.$ip is UP" >> "$OUTPUT_FILE" 2>&1
    fi
done