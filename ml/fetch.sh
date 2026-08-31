#!/bin/sh


TOP=$(git rev-parse --show-toplevel)

VENV_DIR="$TOP/venv"
. "$VENV_DIR/bin/activate"

eval_dir="${TOP}/ml"
input_dir="${eval_dir}/inputs"
parsed_args=""
size="full"
for arg in "$@"; do
    case "$arg" in
        --small)
            parsed_args="$parsed_args $arg"
            size="small"
            ;;
        --min)
            parsed_args="$parsed_args $arg"
            size="min"
            ;;
    esac
done

mkdir -p "$eval_dir/outputs"
mkdir -p "$input_dir/input_$size"

export TMP="$input_dir/input_$size"
mkdir -p "$TMP"
# Generating model & samples
python3 "$eval_dir/scripts/gen_model.py" 1000
python3 "$eval_dir/scripts/gen_samples.py" $parsed_args
