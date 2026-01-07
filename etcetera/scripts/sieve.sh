#!/bin/sh

sqrt() { echo "$1 v p" | dc; }

sequence_2_to() {
    awk -v limit="$1" 'BEGIN { for (i=2; i<=limit; i++) print i }'
}

sequence() {
    awk -v start="$1" -v step="$2" -v limit="$3" '
    BEGIN {
        for (i = start; i <= limit; i += step)
            print i
    }'
}

get_multiples() {
    p=$1
    limit=$2
    start=$((p * 2))
    
    if [ "$start" -le "$limit" ]; then
        sequence "$start" "$p" "$limit"
    fi
}

gen_composites() {
    n=$1
    limit_root=$(sqrt "$n")
    
    primes "$limit_root" | while read p; do
        get_multiples "$p" "$n"
    done | sort -u
}

primes() {
    n=${1:-1000}

    if [ "$n" -lt 2 ]; then
        return
    fi

    tmp_dir=$(mktemp -d) || exit 1
    trap 'rm -rf "$tmp_dir"; exit' EXIT INT TERM
    pipe_path="$tmp_dir/pipe"

    mkfifo "$pipe_path"

    ( 
        gen_composites "$n" > "$pipe_path" 
    ) 2>/dev/null &
    pid_writer=$!

    sequence_2_to "$n" | sort | comm -23 - "$pipe_path"

    wait "$pid_writer"
    rm -r "$tmp_dir"
}

primes "${1:-1000}" | sort -n | pr -t -w 80 -4 > $2