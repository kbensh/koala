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

if should_run "block-country-ips"; then
    bci_out="$outputs_dir/block-country-ips_$size.txt"
    bci_in="$input_dir/ips_$size.txt"
    bci_status=0

    if [ ! -s "$bci_out" ]; then
        echo "ERROR [block-country-ips]: Output file '$bci_out' is missing or empty" >&2
        bci_status=1
    fi
    
    if [ $bci_status -eq 0 ]; then
        for marker in "--- IPSet Created" "--- IPTables Rule Applied" "IPs blocked successfully"; do
            if ! grep -Fq -- "$marker" "$bci_out"; then
                echo "ERROR [block-country-ips]: Missing '$marker' marker in output" >&2
                bci_status=1
                break
            fi
        done
    fi
    
    if [ $bci_status -eq 0 ]; then
        if ! grep -Fq -- "match-set dummy src" "$bci_out"; then
            echo "ERROR [block-country-ips]: Missing expected iptables rule 'match-set dummy src DROP'" >&2
            bci_status=1
        fi
    fi
    
    if [ $bci_status -eq 0 ] && [ -f "$bci_in" ]; then
        clean_input=$(mktemp)
        grep -vE '^\s*#|^\s*$' "$bci_in" > "$clean_input"
        missing_ips=$(grep -Fvwf "$bci_out" "$clean_input")
        
        if [ -n "$missing_ips" ]; then
            missing_count=$(echo "$missing_ips" | wc -l)
            first_missing=$(echo "$missing_ips" | head -n 1)
            
            echo "ERROR [block-country-ips]: IP '$first_missing' (and $missing_count total) not found in output" >&2
            bci_status=1
        fi
        rm -f "$clean_input"
    fi
    
    report "block-country-ips" $bci_status
fi

if should_run "get-ip"; then
    get_ip_out="$outputs_dir/get-ip.txt"
    get_ip_status=0

    if [ ! -s "$get_ip_out" ]; then
        echo "ERROR [get-ip]: Output file '$get_ip_out' is missing or empty" >&2
        get_ip_status=1
    fi

    if [ $get_ip_status -eq 0 ]; then
        if ! grep -q "Active Interface:" "$get_ip_out"; then
            echo "ERROR [get-ip]: Missing 'Active Interface:' in output" >&2
            get_ip_status=1
        elif ! grep -q "Current IPv4:" "$get_ip_out"; then
            echo "ERROR [get-ip]: Missing 'Current IPv4:' in output" >&2
            get_ip_status=1
        fi
    fi

    if [ $get_ip_status -eq 0 ]; then
        if ! grep -q "10.200.1.2" "$get_ip_out"; then
            echo "ERROR [get-ip]: Expected IP '10.200.1.2' not found in output" >&2
            get_ip_status=1
        fi
    fi

    report "get-ip" $get_ip_status
fi

if should_run "massvulscan"; then
    mvs_out="$outputs_dir/massvulscan_output.txt"
    mvs_status=0
    
    if [ ! -s "$mvs_out" ]; then
        echo "ERROR [massvulscan]: Log file '$mvs_out' is missing or empty" >&2
        mvs_status=1
    fi

    if [ $mvs_status -eq 0 ]; then
        if grep -Fq "End of script execution." "$mvs_out"; then
            : # Success
        elif grep -Fq "No ip with open TCP/UDP ports found" "$mvs_out"; then
            echo "INFO [massvulscan]: Script finished successfully but found no open ports."
        else
            echo "ERROR [massvulscan]: Script did not finish cleanly (Missing completion message)" >&2
            mvs_status=1
        fi
    fi

    if [ $mvs_status -eq 0 ]; then
        txt_report=$(grep "The report is available here:" "$mvs_out" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $NF}' | tail -n 1)
        
        if [ -n "$txt_report" ]; then
            if [ ! -s "$txt_report" ]; then
                echo "ERROR [massvulscan]: Reported text output '$txt_report' is missing or empty" >&2
                mvs_status=1
            fi
        fi
        vuln_report=$(grep "All details on the vulnerabilities:" "$mvs_out" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $NF}' | tail -n 1)
        
        if [ -n "$vuln_report" ]; then
            if [ ! -s "$vuln_report" ]; then
                 echo "ERROR [massvulscan]: Vulnerability detail report '$vuln_report' is missing" >&2
                 mvs_status=1
            fi
        fi
    fi

    report "massvulscan" $mvs_status
fi

if should_run "networkconf"; then
    netconf_out="$outputs_dir/networkconf.txt"
    netconf_status=0

    if [ ! -s "$netconf_out" ]; then
        echo "ERROR [networkconf]: Output file '$netconf_out' is missing or empty" >&2
        netconf_status=1
    fi

    if [ $netconf_status -eq 0 ]; then
        if ! grep -q "Network Interfaces" "$netconf_out"; then
            echo "ERROR [networkconf]: Missing 'Network Interfaces' section in output" >&2
            netconf_status=1
        elif ! grep -q "Kernel Routing Table" "$netconf_out"; then
            echo "ERROR [networkconf]: Missing 'Kernel Routing Table' section in output" >&2
            netconf_status=1
        elif ! grep -q "DNS Client" "$netconf_out"; then
            echo "ERROR [networkconf]: Missing 'DNS Client' section in output" >&2
            netconf_status=1
        fi
    fi

    if [ $netconf_status -eq 0 ]; then
        if ! grep -q "10.200.1.2" "$netconf_out"; then
            echo "ERROR [networkconf]: Expected IP '10.200.1.2' not found in output" >&2
            netconf_status=1
        fi
    fi

    report "networkconf" $netconf_status
fi

if should_run "onetwopunch"; then
    otp_dir="$outputs_dir/onetwopunch"
    otp_status=0

    if [ ! -d "$otp_dir/udir" ]; then
        echo "ERROR [onetwopunch]: Unicornscan directory '$otp_dir/udir' not found" >&2
        otp_status=1
    fi
    
    if [ ! -d "$otp_dir/ndir" ]; then
        echo "ERROR [onetwopunch]: Nmap directory '$otp_dir/ndir' not found" >&2
        otp_status=1
    fi

    if [ $otp_status -eq 0 ]; then
        if [ ! -s "$otp_dir/udir/10.200.1.1-tcp.txt" ] && \
           [ ! -s "$otp_dir/udir/10.200.1.1-udp.txt" ]; then
            echo "ERROR [onetwopunch]: No scan results found for gateway 10.200.1.1 (checked tcp and udp)" >&2
            if [ -d "$otp_dir/udir" ]; then
                found_files=$(ls -la "$otp_dir/udir/" 2>&1)
                echo "DEBUG [onetwopunch]: Contents of udir: $found_files" >&2
            fi
            otp_status=1
        fi
    fi
    
    report "onetwopunch" $otp_status
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

if should_run "ssh-ips"; then
    ssh_out="$outputs_dir/ssh-ips_$size.txt"
    ssh_status=0

    if [ ! -f "$ssh_out" ]; then
        echo "ERROR [ssh-ips]: Output file '$ssh_out' not found" >&2
        ssh_status=1
    fi

    if [ $ssh_status -eq 0 ]; then
        error_patterns="Connection refused|Permission denied|Could not resolve hostname|Host key verification failed"
        if grep -qE "$error_patterns" "$ssh_out"; then
            echo "ERROR [ssh-ips]: Found error patterns in output:" >&2
            grep -E "$error_patterns" "$ssh_out" | head -5 >&2
            ssh_status=1
        fi
    fi
    
    report "ssh-ips" $ssh_status
fi

echo "networking $ANY_FAIL"
exit $ANY_FAIL