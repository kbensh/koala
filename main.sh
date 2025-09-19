#!/bin/bash

error() {
    echo "Error: $1" >/dev/stderr
    exit 1
}

correct() { [ "$(cut -d' ' -f 2 <"$BENCHMARK.hash" | grep -vc 0)" -eq 0 ]; }

in_container() {
  [ -f /proc/1/cgroup ] && grep -qaE 'docker|kubepods|containerd' /proc/1/cgroup && return 0
  [ -f /proc/1/cgroup ] && grep -w '0::/' /proc/1/cgroup && return 0
  [ -f /.dockerenv ] && return 0
  return 1
}

is_integer() { [[ $1 =~ ^[0-9]+$ && $1 -gt 0 ]]; }

usage() {
    echo "Usage: $0 BENCHMARK_NAME [--time|--resources|--bare|args...]"
    echo "  --min            Run the benchmark with minimal inputs (default)"
    echo "  --small          Run the benchmark with small inputs"
    echo "  --full          Run the benchmark with full inputs"
    echo "  --time, -t       Measure wall-clock time"
    echo "  --resources      Measure resource usage"
    echo "  --bare           Run locally without Docker"
    echo "  --runs, -n N     Number of runs (default: 1)"
    echo "  --clean, -c      Run the full cleanup script (both inputs and outputs)"
    echo "  --keep, -k       Keep outputs"
    echo "  --prune          Run the benchmark on a fresh container (will need to re-download everything on each run)"
    echo "  --quiet, -q      Suppress non-essential output (alias for --verbose 0)"
    echo "  --verbose N      Verbosity level: 0=silent, 1=info (default), 2=debug"
    echo "  --help, -h       Show this help message"
}


