#!/bin/sh


TOP=$(git rev-parse --show-toplevel)

input_dir="${TOP}/file-mod/inputs"
mkdir -p "$input_dir"

URL="${KOALA_DATA_URL:-https://atlas.cs.brown.edu/data}"
ZIP_DST="$input_dir/pcaps.zip"

size=full
for arg in "$@"; do
    case "$arg" in
    --small) size=small ;;
    --min) size=min ;;
    esac
done

if [ -d "$input_dir/pcaps_$size" ]; then
    echo "Directory $input_dir/pcaps_$size already exists. Skipping download."
else
    if [ "$size" = "min" ]; then
        mkdir -p "$input_dir/pcaps_$size"
        cp min_inputs/*.pcapng "$input_dir/pcaps_$size/"
    fi

    if [ "$size" = "small" ]; then
        wget --no-check-certificate $URL/pcaps.zip -O "$input_dir/pcaps_$size.zip"
        unzip "$input_dir/pcaps_$size.zip" -d "$input_dir"
        mv "$input_dir/pcaps/" "$input_dir/pcaps_$size/"
        rm "$input_dir/pcaps_$size.zip"
    fi
    if [ "$size" = "full" ]; then
        wget --no-check-certificate $URL/pcaps.zip -O "$input_dir/pcaps.zip"
        unzip "$input_dir/pcaps.zip" -d "$input_dir"
        mv "$input_dir/pcaps/" "$input_dir/pcaps_$size/"
        rm "$input_dir/pcaps.zip"

        wget --no-check-certificate "$URL"/pcaps_large.zip -O "$ZIP_DST"
        unzip "$ZIP_DST" -d "$input_dir/pcaps_$size"
        rm "$ZIP_DST"
    fi
fi

data_url=$URL/wav.zip
zip_dst=$input_dir/wav.zip
full_dir="$input_dir/wav_full"
small_dir="$input_dir/wav_small"
min_dir="$input_dir/wav_min"
if [ ! -d "$full_dir" ] || { [ -d "$full_dir" ] && [ -z "$(ls -A "$full_dir")" ]; }; then
    wget --no-check-certificate "$data_url" -O "$zip_dst"
    unzip "$zip_dst" -d "$input_dir"
    rm -rf "$full_dir" "$small_dir" "$min_dir"

    # copy `.wav`s to their final destinations.
    # Make sure we have the correct number of inputs
    # with numbered backups (do not overwrite inputs).
    if [ "$size" = "full" ]; then
        mkdir -p "$full_dir"
        for i in $(seq 1 120); do
            cp --backup=numbered "$input_dir"/wav/* "--target-directory=$full_dir"
        done
    fi
    if [ "$size" = "small" ]; then
        mkdir -p "$small_dir"
        for i in $(seq 1 10); do
            cp --backup=numbered "$input_dir"/wav/* "--target-directory=$small_dir"
        done
    fi
    if [ "$size" = "min" ]; then
        mkdir -p "$min_dir"
        for i in $(seq 1 2); do
            cp --backup=numbered "$input_dir"/wav/* "--target-directory=$min_dir"
        done
    fi
    rm -r "$zip_dst" "$input_dir/wav"
fi

# if small flag
if [ "$size" = "small" ]; then
    if [ -d "$input_dir/jpg_small" ]; then
        echo "Data already downloaded and extracted."
        exit 0
    fi
    data_url=${URL}/small/jpg.zip
    zip_dst=$input_dir/jpg_small.zip
    out_dir=$input_dir/jpg_small
    wget --no-check-certificate $data_url -O $zip_dst || {
        echo "Failed to download $data_url"
        exit 1
    }
    unzip $zip_dst -d $out_dir || {
        echo "Failed to unzip $zip_dst"
        exit 1
    }
    rm "$zip_dst"
    exit 0
elif [ "$size" = "min" ]; then
    if [ -d "$input_dir/jpg_min" ]; then
        echo "Data already downloaded and extracted."
        exit 0
    fi
    min_inputs="${TOP}/file-mod/min_inputs"
    mkdir -p "$input_dir"
    cp -r "$min_inputs"/jpg_min "$input_dir/"
    exit 0
fi

if [ -d "$input_dir/jpg" ]; then
    echo "Data already downloaded and extracted."
    exit 0
fi
data_url=${URL}/full/jpg.zip
zip_dst="$input_dir/jpg_full.zip"
out_dir="$input_dir/jpg_full"
wget --no-check-certificate $data_url -O $zip_dst
unzip -o $zip_dst -d $out_dir
rm "$zip_dst"
