#!/bin/bash

SAMPLING_INT=1
CSV_HEADER="Benchmark,Sys Calls,FD_Snapshot,Unique_FD,Peak_FD"
BENCHMARK_TIMEOUT="12000s"

output_file="newbenchmark_results.csv"

default_benchmarks=("net")
benchmarks=()
args=()

found_separator=false

for arg in "$@"; do
    if [[ "$found_separator" == "true" ]]; then
        # Everything after '--' goes into args
        args+=("$arg")
    elif [[ "$arg" == "--" ]]; then
        # Found the separator, flip the flag
        found_separator=true
    else
        benchmarks+=("$arg")
    fi
done

[[ ${#benchmarks[@]} -eq 0 ]] && benchmarks=("${default_benchmarks[@]}")

echo "$CSV_HEADER" > "$output_file"

for benchmark in "${benchmarks[@]}"; do
    echo "------------------------------------------------"
    echo "Running benchmark: $benchmark"
    echo "Passing args to inner scripts: ${args[*]}"

    mkdir -p "/tmp/${benchmark}"
    strace_out="/tmp/${benchmark}_strace.txt"
    snap_out="/tmp/${benchmark}_lsof_snapshot.txt"
    stream_out="/tmp/${benchmark}_lsof_stream.txt"

    if ! cd "./$benchmark"; then
        echo "$benchmark,FAIL: directory not found" >> "../$output_file"
        continue
    fi

    # 1. Install & Fetch
    echo "  -> Installing..."
    ./install.sh || { echo "$benchmark,FAIL: install.sh" >> "../$output_file"; cd - >/dev/null; continue; }
    echo "  -> Fetching..."
    # Pass the captured args to fetch.sh
    ./fetch.sh "${args[@]}" || { echo "$benchmark,FAIL: fetch.sh" >> "../$output_file"; cd - >/dev/null; continue; }

    # 2. RUN 1: LSOF Metric (Background)
    echo "  -> Executing Run 1 (LSOF capture) with ${BENCHMARK_TIMEOUT} timeout..."
    
    # Run in new session so we can track PGID
    # Pass the captured args to execute.sh
    setsid timeout "$BENCHMARK_TIMEOUT" ./execute.sh "${args[@]}" &
    pid=$!
    
    # Give it a moment to start
    sleep 1
    
    # Get PGID (Process Group ID) to track child processes
    pgid=$(ps -o pgid= -p "$pid" | tr -d ' ')

    if [[ -z $pgid ]]; then
        echo "  -> Process finished too quickly or failed to start."
    else
        # Start LSOF Sampler on the Process Group
        lsof -n -P -w -g "$pgid" -r${SAMPLING_INT} > "$stream_out" &
        sampler_pid=$!
        
        # Take a snapshot
        lsof -n -P -w -g "$pgid" > "$snap_out" 2>/dev/null
    fi

    # Wait for the benchmark to finish (or timeout)
    wait "$pid"
    
    # Clean up sampler
    if [[ -n $sampler_pid ]]; then
        kill "$sampler_pid" 2>/dev/null
        wait "$sampler_pid" 2>/dev/null
    fi

    # 3. RUN 2: Strace Metric (Foreground)
    echo "  -> Executing Run 2 (Strace) with ${BENCHMARK_TIMEOUT} timeout..."
    
    # Run strace with timeout.
    # Pass the captured args to execute.sh
    timeout "$BENCHMARK_TIMEOUT" strace -c -f -o "$strace_out" ./execute.sh "${args[@]}" 
    exit_code=$?

    if [ $exit_code -eq 124 ]; then
        echo "  -> WARNING: Run 2 timed out."
    elif [ $exit_code -ne 0 ]; then
         echo "$benchmark,FAIL: strace run failed" >> "../$output_file"
         cd - >/dev/null
         continue
    fi

    # 4. Parse Results
    syscalls=$(grep "100.00" "$strace_out" | awk '{print $4}')
    
    FD_Snapshot=$(awk 'NR>1' "$snap_out" 2>/dev/null | wc -l)
    Unique_FD=$(awk 'NR>1 {print $4":"$10}' "$snap_out" 2>/dev/null | sort -u | wc -l)

    if [[ -s "$stream_out" ]]; then
        Peak_FD=$(awk '
            NF && $1!="COMMAND" {seen[$4":"$10]++}
            /^====/             {print length(seen); delete seen}
        ' "$stream_out" | awk 'max<$1{max=$1} END{print max+0}') 
    else
        Peak_FD=0
    fi

    echo "${benchmark%,/},${syscalls:-0},${FD_Snapshot:-0},${Unique_FD:-0},${Peak_FD:-0}" \
     >> "../$output_file"

    # Cleanup
    rm -f "$strace_out" "$snap_out" "$stream_out"
    cd - >/dev/null
    
    echo "  -> Completed."
done

echo "Benchmark results saved to $output_file."