#!/bin/sh

# Get current user
usr=$(whoami)

# Parse arguments
CURRENT_USER="${1:-$usr}"
LOCALHOST="${2:-localhost}" 
ACTION="$3"
FILE="$4"
OUTPUT_FILE="${5:-firewall_output.txt}"

# Function: Add an IP over ssh to localhost
remoteipadd(){
    client=$(echo "$1" | cut -d':' -f1)
    port=$(echo "$1" | cut -d':' -f2)
    wallif=$(echo "$1" | cut -d':' -f3)
    ip=$(echo "$1" | cut -d':' -f4)
    output_file="$2"

    echo " [OPENING] Port $port for $client on $LOCALHOST (via SSH as $CURRENT_USER)..."
    ssh -i "$HOME/.ssh/id_rsa_ip_ssh" -n ${CURRENT_USER}@${LOCALHOST} /sbin/iptables -I INPUT -i ${wallif} -s ${client} -d ${ip} -p tcp --destination-port ${port} -j ACCEPT >> "$output_file" 2>&1
}

# Function: Delete an IP over ssh from localhost
remoteipdelete(){
    client=$(echo "$1" | cut -d':' -f1)
    port=$(echo "$1" | cut -d':' -f2)
    wallif=$(echo "$1" | cut -d':' -f3)
    ip=$(echo "$1" | cut -d':' -f4)
    output_file="$2"

    echo " [CLOSING] Port $port for $client on $LOCALHOST (via SSH as $CURRENT_USER)..."
    ssh -i "$HOME/.ssh/id_rsa_ip_ssh" -n ${CURRENT_USER}@${LOCALHOST} /sbin/iptables -D INPUT -i ${wallif} -s ${client} -d ${ip} -p tcp --destination-port ${port} -j ACCEPT >> "$output_file" 2>&1
}

usage(){
    echo "Usage: $0 [user] [host] {open|close} filename.txt [output_file]"
    echo "Example: $0 root localhost open rules.txt firewall_output.txt"
    echo "Example: $0 open rules.txt  # Uses current user and localhost"
    echo ""
    echo "Arguments:"
    echo "  user        - SSH user (default: current user '$usr')"
    echo "  host        - SSH host (default: localhost)"
    echo "  action      - 'open' or 'close'"
    echo "  filename    - File containing firewall rules"
    echo "  output_file - Output file (default: firewall_output.txt)"
    exit 1
}

# Handle case where user provides action directly (backward compatibility)
if [ "$1" = "open" ] || [ "$1" = "close" ]; then
    CURRENT_USER="$usr"
    LOCALHOST="localhost"
    ACTION="$1"
    FILE="$2"
    OUTPUT_FILE="${3:-firewall_output.txt}"
fi

if [ $# -lt 2 ]; then
    usage
fi

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