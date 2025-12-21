#!/bin/bash

for arg in "$@"; do
    case "$arg" in
        "-f") force=true ;;
    esac
done

TOP=$(git rev-parse --show-toplevel)
input_dir="${TOP}/interactive/inputs"
outputs_dir="${TOP}/interactive/outputs"

rm -rf "$outputs_dir"
rm -rf $TOP/miniforge3
if [ "$force" = true ]; then
    rm -rf "$input_dir"
fi
