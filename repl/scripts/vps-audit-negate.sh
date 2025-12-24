#!/bin/sh

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get current timestamp for the report filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="vps-audit-negate-report.txt"

print_header() {
    header="$1"
    echo -e "\n${BLUE}${BOLD}$header${NC}"
    echo -e "\n$header" >> "$REPORT_FILE"
    echo "================================" >> "$REPORT_FILE"
}

print_info() {
    label="$1"
    value="$2"
    echo -e "${BOLD}$label:${NC} $value"
    echo "$label: $value" >> "$REPORT_FILE"
}

# Start the audit
echo -e "${BLUE}${BOLD}VPS Security Audit Tool${NC}"
echo -e "${GRAY}https://github.com/vernu/vps-audit${NC}"
echo -e "${GRAY}Starting audit at $(date)${NC}\n"

echo "VPS Security Audit Tool" > "$REPORT_FILE"
echo "https://github.com/vernu/vps-audit" >> "$REPORT_FILE"
echo "Starting audit at $(date)" >> "$REPORT_FILE"
echo "================================" >> "$REPORT_FILE"

# System Information Section
print_header "System Information"

# Get system information
OS_INFO=$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
KERNEL_VERSION=$(uname -r)
HOSTNAME=$(hostname)
UPTIME=$(uptime -p)
UPTIME_SINCE=$(uptime -s)
CPU_INFO=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
CPU_CORES=$(nproc)
TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
TOTAL_DISK=$(df -h / | awk 'NR==2 {print $2}')
PUBLIC_IP=$(curl -s https://api.ipify.org)
LOAD_AVERAGE=$(uptime | awk -F'load average:' '{print $2}' | xargs)

# Print system information
print_info "Hostname" "$HOSTNAME"
print_info "Operating System" "$OS_INFO"
print_info "Kernel Version" "$KERNEL_VERSION"
print_info "Uptime" "$UPTIME (since $UPTIME_SINCE)"
print_info "CPU Model" "$CPU_INFO"
print_info "CPU Cores" "$CPU_CORES"
print_info "Total Memory" "$TOTAL_MEM"
print_info "Total Disk Space" "$TOTAL_DISK"
print_info "Public IP" "$PUBLIC_IP"
print_info "Load Average" "$LOAD_AVERAGE"

echo "" >> "$REPORT_FILE"

# Security Audit Section
print_header "Security Audit Results"

# Function to check and report with three states
check_security() {
    test_name="$1"
    status="$2"
    message="$3"
    
    case $status in
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $test_name ${GRAY}- $message${NC}"
            echo "[PASS] $test_name - $message" >> "$REPORT_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $test_name ${GRAY}- $message${NC}"
            echo "[WARN] $test_name - $message" >> "$REPORT_FILE"
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $test_name ${GRAY}- $message${NC}"
            echo "[FAIL] $test_name - $message" >> "$REPORT_FILE"
            ;;
    esac
    echo "" >> "$REPORT_FILE"
}

# Check system uptime
UPTIME=$(uptime -p)
UPTIME_SINCE=$(uptime -s)
echo -e "\nSystem Uptime Information:" >> "$REPORT_FILE"
echo "Current uptime: $UPTIME" >> "$REPORT_FILE"
echo "System up since: $UPTIME_SINCE" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo -e "System Uptime: $UPTIME (since $UPTIME_SINCE)"

# Check if system requires restart
if [ ! -f /var/run/reboot-required ]; then
    check_security "System Restart" "PASS" "No restart required"
else
    check_security "System Restart" "WARN" "System requires a restart to apply updates"
fi

# Check SSH config overrides
SSH_CONFIG_OVERRIDES=$(grep "^Include" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')

# Check SSH root login (handle both main config and overrides if they exist)
if [ ! -n "$SSH_CONFIG_OVERRIDES" ] || [ ! -d "$(dirname "$SSH_CONFIG_OVERRIDES")" ]; then
    SSH_ROOT=$(grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | head -1 | awk '{print $2}')
else
    SSH_ROOT=$(grep "^PermitRootLogin" "$SSH_CONFIG_OVERRIDES" /etc/ssh/sshd_config 2>/dev/null | head -1 | awk '{print $2}')
fi
if [ -z "$SSH_ROOT" ] || [ "$SSH_ROOT" != "no" ]; then
    check_security "SSH Root Login" "FAIL" "Root login is currently allowed - this is a security risk. Disable it in /etc/ssh/sshd_config"
else
    check_security "SSH Root Login" "PASS" "Root login is properly disabled in SSH configuration"
fi

# Check SSH password authentication (handle both main config and overrides if they exist)
if [ ! -n "$SSH_CONFIG_OVERRIDES" ] || [ ! -d "$(dirname "$SSH_CONFIG_OVERRIDES")" ]; then
    SSH_PASSWORD=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | head -1 | awk '{print $2}')
else
    SSH_PASSWORD=$(grep "^PasswordAuthentication" "$SSH_CONFIG_OVERRIDES" /etc/ssh/sshd_config 2>/dev/null | head -1 | awk '{print $2}')
fi
if [ -z "$SSH_PASSWORD" ] || [ "$SSH_PASSWORD" != "no" ]; then
    check_security "SSH Password Auth" "FAIL" "Password authentication is enabled - consider using key-based authentication only"
else
    check_security "SSH Password Auth" "PASS" "Password authentication is disabled, key-based auth only"
fi

# Check SSH default port
UNPRIVILEGED_PORT_START=$(sysctl -n net.ipv4.ip_unprivileged_port_start)
SSH_PORT=""
if [ ! -n "$SSH_CONFIG_OVERRIDES" ] || [ ! -d "$(dirname "$SSH_CONFIG_OVERRIDES")" ]; then
    SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | head -1 | awk '{print $2}')
