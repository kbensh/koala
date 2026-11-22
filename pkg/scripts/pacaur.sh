#!/bin/bash

IN="$1"
OUT="$2"

if [ "$(uname -s)" != "Linux" ]; then
    echo "pacaur.sh: skipped, not supported on this platform ($(uname -s)) — needs makedeb" >&2
    for pkg in $(cat "${IN}" | tr '\n' ' '); do
        mkdir -p "${OUT}/$pkg"
        echo "SKIPPED: not supported on this platform ($(uname -s)) — needs makedeb" > "${OUT}/$pkg.txt"
    done
    exit 0
fi

mkcd() {
    mkdir -p "$1" || return 1
    cd "$1" || return 1
}

# set link to plaintext PKGBUILDs
URL="${KOALA_DATA_URL:-https://atlas.cs.brown.edu/data}/aurpkg"

run_tests() {
    pkg=$1
    ORIG_DIR=$(pwd)

    mkcd "${OUT}/$pkg" || exit 1

    curl --insecure -o PKGBUILD "$URL/$pkg/PKGBUILD" 2>/dev/null || echo ' '

    gpg --recv-keys $(sed -n "s:^validpgpkeys=('\([0-9A-Fa-fx]\+\)').*$:\1:p" PKGBUILD)

    if [ "$EUID" -eq 0 ]; then
        chown -R user:user "$OUT"
        runuser -u user -p -- makedeb -d >"../$pkg.txt" 2>&1 || true
    else
        makedeb -d >"../$pkg.txt" 2>&1 || true
    fi 
    cd "$ORIG_DIR" || exit 1
}

export -f run_tests

pkg_count=0

# loop over required packages
for pkg in $(cat "${IN}"  | tr '\n' ' '); do
    pkg_count=$((pkg_count + 1))
    echo "$pkg"
    run_tests "$pkg">"${OUT}/$pkg_count.txt"
done
