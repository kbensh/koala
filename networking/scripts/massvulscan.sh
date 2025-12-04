#!/bin/sh

# source: https://github.com/choupit0/MassVulScan/blob/master/MassVulScan.sh
version="3.0.0"

# We enter the directory of $0 and print the working directory
if [ -h "$0" ]; then
    # If $0 is a symlink, resolving it strictly in POSIX is complex without readlink -f.
    # We assume standard dirname usage here.
    script_dir=$(dirname "$0")
else 
    script_dir=$(dirname "$0")
fi
dir_name=$(cd "$script_dir" && pwd)

source_installation="$../sources/installation.sh"
source_top_tcp="$../sources/top-ports-tcp-1000.txt"
source_top_udp="$../sources/top-ports-udp-1000.txt"
report_folder="$../outputs/"

# ANSI Colors
blue_color="\033[0;36m"
red_color="\033[1;31m"
green_color="\033[0;32m"
purple_color="\033[1;35m"
bold_color="\033[1m"
end_color="\033[0m"

# SECONDS is a bashism. Use date for POSIX timing.
script_start=$(date +%s)
dns="1.1.1.1"
network_interface=""

##########################
# OS Detection Function  #
##########################
detect_os(){
    if [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "redhat"
    else
        echo "unknown"
    fi
}

##########################
# Checking prerequisites #
##########################
checking_prerequisites(){
    os_family=$(detect_os)
    missing_or_outdated_packages=""

    if [ "$os_family" = "debian" ]; then
        # Debian/Ubuntu packages
        # No arrays in POSIX, iterating over string list
        for package in iproute2 build-essential git curl wget gpg tar libpcre3-dev libssl-dev libpcap-dev net-tools xsltproc bind9-dnsutils netcat-traditional toilet boxes lolcat gum automake; do
            # Using grep quietly
            if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                missing_or_outdated_packages="$missing_or_outdated_packages $package"
            fi
        done
    elif [ "$os_family" = "redhat" ]; then
        # RedHat/Rocky packages
        for package in iproute gcc gcc-c++ make git curl wget tar pcre-devel openssl-devel libpcap-devel net-tools bind-utils nmap-ncat toilet boxes gum automake bzip2; do
            if ! rpm -q "$package" >/dev/null 2>&1; then
                missing_or_outdated_packages="$missing_or_outdated_packages $package"
            fi
        done
        for package in gpg xsltproc lolcat; do
            if ! command -v "$package" >/dev/null 2>&1; then
                missing_or_outdated_packages="$missing_or_outdated_packages $package"
            fi
        done
    else
        printf "${red_color}Unsupported OS. Only Debian or RedHat families are supported.${end_color}\n"
        exit 1
    fi

    # Masscan & Nmap check
    for package in masscan nmap; do
        if [ "$package" = "masscan" ] && ! command -v masscan >/dev/null 2>&1; then
            missing_or_outdated_packages="$missing_or_outdated_packages $package"
        elif [ "$package" = "nmap" ] && ! command -v nmap >/dev/null 2>&1; then
            missing_or_outdated_packages="$missing_or_outdated_packages $package"
        fi
    done

    # Version checks
    # Using grep -E instead of grep -P (non-standard) or grep with perl regex
    installed_masscan_version="$(masscan -V 2>/dev/null | grep "Masscan version" | grep -o '[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?')"
    installed_nmap_version="$(nmap -V 2>/dev/null | grep "Nmap version" | grep -o '[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?')"
    min_masscan_version_required="1.3.2"
    min_nmap_version_required="7.92"

    version_comparison(){
        # POSIX sh does not support <<< or arrays.
        # We use 'set' to parse positional parameters based on IFS
        
        # Save current IFS
        old_ifs="$IFS"
        
        # Parse Argument 1
        IFS='.'
        set -- $1
        a1=${1:-0}
        b1=${2:-0}
        c1=${3:-0}
        
        # Parse Argument 2
        set -- $2
        a2=${1:-0}
        b2=${2:-0}
        c2=${3:-0}
        
        # Restore IFS
        IFS="$old_ifs"

        # Comparison Logic
        if [ "$a1" -lt "$a2" ]; then echo "-1"; return; fi
        if [ "$a1" -gt "$a2" ]; then echo "1"; return; fi
        
        if [ "$b1" -lt "$b2" ]; then echo "-1"; return; fi
        if [ "$b1" -gt "$b2" ]; then echo "1"; return; fi
        
        if [ "$c1" -lt "$c2" ]; then echo "-1"; return; fi
        if [ "$c1" -gt "$c2" ]; then echo "1"; return; fi
        
        echo "0"
    }

    if [ -n "$installed_masscan_version" ]; then
        check_version=$(version_comparison "$installed_masscan_version" "$min_masscan_version_required")
        if [ "$check_version" -lt 0 ]; then
             missing_or_outdated_packages="$missing_or_outdated_packages masscan"
        fi
    fi

    if [ -n "$installed_nmap_version" ]; then
        check_version=$(version_comparison "$installed_nmap_version" "$min_nmap_version_required")
        if [ "$check_version" -lt 0 ]; then
             missing_or_outdated_packages="$missing_or_outdated_packages nmap"
        else
            # POSIX string matching
            nmap_path=$(command -v nmap)
            case "$nmap_path" in
                */local/*) nmap_scripts_folder="/usr/local/share/nmap/scripts/" ;;
                *) nmap_scripts_folder="/usr/share/nmap/scripts/" ;;
            esac
        fi
    fi

    # Vulners Check
    if [ ! -f "${nmap_scripts_folder}vulners.nse" ]; then
         missing_or_outdated_packages="$missing_or_outdated_packages vulners"
    fi

    # Installation if missing
    # In POSIX, we check if string is not empty
    if [ -n "$missing_or_outdated_packages" ]; then
        # Count items by counting words
        count=$(echo "$missing_or_outdated_packages" | wc -w)
        
        printf "${bold_color}${red_color}Some prerequisites are missing or outdated ($count):${end_color}\n"
        printf "${blue_color}${missing_or_outdated_packages}${end_color}\n"
        
        export packages_to_install="$missing_or_outdated_packages"
        export nmap_scripts_folder
        export os_family
        
        if [ ! -s "${source_installation}" ]; then
            printf "${red_color}Missing installation source file: ${source_installation}. Please re-clone repository.${end_color}\n"
            exit 1
        fi
        # Use dot for sourcing
        . "${source_installation}"
    else
        touch "${dir_name}/.prerequisites_already_installed" 2>/dev/null
    fi
}

if [ ! -f "${dir_name}/.prerequisites_already_installed" ]; then
    checking_prerequisites
fi

# NSE folder check re-run (outside function)
nmap_path=$(command -v nmap)
case "$nmap_path" in
    */local/*) nmap_scripts_folder="/usr/local/share/nmap/scripts/" ;;
    *) nmap_scripts_folder="/usr/share/nmap/scripts/" ;;
esac

######################################
# The script is now fully functional #
######################################

# Time elapsed 
time_elapsed(){
    script_end=$(date +%s)
    script_duration=$((script_end - script_start))
    
    hours=$((script_duration / 3600))
    minutes=$(( (script_duration % 3600) / 60 ))
    seconds=$((script_duration % 60))

    printf 'Duration: %02dh:%02dm:%02ds\n' "$hours" "$minutes" "$seconds"
}

# Let's make our script more glamorous
# Warning: gum style works, but ensure "$1" and "$2" are quoted to handle spaces safely
warning_message_with_border(){
    if [ -n "$2" ]; then
        gum style --background 1 --padding "1 1" --bold "$1" "$2"
    else
        gum style --background 1 --padding "1 1" --bold "$1"
    fi
}

tip_message_with_border(){
    if [ -n "$2" ]; then
        gum style --background 4 --padding "1 1" --bold "$1" "$2"
    else
        gum style --background 4 --padding "1 1" --bold "$1"
    fi
}

task_completion_message(){
    gum style --foreground 10 --bold "$1"
}

blue_info_message(){
    if [ -n "$2" ]; then
        gum style --foreground 69 --bold "$1" "$2"
    else
        gum style --foreground 69 --bold "$1"
    fi
}

yellow_info_message(){
    if [ -n "$2" ]; then
        gum style --foreground 11 --bold "$1" "$2"
    else
        gum style --foreground 11 --bold "$1"
    fi
}

logo(){
    # POSIX sh does not support arrays. We use a string list and awk to pick a random one.
    fonts="smbraille smblock pagga future emboss emboss2"
    
    # Pick a random font using awk (standard POSIX utility)
    # we seed srand with date to ensure randomness
    random_font=$(echo "$fonts" | awk 'BEGIN{srand()} {n=split($0, a, " "); print a[int(rand()*n)+1]}')

    current_lang=${LANG}
    current_lc_all=${LC_ALL}

    # Find the first available locale containing "utf8"
    utf8_locale=$(locale -a | grep 'utf8' | head -n 1)
    
    if [ -n "$utf8_locale" ]; then
        export PATH=$PATH:/usr/games
        export LANG=$utf8_locale
        export LC_ALL=$utf8_locale
        printf '\n'
        
        # Note: toilet, boxes, lolcat are external dependencies
        toilet -f "${random_font}" "MassVulScan" | boxes -d peek -a hc -p h1 | lolcat
        gum style --foreground 5 --bold --align right --width 40 "v${version}"
        
        export LANG=${current_lang}
        export LC_ALL=${current_lc_all}
        printf '\n'
    else
        gum style --foreground 42 --bold --border thick "M a s s V u l S c a n"
        gum style --foreground 5 --bold --align right --width 25 "v${version}"
    fi
}

# Root user?
root_user(){
    # Using -ne for integer comparison is safer in POSIX if we are sure it's a number
    if [ "$(id -u)" -ne 0 ]; then
        warning_message_with_border "You are not the root user." "If you have the appropriate permissions (sudoers), rerun the script with 'sudo'."
        exit 1
    fi
}

# Verifying if top-ports source files exist
source_file_top(){
    if [ -z "${source_top_tcp}" ] || [ ! -s "${source_top_tcp}" ]; then
        warning_message_with_border "The file \"${source_top_tcp}\" is missing or is empty."
        tip_message_with_border "Redownload the source from Github: git clone https://github.com/choupit0/MassVulScan.git"
        exit 1
    elif [ -z "${source_top_udp}" ] || [ ! -s "${source_top_udp}" ]; then
        warning_message_with_border "The file \"${source_top_udp}\" is missing or is empty."
        tip_message_with_border "Redownload the source from Github: git clone https://github.com/choupit0/MassVulScan.git"
        exit 1
    fi
}

hosts="$1"
exclude_file=""
interactive="off"
check="off"

# Usage of script
usage(){
    # Replaced echo -e with printf for portability
    printf "${bold_color}${red_color}Usage: ./%s COMMAND [ARGS]${end_color} OPTIONS\n" "$(basename "$0")"
    printf "      ${red_color}Commands (required):${end_color}\n"
    printf "        -h | --hosts ${red_color}[ARGS]${end_color}  \t\tTarget host(s): IP address (CIDR format compatible)\n"
    printf "        -f | --include-file ${red_color}[ARGS]${end_color} \tFile including IPv4 addresses (CIDR format) or hostnames to scan (one by line)\n"
    printf "      Options:\n"
    printf "        -x | --exclude-file ${red_color}[ARGS]${end_color} \tFile including IPv4 addresses ONLY (CIDR format) to NOT scan (one by line)\n"
    printf "        -i | --interactive-mode \tExtra parameters: ports to scan, rate level and NSE script\n"
    printf "        -a | --all-ports \t\tScan all 65535 ports (TCP + UDP) at 1.5K pkts/sec with NSE vulners script\n"
    printf "        -c | --check-live-hosts \tPerform a pre-scanning to identify online hosts and scan only them\n"
    printf "        -r | --report \t\t\tFile including IPs scanned with open ports and protocols\n"
    printf "        -n | --no-nmap-scan \t\tThe script detect only the hosts with open ports (no nmap scan & HTML report)\n"
    printf "        -d | --dns ${red_color}[ARGS]${end_color} \t\tDNS server to use (useful with the \"-f\" command and hostnames, current: ${dns})\n"
    printf "        -I | --interface ${red_color}[ARGS]${end_color} \tNetwork interface to use for scanning (e.g. eth0, wlan0), or the one with the default route is used\n"
    printf "      Information:\n"
    printf "        -H | --help \t\t\tShow this help menu\n"
    printf "        -V | --version \t\t\tScript version\n"
    printf "\n"
}

# No paramaters
if [ "$#" -eq 0 ]; then
    logo
    usage
    exit 1
fi



# Available parameters
# POSIX loop for argument parsing
while [ -n "$1" ]; do
        case "$1" in
                -h | --hosts )
                        host_parameter="yes"
                        shift
                        initial_hosts="$1"
                        hosts="$1"
                        ;;
                -f | --include-file )
                        file_of_hosts_to_include="yes"
                        shift
                        hosts="$1"
                        ;;
                -x | --exclude-file )
                        file_of_hosts_to_exclude="yes"
                        shift
                        exclude_file="$1"
                        ;;
                -i | --interactive-mode )
                        interactive="on"
                       ;;
                -a | --all-ports )
                        all_ports="on"
                       ;;
                -c | --check-live-hosts )
                        check="on"
                        ;;
                -r | --report )
                        report="on"
                        ;;
                -n | --no-nmap-scan )
                        no_nmap_scan="on"
                        ;;
                -d | --dns )
                        shift
                        dns="$1"
                        ;;
                -I | --interface )
                        shift
                        network_interface="$1"
                        ;;
                -H | --help )
                        printf "\n"
                        usage
                        exit 0
                        ;;
                -V | --version )
                        blue_info_message "MassVulScan version ${version} (https://github.com/choupit0/MassVulScan)"
                        blue_info_message "Now compatible with RedHat and Debian OS since version 3.0.0."
                        exit 0
                        ;;
                * )
                        warning_message_with_border "One parameter is missing or does not exist."
                        exit 1
        esac
        shift
done

root_user

# Checking if process already running
check_proc="$(pgrep -i massvulscan)"
# Using wc -l implies counting lines, we trim whitespace if necessary or just compare integers
check_proc_nb="$(echo "$check_proc" | grep -c .)" 

# POSIX integer comparison using -gt
if [ "${check_proc_nb}" -gt 2 ]; then
    warning_message_with_border "A process is already running: ${check_proc}"
    exit 1
fi

# Logic validation for parameters
# We split long conditions into multiple nested or sequenced checks for POSIX clarity
if [ "$host_parameter" = "yes" ]; then
    if [ "$file_of_hosts_to_include" = "yes" ] || [ "$file_of_hosts_to_exclude" = "yes" ]; then
        warning_message_with_border "You can only use one command at a time.: -h | --hosts [ARGS] OR -f | --include-file [ARGS]" "Additionally: -x | --exclude-file [ARGS] is incompatible with -h | --hosts"
        exit 1
    fi
fi

# Valid input file or host?
if [ "$file_of_hosts_to_include" = "yes" ] && [ -z "$hosts" ]; then
    warning_message_with_border "You must specify an argument: -f | --include-file [ARGS]"
    exit 1
elif [ "$file_of_hosts_to_include" = "yes" ] && [ ! -s "$hosts" ]; then
    warning_message_with_border "The input file \"${hosts}\" does not exist or is empty."
    exit 1
elif [ "$host_parameter" = "yes" ] && [ -z "$hosts" ]; then
    warning_message_with_border "You must specify an argument: -h | --hosts [ARGS]"
    exit 1
fi

# Helper function for absolute path (POSIX replacement for readlink -f)
get_abs_path(){
    if [ -f "$1" ]; then
        dir=$(dirname "$1")
        base=$(basename "$1")
        echo "$(cd "$dir" && pwd)/$base"
    else
        echo "$1"
    fi
}

# Valid exclude file?
if [ "$file_of_hosts_to_exclude" = "yes" ]; then
    if [ -z "$exclude_file" ]; then
        warning_message_with_border "You must specify an argument: -x | --exclude-file [ARGS]"
        exit 1
    elif [ ! -s "$exclude_file" ]; then
        warning_message_with_border "The exclude file \"${hosts}\" does not exist or is empty."
        exit 1
    fi
fi

# Formatting of the "hosts" variable
if [ "$file_of_hosts_to_include" = "yes" ]; then
    # Complete path to the "hosts" file
    hosts=$(get_abs_path "$hosts")
fi

# Cleaning old files - if the script is ended before the end (CTRL + C)
rm -rf /tmp/temp_dir-* /tmp/temp_nmap-* paused.conf 2>/dev/null

# Folder for temporary file(s)
# mktemp is not strictly POSIX but widely available. 
# Fallback to date/pid if needed, but keeping mktemp for security.
temp_dir=$(mktemp -d /tmp/temp_dir-XXXXXXXX)
temp_nmap=$(mktemp -d /tmp/temp_nmap-XXXXXXXX)

clear

# Function to validate the format of an IP address
valid_ip(){
    ip_to_check="$1"
    
    # Regex for IPv4 and IPv4/CIDR
    if echo "$ip_to_check" | grep -Eq '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$'; then
        # Remove CIDR part for validation if present
        ip_only=$(echo "$ip_to_check" | cut -d/ -f1)
        
        # Split by dot
        old_ifs="$IFS"
        IFS='.'
        set -- $ip_only
        o1=$1; o2=$2; o3=$3; o4=$4
        IFS="$old_ifs"
        
        # Check octets
        if [ "$o1" -le 255 ] && [ "$o2" -le 255 ] && [ "$o3" -le 255 ] && [ "$o4" -le 255 ]; then
            return 0
        else
            return 1
        fi
    fi
    
    # Regex for IPv6 (Basic check)
    if echo "$ip_to_check" | grep -Eq '^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'; then
        return 0
    fi
    
    return 1
}

# DNS Server selection
if [ "${dns}" = "1.1.1.1" ]; then
    yellow_info_message "Default Public DNS Server Configured: ${dns}"
elif valid_ip "${dns}"; then
    yellow_info_message "Your own DNS Server configuration: ${dns}"
else
    warning_message_with_border "\"${dns}\" is not a valid IPv4 address for a DNS server."
    exit 1
fi

#######################################
# Parsing the input and exclude files #
#######################################
if [ "$file_of_hosts_to_include" = "yes" ] || [ "$file_of_hosts_to_exclude" = "yes" ]; then
    # Filter valid chars, remove punctuation, sort unique
    # Note: Using grep -c for counting instead of piping to wc -l where possible
    
    # We create a clean version of the hosts file to work with
    grep '[[:alnum:].-]' "${hosts}" | grep -Ev '^[[:punct:]]|[[:punct:]]$' | sed '/[]!"#\$%&'\''()\*+,:;<=>?@\[\\^_`{|}~]/d' | sort -u > "${temp_dir}/clean_hosts.txt"
    
    # Count hostnames (lines that do NOT look like IPs)
    num_hostnames_init=$(grep -vEc '.*([0-9]{1,3}\.){3}[0-9]{1,3}.*' "${temp_dir}/clean_hosts.txt")
    
    # Count IPs
    num_ips_init=$(grep -Eoc '.*([0-9]{1,3}\.){3}[0-9]{1,3}.*' "${temp_dir}/clean_hosts.txt")

    printf "\r                                                                                                                 "
    printf "\rParsing the input file (DNS lookups, duplicate IPs, multiple hostnames and valid IPs)..."

    # Saving IPs first
    if [ "$num_ips_init" -gt 0 ]; then
        grep -Eo '.*([0-9]{1,3}\.){3}[0-9]{1,3}.*' "${temp_dir}/clean_hosts.txt" | while read -r check_ip; do
            if valid_ip "${check_ip}"; then
                echo "${check_ip}" >> "${temp_dir}"/IPs.txt
            else
                printf "\r\"%s\" is not a valid IPv4 address and/or subnet mask                           \n" "${check_ip}"
            fi
        done
    fi

    

    # Detect and deduplicate CIDR subnets
    # Replaced Bash logic with POSIX compliant AWK script
    if [ -s "${temp_dir}/IPs.txt" ] && grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+' "${temp_dir}"/IPs.txt; then
        
        # Prepare file: Ensure all have CIDR. If no /x, append /32
        sed -E 's|^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)$|\1/32|' "${temp_dir}"/IPs.txt > "${temp_dir}"/IPs_CIDR_pre.txt
        
        # Use awk to handle the logic previously done by Bash Associative Arrays
        # This script calculates the network address and checks for overlaps
        awk '
        function ip2int(ip) {
            split(ip, a, ".")
            return (a[1]*16777216) + (a[2]*65536) + (a[3]*256) + a[4]
        }
        function get_mask(bits) {
            if(bits==0) return 0
            # Create mask using arithmetic to avoid non-standard bitwise ops
            return 4294967295 - (2^(32-bits) - 1)
        }
        function get_network(ip_int, mask_int) {
            # Simulate bitwise AND via arithmetic if standard and() is missing
            # However, for subnetting, int(ip / size) * size works
            # Size of block = 2^(32-bits)
            # This is a safe POSIX awk mathematical way to get network address
            # block_size = 2^(32-bits)
            # return int(ip_int / block_size) * block_size
            
            # Using standard bitwise if available, or math fallback
            # We assume a standard awk that can do basic math
            p = 2^(32-bits)
            return int(ip_int / p) * p
        }
        {
            split($0, parts, "/")
            ip = parts[1]
            cidr = parts[2] + 0
            ip_int = ip2int(ip)
            net_start = get_network(ip_int, cidr)
            
            # Store tuple: net_start, cidr, original_line
            lines[NR] = $0
            starts[NR] = net_start
            cidrs[NR] = cidr
            count++
        }
        END {
            # Simple O(N^2) check (fine for reasonable list sizes)
            # If a network is contained in a larger one, skip it.
            for(i=1; i<=count; i++) {
                keep = 1
                for(j=1; j<=count; j++) {
                    if(i==j) continue
                    
                    # If J has a smaller CIDR (larger net) than I
                    if(cidrs[j] < cidrs[i]) {
                         # Check if I is inside J
                         # I starts inside J range?
                         j_size = 2^(32-cidrs[j])
                         if(starts[i] >= starts[j] && starts[i] < (starts[j] + j_size)) {
                            keep = 0
                            break
                         }
                    }
                    # Handle exact duplicates (same start, same cidr), keep first only
                    if(cidrs[j] == cidrs[i] && starts[j] == starts[i] && j < i) {
                        keep = 0
                        break
                    }
                }
                if(keep) print lines[i]
            }
        }
        ' "${temp_dir}"/IPs_CIDR_pre.txt > "${temp_dir}"/IPs.txt
        
        rm -f "${temp_dir}"/IPs_CIDR_pre.txt
    fi

    # First parsing to translate the hostnames to IPs
    if [ "$num_hostnames_init" != "0" ]; then
        # Filtering on the hosts only
        grep -vE '([0-9]{1,3}\.){3}[0-9]{1,3}' "${temp_dir}/clean_hosts.txt" | sort -u > "${temp_dir}/hostnames_only.txt"

        # Conversion to IPs
        while read -r host_to_convert; do
            search_ip=$(dig @"${dns}" "${host_to_convert}" +short | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
            if [ -n "${search_ip}" ]; then
                # POSIX printf usage
                echo "${search_ip}" | while read -r sip; do
                    echo "$sip $host_to_convert" >> "${temp_dir}"/hosts_converted.txt
                done
            else
                printf "\r                                                                                                                 "
                printf "\rNo IP found for hostname \"${host_to_convert}\".\n"
            fi
        done < "${temp_dir}/hostnames_only.txt"
    fi

    # Second parsing to detect multiple IPs for the same hostname
    if [ -s "${temp_dir}/hosts_converted.txt" ]; then
        while read -r line; do
            # Count IPs in the line
            check_ips=$(echo "${line}" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | wc -l)
            # Remove whitespace
            check_ips=$(echo "$check_ips" | tr -d '[:space:]')

            # Filtering on the multiple IPs only
            if [ "$check_ips" -gt 1 ]; then
                hostname=$(echo "${line}" | awk '{print $NF}')
                # Iterate over IPs
                echo "${line}" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | while read -r single_ip; do
                    echo "${single_ip} ${hostname}" >> "${temp_dir}"/multiple_IPs.txt
                done
            elif [ "$check_ips" -eq 1 ]; then
                # Saving uniq IP
                echo "${line}" >> "${temp_dir}"/uniq_IPs.txt
            fi
        done < "${temp_dir}"/hosts_converted.txt

        if [ -s "${temp_dir}/uniq_IPs.txt" ]; then
            cat "${temp_dir}"/uniq_IPs.txt >> "${temp_dir}"/IPs_and_hostnames.txt
            rm -f "${temp_dir}"/uniq_IPs.txt
        fi

        if [ -s "${temp_dir}/multiple_IPs.txt" ]; then
            cat "${temp_dir}"/multiple_IPs.txt >> "${temp_dir}"/IPs_and_hostnames.txt
            rm -f "${temp_dir}"/multiple_IPs.txt
        fi

        # Third parsing to detect duplicate IPs and keep the multiple hostnames
        # Awk is standard and replaces the previous logic
        awk '/.+/ { 
            if (!($1 in ips_list)) { 
                value[++i] = $1 
            } 
            ips_list[$1] = ips_list[$1] $2 "," 
        } 
        END { 
            for (j = 1; j <= i; j++) { 
                printf("%s %s\n", value[j], ips_list[value[j]]) 
            } 
        }' "${temp_dir}"/IPs_and_hostnames.txt | sed '/^$/d' | sed 's/,$//' > "${temp_dir}"/IPs_unsorted.txt
        
        rm -f "${temp_dir}"/IPs_and_hostnames.txt
    fi

    if [ ! -s "${temp_dir}/IPs_unsorted.txt" ] && [ ! -s "${temp_dir}/IPs.txt" ]; then
        warning_message_with_border "No valid host found."
        exit 1
    fi

    if [ "$host_parameter" = "yes" ]; then
        hosts_file_no_path="${initial_hosts}"
    else
        hosts_file_no_path="$(basename "$hosts")"
    fi

    printf "\r                                                                                             "
    printf "\rValid host(s) to scan:\n"

    # Merge and sort
    if [ -s "${temp_dir}/IPs.txt" ]; then
        cat "${temp_dir}"/IPs.txt >> "${temp_dir}"/IPs_unsorted.txt
        rm -f "${temp_dir}"/IPs.txt
    fi

    if [ -s "${temp_dir}/IPs_unsorted.txt" ]; then
        sort -u "${temp_dir}"/IPs_unsorted.txt | sort -t . -n -k1,1 -k2,2 -k3,3 -k4,4 > "${temp_dir}"/"${hosts_file_no_path}"_parsed
        rm -f "${temp_dir}"/IPs_unsorted.txt
        cat "${temp_dir}"/"${hosts_file_no_path}"_parsed
    else
        # Should not happen given previous checks, but for safety
        mv "${temp_dir}"/IPs.txt "${temp_dir}"/"${hosts_file_no_path}"_parsed 2>/dev/null
        cat "${temp_dir}"/"${hosts_file_no_path}"_parsed 2>/dev/null
    fi

    hosts_file="${temp_dir}/${hosts_file_no_path}_parsed"

    if [ -n "$exclude_file" ]; then
        # Complete path to the "hosts" file
        exclude_file="$(get_abs_path "$exclude_file")"
        printf "\r                                                                                                                 "
        printf "\rParsing the exclude file (valid IPv4 addresses ONLY)..."
        
        # Count xIPs
        grep -Ev '^[[:punct:]]|[[:punct:]]$' "${exclude_file}" | sed '/[]!"#\$%&'\''()\*+,\/:;<=>?@\[\\^_`{|}~]/d' | sort -u > "${temp_dir}/xIPs_candidates.txt"
        
        num_xips_init=$(grep -Eoc '.*([0-9]{1,3}\.){3}[0-9]{1,3}.*' "${temp_dir}/xIPs_candidates.txt")
        
        if [ "$num_xips_init" -gt 0 ]; then
            grep -Eo '.*([0-9]{1,3}\.){3}[0-9]{1,3}.*' "${temp_dir}/xIPs_candidates.txt" | while read -r check_ip; do
                if valid_ip "${check_ip}"; then
                    echo "${check_ip}" >> "${temp_dir}"/xIPs.txt
                else
                    printf "\r\"%s\" is not a valid IPv4 address and/or subnet mask to exclude                    \n" "${check_ip}"
                fi
            done
        fi
    fi

    xhosts_file_no_path="$(basename "$exclude_file")"

    if [ -s "${temp_dir}/xIPs.txt" ]; then
        printf "\r                                                                                            "
        printf "\rValid host(s) to exclude:\n"
        sort -u "${temp_dir}"/xIPs.txt | sort -t . -n -k1,1 -k2,2 -k3,3 -k4,4 > "${temp_dir}"/"${xhosts_file_no_path}"_parsed
        rm -f "${temp_dir}"/xIPs.txt
        cat "${temp_dir}"/"${xhosts_file_no_path}"_parsed
    fi

    xhosts_file="${temp_dir}/${xhosts_file_no_path}_parsed"
fi

####################
# Interactive mode #
####################
# grep is standard POSIX
top_ports_tcp="$(grep -v '^#' "${source_top_tcp}")"
top_ports_udp="$(grep -v '^#' "${source_top_udp}")"

# Check mutually exclusive flags
if [ "$interactive" = "on" ] && [ "$all_ports" = "on" ]; then
    warning_message_with_border "You can't chose interactive mode (-i) with all ports scanning mode (-a)."
    exit 1
elif [ "$all_ports" = "on" ]; then
    gum style --foreground 1 --bold --border thick "All-ports scan mode"
    blue_info_message "We will scan ALL the ports 1-65535 on TCP AND UDP protocols and use the NSE Vulners script."
    ports="-p1-65535,U:1-65535"
    rate="1500"
    script="vulners"
elif [ "$interactive" = "on" ]; then
    gum style --foreground 42 --bold --border thick "Interactive Mode"
    
    # POSIX way to handle list options: Use a variable with newlines
    default_ports_opts="Top 1000 ports (TCP/UDP)
Common ports (20-25,53,80,110,143,161,443,445,993,995,3306,8080)
All TCP and UDP ports (1-65535)
Custom ports (enter manually)"
      
    # Use gum choose to select ports (piping the string variable)
    selected_option=$(printf "%s" "$default_ports_opts" | gum choose --selected "All TCP and UDP ports (1-65535)" --header "Select the ports:")

    case "$selected_option" in
        "Top 1000 ports (TCP/UDP)")
            source_file_top
            ports="-p${top_ports_tcp},U:${top_ports_udp}"
            blue_info_message "Selected ports: --top-ports 1000 (TCP/UDP)."
            ;;
        "Common ports (20-25,53,80,110,143,161,443,445,993,995,3306,8080)")
            ports="-p20-25,53,80,110,143,443,445,993,995,3306,8080,U:53,161"
            blue_info_message "Selected ports: ${ports}"
            ;;
        "All TCP and UDP ports (1-65535)")
            ports="-p1-65535,U:1-65535"
            blue_info_message "Selected ports: ${ports}"
            ;;
        "Custom ports (enter manually)")
            # Use gum input to enter custom ports
            custom_ports=$(gum input --placeholder "Enter custom ports (e.g., -p20-25,80 --exclude-ports 26 or -pU:53,161 for UDP)" --timeout 120s)
            if [ -z "${custom_ports}" ]; then
                echo "Error: No custom ports provided."
                exit 1
            else
                ports="${custom_ports}"
                blue_info_message "Custom ports to scan: ${ports}"
            fi
            ;;
        *)
            echo "Error: Invalid option selected."
            ;;
    esac
    
    # Default rate options for masscan (POSIX string)
    default_rates_opts="100 packets/sec (Slow and stealthy)
1000 packets/sec (Moderate speed)
10000 packets/sec (Fast)
Custom rate (enter manually)"
      
    # Use gum choose to select the rate
    selected_rate_option=$(printf "%s" "$default_rates_opts" | gum choose --selected "1000 packets/sec (Moderate speed)" --header "Select the rate:")

    case "$selected_rate_option" in
        "100 packets/sec (Slow and stealthy)")
            rate="100"
            blue_info_message "Selected rate: ${rate}"
            ;;
        "1000 packets/sec (Moderate speed)")
            rate="1000"
            blue_info_message "Selected rate: ${rate}"
            ;;
        "10000 packets/sec (Fast)")
            rate="10000"
            blue_info_message "Selected rate: ${rate}"
            ;;
        "Custom rate (enter manually)")
            # Use gum input to enter custom rate
            custom_rate=$(gum input --placeholder "Enter custom rate (packets/sec)" --timeout 120s)
            if [ -z "${custom_rate}" ]; then
                echo "Error: No custom rate provided."
                exit 1
            else
                rate="${custom_rate}"
                blue_info_message "Custom rate: ${rate}"
            fi
            ;;
        *)
            echo "Error: Invalid option selected."
            ;;
    esac

    # Use gum to select the NSE script for nmap
    
    if [ "${no_nmap_scan}" != "on" ]; then
        locate_scripts="${nmap_scripts_folder}"
        
        # We rely on ls here because wildcards in variables are tricky in strict POSIX
        # We strip the path to just show filenames for the menu
        scripts_list=$(ls "${locate_scripts}"*.nse 2>/dev/null | awk -F'/' '{print $NF}')

        # Verifying if Nmap folder scripts is present (check if string is empty)
        if [ -z "$scripts_list" ]; then
            printf "The Nmap folder does not exist or is empty (e.g. /usr/local/share/nmap/scripts/*.nse).\n"
            printf "This script can install the prerequisites for you: %s\n" "${source_installation}"
            echo "Please, download the source from Github and try again: git clone https://github.com/choupit0/MassVulScan.git"
            exit 1
        fi
        
        

        # No arrays needed, just pipe the newline-separated string
        selected_script=$(printf "%s" "$scripts_list" | gum filter --indicator "◉" --limit 1 --header "Select a script:" --placeholder "Search for and select the Nmap NSE script" --timeout 120s)

        if [ -n "${selected_script}" ]; then
            script="${selected_script}"
            blue_info_message "Selected script: ${selected_script}"
            
            # suggestions for --script-args
            default_script_args_opts="Set a minimum CVSS score of 5 (vulners)
Set a minimum CVSS score of 7 (vulners)
Set a minimum CVSS score of 10 (vulners)
No script argument
Custom script arguments (enter manually)"
          
            # Use gum choose to select the --script-args
            selected_script_args=$(printf "%s" "$default_script_args_opts" | gum choose --selected "No script argument" --header "Select the script argument:")

            case "$selected_script_args" in
                "Set a minimum CVSS score of 5 (vulners)")
                    script_args="mincvss=5"
                    blue_info_message "Selected script argument: ${script_args}"
                    script="${script} --script-args ${script_args}"
                    ;;
                "Set a minimum CVSS score of 7 (vulners)")
                    script_args="mincvss=7"
                    blue_info_message "Selected script argument: ${script_args}"
                    script="${script} --script-args ${script_args}"
                    ;;
                "Set a minimum CVSS score of 10 (vulners)")
                    script_args="mincvss=10"
                    blue_info_message "Selected script argument: ${script_args}"
                    script="${script} --script-args ${script_args}"
                    ;;
                "No script argument")
                    script_args=""
                    blue_info_message "No script argument."
                    ;;
                "Custom script arguments (enter manually)")
                    # Use gum input to enter custom script argument
                    custom_script_args=$(gum input --placeholder "Enter custom script argument (e.g., smbusername=<username>,smbpass=<password> for the NSE 'script smb-enum-services')" --timeout 120s)
                    if [ -z "${custom_script_args}" ]; then
                        echo "Error: No custom script argument provided."
                        exit 1
                    else
                        script_args="${custom_script_args}"
                        blue_info_message "Custom script argument: ${script_args}"
                        script="${script} --script-args ${script_args}"
                    fi
                    ;;
                *)
                    echo "Error: Invalid option selected."
                    ;;
            esac
        else
            echo "Error: No script selected."
            exit 1
        fi
    fi

else
    # Non-Interactive Defaults
    if [ "${no_nmap_scan}" != "on" ]; then  
        source_file_top
        ports="-p${top_ports_tcp},U:${top_ports_udp}"
        rate="1500"
        script="vulners"
        blue_info_message "Default parameters: --top-ports 1000 (TCP/UDP), --max-rate 1500 and Vulners script (NSE)"
    else
        source_file_top
        ports="-p${top_ports_tcp},U:${top_ports_udp}"
        rate="1500"
        blue_info_message "Default parameters: --top-ports 1000 (TCP/UDP) and --max-rate 1500 (no Nmap Scan)"
    fi
fi

# Network interface selection
if [ -z "${network_interface}" ]; then

    # Get the default interface
    # POSIX: Use route or ip. 'ip' is standard on Linux, but not strictly POSIX utility, 
    # however the original script relied on 'ip' and 'ifconfig'. 
    # We keep the logic but ensure the shell wrapping is safe.
    default_interface=$(ip route show default | awk '/default/ {print $5; exit}')

    # Get the number of network interfaces
    # Using grep -c for counting
    nb_interfaces=$(ifconfig | grep -E "[[:space:]](Link|flags)" | grep -c "^[[:alnum:]]*")

    ################################################
    # Checking if there are more than 2 interfaces #
    ################################################

    if [ "${nb_interfaces}" -gt 2 ]; then
        # List of network interfaces
        interfaces_list=$(ifconfig | grep -E "[[:space:]](Link|flags)" | grep -o "^[[:alnum:]]*")
        
        # Display a warning message with gum
        echo "Warning: multiple network interfaces have been detected:" | gum style --foreground 212

        # Display the list of interfaces using gum for selection
        # Pass the newline-separated string directly to gum
        selected_interface=$(printf "%s\n" "${interfaces_list}" | gum choose --limit 1 --selected "${default_interface}" --header "Which one do you want to use (the default one is selected)?" --timeout 90s)

        # Check if an interface was selected
        if [ -z "${selected_interface}" ]; then
            echo "No interface chosen, we will use the one with the default route." | gum style --foreground 212
            interface="${default_interface}"
        else
            interface="${selected_interface}"
        fi

        echo "Network interface chosen: ${interface}" | gum style --foreground 212
    else
        interface="${default_interface}"
        echo "Default network interface chosen: ${interface}" | gum style --foreground 212
    fi
else
    # Check if the provided interface exists on the system
    
    # Get the list of network interfaces available on the system and only UP
    available_interfaces=$(ip -o link show up | awk -F': ' '{print $2}')

    # grep -q is widely supported, strictly POSIX is >/dev/null
    if ! echo "$available_interfaces" | grep -q "$network_interface"; then
        warning_message_with_border "\"${network_interface}\" does not exist on this system or the network interface is down."
        yellow_info_message "Available and UP interfaces are:"
        echo "$available_interfaces" | tr ' ' '\n'
        exit 1
    fi

    interface="${network_interface}"
    echo "Network interface chosen: ${interface}" | gum style --foreground 212
fi

##################################################
##################################################
## Okay, serious matters start there! Let's go! ##
##################################################
##################################################

###################################################
# 1/4 First analysis with Nmap to find live hosts #
###################################################

if [ "${check}" = "on" ]; then
    if [ "${file_of_hosts_to_include}" = "yes" ]; then
        cut -d" " -f1 "${hosts_file}" > "${temp_dir}"/ips_list.txt
        
        gum spin --spinner dot --title.foreground 6 --title "Let's check how many hosts are online; please be patient." -- \
            nmap -n -sP -T5 --min-parallelism 100 --max-parallelism 256 -iL "${temp_dir}"/ips_list.txt > "${temp_dir}"/nmap_ping_output.txt
            
        # Parse output after execution to avoid pipe exit code issues in strictly POSIX shells
        grep -B1 "Host is up" "${temp_dir}"/nmap_ping_output.txt | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" > "${temp_dir}"/live_hosts.txt
            
        # Check if live_hosts is empty
        if [ ! -s "${temp_dir}/live_hosts.txt" ]; then
            warning_message_with_border "No host detected online. The script is ended."
            rm -f "${temp_dir}"/live_hosts.txt "${temp_dir}"/"${hosts_file_no_path}"_parsed "${temp_dir}"/nmap_ping_output.txt
            time_elapsed            
            exit 1
        fi
        
        task_completion_message "Pre-scanning phase is ended."
        rm -f "${temp_dir}"/ips_list.txt "${temp_dir}"/nmap_ping_output.txt 2>/dev/null
        
        # Count lines
        nb_hosts_to_scan=$(grep -c . "${temp_dir}/live_hosts.txt")
        blue_info_message "${nb_hosts_to_scan} ip(s) to scan."
        
    elif [ "${host_parameter}" = "yes" ]; then
        gum spin --spinner dot --title.foreground 6 --title "Let's check how many hosts are online; please be patient." -- \
            nmap -n -sP -T5 --min-parallelism 100 --max-parallelism 256 ${hosts} | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" > "${temp_dir}"/live_hosts.txt
            
        # Check if file has size 0
        if [ ! -s "${temp_dir}/live_hosts.txt" ]; then
            warning_message_with_border "No host detected online. The script is ended."
            time_elapsed            
            exit 1
        fi

        task_completion_message "Pre-scanning phase is ended."
        nb_hosts_to_scan=$(grep -c . "${temp_dir}/live_hosts.txt")
        blue_info_message "${nb_hosts_to_scan} ip(s) to scan."
    fi      
fi

########################################
# 2/4 Using Masscan to find open ports #
########################################

if [ -s "${temp_dir}/live_hosts.txt" ]; then
    hosts="${temp_dir}/live_hosts.txt"
elif [ "${host_parameter}" = "yes" ]; then
    echo "${hosts}" > "${temp_dir}/ips_list.txt"
    hosts="${temp_dir}/ips_list.txt"
else
    cut -d" " -f1 "${hosts_file}" > "${temp_dir}"/ips_list.txt 2>/dev/null
    hosts="${temp_dir}/ips_list.txt"
fi

# POSIX id check
if [ "${exclude_file}" = "" ] && [ "$(id -u)" -eq 0 ]; then
    # masscan execution
    masscan --open ${ports} --source-port 40000 -iL "${hosts}" -e "${interface}" --max-rate "${rate}" --wait 5 | tee "${temp_dir}"/masscan-output.txt
elif [ "${exclude_file}" != "" ] && [ "$(id -u)" -eq 0 ]; then
    # masscan execution with exclude
    masscan --open ${ports} --source-port 40000 -iL "${hosts}" -e "${interface}" --excludefile "${xhosts_file}" --max-rate "${rate}" --wait 5 | tee "${temp_dir}"/masscan-output.txt
fi

# Capture exit code of masscan (via pipe, usually need PIPESTATUS in bash, 
# in POSIX checking if the output file exists or is valid is safer)
if [ ! -f "${temp_dir}/masscan-output.txt" ]; then
    clear
    warning_message_with_border "One or more parameters/arguments are incorrect or Masscan failed."
    rm -f "${temp_dir}"/masscan-output.txt
    exit 1
fi

task_completion_message "Masscan phase is ended."

if [ ! -s "${temp_dir}/masscan-output.txt" ]; then
    warning_message_with_border "No ip with open TCP/UDP ports found, so, exit! ->"
    rm -f "${temp_dir}"/masscan-output.txt "${temp_dir}"/hosts_converted.txt "${temp_dir}"/ips_list.txt
    time_elapsed
    exit 0
else
    
    tcp_ports=$(grep -c "^Discovered open port.*tcp" "${temp_dir}"/masscan-output.txt)
    udp_ports=$(grep -c "^Discovered open port.*udp" "${temp_dir}"/masscan-output.txt)
    nb_ports=$(grep -c "^Discovered open port" "${temp_dir}"/masscan-output.txt)
    nb_hosts_nmap=$(grep "^Discovered open port" "${temp_dir}"/masscan-output.txt | cut -d" " -f6 | sort | uniq -c | wc -l)
    
    # Strip whitespace from counts
    nb_hosts_nmap=$(echo "$nb_hosts_nmap" | tr -d '[:space:]')
    
    blue_info_message "${nb_hosts_nmap} host(s) concerning ${nb_ports} open ports."
fi

rm -f "${temp_dir}"/ips_list.txt 2>/dev/null

###########################################################################################
# 3/4 Identifying open services with Nmap and if they are vulnerable with vulners script  #
###########################################################################################

# Output file with hostnames
merge_ip_hostname(){
    # POSIX loop: read from file input at the end of the loop block
    while read -r line; do
        search_ip=$(echo "${line}" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')

        # Check if grep finds the IP in the hosts file
        if grep -q "${search_ip}" "${hosts_file}" 2>/dev/null; then
            
            # Extract hostname
            search_hostname=$(grep "${search_ip}" "${hosts_file}" | awk -F" " '{print $2}')
            
            if [ -n "${search_hostname}" ]; then
                echo "${line} ${search_hostname}" >> "${temp_dir}"/IPs_hostnames_merged.txt
            else
                echo "${line}" >> "${temp_dir}"/IPs_hostnames_merged.txt
            fi
        else
            echo "${line}" >> "${temp_dir}"/IPs_hostnames_merged.txt
        fi
    done < "${temp_dir}"/nmap-input.txt
}

# Preparing the input file for Nmap
nmap_file(){
    proto="$1"

    # POSIX awk to parse the masscan output and group ports by IP
    grep "Discovered open port .*/${proto} on" "${temp_dir}"/masscan-output.txt | awk -v proto="$proto" '
    {
        # Split line by space. Masscan output format:
        # Discovered open port 80/tcp on 192.168.1.1
        # $1=$2=$3, $4=port/proto, $5=on, $6=ip
        
        port_proto = $4
        ip = $6
        split(port_proto, p, "/")
        port = p[1]

        if (!seen[ip]) {
            order[++i] = ip
            seen[ip] = 1
            ips_list[ip] = port
        } else {
            ips_list[ip] = ips_list[ip] "," port
        }
    }
    END {
        for (j = 1; j <= i; j++) {
            printf("%s:%s:%s\n", proto, order[j], ips_list[order[j]])
        }
    }' >> "${temp_dir}"/nmap-input.temp.txt
}

rm -f "${temp_dir}"/nmap-input.temp.txt

if [ "${tcp_ports}" -gt 0 ]; then
    nmap_file tcp
fi

if [ "${udp_ports}" -gt 0 ]; then
    nmap_file udp
fi

# Sort uniquely
sort -t . -n -k1,1 -k2,2 -k3,3 -k4,4 "${temp_dir}"/nmap-input.temp.txt > "${temp_dir}"/nmap-input.txt

if [ "${no_nmap_scan}" != "on" ]; then
    # If we are using Vulners.nse script, check if vulners.com site is reachable
    if [ "${script}" = "vulners" ]; then
        # nc -z is common but check specific netcat version if fails. 
        # Using redirection 2>&1 to capture stderr.
        if nc -z -v -w 1 vulners.com 443 >/dev/null 2>&1; then
            check_vulners_api_status="open"
        else
            check_vulners_api_status="closed"
        fi

        if [ "${check_vulners_api_status}" = "open" ]; then
            blue_info_message "Vulners.com site is reachable on port 443."
        else
            warning_message_with_border "Warning: Vulners.com site is NOT reachable on port 443. Please, check your firewall rules, dns configuration and your Internet link." \
                "So, vulnerability check will be not possible, only opened ports will be present in the report."
        fi
    fi

    nb_nmap_process=$(sort -n "${temp_dir}"/nmap-input.txt | wc -l)
    current_date=$(date +%F_%H-%M-%S)

    # Keep the nmap input file?
    if [ "${report}" = "on" ]; then
        if [ "${host_parameter}" = "yes" ]; then
            sanitized_hosts_list=$(echo "${initial_hosts}" | tr '/\\:*?"<>,;' '_')
            merge_ip_hostname
            mv "${temp_dir}"/IPs_hostnames_merged.txt "${report_folder}${sanitized_hosts_list}_open-ports_${current_date}.txt"
            yellow_info_message "The report is available here: ${report_folder}${sanitized_hosts_list}_open-ports_${current_date}.txt"
        else
            merge_ip_hostname
            mv "${temp_dir}"/IPs_hostnames_merged.txt "${report_folder}${hosts_file_no_path}_open-ports_${current_date}.txt"
            yellow_info_message "The report is available here: ${report_folder}${hosts_file_no_path}_open-ports_${current_date}.txt"
        fi
    fi

    # Function for parallel Nmap scans
    parallels_scans(){
        # No arrays, using cut to parse "proto:ip:port" string
        proto=$(echo "$1" | cut -d":" -f1)
        ip=$(echo "$1" | cut -d":" -f2)
        port=$(echo "$1" | cut -d":" -f3)
        
        if [ "$proto" = "tcp" ]; then
            nmap --max-retries 2 --max-rtt-timeout 500ms -p"${port}" -Pn -sT -sV -n --script "${script}" -oA "${temp_nmap}/${ip}_tcp_nmap-output" "${ip}" > /dev/null 2>&1
        else
            nmap --max-retries 2 --max-rtt-timeout 500ms -p"${port}" -Pn -sU -sV -n --script "${script}" -oA "${temp_nmap}/${ip}_udp_nmap-output" "${ip}" > /dev/null 2>&1
        fi
        
        echo "${ip} (${proto}): Done" >> "${temp_dir}"/process_nmap_done.txt

        nmap_proc_ended=$(grep -c "Done" "${temp_dir}"/process_nmap_done.txt)
        
        # awk float calculation
        percentage=$(awk "BEGIN {printf \"%.2f\", ($nmap_proc_ended / $nb_nmap_process) * 100}")
        
        printf "\r                                                                                                         "
        printf "\rLast scan completed for: %s:%s (%s)... %s%%" "${ip}" "${port}" "${proto}" "${percentage}"
    }

    # Controlling the number of Nmap scanner to launch
    if [ "${nb_nmap_process}" -ge 50 ]; then
        max_job=50
        blue_info_message "Warning: A lot of Nmap process to launch: ${nb_nmap_process}" \
            "So, to no disturb your system, I will only launch ${max_job} Nmap process at time."
    else
        max_job="${nb_nmap_process}"
        blue_info_message "Launching ${nb_nmap_process} Nmap scanner(s)."
    fi

    # Queue files manager
    new_job(){
        # While loop to wait for slots
        # We count lines in 'jobs'. Note: jobs behavior varies by shell, but 'wc -l' is a safe standard approach.
        while [ "$(jobs 2>/dev/null | wc -l)" -ge "${max_job}" ]; do
            sleep 1
        done

        parallels_scans "$1" &
    }

    

[Image of parallel processing flow diagram]


    # We are launching all the Nmap scanners
    count=1

    # Using file descriptor redirection to ensure the loop runs in current shell context if needed,
    # though strictly POSIX while loops might be subshells.
    while read -r ip_to_scan; do
        new_job "${ip_to_scan}"
        count=$((count + 1))
    done < "${temp_dir}"/nmap-input.txt

    wait

    sleep 1 
    # tset might not be available, stty sane is a POSIX alternative or just reset
    if command -v tset >/dev/null 2>&1; then tset > /dev/null 2>&1; fi

    printf "\r                                                                                                                                                               "
    printf "\r"
    task_completion_message "Nmap phase is ended."
    
    # Verifying vulnerable hosts
    # Optimization: Parse ONCE into a file, then grep from that file.
    # Note: 'tac' is not POSIX (it is coreutils). 
    # If tac is missing, use: sed '1!G;h;$!d'
    
    TAC_CMD="tac"
    if ! command -v tac >/dev/null 2>&1; then
        TAC_CMD="sed '1!G;h;$!d'"
    fi

    # Create a consolidated file of vulnerability blocks
    for i in "${temp_nmap}"/*.nmap; do 
        [ -e "$i" ] || continue
        # Extract block from 'vulners' or 'VULNERABLE' up to 'Nmap' (reversed)
        eval "$TAC_CMD" "$i" | sed -n -e '/|_.*vulners.com\|VULNERABLE/,/^Nmap/p' | eval "$TAC_CMD"
    done > "${temp_dir}/all_vulns_raw.txt"

    vuln_hosts_count=$(grep -c "Nmap" "${temp_dir}/all_vulns_raw.txt")
    vuln_ports_count=$(grep -Eoc '(/udp.*open|/tcp.*open)' "${temp_dir}/all_vulns_raw.txt")
    
    # Get IPs
    grep "^Nmap scan report for" "${temp_dir}/all_vulns_raw.txt" | cut -d" " -f5 | sort -u > "${temp_dir}/vuln_ips.txt"

    current_date=$(date +%F_%H-%M-%S)

    if [ "${vuln_hosts_count}" != "0" ]; then
        warning_message_with_border "${vuln_hosts_count} vulnerable (or potentially vulnerable) host(s) found."
        
        # DNS Resolution for Report
        while read -r line; do
            host=$(dig @"${dns}" -x "${line}" +short)
            echo "${line} ${host}" >> "${temp_dir}"/vulnerable_hosts.txt
        done < "${temp_dir}/vuln_ips.txt"
    
        # Format list
        if [ -f "${temp_dir}/vulnerable_hosts.txt" ]; then
             vuln_hosts_format=$(awk '{print $1 "\t" $NF}' "${temp_dir}"/vulnerable_hosts.txt | sed 's/3(NXDOMAIN)/No reverse DNS entry found/' | sort -t . -n -k1,1 -k2,2 -k3,3 -k4,4 | sort -u)
        else
             vuln_hosts_format=""
        fi

        if [ "${host_parameter}" = "yes" ]; then
            sanitized_hosts_list=$(echo "${initial_hosts}" | tr '/\\:*?"<>,;' '_')
            hosts_file_no_path="${sanitized_hosts_list}"
        fi

        report_file="${report_folder}${hosts_file_no_path}_vulnerable-hosts-details_${current_date}.txt"
        
        printf "\t----------------------------\n" > "${report_file}"
        printf "Report date: %s\n" "$(date)" >> "${report_file}"
        printf "Host(s) found: %s\n" "${vuln_hosts_count}" >> "${report_file}"
        printf "Port(s) found: %s\n" "${vuln_ports_count}" >> "${report_file}"
        printf "%s\n" "${vuln_hosts_format}" >> "${report_file}"
        printf "All the details below." >> "${report_file}"
        printf "\n\t----------------------------\n" >> "${report_file}"
        cat "${temp_dir}/all_vulns_raw.txt" >> "${report_file}"
    else
        blue_info_message "No host seems to have any known vulnerabilities."
    fi

elif [ "${no_nmap_scan}" = "on" ] && [ "${report}" = "on" ]; then
    current_date=$(date +%F_%H-%M-%S)

    if [ "${host_parameter}" = "yes" ]; then
        sanitized_hosts_list=$(echo "${initial_hosts}" | tr '/\\:*?"<>,;' '_')

        blue_info_message "No Nmap scan to perform."
        blue_info_message "Host(s) discovered with an open port(s):"
        merge_ip_hostname
        cat "${temp_dir}"/IPs_hostnames_merged.txt
        
        mv "${temp_dir}"/IPs_hostnames_merged.txt "${report_folder}${sanitized_hosts_list}_open-ports_${current_date}.txt"
        yellow_info_message "The report is available here: ${report_folder}${sanitized_hosts_list}_open-ports_${current_date}.txt"
    else
        merge_ip_hostname
        mv "${temp_dir}"/IPs_hostnames_merged.txt "${report_folder}${hosts_file_no_path}_open-ports_${current_date}.txt"
        yellow_info_message "The report is available here: ${report_folder}${hosts_file_no_path}_open-ports_${current_date}.txt"
    fi
else
    blue_info_message "No Nmap scan to perform."
    blue_info_message "Host(s) discovered with an open port(s):"
    merge_ip_hostname
    cat "${temp_dir}"/IPs_hostnames_merged.txt
fi

##########################
# 4/4 Generating reports #
##########################

if [ "${host_parameter}" = "yes" ]; then
    sanitized_hosts_list=$(echo "${initial_hosts}" | tr '/\\:*?"<>,;' '_')
    hosts_file_no_path="${sanitized_hosts_list}"
fi

if [ "${no_nmap_scan}" != "on" ]; then
    nmap_bootstrap="${dir_name}/stylesheet/nmap-bootstrap.xsl"
    global_report="${hosts_file_no_path}_global-report_${current_date}.html"

    if [ -s "${report_folder}${hosts_file_no_path}_vulnerable-hosts-details_${current_date}.txt" ]; then
        yellow_info_message "All details on the vulnerabilities: ${report_folder}${hosts_file_no_path}_vulnerable-hosts-details_${current_date}.txt"
    fi

    # Merging all the Nmap XML files to one big XML file
    echo "<?xml version=\"1.0\"?>" > "${temp_dir}"/nmap-output.xml
    echo "<!DOCTYPE nmaprun PUBLIC \"-//IDN nmap.org//DTD Nmap XML 1.04//EN\" \"https://svn.nmap.org/nmap/docs/nmap.dtd\">" >> "${temp_dir}"/nmap-output.xml
    # Escaping quotes for echo
    echo "<?xml-stylesheet href=\"https://svn.nmap.org/nmap/docs/nmap.xsl\" type=\"text/xsl\"?>" >> "${temp_dir}"/nmap-output.xml
    echo "" >> "${temp_dir}"/nmap-output.xml
    
    # We can't access ${nmap_version} if it wasn't set earlier, ensuring fallback
    nmap_ver=${nmap_version:-"unknown"}
    
    echo "<nmaprun args=\"nmap --max-retries 2 --max-rtt-timeout 500ms -p[port(s)] -Pn -s(T|U) -sV -n --script ${script} [ip(s)]\" scanner=\"Nmap\" start=\"\" version=\"${nmap_ver}\" xmloutputversion=\"1.04\">" >> "${temp_dir}"/nmap-output.xml
    echo "<verbose level=\"0\" /><debug level=\"0\" />" >> "${temp_dir}"/nmap-output.xml

    for i in "${temp_nmap}"/*.xml; do
        [ -e "$i" ] || continue
        sed -n -e '/<host /,/<\/host>/p' "$i" >> "${temp_dir}"/nmap-output.xml
    done

    echo "<runstats><finished elapsed=\"\" exit=\"success\" summary=\"Nmap XML merge done at $(date); ${vuln_hosts_count} vulnerable host(s) found\" time=\"\" timestr=\"\" /><hosts down=\"0\" total=\"${nb_hosts_nmap}\" up=\"${nb_hosts_nmap}\" /></runstats></nmaprun>" >> "${temp_dir}"/nmap-output.xml

    # Using bootstrap to generate a beautiful HTML file (report)
    if command -v xsltproc >/dev/null 2>&1; then
        xsltproc -o "${report_folder}${global_report}" "${nmap_bootstrap}" "${temp_dir}"/nmap-output.xml 2>/dev/null
        yellow_info_message "HTML report generated: ${report_folder}${global_report}"
    else
        warning_message_with_border "xsltproc is missing. Cannot generate HTML report."
    fi

    # End of script
    task_completion_message "End of script execution."
else
    blue_info_message "No HTML report generated."
    task_completion_message "End of script execution."
fi

# Cleaning files
rm -rf "${temp_dir}" "${temp_nmap}" paused.conf 2>/dev/null

time_elapsed

exit 0