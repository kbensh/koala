#!/bin/sh


TOP=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD/..")
eval_dir="${TOP}/net"
input_dir="${eval_dir}/inputs"
scripts_dir="${eval_dir}/scripts"
outputs_dir="${eval_dir}/outputs"

size=full
selected_scripts=""

while [ $# -gt 0 ]; do
    case "$1" in
        --small) size=small; shift ;;
        --min)   size=min; shift ;;
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
        *) shift ;;
    esac
done

ANY_FAIL=0

should_run() {
    script_name=$1
    if [ -z "$selected_scripts" ]; then return 0; fi
    for selected in $selected_scripts; do
        if [ "$selected" = "$script_name" ]; then return 0; fi
    done
    return 1
}

# main.sh reads "<name> <0|1>" from stdout to decide pass/fail, and treats a
# non-zero exit as "could not verify at all" -- so always exit 0 from here.
report() {
    name=$1
    status=$2
    
    if [ "$status" -eq 0 ]; then
        echo "$name 0"
    else
        echo "$name 1"
        ANY_FAIL=1
    fi
}

if should_run "portscan"; then
    portscan_out="$outputs_dir/portscan.txt"
    portscan_status=0

    if [ ! -s "$portscan_out" ]; then
        echo "ERROR [portscan]: Output file '$portscan_out' is missing or empty" >&2
        portscan_status=1
    fi

    if [ $portscan_status -eq 0 ] &&
       grep -qE "command not found|Permission denied|DIAGNOSTIC INFO" "$portscan_out"; then
        echo "ERROR [portscan]: Scan reported an error or discovered no open ports" >&2
        portscan_status=1
    fi

    # execute.sh holds listeners open on 4444/5555/6666 for the duration of the
    # scan, so a working scan of 127.0.0.1 must report all three as open.
    if [ $portscan_status -eq 0 ]; then
        for port in 4444 5555 6666; do
            if ! grep -qE "^${port}/tcp[[:space:]]+open" "$portscan_out"; then
                echo "ERROR [portscan]: Expected open port $port not found in report" >&2
                portscan_status=1
                break
            fi
        done
    fi

    report "portscan" $portscan_status
fi

if should_run "ping"; then
    ping_out="$outputs_dir/ping_$size.txt"
    ping_in="$input_dir/ping_$size.txt"
    ping_status=0

    if [ ! -s "$ping_out" ]; then
        echo "ERROR [ping]: Output file '$ping_out' is missing or empty" >&2
        ping_status=1
    fi

    if [ $ping_status -eq 0 ] && ! grep -q "is UP" "$ping_out"; then
        echo "ERROR [ping]: No 'is UP' markers found in output (no hosts detected)" >&2
        ping_status=1
    fi

    # execute.sh sweeps the 127.0.0 subnet, so loopback answers regardless of
    # what the host's external network can actually reach.
    if [ $ping_status -eq 0 ] && ! grep -q "127.0.0.1 is UP" "$ping_out"; then
        echo "ERROR [ping]: Localhost 127.0.0.1 not detected as UP" >&2
        echo "DEBUG [ping]: Checking what hosts were found..." >&2
        grep "is UP" "$ping_out" >&2 || echo "DEBUG [ping]: No UP hosts in output" >&2
        ping_status=1
    fi

    # Every IP in the input file must be classified UP or DOWN, on top of the
    # subnet sweep's own hits. Counted rather than matched per-IP to stay linear
    # in the input size.
    if [ $ping_status -eq 0 ] && [ -f "$ping_in" ]; then
        ping_expected=$(grep -cvE '^[[:space:]]*(#|$)' "$ping_in")
        ping_seen=$(grep -c "is UP\|is DOWN" "$ping_out")
        if [ "$ping_seen" -lt "$ping_expected" ]; then
            echo "ERROR [ping]: Only $ping_seen host results recorded for $ping_expected input IPs" >&2
            ping_status=1
        fi
    fi

    report "ping" $ping_status
fi

if should_run "accept-ips"; then
    accept_ips_out="$outputs_dir/accept-ips_$size.txt"
    accept_ips_in="$input_dir/ips_$size.txt"
    accept_ips_status=0
    
    if [ ! -s "$accept_ips_out" ]; then
        echo "ERROR [accept-ips]: Output file '$accept_ips_out' is missing or empty" >&2
        accept_ips_status=1
    fi

    if [ $accept_ips_status -eq 0 ] && ! grep -q "DROP.*tcp dpt:22" "$accept_ips_out"; then
        echo "ERROR [accept-ips]: Missing expected iptables DROP rule for tcp dpt:22" >&2
        accept_ips_status=1
    fi

    if [ $accept_ips_status -eq 0 ] && [ -f "$accept_ips_in" ]; then
        while read -r ip || [ -n "$ip" ]; do
            case "$ip" in
                ""|\#*) continue ;;
                *)
                    if ! grep -Fq "$ip" "$accept_ips_out"; then
                        echo "ERROR [accept-ips]: IP '$ip' from input file not found in output" >&2
                        accept_ips_status=1
                        break
                    fi
                    ;;
            esac
        done < "$accept_ips_in"
    fi

    report "accept-ips" $accept_ips_status
fi
