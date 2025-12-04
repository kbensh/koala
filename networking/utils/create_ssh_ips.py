#!/usr/bin/env python3

import random
import os
import datetime
random.seed(42)

def generate_random_ip():
    """
    Generates a random private IP address based on shell script logic:
    0: 192.168.x.x
    1: 10.x.x.x
    2: 172.16-31.x.x
    """
    choice = random.randint(0, 2)
    if choice == 0:
        # 192.168.x.x
        return f"192.168.{random.randint(0, 255)}.{random.randint(0, 255)}"
    elif choice == 1:
        # 10.x.x.x
        return f"10.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}"
    else:
        # 172.16-31.x.x
        return f"172.{random.randint(16, 31)}.{random.randint(0, 255)}.{random.randint(0, 255)}"

def generate_random_port():
    """
    Generates a random port, weighted towards common services or unprivileged ports.
    """
    # Shell script used $((RANDOM % 10))
    choice = random.randint(0, 9)
    
    ports = {
        0: 22,      # SSH
        1: 80,      # HTTP
        2: 443,     # HTTPS
        3: 3306,    # MySQL
        4: 5432,    # PostgreSQL
        5: 8080,    # Alt HTTP
        6: 3000,    # Dev server
        7: 27017,   # MongoDB
    }
    
    if choice in ports:
        return str(ports[choice])
    else:
        # Cases 8 and 9 (and default * in shell) -> Random unprivileged port
        # Shell logic: 1024 + RANDOM % 64512
        return str(random.randint(1024, 65535))

def generate_random_interface():
    """Generates a random network interface name."""
    interfaces = ["eth0", "eth1", "ens33", "enp0s3", "wlan0"]
    return random.choice(interfaces)

def generate_rule():
    """Generates a single firewall rule line: client_ip:port:interface:server_ip"""
    client_ip = generate_random_ip()
    port = generate_random_port()
    interface = generate_random_interface()
    server_ip = generate_random_ip()
    
    return f"{client_ip}:{port}:{interface}:{server_ip}"

def create_rules_file(num_rules, filepath):
    """Generates a file with num_rules firewall rules, including headers and comments."""
    print(f"Generating {filepath} with {num_rules} rules...")
    
    # Ensure directory exists
    directory = os.path.dirname(filepath)
    if directory and not os.path.exists(directory):
        try:
            os.makedirs(directory)
            print(f"Created directory: {directory}")
        except OSError as e:
            print(f"Error creating directory {directory}: {e}")
            return

    try:
        with open(filepath, 'w') as f:
            # Create header
            timestamp = datetime.datetime.now().strftime("%a %b %d %H:%M:%S %Z %Y")
            f.write("# Firewall Rules - Auto-generated for testing\n")
            f.write("# Format: client_ip:port:interface:server_ip\n")
            f.write(f"# Total rules: {num_rules}\n")
            f.write(f"# Generated: {timestamp}\n\n")
            
            for i in range(num_rules):
                # Add occasional comments for realism (every 50 lines, skipping 0)
                if i > 0 and i % 50 == 0:
                    f.write(f"\n# Rule batch {i // 50}\n")
                
                f.write(generate_rule() + "\n")
                
                # Progress indicator
                if (i + 1) % 1000 == 0:
                    print(f"  Progress: {i + 1}/{num_rules} rules")
                    
        print(f"  Finished: {filepath}")
        print("")
        
    except IOError as e:
        print(f"Error writing to file {filepath}: {e}")

if __name__ == "__main__":
    # Determine directory relative to script location
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
    except NameError:
        script_dir = os.getcwd()
        
    base_dir = os.path.join(script_dir, "../inputs")
    
    create_rules_file(100, os.path.join(base_dir, "ips_ssh_min.txt"))
    create_rules_file(1000, os.path.join(base_dir, "ips_ssh_small.txt"))
    create_rules_file(10000, os.path.join(base_dir, "ips_ssh_full.txt"))