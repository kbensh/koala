#!/bin/sh

# testing on ourselves
CURRENT_USER=$(whoami) 
LOCALHOST="localhost" 

# Function: Add an IP over ssh to localhost
remoteipadd(){
    client=$(echo "$1" | cut -d':' -f1)
    port=$(echo "$1" | cut -d':' -f2)
    wallif=$(echo "$1" | cut -d':' -f3)
    ip=$(echo "$1" | cut -d':' -f4)
    output_file="$2"
    
    echo " [OPENING] Port $port for $client on $LOCALHOST (via SSH as $CURRENT_USER)..."
    ssh -n ${CURRENT_USER}@${LOCALHOST} /sbin/iptables -I INPUT -i ${wallif} -s ${client} -d ${ip} -p tcp --destination-port ${port} -j ACCEPT >> "$output_file" 2>&1
}

# Function: Delete an IP over ssh from localhost
remoteipdelete(){
    client=$(echo "$1" | cut -d':' -f1)
    port=$(echo "$1" | cut -d':' -f2)
    wallif=$(echo "$1" | cut -d':' -f3)
    ip=$(echo "$1" | cut -d':' -f4)
    output_file="$2"
    
    echo " [CLOSING] Port $port for $client on $LOCALHOST (via SSH as $CURRENT_USER)..."
    ssh -n ${CURRENT_USER}@${LOCALHOST} /sbin/iptables -D INPUT -i ${wallif} -s ${client} -d ${ip} -p tcp --destination-port ${port} -j ACCEPT >> "$output_file" 2>&1
}

usage(){
    echo "Usage: $0 {open|close} filename.txt [output_file]"
    echo "Example: $0 open rules.txt firewall_output.txt"
    echo ""
    echo "This script will SSH to localhost as $CURRENT_USER"
    echo "If output_file is not specified, defaults to firewall_output.txt"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

ACTION=$1
FILE=$2
OUTPUT_FILE="${3:-firewall_output.txt}"

if [ "$ACTION" != "open" ] && [ "$ACTION" != "close" ]; then
    echo "Error: Action must be 'open' or 'close'"
    usage
fi

if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found."
    exit 1
fi

# Clear output file
> "$OUTPUT_FILE"

echo "Connecting to: ${CURRENT_USER}@${LOCALHOST}"
echo ""

while IFS= read -r line || [ -n "$line" ]; do
    
    case "$line" in
        \#*) continue ;;
    esac

    if [ -z "$line" ]; then
        continue
    fi

    if [ "$ACTION" = "open" ]; then
        remoteipadd "$line" "$OUTPUT_FILE"
    else
        remoteipdelete "$line" "$OUTPUT_FILE"
    fi

done < "$FILE"

echo ""
echo "Completed!"