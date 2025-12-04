#!/bin/sh
# Setup script for wifi-strength benchmarking

if ! command -v iw >/dev/null 2>&1; then
    echo "Installing iw..."
    sudo apt-get update && sudo apt-get install -y iw
fi

if iw dev 2>/dev/null | grep -q "Interface"; then
    echo "Real wireless interface found - using real iw"
    exit 0
fi

echo "No wireless interfaces found - creating mock iw for benchmarking"

cat > /usr/local/bin/iw << 'EOF'
#!/bin/sh
# Mock iw for benchmarking

if [ "$1" = "dev" ] && [ -z "$2" ]; then
    echo "Interface wlan0"
elif [ "$1" = "dev" ] && [ "$3" = "link" ]; then
    echo "Connected to aa:bb:cc:dd:ee:ff (on wlan0)"
    echo "SSID: TestNetwork"
    echo "freq: 5200"
    echo "signal: -65 dBm"
    echo "tx bitrate: 150.0 MBit/s"
elif [ "$1" = "dev" ] && [ "$3" = "scan" ]; then
    cat << 'SCAN'
BSS aa:bb:cc:dd:ee:ff
	freq: 5200
	signal: -65 dBm
	SSID: TestNetwork1
BSS 11:22:33:44:55:66
	freq: 2437
	signal: -70 dBm
	SSID: TestNetwork2
BSS 99:88:77:66:55:44
	freq: 2412
	signal: -78 dBm
	MESH ID: MeshNet
BSS ff:ee:dd:cc:bb:aa
	freq: 5180
	signal: -85 dBm
	SSID: <hidden>
ExitCode: 000
SCAN
fi
EOF

chmod +x /usr/local/bin/iw
echo "Mock iw created at /usr/local/bin/iw"