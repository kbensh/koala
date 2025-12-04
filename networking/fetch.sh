#!/bin/sh
set -e

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/networking"
input_dir="${eval_dir}/inputs"
KOALA_SHELL=${KOALA_SHELL:-bash}
cd "$(realpath "$(dirname "$0")")" || exit 1
cd utils
python3 create_ips.py
python3 create_ssh_ips.py
$KOALA_SHELL "mock_iw.sh"