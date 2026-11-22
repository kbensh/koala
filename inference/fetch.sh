#!/bin/sh


TOP=$(git rev-parse --show-toplevel)

eval_dir="$TOP/inference"
input_dir="$eval_dir/inputs"

mkdir -p "$input_dir"

size=full
for arg in "$@"; do
    case "$arg" in
    --small) size=small ;;
    --min) size=min ;;
    esac
done
export LC_ALL=C

URL="${KOALA_DATA_URL:-https://atlas.cs.brown.edu/data}"

full_dir="${input_dir}/dpt.full"
small_dir="${input_dir}/dpt.small"
min_dir="${input_dir}/dpt.min"
models_dir="${input_dir}/models"

if [ ! -d "$models_dir" ]; then
    mkdir -p "$models_dir"
    wget --no-check-certificate "${URL}/models.zip" -O "${input_dir}/models.zip"
    unzip -q "${input_dir}/models.zip" -d "${input_dir}/tmp_models"
    mv "${input_dir}/tmp_models"/models/* "$models_dir"
    rm -r "${input_dir}/tmp_models" "${input_dir}/models.zip"
fi

if [ "$size" = "min" ]; then
    if [ -d "$min_dir" ]; then
        echo "Data already downloaded and extracted."
    else
        cp -r "${eval_dir}"/min_inputs/dpt.min "$input_dir"
    fi
fi

if [ "$size" = "small" ]; then
    if [ -d "$small_dir" ]; then
        echo "Data already downloaded and extracted."
    else
        mkdir -p "$small_dir"
        wget --no-check-certificate "${URL}/pl-06-P_F-A_N-20250401T083751Z-001.zip" -O "${input_dir}/small.zip"
        unzip -q "${input_dir}/small.zip" -d "${input_dir}/tmp_small"
        mv "${input_dir}/tmp_small"/*/* "$small_dir"
        rm -r "${input_dir}/tmp_small" "${input_dir}/small.zip"
    fi
fi

if [ "$size" = "full" ]; then
    if [ -d "$full_dir" ]; then
        echo "Data already downloaded and extracted."
    else
        mkdir -p "$full_dir"
        wget --no-check-certificate "${URL}/pl-01-PFW-20250401T083800Z-001.zip" -O "${input_dir}/full.zip"
        unzip -q "${input_dir}/full.zip" -d "${input_dir}/tmp_full"
        mv "${input_dir}/tmp_full"/*/* "$full_dir"
        rm -r "${input_dir}/tmp_full" "${input_dir}/full.zip"
    fi
fi

URL="${KOALA_DATA_URL:-https://atlas.cs.brown.edu/data}"

if [ "$size" = "small" ]; then
    # if inputs exist
    if [ -d "$input_dir/jpg.small" ]; then
        echo "Image data already downloaded and extracted."
    else
        data_url="${URL}"/small/jpg.zip
        zip_dst=$input_dir/jpg.small.zip
        out_dir=$input_dir/jpg.small
        wget --no-check-certificate $data_url -O $zip_dst || {
            echo "Failed to download $data_url"
            exit 1
        }
        unzip $zip_dst -d $out_dir || {
            echo "Failed to unzip $zip_dst"
            exit 1
        }
        rm "$zip_dst"
    fi
    if [ -d "$input_dir/songs.small" ]; then
        echo "Song already downloaded and extracted."
        exit 0
    fi
    data_url="${URL}/llm/playlist_small.tar.gz"
    wget --no-check-certificate $data_url -O "$input_dir"/playlist_small.tar.gz || {
        echo "Failed to download $data_url"
        exit 1
    }
    tar -xzf "$input_dir/playlist_small.tar.gz" -C "$input_dir" --no-same-owner || {
        echo "Failed to extract $input_dir/playlist_small.tar.gz"
        exit 1
    }
    rm "$input_dir/playlist_small.tar.gz"
    mv "$input_dir/playlist_small" "$input_dir/songs.small"
    exit 0

elif [ "$size" = "min" ]; then
    if [ -d "$input_dir/jpg.min" ]; then
        echo "Image data already downloaded and extracted."
    else
        cp -r "${eval_dir}"/min_inputs/jpg.min "$input_dir"
    fi
    if [ -d "$input_dir/songs.min" ]; then
        echo "Song data already downloaded and extracted."
        exit 0
    fi
    cp -r "${eval_dir}"/min_inputs/songs.min "$input_dir"
else
    if [ -d "$input_dir/jpg" ]; then
        echo "Image data already downloaded and extracted."
    else
        echo "Downloading full dataset."
        data_url="${URL}/full/jpg.zip"
        zip_dst="$input_dir/jpg.zip"
        out_dir="$input_dir/jpg"
        wget --no-check-certificate $data_url -O $zip_dst
        unzip $zip_dst -d $out_dir
        rm "$zip_dst"
    fi
    if [ -d "$input_dir/songs.full" ]; then
        echo "Song data already downloaded and extracted."
        exit 0
    fi
    echo "Downloading full dataset."
    data_url="${URL}/llm/playlist_full.tar.gz"
    wget --no-check-certificate $data_url -O "$input_dir"/playlist_full.tar.gz || {
        echo "Failed to download $data_url"
        exit 1
    }
    tar -xzf "$input_dir/playlist_full.tar.gz" -C "$input_dir" || {
        echo "Failed to extract $input_dir/playlist_full.tar.gz"
        exit 1
    }
    rm "$input_dir/playlist_full.tar.gz"
    mv "$input_dir/playlist_full" "$input_dir/songs.full"
fi
