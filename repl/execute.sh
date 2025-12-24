#!/bin/bash

# For sysctl
export PATH="$PATH:/sbin:/usr/sbin"

KOALA_SHELL=${KOALA_SHELL:-bash}
TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/repl"
scripts_dir="${eval_dir}/scripts"
main_script_1="${scripts_dir}/vps-audit.sh"
main_script_2="${scripts_dir}/vps-audit-negate.sh"

export BENCHMARK_CATEGORY="repl"

selected_scripts=""
NUM_COMMITS=21

while [ $# -gt 0 ]; do
    case "$1" in
        --min)
            NUM_COMMITS=2
            shift
            ;;
        --small)
            NUM_COMMITS=6
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

if should_run "vps-audit"; then
    BENCHMARK_SCRIPT="$(realpath "$main_script_1")"
    export BENCHMARK_SCRIPT
    echo "Starting VPS audit..."
    ${KOALA_SHELL} "${main_script_1}"
    echo $?
fi

if should_run "vps-audit-negate"; then
    BENCHMARK_SCRIPT="$(realpath "$main_script_2")"
    export BENCHMARK_SCRIPT
    ${KOALA_SHELL} "${main_script_2}"
    echo $?
fi

if should_run "git-workflow"; then
    echo "Starting git workflow..."
    git_script="${scripts_dir}/git-workflow.sh"

    export BENCHMARK_SCRIPT="$git_script"
    export BENCHMARK_INPUT_FILE="${eval_dir}/inputs"

    mkdir -p "${eval_dir}/outputs"
    export NUM_COMMITS
    if "$KOALA_SHELL" --posix "$git_script" "$NUM_COMMITS"; then
        exit_code=$?
    else
        # fallback to normal shell invocation
        "$KOALA_SHELL" "$git_script" "$NUM_COMMITS"
        exit_code=$?
    fi
    echo "$exit_code"
fi