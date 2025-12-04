#!/bin/bash

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/interactive"
input_dir="${eval_dir}/inputs"
scripts_dir="${eval_dir}/scripts"
outputs_dir="${eval_dir}/outputs"

export LC_ALL=C

size=full
selected_scripts=""

while [ $# -gt 0 ]; do
    case "$1" in
        --small)
            size=small
            shift
            ;;
        --min)
            size=min
            shift
            ;;
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
        *)
            shift
            ;;
    esac
done

should_run() {
    script_name=$1
    if [ -z "$selected_scripts" ]; then
        return 0
    fi
    for selected in $selected_scripts; do
        if [ "$selected" = "$script_name" ]; then
            return 0
        fi
    done
    return 1
}

validate_result=0

if should_run "shnake"; then
    export SHNAKE_OUTPUT_FILE="$TOP/interactive/outputs/shnake_output_$size"
    # Validate that the output file contains a '0'
    if [ -f "$SHNAKE_OUTPUT_FILE" ]; then
        if grep -q '0' "$SHNAKE_OUTPUT_FILE"; then
            echo "OK: shnake"
        else
            echo "FAILED: shnake"
            validate_result=1
        fi
    else
        echo "FAILED: shnake."
        validate_result=1
    fi
fi

if should_run "shtris"; then
    export SHTRIS_OUTPUT_FILE="$TOP/interactive/outputs/shtris_output_$size"
    # Validate that the output file contains a '0'
    if [ -f "$SHTRIS_OUTPUT_FILE" ]; then
        if grep -q '0' "$SHTRIS_OUTPUT_FILE"; then
            echo "OK: shtris"
        else
            echo "FAILED: shtris"
            validate_result=1
        fi
    else
        echo "FAILED: shtris."
        validate_result=1
    fi
fi

if should_run "Miniforge3-Linux-x86_64" || should_run "miniforge"; then
    # Check paths (Batch vs Interactive locations)
    BATCH_INSTALL_PATH="$outputs_dir/miniforge3_install/bin/conda"
    HOME_INSTALL_PATH="$HOME/miniforge3/bin/conda"
    HOME_CONDA_PATH="$HOME/miniconda3/bin/conda"

    CONDA_BIN=""
    if [ -f "$BATCH_INSTALL_PATH" ]; then CONDA_BIN="$BATCH_INSTALL_PATH"
    elif [ -f "$HOME_INSTALL_PATH" ]; then CONDA_BIN="$HOME_INSTALL_PATH"
    elif [ -f "$HOME_CONDA_PATH" ]; then CONDA_BIN="$HOME_CONDA_PATH"
    fi

    if [ -n "$CONDA_BIN" ]; then
        if "$CONDA_BIN" --version > /dev/null 2>&1; then
             VERSION=$("$CONDA_BIN" --version)
             echo "OK: Found $VERSION at $CONDA_BIN"
        else
             echo "FAILED: Conda binary found but execution failed."
             validate_result=1
        fi
    else
        echo "FAILED: Could not find 'conda' binary in standard locations."
        validate_result=1
    fi
fi

if should_run "ohmyzsh"; then
    # The execute script exports ZSH to outputs_dir. 
    # If run interactively without that export, it likely went to ~/.oh-my-zsh
    EXPECTED_ZSH_DIR="$outputs_dir/ohmyzsh_install"
    DEFAULT_ZSH_DIR="$HOME/.oh-my-zsh"

    if [ -f "$EXPECTED_ZSH_DIR/oh-my-zsh.sh" ]; then
        echo "OK: Oh My Zsh found in output directory."
    elif [ -f "$DEFAULT_ZSH_DIR/oh-my-zsh.sh" ]; then
        echo "OK: Oh My Zsh found in default home directory."
    else
        echo "FAILED: oh-my-zsh.sh not found in $EXPECTED_ZSH_DIR or $DEFAULT_ZSH_DIR"
        validate_result=1
    fi
fi

if [ $validate_result -eq 0 ]; then
    exit 0
else
    exit 1
fi