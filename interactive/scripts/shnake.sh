#!/bin/sh
# Adapted from https://github.com/shanemcdo/shnake into a POSIX compliant version

PRG="shnake"
HEAD_COLOR="\033[42m"
BODY_COLOR="\033[102m\033[36m"
FRUIT_COLOR="\033[31m"
RESET_COLOR="\033[0;0m"
HEAD="${HEAD_COLOR}  ${RESET_COLOR}"
BODY="${BODY_COLOR}XX${RESET_COLOR}"
FRUIT="${FRUIT_COLOR}▝▘${RESET_COLOR}"
CLEAR="  "
OFFSET_X=1
OFFSET_Y=2
SCALE_X=2
INPUT_FILE=$1
SHNAKE_OUTPUT_FILE=${SHNAKE_OUTPUT_FILE:-"$TOP/interactive/shnake_output"}
# POSIX trap allows catching signals
trap quit INT TERM HUP

DEFAULT_IFS=''
reset_term(){
    show_cursor
    stty sane
    printf "${RESET_COLOR}"
}

quit(){
    reset_term
    clear
    if [ "$#" -gt 0 ]; then
        printf "$*"
    fi
    echo "You got a score of $score"
    echo 0 >> $OUTPUT_FILE
    exit 0
}

die(){
    reset_term
    printf "$PRG: \033[1;31merror:\033[0m \033[1;37m%s$RESET_COLOR\n" "$*" >&2
    exit 1
}

move_cursor(){
    printf "\033[%d;%dH" "$2" "$1"
}

show_cursor(){
    printf "\033[?25h"
}

hide_cursor(){
    printf "\033[?25l"
}

print_block(){
    move_cursor "$(($1 * SCALE_X + OFFSET_X))" "$(($2 + OFFSET_Y))"
    printf "$3"
}

get_random_int(){
    # POSIX compliant random number generation using /dev/urandom
    # od reads 2 bytes, converts to unsigned decimal
    # awk trims whitespace
    od -An -N2 -tu2 /dev/urandom | awk '{print $1}'
}

get_random_fruit(){
    rand_val=$(get_random_int)
    fruit_x="$(( rand_val % width ))"
    rand_val=$(get_random_int)
    fruit_y="$(( rand_val % height ))"
    
    # Check collision with head or body
    if [ "$fruit_x,$fruit_y" = "$head_x,$head_y" ] || collides_with_body "$fruit_x" "$fruit_y"; then
        get_random_fruit
    else
        print_block "$fruit_x" "$fruit_y" "$FRUIT"
    fi
}

eat_fruit(){
    if [ "$new_head_x,$new_head_y" = "$fruit_x,$fruit_y" ]; then
        score="$(( score + 1 ))"
        draw_score
        length_to_add="$(( length_to_add + 2 ))"
        get_random_fruit
    fi
}

get_size(){
    term_width="$(tput cols)"
    term_height="$(tput lines)"
    width="$(( term_width / SCALE_X ))"
    # Adjust for score line and 1-based indexing
    height="$(( term_height - 1 ))"
}

out_of_bounds(){
    [ "$1" -lt 0 ] || [ "$1" -ge "$width" ] || [ "$2" -lt 0 ] || [ "$2" -ge "$height" ]
}

collides_with_body(){
    echo "$body" | grep -qE "\b$1,$2\b"
}

collides(){
    out_of_bounds "$1" "$2" || collides_with_body "$1" "$2"
}

move_head(){
    new_head_x="$head_x"
    new_head_y="$head_y"
    
    case "$direction" in
        "up")    new_head_y="$(( head_y - 1 ))";;
        "down")  new_head_y="$(( head_y + 1 ))";;
        "left")  new_head_x="$(( head_x - 1 ))";;
        "right") new_head_x="$(( head_x + 1 ))";;
    esac

    if collides "$new_head_x" "$new_head_y"; then
        game_over
    fi

    # Add current head position to body
    set -- $body "$head_x,$head_y"
    draw_body
    
    # Update head position
    head_x="$new_head_x"
    head_y="$new_head_y"
    draw_head

    # Handle tail growth/movement
    if [ "$length_to_add" -gt 0 ]; then
        length_to_add="$(( length_to_add - 1 ))"
    else
        # Erase the tail segment
        tail_coord="$1"
        x="$(echo "$tail_coord" | cut -d ',' -f 1)"
        y="$(echo "$tail_coord" | cut -d ',' -f 2)"
        print_block "$x" "$y" "$CLEAR"
        shift # Remove first element (tail) from arguments
    fi
    body="$*"
    eat_fruit
}

game_over(){
    quit "You died!\n"
}

draw_head(){
    print_block "$head_x" "$head_y" "$HEAD"
}

draw_body(){
    print_block "$head_x" "$head_y" "$BODY"
}

draw_score(){
    move_cursor 1 1
    printf "Score: %s" "$score"
}

print_instructions(){
    clear
    echo "Welcome to $PRG."
    echo "Use W A S D keys to control."
    echo "Press 'q' to quit."
    echo "Press any key to start..."
    
    # Wait for a single key press (blocking) only in interactive mode
    if [ -z "$INPUT_FILE" ]; then
        stty -echo -icanon min 1 time 0
        dd bs=1 count=1 >/dev/null 2>&1
        stty sane
    fi
}

main(){
    score=0
    length_to_add=2
    direction="up"
    
    get_size
    head_x="$((width / 2))"
    head_y="$((height / 2))"
    body=""
    
    print_instructions
    
    # Setup input mode based on whether INPUT_FILE is set
    if [ -z "$INPUT_FILE" ]; then
        # Interactive mode: Setup non-blocking input with timeout
        # min 0 = return immediately if available
        # time 1 = wait 0.1s (1 decisecond) if not available
        # This effectively acts as our sleep 0.1
        stty -echo -icanon min 0 time 1
    else
        # File mode: Open file for reading
        exec 3< "$INPUT_FILE"
    fi
    
    hide_cursor
    clear
    
    get_random_fruit
    draw_score
    draw_head
    
    # Game Loop
    while true; do
        # Read input based on mode
        if [ -z "$INPUT_FILE" ]; then
            # Interactive: dd captures one byte from keyboard
            key=$(dd bs=1 count=1 2>/dev/null)
        else
            # File: read one character from file descriptor 3
            if ! read -r -n1 key <&3; then
                # End of file reached
                quit
            fi
            # Add small delay to simulate real gameplay when reading from file
            sleep 0.1
        fi
        
        case "$key" in
            w) [ "$direction" != "down" ] && direction="up";;
            a) [ "$direction" != "right" ] && direction="left";;
            s) [ "$direction" != "up" ] && direction="down";;
            d) [ "$direction" != "left" ] && direction="right";;
            q) quit;;
        esac
        
        move_head
    done
}

main