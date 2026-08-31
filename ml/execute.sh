#!/bin/sh


TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/ml"
scripts_dir="${eval_dir}/scripts"

VENV_DIR="$TOP/venv"
. "$VENV_DIR/bin/activate"

KOALA_SHELL=${KOALA_SHELL:-bash}
export BENCHMARK_CATEGORY="ml"
export LC_ALL=C

size="full"
for arg in "$@"; do
    case "$arg" in
        --small)
            size="small"
            ;;
        --min)
            size="min"
            ;;
    esac
done

echo "ml"
cd "$eval_dir" || exit 1 # scripts/execute.sh references PWD
 
BENCHMARK_SCRIPT="$(realpath "$scripts_dir/execute.sh")"
export BENCHMARK_SCRIPT

TMP="$eval_dir/inputs/input_$size"
export TMP
OUT="$eval_dir/outputs/out_$size"
export OUT
mkdir -p "$OUT"
export BENCHMARK_INPUT_FILE="$eval_dir/inputs/input_$size"
$KOALA_SHELL "$scripts_dir/execute.sh"
echo "$?"

