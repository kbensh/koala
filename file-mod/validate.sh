#!/bin/sh


cd "$(realpath "$(dirname "$0")")" || exit 1

export PATH="/usr/local/legacy-bin:$PATH"

outputs_dir="outputs"
hashes_dir="hashes"
TOP="$(git rev-parse --show-toplevel)"
eval_dir="${TOP}/file-mod"
suffix=".full"

mkdir -p "$hashes_dir"

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

hash_audio_dir() {
    local src_dir=$1
    for src in $src_dir/*; do
        got_hash=$(ffmpeg -i "$src" -map 0:a -f md5 - 2>/dev/null)
        echo $got_hash $(realpath "--relative-to=$src_dir" "$src")
    done
}

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

if $generate; then
    if should_run "compress_files"; then
        md5sum $outputs_dir/compress_files$suffix/* > "$hashes_dir/compress_files$suffix.md5sum"
    fi
    
    if should_run "encrypt_files"; then
        md5sum $outputs_dir/encrypt_files$suffix/* > "$hashes_dir/encrypt_files$suffix.md5sum"
    fi
    
    if should_run "img_convert"; then
        md5sum $outputs_dir/img_convert$suffix/* > "$hashes_dir/img_convert$suffix.md5sum"
    fi
    
    if should_run "thumbnail_generation"; then
        md5sum $outputs_dir/thumbnail$suffix/* > "$hashes_dir/thumbnail$suffix.md5sum"
    fi
    
    if should_run "to_mp3"; then
        hash_audio_dir "$eval_dir/$outputs_dir/to_mp3$suffix" > "$eval_dir/$hashes_dir/to_mp3$suffix.md5sum"
    fi
    
    echo "Generated hashes in $hashes_dir"
    exit 0
fi

if should_run "encrypt_files"; then
    status=0
    if ! md5sum --check --quiet "$hashes_dir/encrypt_files$suffix.md5sum"; then
        status=1
    fi
    echo "encrypt_files $status"
fi

if should_run "compress_files"; then
    status=0
    if ! md5sum --check --quiet "$hashes_dir/compress_files$suffix.md5sum"; then
        status=1
    fi
    echo "compress_files $status"
fi

if should_run "img_convert"; then
    status=0
    if ! md5sum --check --quiet "$hashes_dir/img_convert$suffix.md5sum"; then
        status=1
    fi
    echo "img_convert $status"
fi

if should_run "thumbnail_generation"; then
    status=0
    if ! md5sum --check --quiet "$hashes_dir/thumbnail$suffix.md5sum"; then
        status=1
    fi
    echo "thumbnail $status"
fi

if should_run "to_mp3"; then
    generated_tmp=$(mktemp)
    expected_tmp=$(mktemp)

    hash_audio_dir "$eval_dir/$outputs_dir/to_mp3$suffix" | sort > "$generated_tmp"
    sort "$eval_dir/$hashes_dir/to_mp3$suffix.md5sum" > "$expected_tmp"

    if diff -q "$expected_tmp" "$generated_tmp" >/dev/null 2>&1; then
        status=0
    else
        status=1
    fi

    rm -f "$generated_tmp" "$expected_tmp"
    echo "to_mp3 $status"
fi