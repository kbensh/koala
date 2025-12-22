#!/bin/sh
# generate a sequence of n passwords, each of length l

n="$1"
l="$2"

for _ in $(seq 1 "$n"); do
    pswd=$(LC_ALL=C tr -dc 'A-Za-z0-9_@#$%&*-' </dev/urandom | head -c "$l")
    echo "$pswd"
done
