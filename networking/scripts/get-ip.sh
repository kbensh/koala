#!/bin/sh

INTERFACE=$(ip route | grep '^default' | awk '{print $5}')
IP_ADDR=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
IP6_ADDR=$(ip -6 addr show "$INTERFACE" | grep -oP '(?<=inet6\s)[\da-f:]+')

echo "Active Interface: $INTERFACE"
echo "Current IPv4:     $IP_ADDR"
echo "Current IPv6:     $IP6_ADDR"