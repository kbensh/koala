#!/bin/bash

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/rand"
input_dir="${eval_dir}/inputs"
scripts_dir="${eval_dir}/scripts"
outputs_dir="${eval_dir}/outputs"
mkdir -p "$outputs_dir"

export LC_ALL=C

size=full
selected_scripts=""
pass_passwords=50000000
pass_length=32
n_teams=100000
while [ $# -gt 0 ]; do
    case "$1" in
        --small)
            size=small
            pass_passwords=500000
            pass_length=24
            n_teams=10000
            shift
            ;;
        --min)
            size=min
            pass_passwords=5000
            pass_length=16
            n_teams=100
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

export BENCHMARK_CATEGORY="rand"
KOALA_SHELL=${KOALA_SHELL:-bash}

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

if should_run "pass"; then
    echo "pass"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/pass.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL "$scripts_dir/pass.sh" $pass_passwords  $pass_length > "$outputs_dir/pass_$size.txt"
    echo $?
fi

mkdir -p $outputs_dir/pickname_$size

if should_run "pickname"; then
    echo "pickname"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/pickname.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL "$scripts_dir/pickname.sh" $input_dir/all_names.txt $n_teams $outputs_dir/pickname_$size
fi
