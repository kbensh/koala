#!/bin/bash

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/interactive"
input_dir="${eval_dir}/inputs"
scripts_dir="${eval_dir}/scripts"
outputs_dir="${eval_dir}/outputs"
mkdir -p "$outputs_dir"

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

export BENCHMARK_CATEGORY="interactive"
KOALA_SHELL=${KOALA_SHELL:-bash}

shnake_input=$input_dir/shnake_$size
shtris_input=$input_dir/shtris_$size

should_run() {
    script_name=$1
    # If no scripts specified, run all
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

# Shnake game benchmark
if should_run "shnake"; then
    echo "shnake"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/shnake.sh")"
    export BENCHMARK_SCRIPT
    # Run in interactive mode
    export SHNAKE_OUTPUT_FILE="$TOP/interactive/outputs/shnake_output_$size"
    $KOALA_SHELL "$scripts_dir/shnake.sh"
    echo $?

    # Run in non-interactive mode

    # BENCHMARK_INPUT_FILE=$shnake_input
    # export BENCHMARK_INPUT_FILE
    # $KOALA_SHELL "$scripts_dir/shnake.sh" $shnake_input
    # pid=$!
    # wait $pid 2>/dev/null
    # echo $?
fi


# Shtris (Tetris) game benchmark
if should_run "shtris"; then
    echo "shtris"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/shtris.sh")"
    export BENCHMARK_SCRIPT
    export SHTRIS_OUTPUT_FILE="$TOP/interactive/outputs/shtris_output_$size"
    # Run in interactive mode
    export OUTPUT_FILE=
    $KOALA_SHELL "$scripts_dir/shtris.sh"
    echo $?
   
    # Run in non-interactive mode

    # BENCHMARK_INPUT_FILE=$shtris_input
    # export BENCHMARK_INPUT_FILE
    # $KOALA_SHELL "$scripts_dir/shnake.sh" $shtris_input
    # pid=$!
    # wait $pid 2>/dev/null
    # echo $?
fi

# Miniforge3 installer benchmark
if should_run "Miniforge3-Linux-x86_64" || should_run "miniforge" ; then
    echo "Miniforge3-Linux-x86_64"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/Miniforge3-Linux-x86_64.sh")"
    export BENCHMARK_SCRIPT
    
    # # Run in non-interactive mode
    # install_prefix="$outputs_dir/miniforge3_install"
    # mkdir -p "$install_prefix"
    
    #$KOALA_SHELL "$scripts_dir/Miniforge3-Linux-x86_64.sh" -b -p "$install_prefix"
    
    # Run in interactive mode

    $KOALA_SHELL "$scripts_dir/Miniforge3-Linux-x86_64.sh"
    echo $?
    
    # Cleanup installation
    # rm -rf "$install_prefix"
fi

# Oh My Zsh installer benchmark
if should_run "ohmyzsh"; then
    echo "ohmyzsh"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/ohmyzsh.sh")"
    export BENCHMARK_SCRIPT
    export ZSH="$input_dir/ohmyzsh"
    mkdir -p "$ZSH"
    # # Run in non-interactive mode
    # RUNZSH=no CHSH=no $KOALA_SHELL "$scripts_dir/ohmyzsh.sh"
    # Run in interactive mode
    $KOALA_SHELL "$scripts_dir/ohmyzsh.sh"
    echo $?
fi
