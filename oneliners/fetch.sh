#!/bin/sh


TOP=$(git rev-parse --show-toplevel)
URL="${KOALA_DATA_URL:-https://atlas.cs.brown.edu/data}"

input_dir="${TOP}/oneliners/inputs"
mkdir -p "$input_dir"
cd "$input_dir" || exit 1

size=full
for arg in "$@"; do
    case "$arg" in
        --small) size=small ;;
        --min)   size=min ;;
    esac
done

mkdir -p "$input_dir/comm_$size"

if [ ! -f $input_dir/1M.txt ]; then
    wget --no-check-certificate "$URL"/dummy/1M.txt
    # Add newline to file
    echo >>1M.txt
    dos2unix 1M.txt
fi

if [ ! -f $input_dir/dict.txt ]; then
    wget -O - "$URL"/dummy/dict.txt --no-check-certificate | sort >dict.txt
fi

if [ ! -f ./all_cmds.txt ]; then
    wget -O - "$URL"/dummy/all_cmds.txt --no-check-certificate >all_cmds.txt
fi

if [ ! -f $input_dir/all_cmdsx100.txt ]; then
    touch all_cmdsx100.txt
    for i in $(seq 1 100); do
        cat all_cmds.txt >>all_cmdsx100.txt
    done
fi

# For uniq-ips
if [ "$size" = "small" ]; then
    N=400000 # 400K
elif [ "$size" = "min" ]; then
    N=40
else
    N=40000000 # 40M
fi

../scripts/gen_ips.py "$N" >logs-popcount-org_$size.txt
../scripts/gen_comm.py "$N" "comm_$size"

if [ "$size" = "small" ]; then
    if [ ! -f ./10M.txt ]; then
        touch 10M.txt
        for i in $(seq 1 10); do
            cat 1M.txt >>10M.txt
        done
    fi

    if [ ! -f ./30M.txt ]; then
        touch 30M.txt
        for i in $(seq 1 3); do
            cat 10M.txt >>30M.txt
        done
    fi
    
    if [ ! -d ./chessdata_small ]; then
        archive="chessdata_small.tar.gz"
        wget --no-check-certificate "$URL/oneliners/$archive" -O "$archive"
        mkdir -p "chessdata_small"
        tar -xzf "$archive" -C "chessdata_small" --no-same-owner
        rm "$archive"
    fi
    rm 1M.txt
    exit 0
elif [ "$size" = "min" ]; then
    if [ ! -d ./chessdata_min ]; then
        archive="chessdata_min.tar.gz"
        wget --no-check-certificate "$URL/oneliners/$archive" -O "$archive"
        mkdir -p "chessdata_min"
        tar -xzf "$archive" -C "chessdata_min" --no-same-owner
        rm "$archive"
    fi
    exit 0
fi

# full size files
if [ ! -f ./1G.txt ]; then
    touch 1G.txt
    for i in $(seq 1 1000); do
        cat 1M.txt >>1G.txt
    done
fi

if [ ! -f ./3G.txt ]; then
    touch 3G.txt
    for i in $(seq 1 3); do
        cat 1G.txt >>3G.txt
    done
fi

if [ ! -d ./chessdata ]; then
    archive="chessdata.tar.gz"
    wget --no-check-certificate "$URL/oneliners/$archive" -O "$archive"
    mkdir -p "chessdata"
    tar -xzf "$archive" -C "chessdata" --no-same-owner
    rm "$archive"
fi
rm 1M.txt