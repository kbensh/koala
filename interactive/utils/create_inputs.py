import os
import random

def generate_inputs():
    """
    Generates input files for shnake.sh and shtris.sh scripts.
    Creates files in interactive/inputs/ with the naming convention {script_name}_{suffix}.
    """
    
    # Configuration for the different input sizes
    configs = {
        "min": 5,
        "small": 50,
        "full": 5000
    }
    
    # Valid control keys for each script
    # shnake: w=up, a=left, s=down, d=right
    # shtris: 4=left, 6=right, x=rotate_cw, z=rotate_ccw, c=hold, 2=soft_drop, ' '=hard_drop
    script_configs = {
        "shnake": ['w', 'a', 's', 'd'],
        "shtris": ['4', '6', 'x', 'z', 'c', '2', ' ']
    }
    
    # Determine paths
    # Assumes this script runs from interactive/utils/
    current_dir = os.path.dirname(os.path.abspath(__file__))
    inputs_dir = os.path.join(os.path.dirname(current_dir), "inputs")
    
    # Create the inputs directory if it doesn't exist
    if not os.path.exists(inputs_dir):
        print(f"Creating directory: {inputs_dir}")
        os.makedirs(inputs_dir)
    
    for script_name, valid_moves in script_configs.items():
        for suffix, count in configs.items():
            filename = f"{script_name}_{suffix}"
            filepath = os.path.join(inputs_dir, filename)
            
            print(f"Generating {filename} with {count} moves...")
            
            # Generate random sequence of moves
            moves_data = "".join(random.choices(valid_moves, k=count))
            
            try:
                with open(filepath, "w") as f:
                    f.write(moves_data)
                print(f"Successfully wrote {filepath}")
            except IOError as e:
                print(f"Error writing to {filepath}: {e}")

if __name__ == "__main__":
    generate_inputs()