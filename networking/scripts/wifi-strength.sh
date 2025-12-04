#!/bin/sh
# https://github.com/wfahren/wifi-strength/blob/master/wifi-strength.sh
# File name: wifi-strength.sh
# Description: This script scans for "masters" and displays wifi signal strength
# with a text-based bar graph.
#
# The SSID and signal strength are from iw output, others are
# calculated like Quality and GOOD/BAD signal.
#
# As normal user:
#  sudo sh wifi-strength.sh -h
#  iw scan command requires root access

# Set Defaults
strength_str='#'                # default pound sign
bar_len='50'                    # default 50
bar_fill_char=' '               # default space
num_lines=''                    # number of lines to display
scan=1                          # scan for AP's
passive=1                       # scan type, default active scan
scan_interval='5'               # scan interval, default 5 seconds
max_scans=${max_scans:-100}     # maximum number of scans before exit

# Must provide the network interface, wlan0 for example
if [ $# -lt 1 ]; then
    printf "\n Usage: \"%s [options] [interface]\"\n -- for example;\n" "$(basename -- "$0")"
    printf "\t%s wlan1\t# scan wlan1\n" "$(basename -- "$0")"
    printf "\t%s -h\t# for help\n" "$(basename -- "$0")"
    printf "\n Interfaces found:\n"
    iw dev 2>/dev/null | grep "Interface" | awk '{print $2}'
    exit
fi

# Parse command line options and ignore invalid.
parse_options() {
    while [ $# -gt 1 ]; do
        key="$1"
        case "$key" in
        -h)
            usage_txt
            ;;
        -m)
            scan=0
            shift
            ;;
        -n)
            num_lines="$2"
            shift 2
            ;;
        -i)
            scan_interval="$2"
            shift 2
            ;;
        -l)
            if printf "%s" "$2" | grep -E '^[1-9][0-9]?$|^100$' >/dev/null 2>&1; then 
                bar_len="$2"
            fi
            shift 2
            ;;
        -a)
            passive=0
            shift
            ;;
        -f)
            filter="$2"
            shift 2
            ;;
        -s)
            max_scans="$2"
            shift 2
            ;;
        *)
            printf "\n\nInvalid option: %s\n\n" "$key"
            usage_txt
            ;;
        esac
    done
    net="${1:-}"
}

# Help text
usage_txt() {
    script=$(basename -- "$0")
    printf "\nUsage: %s [options] <interface>\n\n" "$script"
    printf "<interface>  The interface to monitor.\n\n"
    printf "[options]\n"
    printf "  -m\tMonitor link signal strength.\n"
    printf "  -n\tDisplay x number of lines\n"
    printf "  -i\tSet scan interval, default 5 seconds\n"
    printf "  -l\tLength of strength bar, range 1-100, Default 50\n"
    printf "  -a\tActive scan, default passive scan. (Active scan sends Beacon's)\n"
    printf "  -f\tFilter results, use extended grep pattern. Example: -f 'Whispering|MESH'\n"
    printf "  -s\tMaximum number of scans before exit, default 100\n"
    printf "Example:\n"
    printf "  Scan for \"masters\" on interface wlan1;\n\n"
    printf "\t%s wlan1\n\n" "$script"
    printf "  Scan AP's on wlan1 set strength bar length to 10;\n\n"
    printf "\t%s -l 10 wlan1\n\n" "$script"
    printf "  Monitor client connection on interface wlan1\n\n"
    printf "\t%s -m wlan1\n\n" "$script"
    printf "  Run 50 scans then exit\n\n"
    printf "\t%s -s 50 wlan1\n\n" "$script"
    printf "Interfaces found:\n"
    iw dev 2>/dev/null | grep "Interface" | awk '{print $2}'
    printf "\n\n"
    exit
}

