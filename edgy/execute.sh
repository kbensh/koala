#!/bin/bash

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/edgy"
input_dir="${eval_dir}/inputs"
scripts_dir="${eval_dir}/scripts"
outputs_dir="${eval_dir}/outputs"
mkdir -p "$outputs_dir"

export LC_ALL=C

size=full
selected_scripts=""
sieve_size=500000000
while [ $# -gt 0 ]; do
    case "$1" in
        --small)
            size=small
            sieve_size=100000000
            shift
            ;;
        --min)
            size=min
            sieve_size=10000000
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

export BENCHMARK_CATEGORY="edgy"
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

if should_run "sieve"; then
    echo "sieve"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/sieve.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL "$scripts_dir/sieve.sh" $sieve_size "$outputs_dir" "$outputs_dir/sieve_$size.txt"
    echo $?
fi

if should_run "try"; then
    echo "try"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/try.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL "$scripts_dir/try.sh" -y "mkdir -p /tmp/lib/edgy/test && echo 'works' > /tmp/lib/edgy/test/try_status.txt"> "$outputs_dir/try_out.txt"
    mv /tmp/lib/edgy/test/try_status.txt $outputs_dir
    echo $?
fi
