import os
import random
random.seed(42)
SIZES = {
    "min": {
        "shnake_lines": 5,
        "shnake_len": 10,
        "tetris_ops": 20,
        "bag_count": 10
    },
    "small": {
        "shnake_lines": 50,
        "shnake_len": 50,
        "tetris_ops": 200,
        "bag_count": 100
    },
    "full": {
        "shnake_lines": 5000,
        "shnake_len": 1000,
        "tetris_ops": 20000,
        "bag_count": 10000
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

def generate_tetris_collision(size_key):
    """
    Generates inputs for tetris_collision.sh.
    Format: 'op x y' where op is 'c' (check) or 'd' (drop).
    x range: -2 to 12 (to test bounds).
    y range: -2 to 22.
    """
    config = SIZES[size_key]
    lines = []
    ops = ['c', 'd']
    
    for _ in range(config["tetris_ops"]):
        op = random.choice(ops)
        # Generate coordinates, occasionally out of bounds to test safety logic
        x = random.randint(-2, 11)
        y = random.randint(-2, 21)
        lines.append(f"{op} {x} {y}")
        
    return "\n".join(lines)

def generate_tetris_bag(size_key):
    """
    Generates inputs for tetris_bag.sh.
    Format: Integers (seeds) or empty lines (continue generation).
    """
    config = SIZES[size_key]
    lines = []
    
    for i in range(config["bag_count"]):
        if random.random() < 0.1:
            lines.append(str(random.randint(1, 99999)))
        else:
            # Empty line triggers the bag generation with current state
            lines.append("") 
            
    return "\n".join(lines)

def main():
    ensure_dir(OUTPUT_DIR)
    
    for size in SIZES.keys():
        print(f"Generating {size} inputs...")
        
        content = generate_shnake(size)
        with open(os.path.join(OUTPUT_DIR, f"shnake_{size}"), "w") as f:
            f.write(content)
            
        content = generate_tetris_collision(size)
        with open(os.path.join(OUTPUT_DIR, f"tetris_collision_{size}"), "w") as f:
            f.write(content)

        content = generate_tetris_bag(size)
        with open(os.path.join(OUTPUT_DIR, f"tetris_bag_{size}"), "w") as f:
            f.write(content)

    print(f"Done! Inputs generated in '{OUTPUT_DIR}/'.")

if __name__ == "__main__":
    main()