# Create $len length signal bar from percentage of $quality.
get_strength_bar() {
    char=$1
    fill_char=$bar_fill_char
    num=$2
    len=$3
    # Calculate number of char(s) for strength part of bar
    num_char=$(awk "BEGIN {printf \"%.0f\", $num/100*$len}")
    # Calculate number of char(s) to fill the remaining part of the bar.
    num_fill=$(expr "$len" - "$num_char")
    v=$(printf "%${num_char}s" "")
    s=$(printf "%${num_fill}s" "")
    # Combine strength and fill char(s) to assign $strength
    strength=${v## }
    strength=$(printf "%s" "$strength" | sed "s/ /$char/g")
    fill_part=${s## }
    fill_part=$(printf "%s" "$fill_part" | sed "s/ /$fill_char/g")
    strength="${strength}${fill_part}"
}

# Clean string by removing carriage returns and leading/trailing spaces
clean_string() {
    string="$1"
    printf "%s" "$string" | tr -d '\r\n' | sed 's/^[ \t]*//'
}

# Function to parse options from scan data
check_complete() {
    # If no SSID or Mesh ID but other fields are set, assume hidden and finalize
    if [ -n "$data_bssid" ] && [ -n "$data_freq" ] && [ -n "$data_signal" ] && [ -n "$data_ssid" ]; then
        printf "%s,%s,%s,%s\n" "$data_signal" "$data_freq" "$data_bssid" "$data_ssid" >>/tmp/results.$$
        # Reset variables
        data_freq=""
        data_signal=""
        data_ssid=""
        # If new BSSID is set, set it to the current BSSID
        if [ -n "$new_bssid" ]; then
            data_bssid="$new_bssid"
            new_bssid=""
        else
            data_bssid=""
        fi
    fi

}
# Function to parse options from scan data
parse_scan() {
    data_freq=""
    data_signal=""
    data_ssid=""
    data_bssid=""
    n=1

    # Read each line from the input (scan data)
    while IFS= read line; do
        # Clean the line
        line=$(clean_string "$line")

        # Skip empty lines
        [ -z "$line" ] && continue

        # Parse based on key. BSSI, freq, signal are mandatory keys.
        if [ -z "$data_bssid" ]; then
            printf "%s" "$line" | grep '^BSS' >/dev/null 2>&1 && data_bssid=$(printf "%s" "$line" | grep -oE '[0-9a-fA-F:]{17}')
            [ -n "$data_bssid" ] && continue
        fi

        if [ -z "$data_freq" ]; then
            printf "%s" "$line" | grep '^freq:' >/dev/null 2>&1 && data_freq=$(printf "%s" "$line" | awk '{print int($2)}')
            [ -n "$data_freq" ] && continue
        fi

        if [ -z "$data_signal" ]; then
            printf "%s" "$line" | grep '^signal:' >/dev/null 2>&1 && data_signal=$(printf "%s" "$line" | awk '{print int($2)}')
            [ -n "$data_signal" ] && continue
        fi

        # After the three mandatory keys have been parsed,
        # Check the line to see if a new station, if so we save.
        if printf "%s" "$line" | grep '^BSS' >/dev/null 2>&1 && check_bssid=$(printf "%s" "$line" | grep -oE '[0-9a-fA-F:]{17}'); then
            new_bssid="$check_bssid"
        fi
        # Now we need to set the SSID
        # If the line contains "SSID:" or "MESH ID:" then set the SSID to that.
        if printf "%s" "$line" | grep 'MESH ID:' >/dev/null 2>&1; then
            data_ssid=$(printf "%s" "$line" | awk '{print "MESH ID: " $3}')
            check_complete
        elif printf "%s" "$line" | grep '^SSID:' >/dev/null 2>&1; then
            data_ssid=$(printf "%s" "$line" | cut -d' ' -f2-)
            check_complete
        # Default to hidden if no SSID or MESH ID is found.
        else
            data_ssid="<hidden>"
            check_complete
        fi
    done

    # Sort results by signal strength in descending order (numeric, reverse)
    if [ -s /tmp/results.$$ ]; then
        # Filter results if filter is set
        if [ -n "$filter" ]; then
            filtered_results=$(grep -Ei "$filter" /tmp/results.$$)
            [ -n "$filtered_results" ] && printf "%s" "$filtered_results" >/tmp/results.$$
        fi
        # Sort results
        sorted_results=$(sort -rn /tmp/results.$$ && printf "")
        rm -f /tmp/results.$$

        # Process and print sorted results
        printf "%s" "$sorted_results" | while IFS=',' read s f bs ss; do
            # Truncate SSID if longer than 30 characters
            ss_len=$(printf "%s" "$ss" | wc -c)
            if [ "$ss_len" -gt 30 ]; then
                ss=$(printf "%s" "$ss" | awk '{print substr($0,1,26)}')
            fi

            # Print the output if all fields are present
            if [ -n "$num_lines" ] && [ "$n" -gt "$num_lines" ]; then break; fi
            [ -n "$s" ] && [ -n "$f" ] && get_output "$s" "$ss" "$f" "$bs"
            n=$(expr "$n" + 1)
        done
    fi
}

# Header for monitor link.
get_header() {
    printf "Press ctrl-c to quit\n\n"
    iw dev "$net" link 2>/dev/null | awk 'FNR <= 3'
    header_width=$(expr "$bar_len" + 10)
    printf "\n%-${header_width}s|%8s |%8s | %-10s\n" "" "Signal" "Quality" "Bandwidth"
}

# Calculate quality and range from Strong to Bad. Format the output for display.
get_output() {
    rssi=$1
    ssid=$2
    freq=$3
    bssid=$4

    if [ -z "$rssi" ] || [ "$rssi" -ge 0 ]; then
        strength='No signal'
    elif [ "$rssi" -ge -65 ]; then
        link='Strong'
    elif [ "$rssi" -ge -73 ]; then
        link='Good'
    elif [ "$rssi" -ge -80 ]; then
        link='Fair'
    elif [ "$rssi" -ge -94 ]; then
        link='Weak'
    else
        link='Bad'
    fi

    if [ "$rssi" -lt -110 ]; then
        signal='-110'
    elif [ "$rssi" -gt -40 ]; then
        signal='-40'
    else
        signal=$rssi
    fi

    if [ "$rssi" = 0 ]; then
        link=''
        bw=''
        quality=''
    else
        quality=$(expr \( "$signal" + 110 \) \* 10 / 7) # Quality as percentage max -40 min -110
        get_strength_bar "$strength_str" "$quality" "$bar_len"
    fi

    if [ "$scan" = 0 ]; then
        bw=$(iw "$net" link 2>/dev/null | grep "tx bitrate:" | awk '{print $3,$4}')
        printf "[%-${bar_len}s] %6s |%8s |%7s%% | %-15s\r" "$strength" "$link" "$rssi" "$quality" "$bw"
    else
        printf "[%-${bar_len}s] %6s |%5s |%7s%% |%10s | %s | %-15s\n" "$strength" "$link" "$rssi" "$quality" "$freq" "$bssid" "$ssid"
    fi
}

# Main
if [ $# = 1 ] && [ ! "$1" = "-h" ]; then
    net=$1
elif [ "$1" = "-h" ]; then
    usage_txt
else
    parse_options "$@"
fi

# Check that interface is valid
if ! iw dev 2>/dev/null | grep "Interface $net" >/dev/null 2>&1; then
    printf "\n\tInterface %s not found\n\n" "$net"
    exit
fi

# Initialize scan counter
scan_count=0

# Loop until max_scans reached or ctrl-C
while [ "$scan_count" -lt "$max_scans" ]; do
    if [ "$scan" = 1 ]; then

        printf "\nScan %d/%d\n" "$((scan_count + 1))" "$max_scans"
        printf "Scanning on %s\n" "$net"

        if [ $passive -eq 1 ]; then
            # If passive scan is set, passive (don't send Beacon's) scan for AP's
            printf "Passive scan\n"
            scan_data=$(iw dev "$net" scan passive 2>/dev/null && printf "\nExitCode: %03d\n" $? || printf "\nExitCode: %03d\n" $?)
        else
            # If passive scan is not set, active scan for AP's
            printf "Active scan\n"
            scan_data=$(iw dev "$net" scan 2>/dev/null && printf "\nExitCode: %03d\n" $? || printf "\nExitCode: %03d\n" $?)
        fi

        # The "$scan_interval" # allows time for scan to complete and we don't want to overload the interface
        # never should be less than 5 seconds.
        sleep "$scan_interval"

        # Get the exit code for the scan data, it will be on the last line
        exit_code=$(printf "%s" "$scan_data" | tail -n 1 | awk '{print $2}')
        printf "\n\nExit code:   %s\n\n" "$exit_code"
        # If the exit code is 0, the scan data returned with no errors
        if [ "$exit_code" -eq "0" ]; then
            scan_data=$(printf "%s" "$scan_data" | grep -E '^BSS|freq:|signal:|SSID:|MESH ID')
        # If the exit code is 255, the user must be root to run the script
        elif [ "$exit_code" -eq "255" ]; then
            scan_data=$(printf "%s" "$scan_data" | grep -v "ExitCode")
            printf "\n\n\tMust be root to run\n"
            printf "\tEither change to user root or use sudo\n\n"
            break
            # If the exit code is 237, the wireless interface not found
        elif [ "$exit_code" -eq "237" ]; then
            scan_data=$(printf "%s" "$scan_data" | grep -v "ExitCode")
            printf "\n\tInterface device %s not up.\n\n" "$net"
            break
            # If the exit code is 1, the iw command returned an error
        elif [ "$exit_code" -eq "1" ]; then
            scan_data=$(printf "%s" "$scan_data" | grep -v "ExitCode")
            printf "\n\n\tiw command failed, or error returned from the iw command\n\n"
            break
        else
            # If the exit code is not 0, 255, or 1, the wireless interface is busy
            scan_data=$(printf "%s" "$scan_data" | grep -v "ExitCode")
            printf "\n\n\tWireless interface busy trying again in 5 seconds\n\n"
            sleep 5
            continue
        fi
        clear
        # printf "\n\n%s\n\n" "$exit_code"
        header_width=$(expr "$bar_len" + 9)
        printf "\n%${header_width}s |%5s |%8s |%10s | %-17s | %-10s\n" "Signal" "dBm" "Quality" "Frequency" "BSSID" "SSID"
        # Parse the scan data
        printf "%s" "$scan_data" | parse_scan
        
        # Increment scan counter
        scan_count=$((scan_count + 1))
    else
        rssi=$(iw dev "$net" link | grep signal || printf "%s" $?)
        if [ "$rssi" != "1" ]; then
            clear
            get_header
            get_output "$(printf "%s" "$rssi" | awk '{print $2}')"
            sleep 2
            
            # Increment scan counter
            scan_count=$((scan_count + 1))
        else
            printf "\n\Interface device %s not connected.\n" "$net"
            break
        fi
    fi
done

printf "\n\nCompleted %d scans. Exiting.\n" "$scan_count"
exit