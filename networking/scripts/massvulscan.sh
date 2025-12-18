#!/bin/sh
# MassVulScan adapted from https://github.com/choupit0/MassVulScan
D=$(cd "$(dirname "$0")/../../networking" && pwd)
SRC="$D/sources"; OUT="$D/outputs"; DNS="1.1.1.1"
TCP="$SRC/top-ports-tcp-1000.txt"; UDP="$SRC/top-ports-udp-1000.txt"

die() { echo "$1" >&2; exit 1; }
valid_ip() { echo "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$' && \
  { ip=${1%%/*}; OIFS=$IFS; IFS=.; set -- $ip; IFS=$OIFS; [ "$1" -le 255 ] && [ "$2" -le 255 ] && [ "$3" -le 255 ] && [ "$4" -le 255 ]; }; }

# Parse Args
while [ -n "$1" ]; do case "$1" in
  -h|--hosts) shift; [ -n "$F_IN" ] && die "Conflict: -h and -f"; RAW="$1" ;;
  -f|--include-file) shift; [ -n "$RAW" ] && die "Conflict: -h and -f"; F_IN="$1" ;;
  -x|--exclude-file) shift; F_EX="$1" ;;
  -a|--all-ports) ALL_P=1 ;;
  -c|--check-live-hosts) CHK=1 ;;
  -n|--no-nmap-scan) NO_MAP=1 ;;
  -d|--dns) shift; DNS="$1" ;;
  -I|--interface) shift; IFACE="$1" ;;
  *) die "Usage: $0 -h <ip>|-f <file> [-x <excl>] [-a] [-c] [-n] [-d <dns>] [-I <if>]" ;;
esac; shift; done

[ "$(id -u)" -eq 0 ] || die "Root required"
[ -n "$F_IN" ] && { [ -s "$F_IN" ] || die "Empty input"; RAW=$(cat "$F_IN"); NAME=$(basename "$F_IN"); } || NAME=$(echo "$RAW" | tr '/:' '_')
[ -n "$RAW" ] || die "No targets"
valid_ip "$DNS" || die "Invalid DNS"

# Setup
TMP=$(mktemp -d /tmp/mvs-XXXXXX); trap 'rm -rf "$TMP" 2>/dev/null' EXIT
mkdir -p "$OUT"; REPORT="${OUT}/${NAME}_scan_$(date +%F_%H-%M-%S).txt"

# Processor: Resolve Hostnames/Validate IPs
process() { echo "$1" | grep -oE '[^[:space:]]+' | sort -u | while read -r L; do
  valid_ip "$L" && echo "$L" || dig @"$DNS" "$L" +short | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | awk -v h="$L" '{print $1,h}'; done; }
process "$RAW" > "$TMP/t_full"; cut -d' ' -f1 "$TMP/t_full" > "$TMP/t"
[ -s "$TMP/t" ] || die "No valid targets"
[ -n "$F_EX" ] && process "$(cat "$F_EX")" | cut -d' ' -f1 > "$TMP/e"

# Ports & Iface
[ "$ALL_P" ] && PORTS="1-65535,U:1-65535" || \
  PORTS="$(grep -v '#' "$TCP" 2>/dev/null || echo 21,22,23,25,53,80,110,143,443,445,993,995,3306,3389,8080),U:$(grep -v '#' "$UDP" 2>/dev/null || echo 53,67,68,69,123,161,500,514)"
[ -z "$IFACE" ] && IFACE=$(ip route show default | awk '/default/ {print $5; exit}')

# 1. Live Check
if [ "$CHK" ]; then
  nmap -n -sP -T5 --min-parallelism 100 --max-parallelism 256 -iL "$TMP/t" 2>/dev/null | \
    grep -B1 "Host is up" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' > "$TMP/live"
  [ -s "$TMP/live" ] || { echo "No live hosts." >> "$REPORT"; die "No live hosts"; }
  mv "$TMP/live" "$TMP/t"; echo "Live Hosts: $(wc -l < "$TMP/t")" >> "$REPORT"
fi

# 2. Masscan
CMD="masscan --open -p$PORTS --source-port 40000 -iL $TMP/t -e $IFACE --max-rate 1500 --wait 5"
[ -s "$TMP/e" ] && CMD="$CMD --excludefile $TMP/e"
$CMD > "$TMP/raw" 2>&1; [ -s "$TMP/raw" ] || { echo "No open ports." >> "$REPORT"; exit 0; }

# 3. Parsing (Original Logic)
TCP_CNT=$(grep -c "^Discovered open port.*tcp" "$TMP/raw" || echo 0)
UDP_CNT=$(grep -c "^Discovered open port.*udp" "$TMP/raw" || echo 0)
parse_masscan() {
    proto="$1"
    grep "Discovered open port .*/${proto} on" "$TMP/raw" | awk -v proto="$proto" '
    {
        split($4, p, "/"); port = p[1]; ip = $6
        if (!seen[ip]) { order[++i] = ip; seen[ip] = 1; ips[ip] = port }
        else { ips[ip] = ips[ip] "," port }
    }
    END { for (j = 1; j <= i; j++) printf("%s:%s:%s\n", proto, order[j], ips[order[j]]) }'
}
rm -f "$TMP/list"
[ "$TCP_CNT" -gt 0 ] && parse_masscan tcp >> "$TMP/list"
[ "$UDP_CNT" -gt 0 ] && parse_masscan udp >> "$TMP/list"
echo "Hosts Found: $(wc -l < "$TMP/list" 2>/dev/null || echo 0)" >> "$REPORT"

# 4. Nmap
if [ -z "$NO_MAP" ] && [ -s "$TMP/list" ]; then
  mkdir "$TMP/n"; while read -r L; do
    while [ "$(jobs 2>/dev/null | wc -l)" -ge 50 ]; do sleep 1; done
    proto=${L%%:*}; rest=${L#*:}; ip=${rest%%:*}; pts=${rest#*:}
    [ "$proto" = "tcp" ] && F="-sT" || F="-sU"
    nmap -Pn $F -sV -n -p"$pts" --max-retries 2 --max-rtt-timeout 500ms -oN "$TMP/n/${ip}_${proto}.nmap" "$ip" >/dev/null 2>&1 &
  done < "$TMP/list"; wait
  for f in "$TMP/n"/*.nmap; do
    [ -e "$f" ] || continue
    echo "" >> "$REPORT"
    echo "--- $(basename "$f" .nmap) ---" >> "$REPORT"
    sed -n '/Nmap scan report for/,/Service detection performed/p' "$f" | head -n -1 >> "$REPORT"
  done
else
  echo "Nmap skipped." >> "$REPORT"
fi