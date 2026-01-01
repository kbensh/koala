#!/bin/sh
# Sample 100000 people randomly from the input file for each team and save to separate files.
# warning: this may select the same person multiple times across different teams.
input="$1"
n_teams="$2"
out="$3"
for i in $(seq 1 $n_teams); do
    cat $input | shuf | head -n 10 > $out/team_$i.txt
done
