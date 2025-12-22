#!/bin/bash
# https://github.com/CYBWithFlourish/IP-Sweeper-Script/blob/main/ip_sweeper.sh
SUBNET="$1"
INPUT_FILE="$2"
OUTPUT_FILE="${3:-ip_sweeper_output.txt}"

rm -f "$OUTPUT_FILE"

for ip in $(seq 1 254); do
    if ping -c 1 -W 1 $SUBNET.$ip >> "$OUTPUT_FILE" 2>&1; then
        echo "Host $SUBNET.$ip is UP" >> "$OUTPUT_FILE" 2>&1
    fi
done

while IFS= read -r target_ip || [ -n "$target_ip" ]; do
    [[ -z "$target_ip" || "$target_ip" =~ ^# ]] && continue

    # Ping the IP
    if ping -c 1 -W 1 "$target_ip" > /dev/null 2>&1; then
        echo "Host $target_ip is UP" | tee -a "$OUTPUT_FILE"
    else
        echo "Host $target_ip is DOWN" >> "$OUTPUT_FILE"
    fi

done < "$INPUT_FILE"
