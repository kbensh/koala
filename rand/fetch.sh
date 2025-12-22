#!/bin/bash

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/rand"
input_dir="${eval_dir}/inputs"

mkdir -p $input_dir/ssa_names_temp
cd "$input_dir/ssa_names_temp"

wget -q https://www.ssa.gov/oact/babynames/names.zip
unzip -o -q names.zip
cat *.txt | cut -d',' -f1 > ../all_names.txt
cd ..
rm -rf ssa_names_temp
