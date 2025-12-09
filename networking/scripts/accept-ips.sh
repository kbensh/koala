#!/bin/sh

iptables_ssh() {
    input_file="$1"
    output_file="${2:-iptables_ssh_rules.txt}"

    if [ ! -f "$input_file" ]; then
        echo "Error: File '$input_file' not found." >&2
        return 1
    fi

    echo "Starting iptables configuration..." > "$output_file"

    # iptables -A is silent on success
    # only redirect stderr
    iptables -A INPUT -p tcp --dport ssh -i lo -j ACCEPT 2>> "$output_file"

    iptables -A INPUT -p tcp --dport ssh -m conntrack \
        --ctstate ESTABLISHED,RELATED -j ACCEPT 2>> "$output_file"

    while read -r ip || [ -n "$ip" ]; do
        case "$ip" in
            ""|\#*)
                continue
                ;;
            *)
                iptables -A INPUT -s "$ip" -p tcp --dport ssh -j ACCEPT 2>> "$output_file"
                ;;
        esac
    done < "$input_file"

    iptables -A INPUT -p tcp --dport ssh -j DROP 2>> "$output_file"
    
    echo "" >> "$output_file"
    echo "--- Applied Rules Verification ---" >> "$output_file"
    iptables -L INPUT -n >> "$output_file"
}

iptables_ssh "$1" "$2"