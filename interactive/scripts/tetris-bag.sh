#!/bin/sh
# bench_rng.sh

O_TETRIMINO=1; I_TETRIMINO=2; T_TETRIMINO=3; L_TETRIMINO=4; J_TETRIMINO=5; S_TETRIMINO=6; Z_TETRIMINO=7

# Xorshift32 PRNG implementation
randnext() {
  eval "$1=$(( $1 ^ (($1 << 13) & 4294967295) ))" 
  eval "$1=$(( $1 ^ (($1 >> 17) & 131071) ))"     
  eval "$1=$(( $1 ^ (($1  << 5) & 4294967295) ))" 
}

# Fisher-Yates Shuffle
shuffle() {
  varname="$1" random_value="$2" random_shift=0 shuffled=''
  shift 2
  while [ $# -gt 1 ]; do
    randnext "$random_value"
    random_shift=$(( $random_value % $# ))
    random_shift=${random_shift#-} # absolute value

    # Rotate args until selected arg is at $1
    while [ $random_shift -gt 0 ]; do
      set -- "$@" "$1"; shift
      random_shift=$(( random_shift - 1 ))
    done
    shuffled="${shuffled}${1} "
    shift
  done
  eval "$varname=\${shuffled}\${1}"
}

fill_bag() {
  shuffle bag bag_seed $O_TETRIMINO $I_TETRIMINO $T_TETRIMINO $L_TETRIMINO $J_TETRIMINO $S_TETRIMINO $Z_TETRIMINO
}

# --- BENCHMARK DRIVER ---
bag_seed=12345
bag=""
count=0

echo "--- RNG Benchmark ---"
echo "Press ENTER to generate a bag. (Ctrl+C to stop)"
echo "Or pipe 'yes' into this script for speed testing."

while read -r input; do
  if [ -n "$input" ]; then
    case "$input" in
      *[!0-9]*) echo "Invalid seed (not a number): $input"; continue ;;
      *) bag_seed="$input" ;;
    esac
  fi
  fill_bag
  count=$((count + 1))
  # Only print every 100th bag to keep I/O from being the bottleneck
    #   if [ $((count % 1)) -eq 0 ]; then
    #     echo "Bag $count: $bag"
    #   fi
  echo "Bag $count: $bag"
done