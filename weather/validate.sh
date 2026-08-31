#!/bin/sh


set -e

TOP=$(git rev-parse --show-toplevel)

eval_dir="${TOP}/weather"

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

statistics_dir="${eval_dir}/outputs/statistics.$size"
correct_dir="${eval_dir}/correct-results/statistics.$size"

normalize_weather_path() {
    candidate="$1"
    candidate=$(printf '%s' "$candidate" | tr -d '\r')
    candidate=$(printf '%s' "$candidate" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    case "$candidate" in
        *"/weather/"*)
            printf '%s\n' "${candidate#*"/weather/"}"
            ;;
        *)
            printf '%s\n' "$candidate"
            ;;
    esac
}

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

if $generate; then
    if should_run "max-temp"; then
        mkdir -p "$correct_dir"
        cp -r "$statistics_dir"/* "$correct_dir"
    fi
    
    if should_run "tuft-weather"; then
        hash_dir="$eval_dir/hashes/$size"
        hash_file="$hash_dir/tuft-weather.hash"
        plot_root="$eval_dir/outputs/$size/plots"

        mkdir -p "$hash_dir"
        
        find "$plot_root" -type f -name '*.png' ! -path '*/tmp/*' -print0 |
            sort -z | tr '\0' '\n' > "$hash_file"
    fi
    
    exit 0
fi

if should_run "max-temp"; then
    diff -q "$statistics_dir/average.txt" "$correct_dir/average.txt"
    echo average.$size $?

    diff -q "$statistics_dir/min.txt" "$correct_dir/min.txt"
    echo min.$size $?

    diff -q "$statistics_dir/max.txt" "$correct_dir/max.txt"
    echo max.$size $?
fi

if should_run "tuft-weather"; then
    hash_dir="$eval_dir/hashes/$size"
    hash_file="$hash_dir/tuft-weather.hash"
    plot_root="$eval_dir/outputs/$size/plots"

    all_exist=true
    while IFS= read -r filepath; do
        [ -n "$filepath" ] || continue

        normalized_path=$(normalize_weather_path "$filepath")
        expected_path="$eval_dir/$normalized_path"

        if [ ! -f "$expected_path" ]; then
            echo "Missing: $expected_path"
            all_exist=false
            break
        fi
    done < "$hash_file"

    if [ "$all_exist" = true ]; then
        echo "tuft-weather 0"
    else
        echo "tuft-weather 1"
    fi
fi