#!/bin/sh
sequence() {
    awk "BEGIN { for (i = $1; i <= $3; i += $2) print i }"
}

comps() {
    _n="$1"
    _limit=$(echo "$_n vp" | dc)

    for p in $(primes "$_limit"); do
        sequence "$((2 * p))" "$p" "$_n"
    done | sort -u
}

primes() {
    _n="$1"

    if [ "$_n" -gt 2 ]; then
        tmp_comps="/tmp/sieve_$$.$_n"
        trap 'rm -f "$tmp_comps"' 0 1 2 15

        comps "$_n" > "$tmp_comps"

        sequence 2 1 "$_n" | sort | comm -23 - "$tmp_comps"

    elif [ "$_n" -eq 2 ]; then
        echo 2
    fi
}

limit="${1:-1000}"
out="$2"
primes "$limit" | sort -n | pr -t -w 80 -s' ' -5 >> $out