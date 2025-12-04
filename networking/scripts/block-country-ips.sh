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
    if [ ! -f "$1" ]; then
        echo "Error: Input file not found: $1" >&2
        exit 1
    fi
    
    GEOIP="$2"
    
    # Create ipset rule
    ipset -N "$GEOIP" hash:net 2>/dev/null || {
        echo "Error: Failed to create ipset. May already exist." >&2
        exit 1
    }
    
    # Add IPs from file
    while IFS= read -r ip; do
        ipset -A "$GEOIP" "$ip"
    done < "$1"
    
    echo "Rules added successfully, blocking IPs..."
    
    # Block traffic
    iptables -I INPUT -p tcp -m set --match-set "$GEOIP" src -j DROP
    iptables -I INPUT -p udp -m set --match-set "$GEOIP" src -j DROP
    
    echo "Country ($GEOIP) IPs blocked successfully!"
}

# Unblock IPs
unblock_ipset() {
    GEOIP="$1"
    
    # Check if rule exists
    if ipset list | grep -q "Name: $GEOIP"; then
        iptables -D INPUT -p tcp -m set --match-set "$GEOIP" src -j DROP
        iptables -D INPUT -p udp -m set --match-set "$GEOIP" src -j DROP
        ipset destroy "$GEOIP"
        echo "Country ($GEOIP) IPs unblocked and rules deleted!"
    else
        echo "Error: No rules found for country: $GEOIP" >&2
        exit 1
    fi
}

# Show block list
block_list() {
    iptables -L | grep match-set
}

# Interactive menu (when only 1 argument provided)
interactive_menu() {
    IP_FILE="$1"
    
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
            block_ipset "$IP_FILE" "$GEOIP"
            ;;
        2)
            printf "Enter country code to unblock (e.g., dummy): "
            read -r GEOIP
            unblock_ipset "$GEOIP"
            ;;
        3)
            block_list
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
    echo "Usage: $0 <ip_list_file> [block|unblock|list] [country_code]" >&2
    echo "   or: $0 <ip_list_file>  (for interactive menu)" >&2
    exit 1
fi

IP_FILE="$1"
ACTION="$2"
COUNTRY_CODE="$3"

# Interactive mode (1 argument only)
if [ "$#" -eq 1 ]; then
    interactive_menu "$IP_FILE"
    exit 0
fi

# Command-line mode (2 or 3 arguments)
if [ "$#" -lt 2 ]; then
    echo "Error: Missing action argument" >&2
    echo "Usage: $0 <ip_list_file> [block|unblock|list] [country_code]" >&2
    exit 1
fi

case "$ACTION" in
    block)
        if [ -z "$COUNTRY_CODE" ]; then
            echo "Error: Country code required for block action" >&2
            echo "Usage: $0 <ip_list_file> block <country_code>" >&2
            exit 1
        fi
        block_ipset "$IP_FILE" "$COUNTRY_CODE"
        ;;
    unblock)
        if [ -z "$COUNTRY_CODE" ]; then
            echo "Error: Country code required for unblock action" >&2
            echo "Usage: $0 <ip_list_file> unblock <country_code>" >&2
            exit 1
        fi
        unblock_ipset "$COUNTRY_CODE"
        ;;
    list)
        block_list
        ;;
    *)
        echo "Error: Invalid action '$ACTION'" >&2
        echo "Valid actions: block, unblock, list" >&2
        exit 1
        ;;
esac