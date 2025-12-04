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
    
    echo " [OPENING] Port $port for $client on $LOCALHOST (via SSH as $CURRENT_USER)..."
    cmd="ssh -n ${CURRENT_USER}@${LOCALHOST} /sbin/iptables -I INPUT -i ${wallif} -s ${client} -d ${ip} -p tcp --destination-port ${port} -j ACCEPT"
    $cmd
}

# Function: Delete an IP over ssh from localhost
remoteipdelete(){
    client=$(echo "$1" | cut -d':' -f1)
    port=$(echo "$1" | cut -d':' -f2)
    wallif=$(echo "$1" | cut -d':' -f3)
    ip=$(echo "$1" | cut -d':' -f4)
    
    echo " [CLOSING] Port $port for $client on $LOCALHOST (via SSH as $CURRENT_USER)..."
    cmd="ssh -n ${CURRENT_USER}@${LOCALHOST} /sbin/iptables -D INPUT -i ${wallif} -s ${client} -d ${ip} -p tcp --destination-port ${port} -j ACCEPT"
    $cmd
}

usage(){
    echo "Usage: $0 {open|close} filename.txt"
    echo "Example: $0 open rules.txt"
    echo ""
    echo "This script will SSH to localhost as $CURRENT_USER"
    exit 1
}

if [ $# -ne 2 ]; then
    usage
fi

ACTION=$1
FILE=$2

if [ "$ACTION" != "open" ] && [ "$ACTION" != "close" ]; then
    echo "Error: Action must be 'open' or 'close'"
    usage
fi

if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found."
    exit 1
fi

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
        remoteipadd "$line"
    else
        remoteipdelete "$line"
    fi

done < "$FILE"

echo ""
echo "Completed!"