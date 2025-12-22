#!/usr/bin/env python3

import random
import os
random.seed(42)

def generate_random_ip():
    return f"{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(0, 255)}"

def generate_ip_file(filepath, count):
    directory = os.path.dirname(filepath)
    
    if directory and not os.path.exists(directory):
        try:
            os.makedirs(directory)
            print(f"Created directory: {directory}")
        except OSError as e:
            print(f"Error creating directory {directory}: {e}")
            return

    print(f"Generating {filepath} with {count:,} IP addresses...")
    
    try:
        with open(filepath, 'w') as f:
            for _ in range(count):
                f.write(generate_random_ip() + '\n')
        print(f"Success: {filepath} created")
    except IOError as e:
        print(f"Error writing to file {filepath}: {e}")

if __name__ == "__main__":
    base_dir = "../inputs"
    
    generate_ip_file(os.path.join(base_dir, "ips_min.txt"), 100)
    generate_ip_file(os.path.join(base_dir, "ips_small.txt"), 10_000)
    generate_ip_file(os.path.join(base_dir, "ips_full.txt"), 100_000)
    generate_ip_file(os.path.join(base_dir, "ping_min.txt"), 50)
    generate_ip_file(os.path.join(base_dir, "ping_small.txt"), 500)
    generate_ip_file(os.path.join(base_dir, "ping_full.txt"), 5000)