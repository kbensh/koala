#!/bin/sh

iptables_ssh() {
    input_file="$1"
    output_file="${2:-iptables_ssh_rules.txt}"
    if [ ! -f "$input_file" ]; then
        echo "Error: File '$input_file' not found." >&2
        return 1
    fi

    # Clear output file
    > "$output_file"

    iptables -A INPUT -p tcp --dport ssh -i lo -j ACCEPT >> "$output_file" 2>&1

    iptables -A INPUT -p tcp --dport ssh -m conntrack \
        --ctstate ESTABLISHED,RELATED -j ACCEPT >> "$output_file" 2>&1

    while read -r ip || [ -n "$ip" ]; do
        case "$ip" in
            ""|\#*)
                continue
                ;;
            *)
                iptables -A INPUT -s "$ip" -p tcp --dport ssh -j ACCEPT >> "$output_file" 2>&1
                ;;
        esac
    done < "$input_file"

    iptables -A INPUT -p tcp --dport ssh -j DROP >> "$output_file" 2>&1
}

iptables_ssh "$1"