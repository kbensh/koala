#!/bin/sh


SCRIPT_PATH="$(realpath "$0")"

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

NETNS_NAME="koala_bench_$$"
VETH_HOST="v_hs_$$"
VETH_NS="v_ns_$$"

cleanup_namespace() {
    # Only cleanup if we actually created it or if it exists
    if $SUDO ip netns list | grep -q "$NETNS_NAME"; then
        echo ""
        echo "Cleaning up network namespace..."
        
        PIDS=$($SUDO ip netns pids "$NETNS_NAME")
        if [ -n "$PIDS" ]; then
            echo "Killing lingering processes in namespace ($NETNS_NAME): $PIDS"
            $SUDO kill -9 $PIDS 2>/dev/null || true
            sleep 0.5
        fi

        $SUDO iptables -t nat -D POSTROUTING -s 10.200.1.0/24 ! -d 10.200.1.0/24 -j MASQUERADE 2>/dev/null || true
        
        # Delete namespace first (this usually destroys the veth pair automatically)
        $SUDO ip netns delete "$NETNS_NAME" 2>/dev/null || true
        
        # Check if host veth still lingers and delete it if so
        if $SUDO ip link show "$VETH_HOST" > /dev/null 2>&1; then
            $SUDO ip link delete "$VETH_HOST" 2>/dev/null || true
        fi
        
        echo "Namespace cleaned up"
    fi
}

NAMESPACE_CREATED=false

trap 'cleanup_namespace' EXIT INT TERM

setup_namespace() {
    echo "Setting up network namespace: $NETNS_NAME"

    # Create network namespace
    $SUDO ip netns add "$NETNS_NAME" || {
        echo "Error: Failed to create network namespace" >&2
        return 1
    }

    # Set up loopback (wait briefly for it to be ready)
    $SUDO ip netns exec "$NETNS_NAME" ip link set lo up
    
    # Create veth pair
    $SUDO ip link add "$VETH_HOST" type veth peer name "$VETH_NS"
    $SUDO ip link set "$VETH_NS" netns "$NETNS_NAME"

    # Configure host side
    $SUDO ip addr add 10.200.1.1/24 dev "$VETH_HOST"
    $SUDO ip link set "$VETH_HOST" up

    # Configure namespace side
    $SUDO ip netns exec "$NETNS_NAME" ip addr add 10.200.1.2/24 dev "$VETH_NS"
    $SUDO ip netns exec "$NETNS_NAME" ip link set "$VETH_NS" up

    sleep 0.5

    $SUDO ip netns exec "$NETNS_NAME" ip route add default via 10.200.1.1

    # Enable forwarding on host
    $SUDO bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward' 2>/dev/null || true
    $SUDO iptables -t nat -A POSTROUTING -s 10.200.1.0/24 ! -d 10.200.1.0/24 -j MASQUERADE
    NAMESPACE_CREATED=true
}

git config --global --add safe.directory "*" 2>/dev/null

TOP=$(git rev-parse --show-toplevel)

eval_dir="${TOP}/net"
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

export BENCHMARK_CATEGORY="net"
KOALA_SHELL=${KOALA_SHELL:-bash}

should_run() {
    script_name=$1
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

if should_run "portscan"; then
    echo "portscan (Running on Host)"
    
    export BENCHMARK_INPUT_FILE="$input_dir/localhost.txt"
    export BENCHMARK_SCRIPT="$(realpath "$scripts_dir/portscan.sh")"
    
    # Open persistent listeners on ports 4444, 5555, and 6666
    for port in 4444 5555 6666; do
        while true; do nc -l -p $port < /dev/null > /dev/null 2>&1; done &
    done
    
    OUT=$outputs_dir $SUDO $KOALA_SHELL $scripts_dir/portscan.sh -f $BENCHMARK_INPUT_FILE
    exit_code=$?
    
    # Clean up background listeners
    pkill -f "nc -l -p 4444" 2>/dev/null
    pkill -f "nc -l -p 5555" 2>/dev/null
    pkill -f "nc -l -p 6666" 2>/dev/null
    
    if [ -f "$outputs_dir/portscan.txt" ]; then
        $SUDO chown $(id -u):$(id -g) "$outputs_dir/portscan.txt"
    fi

    echo $exit_code
fi

if should_run "ping"; then
    echo "ping (Running on Host)"
    export BENCHMARK_INPUT_FILE="$input_dir/ping_$size.txt"
    export BENCHMARK_SCRIPT="$(realpath "$scripts_dir/ping.sh")"
    $KOALA_SHELL "$scripts_dir/ping.sh" 127.0.0 "$input_dir/ping_$size.txt" "$outputs_dir/ping_$size.txt"
    echo $?
fi

if should_run "accept-ips"; then
    echo "accept-ips (Running inside Namespace)"
    
    # Setup the namespace specifically for this test
    setup_namespace
    
    if $SUDO ip netns exec "$NETNS_NAME" true 2>/dev/null; then
        export BENCHMARK_INPUT_FILE="$input_dir/ips_$size.txt"
        export BENCHMARK_SCRIPT="$(realpath "$scripts_dir/accept-ips.sh")"

        # Execute script inside the namespace
        $SUDO ip netns exec "$NETNS_NAME" env \
            BENCHMARK_INPUT_FILE="$BENCHMARK_INPUT_FILE" \
            BENCHMARK_SCRIPT="$BENCHMARK_SCRIPT" \
            KOALA_SHELL="$KOALA_SHELL" \
            LC_ALL=C \
            $KOALA_SHELL "$scripts_dir/accept-ips.sh" "$input_dir/ips_$size.txt" "$outputs_dir/accept-ips_$size.txt"

        echo $?
    else
        echo "Error: cannot execute inside network namespace '$NETNS_NAME'." >&2
        echo "       accept-ips needs CAP_NET_ADMIN and CAP_SYS_ADMIN: run as root," >&2
        echo "       or in a rootful container (e.g. 'sudo podman run --privileged')." >&2
        echo "       Rootless containers cannot mount sysfs in a new netns." >&2
        echo 1
    fi
    
    cleanup_namespace
fi