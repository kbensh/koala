#!/bin/sh


eval_dir=$(realpath "$(dirname "$0")")

export LC_ALL=C
suffix=".full"
generate=false
selected_scripts=""

while [ $# -gt 0 ]; do
    case "$1" in
        --generate)
            generate=true
            shift
            ;;
        --small)
            suffix=".small"
            shift
            ;;
        --min)
            suffix=".min"
            shift
            ;;
        -s|--scripts)
            shift
            while [ $# -gt 0 ] && [ "$(echo "$1" | cut -c1)" != "-" ]; do
                if [ -z "$selected_scripts" ]; then
                    selected_scripts="$1"
                else
                    selected_scripts="$selected_scripts $1"
                fi
                shift
            done
            ;;
        *)
            shift
            ;;
    esac
done

hashes_dir="$eval_dir/hashes"

should_run() {
    script_name=$1
    if [ -z "$selected_scripts" ]; then
        return 0
    fi
    for selected in $selected_scripts; do
        if [ "$selected" = "$script_name" ]; then
            return 0
        fi
    done
    return 1
}

validate_playlist() {
    playlist=$1
    input_dir=$2
    songs_root=$3

    if [ ! -s "$playlist" ]; then
        echo "Playlist $playlist is missing or empty"
        return 1
    fi

    expected=$(find "$input_dir" -type f -name "*.mp3" | sort)
    expected_count=$(printf '%s\n' "$expected" | wc -l)
    expected_first=$(realpath "$(printf '%s\n' "$expected" | head -n 1)")
    expected_last=$(realpath "$(printf '%s\n' "$expected" | tail -n 1)")

    entries=$(sed 's/^"//; s/"$//' "$playlist")
    count=$(printf '%s\n' "$entries" | wc -l)

    if [ "$count" -ne "$expected_count" ]; then
        echo "Playlist $playlist has $count entries, expected $expected_count"
        return 1
    fi

    if [ "$(printf '%s\n' "$entries" | sort -u | wc -l)" -ne "$count" ]; then
        echo "Playlist $playlist contains duplicate entries"
        return 1
    fi

    while IFS= read -r entry; do
        case "$entry" in
            "$songs_root"/*.mp3) ;;
            *)
                echo "Playlist $playlist has an entry outside the inputs: $entry"
                return 1
                ;;
        esac
        if [ ! -f "$entry" ]; then
            echo "Playlist $playlist has an entry that does not exist: $entry"
            return 1
        fi
    done <<EOF
$entries
EOF

    if [ "$(printf '%s\n' "$entries" | head -n 1)" != "$expected_first" ]; then
        echo "Playlist $playlist does not start at $expected_first"
        return 1
    fi

    if [ "$(printf '%s\n' "$entries" | tail -n 1)" != "$expected_last" ]; then
        echo "Playlist $playlist does not end at $expected_last"
        return 1
    fi

    return 0
}

if $generate; then
    mkdir -p "$hashes_dir"

    if should_run "playlist-creation"; then
        echo "Generating file list for playlist-creation"

        outputs_dir="outputs/songs$suffix"
        
        filelist="$hashes_dir/songs$suffix.files"
        cd "$outputs_dir" || exit 1
        > "$filelist"
        for dir in *; do
            if [ -d "$dir" ] && [ -f "$dir/playlist.m3u" ]; then
                echo "$dir/playlist.m3u" >> "$filelist"
            fi
        done

        cd "$eval_dir" || exit 1
        echo "File list generated at $filelist"
    fi

    if should_run "image-annotation"; then
        echo "Generating hashes for image-annotation"

        hashes_dir_jpg="${hashes_dir}/jpg$suffix"
        mkdir -p "$hashes_dir_jpg"

        outputs_dir="outputs/jpg$suffix"
        bench=image-annotation$suffix
        md5sum $outputs_dir/* > "$hashes_dir_jpg/$bench.md5sum"
        echo "Hashes generated at $hashes_dir_jpg/$bench.md5sum"
    fi

    if should_run "dpt"; then
        outputs_dir="outputs"    
        python3 clean_output.py "$outputs_dir/dpt_output$suffix.txt" "$outputs_dir/dpt_output$suffix-cleaned.txt"
        dpt_hash=$(shasum -a 256 "$outputs_dir/dpt_output$suffix-cleaned.txt" | awk '{ print $1 }')
        echo "$dpt_hash" > "$hashes_dir/dpt_output$suffix.txt"
    fi

    exit 0
fi

if should_run "playlist-creation"; then
    bench=playlist-creation$suffix
    outputs_dir="outputs/songs$suffix"
    filelist="$hashes_dir/songs$suffix.files"

    songs_dir=$(realpath "$eval_dir/inputs/songs$suffix")

    cd "$outputs_dir" || exit 1
    status=0

    if [ -f "$filelist" ]; then
        while read -r file; do
            if ! validate_playlist "$file" "$songs_dir/$(dirname "$file")" "$songs_dir"; then
                status=1
            fi
        done < "$filelist"
    else
        echo "File list not found: $filelist"
        status=1
    fi

    echo "$bench $status"

    cd "$eval_dir" || exit 1
fi

if should_run "image-annotation"; then
    bench=image-annotation$suffix

    hashes_dir_jpg="${hashes_dir}/jpg$suffix"
    outputs_dir="outputs/jpg$suffix"

    if [ ! -d "$outputs_dir" ]; then
        echo "Outputs directory not found: $outputs_dir"
        echo $bench 1
    elif [ ! -d "$hashes_dir_jpg" ]; then
        echo "Hashes directory not found: $hashes_dir_jpg"
        echo $bench 1
    else
        md5sum --check --quiet --status $hashes_dir_jpg/$bench.md5sum
        echo $bench $?
    fi
fi

if should_run "dpt"; then
    outputs_dir="outputs"
    python3 clean_output.py "$outputs_dir/dpt_output$suffix.txt" "$outputs_dir/dpt_output$suffix-cleaned.txt"
    dpt_hash=$(shasum -a 256 "$outputs_dir/dpt_output$suffix-cleaned.txt" | awk '{ print $1 }')
    expected_sec_hash=$(cat "$hashes_dir/dpt_output$suffix.txt")

    status=0
    if [ "$dpt_hash" != "$expected_sec_hash" ]; then
        status=1
    fi
    echo "dpt $status"
fi