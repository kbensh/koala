#!/bin/sh
# adapted from: https://github.com/superkojiman/onetwopunch/blob/master/onetwopunch.sh
# Colors
ESC=$(printf '\033[')
RESET="${ESC}39m"
RED="${ESC}31m"
GREEN="${ESC}32m"
BLUE="${ESC}34m"

usage() {
    printf "Usage: %s -t targets.txt [-p tcp/udp/all] [-i interface] [-n nmap-options] [-o output-dir] [-h]\n" "$0"
    printf "       -h: Help\n"
    printf "       -t: File containing ip addresses to scan. This option is required.\n"
    printf "       -p: Protocol. Defaults to tcp\n"
    printf "       -i: Network interface. Defaults to eth0\n"
    printf "       -n: NMAP options (-A, -O, etc). Defaults to no options.\n"
    printf "       -o: Output directory. Defaults to ~/.onetwopunch\n"
}


if [ "$(id -u)" != "0" ]; then
    printf "%b[!]%b This script must be run as root\n" "$RED" "$RESET"
    exit 1
fi

if [ -z "$(command -v nmap)" ]; then
    printf "%b[!]%b Unable to find nmap. Install it and make sure it's in your PATH environment\n" "$RED" "$RESET"
    exit 1
fi

if [ -z "$(command -v unicornscan)" ]; then
    printf "%b[!]%b Unable to find unicornscan. Install it and make sure it's in your PATH environment\n" "$RED" "$RESET"
    exit 1
fi

if [ -z "$1" ]; then
    usage
    exit 0
fi

# commonly used default options
proto="tcp"
iface="eth0"
nmap_opt="-sV"
targets=""
log_dir="${HOME}/.onetwopunch"

while getopts "p:i:t:n:o:h" OPT; do
    case $OPT in
        p) proto="$OPTARG";;
        i) iface="$OPTARG";;
        t) targets="$OPTARG";;
        n) nmap_opt="$OPTARG";;
        o) log_dir="$OPTARG";;
        h) usage; exit 0;;
        *) usage; exit 0;;
    esac
done

if [ -z "$targets" ]; then
    printf "[!] No target file provided\n"
    usage
    exit 1
fi

if [ "$proto" != "tcp" ] && [ "$proto" != "udp" ] && [ "$proto" != "all" ]; then
    printf "[!] Unsupported protocol\n"
    usage
    exit 1
fi

printf "%b[+]%b Protocol : %s\n" "$BLUE" "$RESET" "$proto"
printf "%b[+]%b Interface: %s\n" "$BLUE" "$RESET" "$iface"
printf "%b[+]%b Nmap opts: %s\n" "$BLUE" "$RESET" "$nmap_opt"
printf "%b[+]%b Targets  : %s\n" "$BLUE" "$RESET" "$targets"

# backup any old scans before we start a new one
mkdir -p "${log_dir}/backup/"
if [ -d "${log_dir}/ndir/" ]; then 
    mv "${log_dir}/ndir/" "${log_dir}/backup/ndir-$(date "+%Y%m%d-%H%M%S")/"
fi
if [ -d "${log_dir}/udir/" ]; then 
    mv "${log_dir}/udir/" "${log_dir}/backup/udir-$(date "+%Y%m%d-%H%M%S")/"
fi 

rm -rf "${log_dir}/ndir/"
mkdir -p "${log_dir}/ndir/"
rm -rf "${log_dir}/udir/"
mkdir -p "${log_dir}/udir/"

while IFS= read -r ip; do
    log_ip=$(printf '%s' "$ip" | sed 's/\//-/g')
    printf "%b[+]%b Scanning %s for %s ports...\n" "$BLUE" "$RESET" "$ip" "$proto"

    # unicornscan identifies all open TCP ports
    if [ "$proto" = "tcp" ] || [ "$proto" = "all" ]; then 
        printf "%b[+]%b Obtaining all open TCP ports using unicornscan...\n" "$BLUE" "$RESET"
        printf "%b[+]%b unicornscan -i %s -mT %s:a -l %s/udir/%s-tcp.txt\n" "$BLUE" "$RESET" "$iface" "$ip" "$log_dir" "$log_ip"
        unicornscan -i "$iface" -mT "$ip":a -l "${log_dir}/udir/${log_ip}-tcp.txt"
        ports=$(grep open "${log_dir}/udir/${log_ip}-tcp.txt" | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
        if [ -n "$ports" ]; then 
            # nmap follows up
            printf "%b[*]%b TCP ports for nmap to scan: %s\n" "$GREEN" "$RESET" "$ports"
            printf "%b[+]%b nmap -e %s %s -oX %s/ndir/%s-tcp.xml -oG %s/ndir/%s-tcp.grep -p %s %s\n" "$BLUE" "$RESET" "$iface" "$nmap_opt" "$log_dir" "$log_ip" "$log_dir" "$log_ip" "$ports" "$ip"
            nmap -e "$iface" $nmap_opt -oX "${log_dir}/ndir/${log_ip}-tcp.xml" -oG "${log_dir}/ndir/${log_ip}-tcp.grep" -p "$ports" "$ip"
        else
            printf "%b[!]%b No TCP ports found\n" "$RED" "$RESET"
        fi
    fi

    # unicornscan identifies all open UDP ports
    if [ "$proto" = "udp" ] || [ "$proto" = "all" ]; then  
        printf "%b[+]%b Obtaining all open UDP ports using unicornscan...\n" "$BLUE" "$RESET"
        printf "%b[+]%b unicornscan -i %s -mU %s:a -l %s/udir/%s-udp.txt\n" "$BLUE" "$RESET" "$iface" "$ip" "$log_dir" "$log_ip"
        unicornscan -i "$iface" -mU "$ip":a -l "${log_dir}/udir/${log_ip}-udp.txt"
        ports=$(grep open "${log_dir}/udir/${log_ip}-udp.txt" | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
        if [ -n "$ports" ]; then
            # nmap follows up
            printf "%b[*]%b UDP ports for nmap to scan: %s\n" "$GREEN" "$RESET" "$ports"
            printf "%b[+]%b nmap -e %s %s -sU -oX %s/ndir/%s-udp.xml -oG %s/ndir/%s-udp.grep -p %s %s\n" "$BLUE" "$RESET" "$iface" "$nmap_opt" "$log_dir" "$log_ip" "$log_dir" "$log_ip" "$ports" "$ip"
            nmap -e "$iface" $nmap_opt -sU -oX "${log_dir}/ndir/${log_ip}-udp.xml" -oG "${log_dir}/ndir/${log_ip}-udp.grep" -p "$ports" "$ip"
        else
            printf "%b[!]%b No UDP ports found\n" "$RED" "$RESET"
        fi
    fi
done < "$targets"

printf "%b[+]%b Scans completed\n" "$BLUE" "$RESET"
printf "%b[+]%b Results saved to %s\n" "$BLUE" "$RESET" "$log_dir"