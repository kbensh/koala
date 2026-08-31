#!/bin/sh

cd "$(dirname "$0")" || exit 1
TOP=$(git rev-parse --show-toplevel)

NODE_DIR="$TOP/.tools/nodejs18/bin" 
export PATH="$NODE_DIR:$PATH"

KOALA_SHELL=${KOALA_SHELL:-bash}
export BENCHMARK_CATEGORY="web-search"

# ensure a local ./tmp directory exists for sorting
mkdir -p ./tmp
export TMPDIR=$PWD/tmp

in="$TOP/web-search/inputs"
out="$TOP/web-search/outputs"
export IN=${in}
export OUT=${out}

size="full"
suffix=""
for arg in "$@"; do
    if [ "$arg" = "--small" ]; then
        size="small"
        suffix="_small"
        break
    elif [ "$arg" = "--min" ]; then
        size="min"
        suffix="_min"
        break
    fi
done

mkdir -p "$in"
mkdir -p "$out"


# if [ $size = "min" ]; then
#     echo https://cs.brown.edu/courses/csci1380/sandbox/1 >${OUT}/urls.txt
# elif [ $size = "small" ]; then
#     echo https://cs.brown.edu/courses/csci1380/sandbox/2 >${OUT}/urls.txt
# else
#     echo https://cs.brown.edu/courses/csci1380/sandbox/3 >${OUT}/urls.txt
# fi
export TEST_BASE="$TOP/web-search"
export WIKI="$IN/articles$suffix"
export INDEX_FILE="$IN/index$suffix.txt"


echo "web-index"
BENCHMARK_SCRIPT="$(realpath "./scripts/engine.sh")"
export BENCHMARK_SCRIPT

$KOALA_SHELL "$BENCHMARK_SCRIPT"
echo $?