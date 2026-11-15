#!/bin/bash

IN=$1
OUT=$2
mkdir -p "$OUT"

ollama serve > /dev/null 2>&1 &
find "$IN" -type f -iname "*.jpg" | while IFS= read -r img; do
    title=$(llm -m ollama/moondream:latest \
        "Your only output should be a **single** small title for this image:" \
        -a "$img" -o seed 0 -o temperature 0 < /dev/null)

    base=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/ /_/g; s/[^a-z0-9_-]//g')
    filename="${base}.jpg"
    count=1

    while [ -e "$OUT/$filename" ]; do
        filename="${base}_$count.jpg"
        count=$((count + 1))
    done

    cp "$img" "$OUT/$filename"
done

ollama_pid=$(pgrep ollama)
kill $ollama_pid