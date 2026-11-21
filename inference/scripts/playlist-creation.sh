#!/bin/bash

IN="$1"
OUT="$2"
mkdir -p "$OUT"

# files=$(find "$IN" -type f \( -iname "*.mp3" -o -iname "*.wav" \) | sort)
# num_files=$(printf '%s\n' "$files" | wc -l)

status=0

for dir_path in "$IN"/*; do
    [ -d "$dir_path" ] || continue
    dir=$(basename "$dir_path")
    echo "Processing directory: $dir"

    files=$(find "$dir_path" -type f -name "*.mp3" | sort)
    num_files=$(printf '%s\n' "$files" | wc -l)

    mkdir -p "$OUT/$dir"
    playlist_path="$OUT/$dir/playlist.m3u"
    rm -f "$playlist_path"

    abs_prefix=$(realpath "$dir_path")
    if ! llm embed-multi -m clap songs --binary --files "$abs_prefix" '*.mp3' --prefix "$abs_prefix/"; then
        echo "Embedding failed for $dir" >&2
        status=1
        continue
    fi

    first_song=$(printf '%s\n' "$files" | head -n 1)
    last_song=$(printf '%s\n' "$files" | tail -n 1)

    interpolated=$(mktemp)
    if ! llm interpolate songs "$first_song" "$last_song" -n "$num_files" > "$interpolated"; then
        echo "Interpolation failed for $dir" >&2
        rm -f "$interpolated"
        status=1
        continue
    fi

    if ! jq -e '.[]' "$interpolated" > "$playlist_path.tmp"; then
        echo "Interpolation produced no playlist entries for $dir" >&2
        rm -f "$interpolated" "$playlist_path.tmp"
        status=1
        continue
    fi

    rm -f "$interpolated"
    mv "$playlist_path.tmp" "$playlist_path"
done

exit $status
