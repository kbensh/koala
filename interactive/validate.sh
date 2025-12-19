#!/bin/bash

TOP=$(git rev-parse --show-toplevel)
eval_dir="${TOP}/interactive"
input_dir="${eval_dir}/inputs"
scripts_dir="${eval_dir}/scripts"
outputs_dir="${eval_dir}/outputs"
hashes_dir="${eval_dir}/hashes"
mkdir -p $hashes_dir
export LC_ALL=C

size=full
selected_scripts=""

while [ $# -gt 0 ]; do
    case "$1" in
        --generate)
            generate=true
            shift
            ;;
        --small)
            size=small
            shift
            ;;
        --min)
            size=min
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

validate_result=0
ZDOTDIR=$outputs_dir
if should_run "ohmyzsh"; then
    target_zshrc="$ZDOTDIR/.zshrc"
    expected_install_dir="${ZSH:-$input_dir/ohmyzsh}"
    validation_error=0

    if [ ! -f "$expected_install_dir/oh-my-zsh.sh" ]; then
        validation_error=1
    fi

    if [ ! -f "$target_zshrc" ]; then
        validation_error=1
    else
        if ! grep -q "export ZSH=" "$target_zshrc"; then
            validation_error=1
        fi
    fi

    echo ohmyzsh $validation_error
fi

cd "$outputs_dir" || exit
if $generate; then
    if should_run "shnake"; then
        md5sum "shnake_$size.out" > "$hashes_dir/shnake_$size.md5sum"
    fi
    if should_run "tetris-bag"; then
        md5sum "tetris_bag_$size.out" > "$hashes_dir/tetris_bag_$size.md5sum"
    fi
    if should_run "tetris-collision"; then
        md5sum "tetris_collision_$size.out" > "$hashes_dir/tetris_collision_$size.md5sum"
    fi
fi

if should_run "shnake"; then
    bench=shnake_$size
    md5sum --check --quiet --status "$hashes_dir/$bench.md5sum"
    echo $bench $?
fi
