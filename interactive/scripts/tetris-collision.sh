#!/bin/sh

PLAYFIELD_W=10
PLAYFIELD_H=20
EMPTY=0
FILLED=1

eval piece_minos=\'1 0  0 1  1 1  2 1\'

setup_field() {
  y=0 x=0
  while [ $y -lt $PLAYFIELD_H ]; do
    x=0
    while [ $x -lt $PLAYFIELD_W ]; do
      if [ $y -lt 5 ] && [ $(( (x + y) % 2 )) -eq 0 ]; then
         eval playfield_"$y"_"$x"=$FILLED
      else
         eval playfield_"$y"_"$x"=$EMPTY
      fi
      x=$((x + 1))
    done
    y=$((y + 1))
  done
}

new_piece_location_ok() {
  x_test="$1" y_test="$2" x=0 y=0 cell_val=0
  
  eval set -- \$piece_minos

  while [ $# -gt 0 ]; do
    x=$((x_test + $1))
    y=$((y_test - $2))
    if [ "$y" -lt 0 ] || [ "$x" -lt 0 ] || [ "$x" -ge "$PLAYFIELD_W" ]; then
        return 1
    fi
    eval cell_val=\$playfield_"$y"_"$x"
    if [ "${cell_val:-$EMPTY}" -ne "$EMPTY" ]; then
        return 1
    fi
    shift 2
  done
  return 0
}

test_hard_drop() {
  steps=0
  while new_piece_location_ok "$1" $(($2 - steps)); do
    steps=$((steps + 1))
  done
  if [ "$steps" -eq 0 ]; then
     return 0
  fi
  return $((steps - 1))
}
setup_field
while read -r op x y; do
  case $op in
    c) 
       if new_piece_location_ok "$x" "$y"; then 
           echo "Position $x,$y: SAFE"
       else 
           echo "Position $x,$y: COLLISION"
       fi 
       ;;
    d) 
       test_hard_drop "$x" "$y"
       dist=$?
       echo "From $x,$y -> Drops $dist spaces" 
       ;;
  esac
done