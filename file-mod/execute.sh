#!/bin/sh

TOP=$(git rev-parse --show-toplevel)

export PATH="/usr/local/legacy-bin:$PATH"

eval_dir="${TOP}/file-mod"
input_dir="${eval_dir}/inputs"
outputs_dir="${eval_dir}/outputs"
scripts_dir="${eval_dir}/scripts"
mkdir -p "$outputs_dir"

img_convert_input="$input_dir/jpg_full/jpg"
to_mp3_input="$input_dir/wav_full"
suffix=".full"
size="full"
input_pcaps="$input_dir/pcaps"
selected_scripts=""

while [ $# -gt 0 ]; do
    case "$1" in
        --small)
            img_convert_input="$input_dir/jpg_small/jpg"
            to_mp3_input="$input_dir/wav_small"
            suffix=".small"
            size="small"
            shift
            ;;
        --min)
            img_convert_input="$input_dir/jpg_min/jpg"
            to_mp3_input="$input_dir/wav_min"
            suffix=".min"
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

input_pcaps="$input_dir/pcaps_$size"

KOALA_SHELL=${KOALA_SHELL:-bash}

BENCHMARK_CATEGORY="file-mod"
export BENCHMARK_CATEGORY

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

if should_run "compress_files"; then
    BENCHMARK_INPUT_FILE="$(realpath "$input_pcaps")"
    export BENCHMARK_INPUT_FILE

    echo "compress_files"
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/compress_files.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL "$scripts_dir/compress_files.sh" "$input_pcaps" "$outputs_dir/compress_files$suffix"
    echo $?
fi

if should_run "encrypt_files"; then
    BENCHMARK_INPUT_FILE="$(realpath "$input_pcaps")"
    export BENCHMARK_INPUT_FILE

    echo "encrypt_files"
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/encrypt_files.sh")"
    export BENCHMARK_SCRIPT
    $KOALA_SHELL "$scripts_dir/encrypt_files.sh" "$input_pcaps" "$outputs_dir/encrypt_files$suffix"
    echo $?
fi

if should_run "img_convert"; then
    echo "img_convert"
    BENCHMARK_INPUT_FILE="$(realpath "$img_convert_input")"
    export BENCHMARK_INPUT_FILE

    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/img_convert.sh")"
    export BENCHMARK_SCRIPT

    $KOALA_SHELL "$scripts_dir/img_convert.sh" "$img_convert_input" "$outputs_dir/img_convert$suffix" > "$outputs_dir/img_convert$suffix.log"
    echo $?
fi

if should_run "to_mp3"; then
    echo "to_mp3"
    BENCHMARK_INPUT_FILE="$(realpath "$to_mp3_input")"
    export BENCHMARK_INPUT_FILE
    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/to_mp3.sh")"
    export BENCHMARK_SCRIPT

    $KOALA_SHELL "$scripts_dir/to_mp3.sh" "$to_mp3_input" "$outputs_dir/to_mp3$suffix" > "$outputs_dir/to_mp3$suffix.log"
    echo $?
fi

if should_run "thumbnail_generation"; then
    echo "thumbnail_generation"
    BENCHMARK_INPUT_FILE="$(realpath "$img_convert_input")"
    export BENCHMARK_INPUT_FILE

    BENCHMARK_SCRIPT="$(realpath "$scripts_dir/thumbnail_generation.sh")"
    export BENCHMARK_SCRIPT
    mkdir -p "$outputs_dir/thumbnail$suffix"
    $KOALA_SHELL "$scripts_dir/thumbnail_generation.sh" "$img_convert_input" "$outputs_dir/thumbnail$suffix" > "$outputs_dir/thumbnail$suffix.log"
    echo $?
fi