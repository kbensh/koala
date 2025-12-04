#!/bin/sh

iptables_ssh() {
    input_file="$1"
    if [ ! -f "$input_file" ]; then
        echo "Error: File '$input_file' not found." >&2
        return 1
    fi

    iptables -A INPUT -p tcp --dport ssh -i lo -j ACCEPT

    iptables -A INPUT -p tcp --dport ssh -m conntrack \
        --ctstate ESTABLISHED,RELATED -j ACCEPT

    while read -r ip || [ -n "$ip" ]; do
        case "$ip" in
            ""|\#*)
                continue
                ;;
            *)
                iptables -A INPUT -s "$ip" -p tcp --dport ssh -j ACCEPT
                ;;
        esac
    done < "$input_file"

    iptables -A INPUT -p tcp --dport ssh -j DROP
}

iptables_ssh "$1"