log() {
  local lvl=$1; shift
  (( verbosity >= lvl )) && echo "$@"
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi


    measure_time=false
    measure_resources=false
    run_locally=false
    run_cleanup=false
    keep_outputs=false
    prune=false
    runs=1
    size="min"
    verbosity=1

    args=()
    main_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --help | -h) 
            usage
            exit 0
            ;;
        --time | -t)
            measure_time=true
            main_args+=("$1")
            shift
            ;;
        --resources)
            measure_resources=true
            main_args+=("$1")
            shift
            ;;
        --bare)
            run_locally=true
            shift
            ;;
        --runs | -n)
            shift
            [[ $# -eq 0 ]] && error "Missing value for -n/--runs"
            is_integer "$1" || error "Value for -n/--runs must be a positive integer"
            runs="$1"
            main_args+=("-n" "$runs")
            shift
            ;;
        --clean | -c)
            run_cleanup=true
            main_args+=("$1")
            shift
            ;;
        --keep | -k)
            keep_outputs=true
            main_args+=("$1")
            shift
            ;;
        --prune)
            prune=true
            main_args+=("$1")
            shift
            ;;
        --quiet | -q)
            verbosity=0
            main_args+=("$1")
            shift
            ;;
        --verbose)
            shift
            if ! [[ "$1" =~ ^[012]$ ]]; then
                error "Value for --verbose must be 0, 1 or 2"
            fi
            verbosity="$1"
            main_args+=("--verbose" "$verbosity")
            shift
            ;;
        --min)
            size="min"
            main_args+=("$1")
            shift
            ;;
        --small)
            size="small"
            main_args+=("$1")
            shift
            ;;
        --full)
            size="full"
            main_args+=("$1")
            shift
            ;;
        *)
            if [[ "$1" != -* ]]; then
                BENCHMARK="$(basename "$1")"
            else
                args+=("$1")
            fi
            shift
            ;;
        esac
    done

    if [[ "$size" == "min" ]]; then
        args+=("--min")
    elif [[ "$size" == "small" ]]; then
        args+=("--small")
    elif [[ "$size" == "full" ]]; then
        args+=("")
    fi

    [ -z "$BENCHMARK" ] && usage && exit 1
    [ ! -d "$BENCHMARK" ] && error "Benchmark folder $BENCHMARK does not exist"
    export BENCHMARK

    export LC_ALL=C
    export TZ=UTC
    export DOCKER_DEFAULT_PLATFORM=linux/amd64
    KOALA_SHELL=${KOALA_SHELL:-bash}
    KOALA_CONTAINER_CMD=${KOALA_CONTAINER_CMD:-docker}
    export KOALA_SHELL
    export KOALA_INFO="time:mem:io:cpu"

    if  in_container; then
        run_locally=true
    fi

    shell_word=${KOALA_SHELL%% *}
    shell_word=${shell_word##*/}
    shell_safe=${shell_word//[^A-Za-z0-9_.-]/_}
    log 1 echo "Using shell: $KOALA_SHELL"
    stats_prefix="${BENCHMARK}_${shell_safe}_stats"
    time_values=()
    stats_files=()

    TOP=$(git rev-parse --show-toplevel)
    [[ -z "$TOP" ]] && error "Failed to determine repository top"

    VENV_DIR="$TOP/venv"
    if [ ! -d "$VENV_DIR" ]; then
        log 2 "Creating virtual environment at $VENV_DIR"
        python3 -m venv "$VENV_DIR"
    fi
    log 2 "Activating virtual environment at $VENV_DIR"
    source "$VENV_DIR/bin/activate"

    log 2 "All args: ${args[*]}"
    log 2 "Main args: ${main_args[*]}"
    
    if ! $run_locally; then
        for var in $(compgen -v | grep '^KOALA_'); do
            log 2 "Env $var: ${!var}"
        done

        DOCKER_IMAGE=${KOALA_DOCKER_IMAGE:-ghcr.io/binpash/benchmarks:latest}
        log 1 "Launching KOALA in $KOALA_CONTAINER_CMD container ($DOCKER_IMAGE)"
        log 2 "Pulling image: $DOCKER_IMAGE"
        $KOALA_CONTAINER_CMD pull "$DOCKER_IMAGE"

        USER_FLAGS="-u $(id -u):$(id -g) -e HOST_UID=$(id -u) -e HOST_GID=$(id -g)"

        if $prune; then
            log 1 "Running with prune mode: starting clean container"
            log 2 "Docker run cmd (prune):"
            log 2 "  $KOALA_CONTAINER_CMD run --rm \\"
            log 2 "    -e HOME=/benchmarks \\"
            log 2 "    $USER_FLAGS \\"
            log 2 "    $DOCKER_IMAGE \\"
            log 2 "    -w /benchmarks \\"
            log 2 "    bash -c \"git config --global --add safe.directory /benchmarks && ./setup.sh && ./main.sh \\\"$BENCHMARK\\\" ${args[*]} ${main_args[*]} --bare\""

            $KOALA_CONTAINER_CMD run --rm \
                -e HOME=/benchmarks \
                $USER_FLAGS \
                "$DOCKER_IMAGE" \
                -w "/benchmarks" \
                bash -c "git config --global --add safe.directory /benchmarks && ./setup.sh && ./main.sh \"$BENCHMARK\" ${args[*]} ${main_args[*]} --bare"
        else
            log 1 "Mounting $TOP to /benchmarks in the container"
            log 2 "Docker run cmd (mount):"
            log 2 "  $KOALA_CONTAINER_CMD run --rm \\"
            log 2 "    -e HOME=/benchmarks \\"
            log 2 "    -v $TOP:/benchmarks \\"
            log 2 "    -w /benchmarks \\"
            log 2 "    -e KOALA_SHELL=$KOALA_SHELL \\"
            log 2 "    $USER_FLAGS \\"
            log 2 "    $DOCKER_IMAGE \\"
            log 2 "    bash -c \"git config --global --add safe.directory /benchmarks && ./setup.sh && ./main.sh \\\"$BENCHMARK\\\" ${args[*]} ${main_args[*]} --bare\""

            $KOALA_CONTAINER_CMD run --rm \
                -e HOME=/benchmarks \
                -v "$TOP":/benchmarks \
                -w "/benchmarks" \
                -e KOALA_SHELL="$KOALA_SHELL" \
                $USER_FLAGS \
                "$DOCKER_IMAGE" \
                bash -c "git config --global --add safe.directory /benchmarks && ./setup.sh && ./main.sh \"$BENCHMARK\" ${args[*]} ${main_args[*]} --bare"
        fi
        exit $?
    fi

    cd "$(dirname "$0")/$BENCHMARK" || error "Could not cd into benchmark folder"

    for ((i = 1; i <= runs; i++)); do
        # Download dependencies
        if ((i == 1)); then
            ./install.sh "${args[@]}" ||
                error "Failed to download dependencies for $BENCHMARK"
        fi
        # Fetch inputs
        if ((i == 1)) || [[ "$BENCHMARK" == "ci-cd" ]]; then
            ./fetch.sh "${args[@]}" ||
                error "Failed to fetch inputs for $BENCHMARK"
            if [[ "$measure_resources" == true ]]; then
                python3 $TOP/infrastructure/create_size_inputs_json.py ||
                    error "Failed to calculate input sizes"
            fi
        fi

        # Delete outputs before each run
        if [ "$BENCHMARK" != "ci-cd" ]; then
            ./clean.sh "${args[@]}"
        fi

        log 1 "Executing $BENCHMARK $(date) ($i/$runs)"
        if [[ "$measure_resources" == true ]]; then
            log 1 "[*] Running dynamic resource analysis for $BENCHMARK"
            # check if deps are installed
            if ! command -v cloc &>/dev/null || ! command -v python3 &>/dev/null; then
                echo "Please run setup.sh first to install dependencies."
                exit 1
            fi
            log 2 "Backing up process logs from previous runs in $TOP/infrastructure/target/backup-process-logs"
            mkdir -p "$TOP/infrastructure/target/process-logs"
            mkdir -p "$TOP/infrastructure/target/backup-process-logs"
            find "$TOP/infrastructure/target/process-logs" -type f \
                -exec mv {} "$TOP/infrastructure/target/backup-process-logs/" \; || true
            rm -f "$TOP"/infrastructure/target/process-logs/*
            rm -f "$TOP"/infrastructure/target/dynamic_analysis.jsonl

            cd "$TOP" || exit 1
            log 2 "Running: python3 $TOP/infrastructure/run_dynamic.py $BENCHMARK ${args[*]}"
            python3 "$TOP/infrastructure/run_dynamic.py" "$BENCHMARK" "${args[@]}" || error "Failed to run $BENCHMARK"

            cd "$TOP/infrastructure" || exit 1
            make target/dynamic_analysis.jsonl
            python3 viz/dynamic.py "$TOP/$BENCHMARK" >/dev/null
            if [[ -f "$TOP/$BENCHMARK/benchmark_stats.txt" ]]; then
                log 1 "Benchmark stats generated for $BENCHMARK"
                log 1 "Stats saved to $TOP/$BENCHMARK/${stats_prefix}.txt"
                cat "$TOP/$BENCHMARK/benchmark_stats.txt"
                mv -f "$TOP/$BENCHMARK/benchmark_stats.txt" \
                "$TOP/$BENCHMARK/${stats_prefix}.txt" || error "Failed to move benchmark stats"
            else
                error "Failed to generate benchmark stats"
            fi

            log 2 "Moving backup-process logs back to $TOP/infrastructure/target/process-logs"
            find "$TOP/infrastructure/target/backup-process-logs" -type f \
                -exec mv {} "$TOP/infrastructure/target/process-logs/" \; || true
            cd "$TOP/$BENCHMARK" || exit 1

        elif $measure_time; then

            if [ $run_locally = true ]; then
                if ! command -v /usr/bin/time &>/dev/null || ! command -v gawk &>/dev/null; then
                    echo "Please run setup.sh first to install dependencies."
                    exit 1
                fi
            fi

            log 1 "Timing benchmark: $BENCHMARK  (run #$i)"
            log 2 "Time-cmd: /usr/bin/time -f %e ./execute.sh ${args[*]}"
            time_val_file="${BENCHMARK}_${shell_safe}_time_run${i}.txt"
            rm -f "$time_val_file"

            /usr/bin/time -f "%e" -o "$time_val_file" \
                ./execute.sh "${args[@]}" \
                1>"${BENCHMARK}.out" \
                2>"${BENCHMARK}.err"
            CMD_STATUS=$?

            if [[ -s "$time_val_file" ]]; then
                runtime=$(<"$time_val_file")
            else
                echo "Warning: could not capture runtime for run #$i" >&2
                runtime=0
            fi

            time_values+=("$runtime")
            [[ $CMD_STATUS -ne 0 ]] && error "Failed to run $BENCHMARK"

        else
            log 2 "Running benchmark: $BENCHMARK  (run #$i)"
            ./execute.sh "${args[@]}" 2>"$BENCHMARK.err" | tee "$BENCHMARK.out" || error "Failed to run $BENCHMARK"
        fi

        log 2 "Run #$i completed for $BENCHMARK"
        # Verify output
        log 2 "Verifying output for $BENCHMARK"
        ./validate.sh "${args[@]}" >"$BENCHMARK.hash" || error "Failed to verify output for $BENCHMARK"

        # Cleanup outputs
        if [ "$keep_outputs" = false ] && [ "$i" -eq "$runs" ]; then
            log 2 "Cleaning up outputs for $BENCHMARK"
            if [ "$run_cleanup" = true ]; then
                ./clean.sh -f "${args[@]}"
            else
                ./clean.sh "${args[@]}"
            fi
        fi

        if correct; then
            echo "$BENCHMARK [pass]"
        else
            echo "$BENCHMARK [fail]"
        fi

        if [[ $measure_resources == true ]]; then
            src_stats="$TOP/$BENCHMARK/${stats_prefix}.txt"

            if [[ -f $src_stats ]]; then
                dst_stats="$TOP/$BENCHMARK/${stats_prefix}_run${i}.txt"
                log 2 "Copying stats from $src_stats to $dst_stats"
                cp -f -- "$src_stats" "$dst_stats"
                stats_files+=("$dst_stats") # remember it for later aggregation
            else
                echo "Warning: $src_stats not found for run #$i" >&2
            fi
        fi
    done

    if [[ $measure_resources == true && ${#stats_files[@]} -gt 1 ]]; then
        agg_script="$TOP/infrastructure/aggregate_stats.py"
        if [[ -f $agg_script ]]; then
            log 2 "Aggregating stats files: ${stats_files[*]}"
            python3 "$agg_script" "${stats_files[@]}" \
                >"$TOP/$BENCHMARK/${stats_prefix}_aggregated.txt" ||
                echo "Aggregation failed" >&2
            log 1 "Wrote aggregated stats to $TOP/$BENCHMARK/${stats_prefix}_aggregated.txt" 
        else
            echo "Aggregation script $agg_script missing" >&2
        fi
    fi

    if $measure_time && ((${#time_values[@]} > 1)); then
        times_file="$TOP/$BENCHMARK/${BENCHMARK}_times_aggregated.txt"
        log 2 "Runtimes collected: ${time_values[*]}"
        {
            log 1 "Aggregated Wall-Clock Runtimes"
            log 1 "========================================"
            (( verbosity > 0 )) && printf "Runs analysed: %s\n\n" "${#time_values[@]}"

            printf "%s\n" "${time_values[@]}" |
                awk '
                { sum += $1; arr[NR] = $1 }
                END {
                    asort(arr);                       # gawk ≥ 4
                    mean = sum / NR
                    printf "Mean  : %.3f sec\n", mean
                    printf "Min   : %.3f sec\n", arr[1]
                    printf "Max   : %.3f sec\n", arr[NR]
                }
            '

            echo
            log 1 "Per-run raw values:"
            (( verbosity > 0 )) && paste <(seq 1 ${#time_values[@]}) <(printf "%s\n" "${time_values[@]}") |
                awk '{printf "  run %-3s : %.3f sec\n", $1, $2}'
        } >"$times_file"
        log 1 "Runtime statistics:"
        cat "$times_file"
        log 1 "Wrote aggregated runtimes to $times_file"
    fi

    if [ "$run_cleanup" = true ]; then
        log 1 "Cleaning up all files"

        if [ "$measure_time" = true ]; then
            log 2 "Removing time files"
            for ((i = 1; i <= runs; i++)); do
                rm -f "${BENCHMARK}_${shell_safe}_time_run${i}.txt"
            done
            rm -f "$times_file" || true
        fi

        if [ "$measure_resources" = true ]; then
            log 2 "Removing resource stats files"
            for stats_file in "${stats_files[@]}"; do
                rm -f "$stats_file" || true
            done
            rm -f "$TOP/$BENCHMARK/${stats_prefix}.txt" || true
            rm -f "$TOP/$BENCHMARK/${stats_prefix}_aggregated.txt" || true
            rm -f "$TOP/$BENCHMARK/koala-dyn-trellis.pdf" || true
        fi

        log 2 "Removing $BENCHMARK.out, $BENCHMARK.err and $BENCHMARK.hash"
        rm -f "$BENCHMARK.out" "$BENCHMARK.err" "$BENCHMARK.hash" || true
    fi

    log 2 "Returning to original directory"
    cd - || exit 1

}

cd "$(dirname "$0")" || error "Could not cd into script folder"

main "$@"
