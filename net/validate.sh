#!/bin/bash

TOP=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD/..")
eval_dir="${TOP}/networking"
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

if should_run "massvulscan"; then
    mvs_out="$outputs_dir/massvulscan_output.txt"
    mvs_status=0
    
    if grep -qE "Root required|Conflict:|Empty input|No targets|Invalid DNS|No live hosts" "$mvs_out"; then
        mvs_status=1
    fi

    if grep -qE "command not found|Permission denied" "$mvs_out"; then
        mvs_status=1
    fi

    report "massvulscan" $mvs_status
fi

if should_run "pingsweep"; then
    ps_out="$outputs_dir/pingsweep.txt"
    ps_status=0
    if [ ! -s "$ps_out" ]; then
        echo "ERROR [pingsweep]: Output file '$ps_out' is missing or empty" >&2
        ps_status=1
    fi
    if [ $ps_status -eq 0 ]; then
        if ! grep -q "is UP" "$ps_out"; then
            echo "ERROR [pingsweep]: No 'is UP' markers found in output (no hosts detected)" >&2
            ps_status=1
        fi
    fi
    
    if [ $ps_status -eq 0 ]; then
        # Check for localhost instead of gateway
        if ! grep -q "127.0.0.1 is UP" "$ps_out"; then
            echo "ERROR [pingsweep]: Localhost 127.0.0.1 not detected as UP" >&2
            echo "DEBUG [pingsweep]: Checking what hosts were found..." >&2
            grep "is UP" "$ps_out" >&2 || echo "DEBUG [pingsweep]: No UP hosts in output" >&2
            ps_status=1
        fi
    fi
    report "pingsweep" $ps_status
fi