else
    SSH_PORT=$(grep "^Port" "$SSH_CONFIG_OVERRIDES" /etc/ssh/sshd_config 2>/dev/null | head -1 | awk '{print $2}')
fi
if [ -z "$SSH_PORT" ] || [ "$SSH_PORT" = "22" ]; then
    check_security "SSH Port" "WARN" "Using default port 22 - consider changing to a non-standard port for security by obscurity"
elif [ "$SSH_PORT" -ge "$UNPRIVILEGED_PORT_START" ]; then
    check_security "SSH Port" "FAIL" "Using unprivileged port $SSH_PORT - use a port below $UNPRIVILEGED_PORT_START for better security"
else
    check_security "SSH Port" "PASS" "Using non-default port $SSH_PORT which helps prevent automated attacks"
fi

# Check Firewall Status
# check_firewall_status() {
#     if command -v ufw >/dev/null 2>&1; then
#         if ! ufw status | grep -q "active"; then
#             check_security "Firewall Status (UFW)" "FAIL" "UFW firewall is not active - your system is exposed to network attacks"
#         else
#             check_security "Firewall Status (UFW)" "PASS" "UFW firewall is active and protecting your system"
#         fi
#     elif command -v firewall-cmd >/dev/null 2>&1; then
#         if ! firewall-cmd --state 2>/dev/null | grep -q "running"; then
#             check_security "Firewall Status (firewalld)" "FAIL" "Firewalld is not active - your system is exposed to network attacks"
#         else
#             check_security "Firewall Status (firewalld)" "PASS" "Firewalld is active and protecting your system"
#         fi
#     elif command -v nft >/dev/null 2>&1; then
#         if ! nft list ruleset | grep -q "table"; then
#             check_security "Firewall Status (nftables)" "FAIL" "No active nftables rules found - your system may be exposed"
#         else
#             check_security "Firewall Status (nftables)" "PASS" "nftables rules are active and protecting your system"
#         fi
#     else
#         check_security "Firewall Status" "FAIL" "No recognized firewall tool is installed on this system"
#     fi
# }


# Firewall check
# check_firewall_status

# Check for unattended upgrades
if ! dpkg -l | grep -q "unattended-upgrades"; then
    check_security "Unattended Upgrades" "FAIL" "Automatic security updates are not configured - system may miss critical updates"
else
    check_security "Unattended Upgrades" "PASS" "Automatic security updates are configured"
fi

# Check fail2ban
if ! dpkg -l | grep -q "fail2ban"; then
    check_security "Fail2ban" "FAIL" "No brute force protection installed - system is vulnerable to login attacks"
else 
    if ! pgrep -x "fail2ban-server" >/dev/null 2>&1; then
        check_security "Fail2ban" "WARN" "Fail2ban is installed but not running - brute force protection is disabled"
    else
        check_security "Fail2ban" "PASS" "Brute force protection is active and running"
    fi
fi

# Check failed login attempts
FAILED_LOGINS=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
if [ "$FAILED_LOGINS" -lt 10 ]; then
    check_security "Failed Logins" "PASS" "Only $FAILED_LOGINS failed login attempts detected - this is within normal range"
