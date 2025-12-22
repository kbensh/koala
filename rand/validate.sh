#!/bin/bash

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/rand"
outputs_dir="${eval_dir}/outputs"

mkdir -p "${outputs_dir}"
size="full"
generate=false
selected_scripts=""

pass_passwords=50000000
pass_length=32
n_teams=100000

while [ $# -gt 0 ]; do
    case "$1" in
        --generate)
            generate=true
            shift
            ;;
        --small)
            size="small"
            pass_passwords=500000
            pass_length=24
            n_teams=10000
            shift
            ;;
        --min)
            size="min"
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

cd "$outputs_dir" || exit

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

status=0

if should_run "pass"; then
    bench="pass_$size"
    file="pass_$size.txt"
    
    if [ ! -f "$file" ]; then
        status=1
    else
        line_count=$(wc -l < "$file")
        if [ "$line_count" -ne "$pass_passwords" ]; then
            status=1
        else
            bad_lines=$(awk -v len="$pass_length" 'length($0) != len { count++ } END { print count+0 }' "$file")
            if [ "$bad_lines" -ne 0 ]; then
                status=1
            fi
        fi
    fi
    echo $bench $status
fi

status=0
if should_run "pickname"; then
    bench="pickname_$size"
    dir="pickname_$size"
    
    if [ ! -d "$dir" ]; then
        status=1
    else
        file_count=$(find "$dir" -maxdepth 1 -name 'team_*.txt' -type f | wc -l)
        if [ "$file_count" -ne "$n_teams" ]; then
            status=1
        else
            # Check each file has 100000 lines
            bad_files=0
            for f in "$dir"/team_*.txt; do
                lines=$(wc -l < "$f")
                if [ "$lines" -ne 100000 ]; then
                    bad_files=$((bad_files + 1))
                fi
            done
            if [ "$bad_files" -ne 0 ]; then
                status=1
            fi
        fi
    fi
    echo $bench $status
fi
