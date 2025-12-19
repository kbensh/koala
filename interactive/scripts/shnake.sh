#!/bin/sh
x="${1:-10}"
y="${2:-10}"
direction="${3:-up}"

while IFS= read -r line || [ -n "$line" ]; do
    i=0
    while [ $i -lt ${#line} ]; do
        key=$(printf '%s' "$line" | cut -c$((i+1)))
        i=$((i+1))
        
        case "$key" in
            ' '|'	') continue;;
        esac
        
        case "$key" in
            w) [ "$direction" != "down" ] && direction="up";;
            a) [ "$direction" != "right" ] && direction="left";;
            s) [ "$direction" != "up" ] && direction="down";;
            d) [ "$direction" != "left" ] && direction="right";;
            q) exit 0;;
            *) continue;;
        esac
        
        case "$direction" in
            up)    y=$((y - 1));;
            down)  y=$((y + 1));;
            left)  x=$((x - 1));;
            right) x=$((x + 1));;
        esac
        printf '%d,%d\n' "$x" "$y"
    done
done