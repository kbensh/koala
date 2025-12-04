#!/bin/bash

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/networking"
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

export BENCHMARK_CATEGORY="networking"
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

# accept-ips benchmark
if should_run "accept-ips"; then
    echo "accept-ips"
    BENCHMARK_INPUT_FILE="$input_dir/ips_$size.txt"
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/accept-ips.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/accept-ips.sh $input_dir/ips_$size.txt
    echo $?
fi

# block-country-ips benchmark
if should_run "block-country-ips"; then
    echo "block-country-ips"
    BENCHMARK_INPUT_FILE="$input_dir/ips_$size.txt"
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/block-country-ips.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/block-country-ips.sh $input_dir/ips_$size.txt open dummy
    echo $?
fi

if should_run "get-ip"; then
    echo "get-ip"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/get-ip.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/get-ip.sh
    echo $?
fi

if should_run "networkconf"; then
    echo "networkconf"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/networkconf.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/networkconf.sh
    echo $?
fi

if should_run "pingsweep"; then
    echo "pingsweep"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/pingsweep.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/pingsweep.sh
    echo $?
fi

if should_run "ssh-ips"; then
    echo "ssh-ips"
    BENCHMARK_INPUT_FILE="$input_dir/ips_ssh_$size.txt"
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/ssh-ips.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/ssh-ips.sh "$input_dir/ips_ssh_$size.txt"
    echo $?
fi

if should_run "wifi-strength"; then
    echo "wifi-strength"
    BENCHMARK_INPUT_FILE=""
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/wifi-strength.sh")"
    export BENCHMARK_SCRIPT
    sudo $KOALA_SHELL $scripts_dir/wifi-strength.sh wlan0
    echo $?
fi


# onetwopunch benchmark
if should_run "onetwopunch"; then
    echo "onetwopunch"
    BENCHMARK_INPUT_FILE="$input_dir/localhost.txt"
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/onetwopunch.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL $scripts_dir/onetwopunch.sh -t localhost.txt -i lo -p all
    echo $?
fi

# massvulscan benchmark
if should_run "massvulscan"; then
    echo "massvulscan"
    BENCHMARK_INPUT_FILE="$input_dir/localhost.txt"
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/massvulscan.sh")"
    export BENCHMARK_SCRIPT
    sudo $KOALA_SHELL $scripts_dir/massvulscan.sh -a -f localhost.txt
    echo $?
fi


