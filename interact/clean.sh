#!/bin/bash

for arg in "$@"; do
    case "$arg" in
        "-f") force=true ;;
    esac
done

TOP=$(git rev-parse --show-toplevel)
input_dir="${TOP}/interact/inputs"
outputs_dir="${TOP}/interact/outputs"

rm -rf "$outputs_dir"
if [ "$force" = true ]; then
    rm -rf "$input_dir"
fi