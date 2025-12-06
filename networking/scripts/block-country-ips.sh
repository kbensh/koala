#!/bin/sh
# Adapted from https://github.com/iiiiiii1/Block-IPs-from-countries/blob/master/block-ips.sh
# Block IPs from countries

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root!" >&2
    exit 1
fi

# Block IPs
block_ipset() {
    IP_FILE="$1"
    OUTPUT_FILE="$2"
    GEOIP="$3"
    
    if [ ! -f "$IP_FILE" ]; then
        echo "Error: Input file not found: $IP_FILE" >&2
        exit 1
    fi
    
    # Create ipset rule
    ipset -N "$GEOIP" hash:net >> "$OUTPUT_FILE" 2>&1 || {
        echo "Error: Failed to create ipset. May already exist." >&2
        exit 1
    }
    
    # Add IPs from file
    while IFS= read -r ip; do
        ipset -A "$GEOIP" "$ip" >> "$OUTPUT_FILE" 2>&1
    done < "$IP_FILE"
    
    echo "Rules added successfully, blocking IPs..."
    
    # Block traffic
    iptables -I INPUT -p tcp -m set --match-set "$GEOIP" src -j DROP >> "$OUTPUT_FILE" 2>&1
    iptables -I INPUT -p udp -m set --match-set "$GEOIP" src -j DROP >> "$OUTPUT_FILE" 2>&1
    
    echo "Country ($GEOIP) IPs blocked successfully!"
}

# Unblock IPs
unblock_ipset() {
    OUTPUT_FILE="$1"
    GEOIP="$2"
    
    # Check if rule exists
    if ipset list | grep -q "Name: $GEOIP"; then
        iptables -D INPUT -p tcp -m set --match-set "$GEOIP" src -j DROP >> "$OUTPUT_FILE" 2>&1
        iptables -D INPUT -p udp -m set --match-set "$GEOIP" src -j DROP >> "$OUTPUT_FILE" 2>&1
        ipset destroy "$GEOIP" >> "$OUTPUT_FILE" 2>&1
        echo "Country ($GEOIP) IPs unblocked and rules deleted!"
    else
        echo "Error: No rules found for country: $GEOIP" >&2
        exit 1
    fi
}

# Show block list
block_list() {
    OUTPUT_FILE="$1"
    iptables -L | grep match-set >> "$OUTPUT_FILE" 2>&1
}

# Interactive menu (when only 1 argument provided)
interactive_menu() {
    IP_FILE="$1"
    OUTPUT_FILE="block_ips_output.txt"
    
    clear
    echo "-------------------------------------------"
    echo "Block IPs by country"
    echo "1. Block IPs"
    echo "2. Unblock IPs"
    echo "3. Show block list"
    echo "-------------------------------------------"
    printf "Enter choice [1-3]: "
    read -r num
    
    case "$num" in
        1)
            printf "Enter country code to block (e.g., dummy): "
            read -r GEOIP
            block_ipset "$IP_FILE" "$OUTPUT_FILE" "$GEOIP"
            ;;
        2)
            printf "Enter country code to unblock (e.g., dummy): "
            read -r GEOIP
            unblock_ipset "$OUTPUT_FILE" "$GEOIP"
            ;;
        3)
            block_list "$OUTPUT_FILE"
            ;;
        *)
            clear
            echo "Invalid choice [1-3]"
            sleep 2
            interactive_menu "$IP_FILE"
            ;;
    esac
}

# Main
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <ip_list_file> <output_file> <action> [country_code]" >&2
    echo "   or: $0 <ip_list_file>  (for interactive menu)" >&2
    exit 1
fi

IP_FILE="$1"
OUTPUT_FILE="$2"
ACTION="$3"
COUNTRY_CODE="$4"

# Interactive mode (1 argument only)
if [ "$#" -eq 1 ]; then
    interactive_menu "$IP_FILE"
    exit 0
fi

# Command-line mode (3 or more arguments)
if [ "$#" -lt 3 ]; then
    echo "Error: Missing required arguments" >&2
    echo "Usage: $0 <ip_list_file> <output_file> <action> [country_code]" >&2
    exit 1
fi

case "$ACTION" in
    block)
        if [ -z "$COUNTRY_CODE" ]; then
            echo "Error: Country code required for block action" >&2
            echo "Usage: $0 <ip_list_file> <output_file> block <country_code>" >&2
            exit 1
        fi
        block_ipset "$IP_FILE" "$OUTPUT_FILE" "$COUNTRY_CODE"
        ;;
    unblock)
        if [ -z "$COUNTRY_CODE" ]; then
            echo "Error: Country code required for unblock action" >&2
            echo "Usage: $0 <ip_list_file> <output_file> unblock <country_code>" >&2
            exit 1
        fi
        unblock_ipset "$OUTPUT_FILE" "$COUNTRY_CODE"
        ;;
    list)
        block_list "$OUTPUT_FILE"
        ;;
    *)
        echo "Error: Invalid action '$ACTION'" >&2
        echo "Valid actions: block, unblock, list" >&2
        exit 1
        ;;
esac