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
        accept_ips_status=1
    fi

    if [ $accept_ips_status -eq 0 ] && ! grep -q "DROP.*tcp dpt:22" "$accept_ips_out"; then
        accept_ips_status=1
    fi

    if [ $accept_ips_status -eq 0 ] && [ -f "$accept_ips_in" ]; then
        while read -r ip || [ -n "$ip" ]; do
            case "$ip" in
                ""|\#*) continue ;;
                *)
                    if ! grep -Fq "$ip" "$accept_ips_out"; then
                        accept_ips_status=1
                        break
                    fi
                    ;;
            esac
        done < "$accept_ips_in"
    fi

    report "accept-ips" $accept_ips_status
fi

if should_run "block-country-ips"; then
    bci_out="$outputs_dir/block-country-ips_$size.txt"
    bci_in="$input_dir/ips_$size.txt"
    bci_status=0

    if [ ! -s "$bci_out" ]; then
        bci_status=1
    fi
    # Verify critical stages in output
    if [ $bci_status -eq 0 ]; then
        if ! grep -q "--- IPSet Created" "$bci_out" || \
           ! grep -q "--- IPTables Rule Applied" "$bci_out" || \
           ! grep -q "IPs blocked successfully" "$bci_out"; then
            bci_status=1
        fi
    fi
    # Verify IPTables rule content
    if [ $bci_status -eq 0 ]; then
        if ! grep -q "match-set dummy src DROP" "$bci_out"; then
            bci_status=1
        fi
    fi
    # Verify IPs were actually added to the IPSet
    if [ $bci_status -eq 0 ] && [ -f "$bci_in" ]; then
        while read -r ip || [ -n "$ip" ]; do
            case "$ip" in
                ""|\#*) continue ;;
                *)
                    if ! grep -Fq "$ip" "$bci_out"; then
                        bci_status=1
                        break
                    fi
                    ;;
            esac
        done < "$bci_in"
    fi

    report "block-country-ips" $bci_status
fi

if should_run "get-ip"; then
    get_ip_out="$outputs_dir/get-ip.txt"
    get_ip_status=0

    if [ ! -s "$get_ip_out" ]; then
        get_ip_status=1
    fi

    if [ $get_ip_status -eq 0 ]; then
        if ! grep -q "Active Interface:" "$get_ip_out" || \
           ! grep -q "Current IPv4:" "$get_ip_out"; then
            get_ip_status=1
        fi
    fi

    if [ $get_ip_status -eq 0 ]; then
        if ! grep -q "10.200.1.2" "$get_ip_out"; then
            get_ip_status=1
        fi
    fi

    report "get-ip" $get_ip_status
fi

if should_run "massvulscan"; then
    mv_status=1
    
    found_reports=$(find "$outputs_dir" -type f -name "gateway_target.txt_*" 2>/dev/null)
    
    if [ -n "$found_reports" ]; then
        for f in $found_reports; do
            # If we find at least one non-empty report file: success
            if [ -s "$f" ]; then
                mv_status=0
                
                # specific check: if it's an HTML report, it should contain Nmap structure
                if echo "$f" | grep -q ".html$"; then
                    if ! grep -q "<nmaprun" "$f"; then
                        mv_status=1
                    fi
                fi
                break
            fi
        done
    fi

    report "massvulscan" $mv_status
fi

if should_run "networkconf"; then
    netconf_out="$outputs_dir/networkconf.txt"
    netconf_status=0

    if [ ! -s "$netconf_out" ]; then
        netconf_status=1
    fi

    if [ $netconf_status -eq 0 ]; then
        if ! grep -q "Network Interfaces" "$netconf_out" || \
           ! grep -q "Kernel Routing Table" "$netconf_out" || \
           ! grep -q "DNS Client" "$netconf_out"; then
            netconf_status=1
        fi
    fi

    # The script runs 'ip addr show', so it must list the veth IP 10.200.1.2
    if [ $netconf_status -eq 0 ]; then
        if ! grep -q "10.200.1.2" "$netconf_out"; then
            netconf_status=1
        fi
    fi

    report "networkconf" $netconf_status
fi

if should_run "onetwopunch"; then
    otp_dir="$outputs_dir/onetwopunch"
    otp_status=0

    if [ ! -d "$otp_dir/udir" ] || [ ! -d "$otp_dir/ndir" ]; then
        otp_status=1
    fi

    # Check for Unicornscan artifacts
    # The script creates files named [IP]-tcp.txt inside udir
    # We expect 10.200.1.1 to be scanned.
    if [ $otp_status -eq 0 ]; then
        if [ ! -s "$otp_dir/udir/10.200.1.1-tcp.txt" ] && \
           [ ! -s "$otp_dir/udir/10.200.1.1-udp.txt" ]; then
            otp_status=1
        fi
    fi
    
    report "onetwopunch" $otp_status
fi

if should_run "pingsweep"; then
    ps_out="$outputs_dir/pingsweep.txt"
    ps_status=0

    if [ ! -s "$ps_out" ]; then
        ps_status=1
    fi

    if [ $ps_status -eq 0 ]; then
        if ! grep -q "is UP" "$ps_out"; then
            ps_status=1
        fi
    fi
    
    if [ $ps_status -eq 0 ]; then
        if ! grep -q "10.200.1.1 is UP" "$ps_out"; then
            # Optional: fail if gateway wasn't found (strict validation)
            ps_status=1
        fi
    fi

    report "pingsweep" $ps_status
fi

if should_run "ssh-ips"; then
    ssh_out="$outputs_dir/ssh-ips_$size.txt"
    ssh_status=0

    if [ ! -f "$ssh_out" ]; then
        ssh_status=1
    fi

    if [ $ssh_status -eq 0 ]; then
        if grep -qE "Connection refused|Permission denied|Could not resolve hostname|Host key verification failed" "$ssh_out"; then
            ssh_status=1
        fi
    fi
    
    report "ssh-ips" $ssh_status
fi

echo "networking $ANY_FAIL"
exit $ANY_FAIL