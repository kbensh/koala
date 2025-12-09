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
echo "127.0.0.1" > $input_dir/localhost.txt
echo "10.200.1.1" > "$input_dir/gateway_target.txt"