elif [ "$FAILED_LOGINS" -lt 50 ]; then
    check_security "Failed Logins" "WARN" "$FAILED_LOGINS failed login attempts detected - might indicate breach attempts"
else
    check_security "Failed Logins" "FAIL" "$FAILED_LOGINS failed login attempts detected - possible brute force attack in progress"
fi

# Check system updates
UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -P '^\d+ upgraded' | cut -d" " -f1)
if [ "$UPDATES" -gt 0 ]; then
    check_security "System Updates" "FAIL" "$UPDATES security updates available - system is vulnerable to known exploits"
else
    check_security "System Updates" "PASS" "All system packages are up to date"
fi

# Check running services
SERVICES=$(ps --no-headers -eo cmd | wc -l)
if [ "$SERVICES" -ge 40 ]; then
    check_security "Running Services" "FAIL" "Too many services running ($SERVICES) - increases attack surface"
elif [ "$SERVICES" -ge 20 ]; then
    check_security "Running Services" "WARN" "$SERVICES services running - consider reducing attack surface"
else
    check_security "Running Services" "PASS" "Running minimal services ($SERVICES) - good for security"
fi

# Check ports using netstat or ss
if ! command -v netstat >/dev/null 2>&1; then
    if ! command -v ss >/dev/null 2>&1; then
        check_security "Port Scanning" "FAIL" "Neither 'netstat' nor 'ss' is available on this system."
        LISTENING_PORTS=""
    else
        LISTENING_PORTS=$(ss -tuln | grep LISTEN | awk '{print $5}')
    fi
else
    LISTENING_PORTS=$(netstat -tuln | grep LISTEN | awk '{print $4}')
fi

# Process LISTENING_PORTS to extract unique public ports
if [ -z "$LISTENING_PORTS" ]; then
    check_security "Port Scanning" "WARN" "Port scanning failed due to missing tools. Ensure 'ss' or 'netstat' is installed."
else
    PUBLIC_PORTS=$(echo "$LISTENING_PORTS" | awk -F':' '{print $NF}' | sort -n | uniq | tr '\n' ',' | sed 's/,$//')
    PORT_COUNT=$(echo "$PUBLIC_PORTS" | tr ',' '\n' | wc -w)
    INTERNET_PORTS=$(echo "$PUBLIC_PORTS" | tr ',' '\n' | wc -w)

    if [ "$PORT_COUNT" -ge 10 ] || [ "$INTERNET_PORTS" -ge 3 ]; then
        if [ "$PORT_COUNT" -ge 20 ] || [ "$INTERNET_PORTS" -ge 5 ]; then
            check_security "Port Security" "FAIL" "High exposure (Total: $PORT_COUNT, Public: $INTERNET_PORTS accessible ports): $PUBLIC_PORTS"
        else
            check_security "Port Security" "WARN" "Review recommended (Total: $PORT_COUNT, Public: $INTERNET_PORTS accessible ports): $PUBLIC_PORTS"
        fi
    else
        check_security "Port Security" "PASS" "Good configuration (Total: $PORT_COUNT, Public: $INTERNET_PORTS accessible ports): $PUBLIC_PORTS"
    fi
fi

# Function to format the message with proper indentation for the report file
format_for_report() {
    message="$1"
    echo "$message" >> "$REPORT_FILE"
}

# Check disk space usage
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
DISK_USAGE=$(df -h / | awk 'NR==2 {print int($5)}')
if [ "$DISK_USAGE" -ge 50 ]; then
    if [ "$DISK_USAGE" -ge 80 ]; then
        check_security "Disk Usage" "FAIL" "Critical disk space usage (${DISK_USAGE}% used - Used: ${DISK_USED} of ${DISK_TOTAL}, Available: ${DISK_AVAIL})"
    else
        check_security "Disk Usage" "WARN" "Disk space usage is moderate (${DISK_USAGE}% used - Used: ${DISK_USED} of ${DISK_TOTAL}, Available: ${DISK_AVAIL})"
    fi
else
    check_security "Disk Usage" "PASS" "Healthy disk space available (${DISK_USAGE}% used - Used: ${DISK_USED} of ${DISK_TOTAL}, Available: ${DISK_AVAIL})"
fi

# Check memory usage
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
MEM_AVAIL=$(free -h | awk '/^Mem:/ {print $7}')
MEM_USAGE=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
if [ "$MEM_USAGE" -ge 50 ]; then
    if [ "$MEM_USAGE" -ge 80 ]; then
        check_security "Memory Usage" "FAIL" "Critical memory usage (${MEM_USAGE}% used - Used: ${MEM_USED} of ${MEM_TOTAL}, Available: ${MEM_AVAIL})"
    else
        check_security "Memory Usage" "WARN" "Moderate memory usage (${MEM_USAGE}% used - Used: ${MEM_USED} of ${MEM_TOTAL}, Available: ${MEM_AVAIL})"
    fi
