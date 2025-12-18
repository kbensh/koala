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

shnake_input="$input_dir/shnake_$size"
tetris_bag_input="$input_dir/tetris_bag_$size"
tetris_collision_input="$input_dir/tetris_collision_$size"

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

if should_run "ohmyzsh"; then
    echo "ohmyzsh"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/ohmyzsh.sh")"
    export BENCHMARK_SCRIPT
    export ZSH="$input_dir/ohmyzsh"
    mkdir -p "$ZSH"
    # Run in non-interactive mode
    RUNZSH=no CHSH=no $KOALA_SHELL "$scripts_dir/ohmyzsh.sh"
    echo $?
fi

if should_run "shnake"; then
    echo "shnake"
    BENCHMARK_INPUT_FILE="$shnake_input"
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/shnake.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL "$scripts_dir/shnake.sh" < "$shnake_input" > "$outputs_dir/shnake_${size}.out"
    echo $?
fi

if should_run "tetris-bag"; then
    echo "tetris-bag"
    BENCHMARK_INPUT_FILE="$tetris_bag_input"
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/tetris-bag.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL "$scripts_dir/tetris-bag.sh" < "$tetris_bag_input" > "$outputs_dir/tetris_bag_${size}.out"
    echo $?
fi

if should_run "tetris-collision"; then
    echo "tetris-collision"
    BENCHMARK_INPUT_FILE="$tetris_collision_input"
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/tetris-collision.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL "$scripts_dir/tetris-collision.sh" < "$tetris_collision_input" > "$outputs_dir/tetris_collision_${size}.out"
    echo $?
fi