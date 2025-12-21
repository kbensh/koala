import os
import random
random.seed(42)
SIZES = {
    "min": {
        "shnake_lines": 50,
        "shnake_len": 1000,
    },
    "small": {
        "shnake_lines": 1000,
        "shnake_len": 1000,
    },
    "full": {
        "shnake_lines": 5000,
        "shnake_len": 1000,
    }
}

OUTPUT_DIR = "inputs"

def ensure_dir(directory):
    if not os.path.exists(directory):
        os.makedirs(directory)

def generate_shnake(size_key):
    """
    Generates inputs for shnake.sh.
    Format: Strings of characters 'w', 'a', 's', 'd'.
    """
    config = SIZES[size_key]
    lines = []
    keys = ['w', 'a', 's', 'd']
    
    for _ in range(config["shnake_lines"]):
        line = "".join(random.choices(keys, k=config["shnake_len"]))
        lines.append(line)
    
    return "\n".join(lines)

def main():
    ensure_dir(OUTPUT_DIR)
    
    for size in SIZES.keys():
        print(f"Generating {size} inputs...")
        
        content = generate_shnake(size)
        with open(os.path.join(OUTPUT_DIR, f"shnake_{size}"), "w") as f:
            f.write(content)

    print(f"Done! Inputs generated in '{OUTPUT_DIR}/'.")

if __name__ == "__main__":
    main()