#!/bin/sh
# Portscan
D=$(cd "$(dirname "$0")/../../net" && pwd)
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
[ -z "$IFACE" ] && IFACE="eth0"

TMP=$(mktemp -d /tmp/mvs-XXXXXX)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"
REPORT="${OUT}/portscan.txt"
> $REPORT
# Validate IPs
grep -v '^#' "$F_IN" | while read -r ip; do
    valid_ip "$ip" && echo "$ip"
done | sort -u > "$TMP/t"
[ -s "$TMP/t" ] || die "Error: No valid IPs"

if [ -n "$F_EX" ]; then
    grep -v '^#' "$F_EX" | while read -r ip; do
        valid_ip "$ip" && echo "$ip"
    done | sort -u > "$TMP/e"
fi

# 1. Connectivity Check
echo "Starting connectivity check..."
nmap -sn -PE -PS80,443 -n -iL "$TMP/t" -oG - 2>/dev/null \
    | awk '/Up$/{print $2}' > "$TMP/live"

if [ ! -s "$TMP/live" ]; then
    echo "[!] Warning: Host discovery failed (Ping blocked?). Scanning all inputs anyway." >> "$REPORT"
    cp "$TMP/t" "$TMP/live"
fi
mv "$TMP/live" "$TMP/t"
TARGET_COUNT=$(wc -l < "$TMP/t")
echo "Targets to scan: $TARGET_COUNT" >> "$REPORT"

# 2. Port Scan

CMD="nmap -n -Pn -sT -p- -T3 -v -iL $TMP/t -oG $TMP/raw"
[ -s "$TMP/e" ] && CMD="$CMD --excludefile $TMP/e"

$CMD > "$TMP/nmap_std" 2>&1

# 3. Parse Nmap Output
# We look for "open" ports specifically
awk '/Ports:/ {
    host = $2
    start = 0
    for(i=1;i<=NF;i++) if($i=="Ports:") start=i+1
    
    if(start>0) {
        for (i=start; i<=NF; i++) {
            if ($i ~ /\/open\//) {
                split($i, a, "/")
                port = a[1]; proto = a[3]
                key = proto ":" host
                if (!seen[key]++) { order[++n] = key }
                ports[key] = ports[key] ? ports[key] "," port : port
            }
        }
    }
}
END {
    for (i = 1; i <= n; i++) print order[i] ":" ports[order[i]]
}' "$TMP/raw" > "$TMP/list"

COUNT=$(wc -l < "$TMP/list")
echo "Hosts/Proto groups Found: $COUNT" >> "$REPORT"

# DEBUG: If 0 found, analyze why
if [ "$COUNT" -eq 0 ]; then
    echo "--- DIAGNOSTIC INFO ---" >> "$REPORT"
    # Check if we saw "closed" ports (host up, no services)
    if grep -q "closed" "$TMP/raw"; then
        echo "Result: Host is UP, but ports are CLOSED. (No services running or firewall REJECT)." >> "$REPORT"
    # Check if we saw "filtered" ports (firewall DROP)
    elif grep -q "filtered" "$TMP/raw"; then
        echo "Result: Host is UP, but ports are FILTERED. (Firewall blocking)." >> "$REPORT"
    else
        echo "Result: Scan finished oddly. Raw Nmap output below:" >> "$REPORT"
        tail -n 10 "$TMP/raw" >> "$REPORT"
        echo "Standard Output/Error:" >> "$REPORT"
        cat "$TMP/nmap_std" >> "$REPORT" 
    fi
    exit 0
fi

# 4. Deep Service Scan (Version Detection)
mkdir -p "$TMP/n"
while IFS=: read -r proto ip pts; do
    while [ "$(jobs | wc -l)" -ge 10 ]; do sleep 1; done
    echo "Deep scanning $ip ($proto) ports: $pts" >> "$REPORT"
    nmap -Pn -sT -sV -n -p"$pts" --version-intensity 5 \
        -oN "$TMP/n/${ip}_${proto}.nmap" "$ip" >/dev/null 2>&1 &
done < "$TMP/list"
wait

for f in "$TMP/n"/*.nmap; do
    [ -e "$f" ] || continue
    echo "Processing result: $f"
    echo "\n--- $(basename "$f" .nmap) ---" >> "$REPORT"
    sed -n '/Nmap scan report/,/Service detection/p' "$f" | head -n -1 >> "$REPORT"
done

echo "Scan complete. Report saved to $REPORT"