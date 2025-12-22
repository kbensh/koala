#!/bin/sh
# MassVulScan adapted from https://github.com/choupit0/MassVulScan
D=$(cd "$(dirname "$0")/../../networking" && pwd)
OUT="$D/outputs"

die() { echo "[ERROR] $1" >&2; exit 1; }

valid_ip() {
    echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]+)?$' || return 1
    OIFS=$IFS; IFS=.; set -- ${1%%/*}; IFS=$OIFS
    [ "$1" -le 255 ] && [ "$2" -le 255 ] && [ "$3" -le 255 ] && [ "$4" -le 255 ]
}

while [ -n "$1" ]; do
    case "$1" in
        -f) shift; F_IN="$1" ;;
        -x) shift; F_EX="$1" ;;
        -I) shift; IFACE="$1" ;;
    esac
    shift
done

[ "$(id -u)" -eq 0 ] || die "Error: Root required"
[ -s "$F_IN" ] || die "Error: Input file required and must not be empty"

[ -z "$IFACE" ] && IFACE=$(ip route show default | awk '{print $5; exit}')

TMP=$(mktemp -d /tmp/mvs-XXXXXX)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"
REPORT="${OUT}/$(basename "$F_IN")_scan_$(date +%F_%H-%M-%S).txt"

# Validate IPs
grep -v '^#' "$F_IN" | while read -r ip; do
    valid_ip "$ip" && echo "$ip"
done | sort -u > "$TMP/t"
[ -s "$TMP/t" ] || die "Error: No valid IPs"

if [ -n "$F_EX" ]; then
    grep -v '^#' "$F_EX" | while read -r ip; do
        valid_ip "$ip" && echo "$ip"
    done | sort -u > "$TMP/e"
    debug "Exclusions: $(cat "$TMP/e" | tr '\n' ' ')"
fi

# 1. Live check
debug "Starting live host check..."
nmap -n -sP -T5 --min-parallelism 100 --max-parallelism 256 -iL "$TMP/t" 2>/dev/null \
    | tee "$TMP/nmap_ping_raw" \
    | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' > "$TMP/live"
debug "Nmap ping output: $(cat "$TMP/nmap_ping_raw")"
debug "Live hosts: $(cat "$TMP/live" | tr '\n' ' ')"
[ -s "$TMP/live" ] || die "Error: No live hosts"
mv "$TMP/live" "$TMP/t"

# 2. Masscan
CMD="masscan --open -p1-65535,U:1-65535 --source-port 40000 -iL $TMP/t -e $IFACE --max-rate 1500 --wait 5"
[ -s "$TMP/e" ] && CMD="$CMD --excludefile $TMP/e"
$CMD > "$TMP/raw" 2>&1
[ -s "$TMP/raw" ] || { echo "No open ports." >> "$REPORT"; debug "No open ports found, exiting"; exit 0; }

# 3. Parse masscan output
awk '/Discovered open port/ {
    split($4, p, "/"); port = p[1]; proto = p[2]; ip = $6
    key = proto ":" ip
    if (!seen[key]++) { order[++n] = key }
    ports[key] = ports[key] ? ports[key] "," port : port
}
END {
    for (i = 1; i <= n; i++) print order[i] ":" ports[order[i]]
}' "$TMP/raw" > "$TMP/list"
echo "Hosts Found: $(wc -l < "$TMP/list")" >> "$REPORT"

# 4. Nmap
mkdir "$TMP/n"
while IFS=: read -r proto ip pts; do
    while [ "$(jobs | wc -l)" -ge 50 ]; do sleep 1; done
    [ "$proto" = "tcp" ] && F="-sT" || F="-sU"
    debug "Scanning $ip ($proto) ports: $pts"
    nmap -Pn $F -sV -n -p"$pts" --max-retries 2 --max-rtt-timeout 500ms \
        -oN "$TMP/n/${ip}_${proto}.nmap" "$ip" >/dev/null 2>&1 &
done < "$TMP/list"
wait

for f in "$TMP/n"/*.nmap; do
    [ -e "$f" ] || continue
    debug "Processing result: $f"
    echo "\n--- $(basename "$f" .nmap) ---" >> "$REPORT"
    sed -n '/Nmap scan report/,/Service detection/p' "$f" | head -n -1 >> "$REPORT"
done