else
    check_security "Memory Usage" "PASS" "Healthy memory usage (${MEM_USAGE}% used - Used: ${MEM_USED} of ${MEM_TOTAL}, Available: ${MEM_AVAIL})"
fi

# Check CPU usage
CPU_CORES=$(nproc)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print int($8)}')
CPU_LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | awk -F',' '{ print $1 }' | tr -d ' ')
if [ "$CPU_USAGE" -ge 50 ]; then
    if [ "$CPU_USAGE" -ge 80 ]; then
        check_security "CPU Usage" "FAIL" "Critical CPU usage (${CPU_USAGE}% used - Active: ${CPU_USAGE}%, Idle: ${CPU_IDLE}%, Load: ${CPU_LOAD}, Cores: ${CPU_CORES})"
    else
        check_security "CPU Usage" "WARN" "Moderate CPU usage (${CPU_USAGE}% used - Active: ${CPU_USAGE}%, Idle: ${CPU_IDLE}%, Load: ${CPU_LOAD}, Cores: ${CPU_CORES})"
    fi
else
    check_security "CPU Usage" "PASS" "Healthy CPU usage (${CPU_USAGE}% used - Active: ${CPU_USAGE}%, Idle: ${CPU_IDLE}%, Load: ${CPU_LOAD}, Cores: ${CPU_CORES})"
fi

# Check sudo configuration
# if ! grep -q "^Defaults.*logfile" /etc/sudoers; then
#     check_security "Sudo Logging" "FAIL" "Sudo commands are not being logged - reduces audit capability"
# else
#     check_security "Sudo Logging" "PASS" "Sudo commands are being logged for audit purposes"
# fi

# Check password policy
if ! [ -f "/etc/security/pwquality.conf" ]; then
    check_security "Password Policy" "FAIL" "No password policy configured - system accepts weak passwords"
else
    if ! grep -q "minlen.*12" /etc/security/pwquality.conf; then
        check_security "Password Policy" "FAIL" "Weak password policy - passwords may be too simple"
    else
        check_security "Password Policy" "PASS" "Strong password policy is enforced"
    fi
fi

# Check for suspicious SUID files
COMMON_SUID_PATHS='^/usr/bin/|^/bin/|^/sbin/|^/usr/sbin/|^/usr/lib|^/usr/libexec'
KNOWN_SUID_BINS='ping$|sudo$|mount$|umount$|su$|passwd$|chsh$|newgrp$|gpasswd$|chfn$'

SUID_FILES=$(find / \
    \( -path /proc -o -path /sys -o -path /snap -o -path /mnt -o -path /var/lib/docker \) -prune -o \
    -type f -perm -4000 -print 2>/dev/null | \
    grep -v -E "$COMMON_SUID_PATHS" | \
    grep -v -E "$KNOWN_SUID_BINS" | \
    wc -l)

if [ "$SUID_FILES" -ne 0 ]; then
    check_security "SUID Files" "WARN" "Found $SUID_FILES SUID files outside standard locations - verify if legitimate"
else
    check_security "SUID Files" "PASS" "No suspicious SUID files found - good security practice"
fi

# Add system information summary to report
echo "================================" >> "$REPORT_FILE"
echo "System Information Summary:" >> "$REPORT_FILE"
echo "Hostname: $(hostname)" >> "$REPORT_FILE"
echo "Kernel: $(uname -r)" >> "$REPORT_FILE"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)" >> "$REPORT_FILE"
echo "CPU Cores: $(nproc)" >> "$REPORT_FILE"
echo "Total Memory: $(free -h | awk '/^Mem:/ {print $2}')" >> "$REPORT_FILE"
echo "Total Disk Space: $(df -h / | awk 'NR==2 {print $2}')" >> "$REPORT_FILE"
echo "================================" >> "$REPORT_FILE"

echo -e "\nVPS audit complete. Full report saved to $REPORT_FILE"
echo -e "Review $REPORT_FILE for detailed recommendations."

# Add summary to report
echo "================================" >> "$REPORT_FILE"
echo "End of VPS Audit Report" >> "$REPORT_FILE"
echo "Please review all failed checks and implement the recommended fixes." >> "$REPORT_FILE"