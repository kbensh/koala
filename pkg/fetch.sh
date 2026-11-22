#!/bin/sh
set -x
set -e


TOP=$(git rev-parse --show-toplevel)
input_dir="$TOP/pkg/inputs"
URL="${KOALA_DATA_URL:-https://atlas.cs.brown.edu/data}"

size=full
for arg in "$@"; do
    case "$arg" in
    --small) size=small ;;
    --min) size=min ;;
    esac
done

cd "$TOP" || exit 1
mkdir -p "${input_dir}"
cd "$input_dir" || exit 1

if [ ! -f "packages" ]; then
  wget "$URL"/aurpkg/packages --no-check-certificate -O "packages"
fi

if [ ! -d node_modules ]; then
  wget "$URL/prog-inf/node_modules.tar.gz" -O node_modules.tar.gz
  tar xf node_modules.tar.gz --no-same-owner
  rm node_modules.tar.gz
fi

cp "$TOP/pkg/inputs/node_modules/index.txt" index.txt

if [ "$size" = "min" ]; then
  n_packages=2
  n_aur_packages=2
elif [ "$size" = "small" ]; then
  n_packages=100
  n_aur_packages=10
else
  n_packages=$(wc -l < index.txt)
  n_aur_packages=$(wc -l < packages)
fi
head -n "$n_packages" <index.txt > index.$size.txt
head -n "$n_aur_packages" <packages > "packages.$size"
cp index.$size.txt "$TOP/pkg/inputs/node_modules/index.$size.txt"