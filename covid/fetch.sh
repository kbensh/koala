#!/bin/sh


TOP=$(git rev-parse --show-toplevel)
input_dir="${TOP}/covid/inputs"
URL="${KOALA_DATA_URL:-https://atlas.cs.brown.edu/data}/"

mkdir -p "$input_dir"

size=full
for arg in "$@"; do
    case "$arg" in
        --small) size=small ;;
        --min)   size=min ;;
    esac
done

if [ "$size" = "min" ]; then
    cp min_inputs/* "$input_dir/"
    exit 0
fi

if [ "$size" = "small" ]; then
    if [ -f "$input_dir/in_small.csv" ]; then
        exit 0
    fi
    curl --insecure "$URL"/covid-mts/in_small.csv.gz | gunzip > "$input_dir/in_small.csv"
    exit 0
fi

if [ -f "$input_dir/in.csv" ]; then
    exit 0
fi

curl --insecure "${URL}/covid-mts/in_full.csv.gz" | gunzip > "$input_dir/in.csv"
