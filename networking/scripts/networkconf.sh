#!/bin/sh
# source: https://bash.cyberciti.biz/networking/shell-script-to-find-linux-network-configurations/
DNSCLIENT="/etc/resolv.conf"
DRVCONF="/etc/modprobe.d"
NETCFC="/etc/network/interfaces"
SYSCTL="/etc/sysctl.conf"

## Command paths ##
lsb_release=$(command -v lsb_release)
hwinfo=$(command -v hwinfo)
lspci=$(command -v lspci)
ifconfig=$(command -v ifconfig)
ip=$(command -v ip)
route=$(command -v route)
iptables=$(command -v iptables)
ip6tables=$(command -v ip6tables)
netstat=$(command -v netstat)

## Output file ##
OUTPUT="${1:-networkconf.txt}"

chk_root(){
	meid=$(id -u)
	if [ "$meid" -ne 0 ]; then
		echo "You must be root user to run this tool"
		exit 1
	fi
}

write_header(){
	echo "---------------------------------------------------" >> "$OUTPUT"
	echo "$@" >> "$OUTPUT"
	echo "---------------------------------------------------" >> "$OUTPUT"
}

dump_info(){
	echo "* Hostname: $(hostname)" > "$OUTPUT"
	echo "* Run date and time: $(date)" >> "$OUTPUT"

	write_header "Linux Distro"
	echo "Linux kernel: $(uname -mrs)" >> "$OUTPUT"
	if [ -n "$lsb_release" ] && [ -x "$lsb_release" ]; then
		lsb_release -a >> "$OUTPUT"
	fi

	if [ -n "$hwinfo" ] && [ -x "$hwinfo" ]; then
		write_header "$hwinfo --network_ctrl"
		hwinfo --network_ctrl >> "$OUTPUT"
	fi

	if [ -n "$hwinfo" ] && [ -x "$hwinfo" ]; then
		write_header "$hwinfo --isapnp"
		hwinfo --isapnp >> "$OUTPUT"
	fi

	write_header "PCI Devices"
	if [ -n "$lspci" ] && [ -x "$lspci" ]; then
		lspci -v >> "$OUTPUT"
	fi

	write_header "Network Interfaces (ifconfig)"
	if [ -n "$ifconfig" ] && [ -x "$ifconfig" ]; then
		ifconfig >> "$OUTPUT"
	fi

	write_header "Network Interfaces (ip addr)"
	if [ -n "$ip" ] && [ -x "$ip" ]; then
		ip addr show >> "$OUTPUT"
	fi

	write_header "Kernel Routing Table (route)"
	if [ -n "$route" ] && [ -x "$route" ]; then
		route -n >> "$OUTPUT"
	fi

	write_header "Kernel Routing Table (ip route)"
	if [ -n "$ip" ] && [ -x "$ip" ]; then
		ip route show >> "$OUTPUT"
	fi

	write_header "Network Module Configuration $DRVCONF"
	if [ -d "$DRVCONF" ]; then
		find "$DRVCONF" -type f -exec grep -l eth {} \; -exec echo "** {} **" \; -exec cat {} \; >> "$OUTPUT"
	else
		echo "Error $DRVCONF directory not found." >> "$OUTPUT"
	fi

	write_header "DNS Client $DNSCLIENT Configuration"
	if [ -f "$DNSCLIENT" ]; then
		cat "$DNSCLIENT" >> "$OUTPUT"
	else
		echo "Error $DNSCLIENT file not found." >> "$OUTPUT"
	fi

	write_header "Network Configuration File"
	if [ -f "$NETCFC" ]; then
		echo "** $NETCFC **" >> "$OUTPUT"
		cat "$NETCFC" >> "$OUTPUT"
	else
		echo "Error $NETCFC not found." >> "$OUTPUT"
	fi

	write_header "IP4 Firewall Configuration"
	if [ -n "$iptables" ] && [ -x "$iptables" ]; then
		iptables -L -n >> "$OUTPUT"
	fi

	write_header "IP6 Firewall Configuration"
	if [ -n "$ip6tables" ] && [ -x "$ip6tables" ]; then
		ip6tables -L -n >> "$OUTPUT"
	fi

	write_header "Network Stats"
	if [ -n "$netstat" ] && [ -x "$netstat" ]; then
		netstat -s >> "$OUTPUT"
	fi

	write_header "Network Tweaks via $SYSCTL"
	if [ -f "$SYSCTL" ]; then
		cat "$SYSCTL" >> "$OUTPUT"
	else
		echo "Error $SYSCTL not found." >> "$OUTPUT"
	fi
}

chk_root
dump_info