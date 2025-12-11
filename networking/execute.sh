#!/bin/bash

# Check if inside namespace
if [ -n "$KOALA_NETNS_ACTIVE" ]; then
    # inside the namespace, run normally
    RUN_IN_NAMESPACE=0
else
    #  outside, need to enter namespace
    RUN_IN_NAMESPACE=1
fi

# If not in namespace, set up and exec inside
if [ "$RUN_IN_NAMESPACE" -eq 1 ]; then
    NETNS_NAME="koala_bench_$$"
    VETH_HOST="veth_host_$$"
    VETH_NS="veth_ns_$$"

    echo "Setting up network namespace: $NETNS_NAME"

    # Cleanup function
    cleanup_namespace() {
        echo ""
        echo "Cleaning up network namespace..."
        sudo iptables -t nat -D POSTROUTING -s 10.200.1.0/24 ! -d 10.200.1.0/24 -j MASQUERADE 2>/dev/null || true
        sudo ip netns delete "$NETNS_NAME" 2>/dev/null || true
        sudo ip link delete "$VETH_HOST" 2>/dev/null || true
        echo "Namespace cleaned up"
    }

    trap cleanup_namespace EXIT INT TERM

    # Create network namespace
    sudo ip netns add "$NETNS_NAME" || {
        echo "Error: Failed to create network namespace" >&2
        exit 1
    }

    # Set up loopback
    sudo ip netns exec "$NETNS_NAME" ip link set lo up

    # Create veth pair
    sudo ip link add "$VETH_HOST" type veth peer name "$VETH_NS"
    sudo ip link set "$VETH_NS" netns "$NETNS_NAME"

    # Configure host side
    sudo ip addr add 10.200.1.1/24 dev "$VETH_HOST"
    sudo ip link set "$VETH_HOST" up

    # Configure namespace side
    sudo ip netns exec "$NETNS_NAME" ip addr add 10.200.1.2/24 dev "$VETH_NS"
    sudo ip netns exec "$NETNS_NAME" ip link set "$VETH_NS" up
    sudo ip netns exec "$NETNS_NAME" ip route add default via 10.200.1.1

    # Enable forwarding on host
    sudo bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward' 2>/dev/null || true
    sudo iptables -t nat -A POSTROUTING -s 10.200.1.0/24 ! -d 10.200.1.0/24 -j MASQUERADE
    # Re-execute this script inside the namespace
    # We're entering as root, so we're root inside the namespace
    export KOALA_NETNS_ACTIVE=1
    sudo ip netns exec "$NETNS_NAME" env KOALA_NETNS_ACTIVE=1 bash "$0" "$@"
    exit_code=$?

    echo ""
    if [ $exit_code -eq 0 ]; then
        echo "Networking benchmark completed successfully"
    else
        echo "Networking benchmark failed with exit code $exit_code"
    fi

    # cleanup_namespace will be called by trap
    exit $exit_code
fi

# Inside namespace, already root (via sudo ip netns exec)

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/networking"
input_dir="${eval_dir}/inputs"
scripts_dir="${eval_dir}/scripts"
outputs_dir="${eval_dir}/outputs"
mkdir -p "$outputs_dir"

export LC_ALL=C

size=full
selected_scripts=""

while [ $# -gt 0 ]; do
    case "$1" in
        --small)
            size=small
            export max_scans=20
            shift
            ;;
        --min)
            size=min
            export max_scans=5
            shift
            ;;
        -s|--scripts)
            shift
            while [ $# -gt 0 ] && [ "$(echo "$1" | cut -c1)" != "-" ]; do
                if [ -z "$selected_scripts" ]; then
                    selected_scripts="$1"
                else
                    selected_scripts="$selected_scripts $1"
                fi
                shift
            done
            ;;
        *)
            shift
            ;;
    esac
done

export BENCHMARK_CATEGORY="networking"
KOALA_SHELL=${KOALA_SHELL:-bash}

should_run() {
    script_name=$1
    # If no scripts specified, run all
    if [ -z "$selected_scripts" ]; then
        return 0
    fi
    for selected in $selected_scripts; do
        if [ "$selected" = "$script_name" ]; then
            return 0
        fi
    done
    return 1
}

if should_run "accept-ips"; then
    echo "accept-ips"
    BENCHMARK_INPUT_FILE="$input_dir/ips_$size.txt"
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/accept-ips.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/accept-ips.sh $input_dir/ips_$size.txt $outputs_dir/accept-ips_$size.txt
    echo $?
fi

if should_run "block-country-ips"; then
    echo "block-country-ips"
    BENCHMARK_INPUT_FILE="$input_dir/ips_$size.txt"
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/block-country-ips.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/block-country-ips.sh $input_dir/ips_$size.txt $outputs_dir/block-country-ips_$size.txt block dummy
    echo $?
fi

if should_run "get-ip"; then
    echo "get-ip"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/get-ip.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/get-ip.sh $outputs_dir/get-ip.txt
    echo $?
fi

if should_run "massvulscan"; then
    echo "massvulscan"
    BENCHMARK_INPUT_FILE="$input_dir/gateway_target.txt"
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/massvulscan.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/massvulscan.sh -a -f $input_dir/gateway_target.txt >  $outputs_dir/massvulscan_output.txt 2>&1
    echo $?
fi

if should_run "networkconf"; then
    echo "networkconf"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/networkconf.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/networkconf.sh $outputs_dir/networkconf.txt
    echo $?
fi

if should_run "onetwopunch"; then
    echo "onetwopunch"
    BENCH_IFACE=$(ip route get 10.200.1.1 | grep dev | awk '{print $3}')
    
    export BENCHMARK_INPUT_FILE="$input_dir/gateway_target.txt"
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/onetwopunch.sh")"
    export BENCHMARK_SCRIPT

    $KOALA_SHELL $scripts_dir/onetwopunch.sh -t "$input_dir/gateway_target.txt" -i "$BENCH_IFACE" -p all -o "$outputs_dir/onetwopunch"
    echo $?
fi

if should_run "pingsweep"; then
    echo "pingsweep"
    export BENCHMARK_INPUT_FILE="$input_dir/gateway_target.txt"
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/pingsweep.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/pingsweep.sh 127.0.0 $outputs_dir/pingsweep.txt
    echo $?
fi
