#!/bin/bash

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/edgy"
hashes_dir="${eval_dir}/hashes"
outputs_dir="${eval_dir}/outputs"
mkdir -p "${outputs_dir}"
mkdir -p "${hashes_dir}"
size="full"
generate=false
selected_scripts=""

while [ $# -gt 0 ]; do
    case "$1" in
        --generate)
            generate=true
            shift
            ;;
        --small)
            size="small"
            shift
            ;;
        --min)
            size="min"
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

cd "$outputs_dir" || exit

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

if $generate; then
    if should_run "sieve"; then
        md5sum "sieve_$size.txt" > "$hashes_dir/sieve_$size.md5sum"
    fi
    if should_run "try"; then
        md5sum "try_out.txt" > "$hashes_dir/try_out.md5sum"
        md5sum "try_test.txt" > "$hashes_dir/try_tes.md5sum"
    fi     
    exit 0
fi

if should_run "sieve"; then
    bench=sieve_$size
    md5sum --check --quiet --status "$hashes_dir/$bench.md5sum"
    echo $bench $?
fi

if should_run "try"; then
    bench=try
    md5sum --check --quiet --status "$hashes_dir/try_out.md5sum"
    md5sum --check --quiet --status "$hashes_dir/try_tes.md5sum"
    echo $bench $?
fi 