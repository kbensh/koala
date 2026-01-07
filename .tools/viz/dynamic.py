#!/usr/bin/env python3

import argparse
from sys import stderr
from pathlib import Path
import pandas as pd
import seaborn as sns
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors
import sys, os
# Add the parent directory to sys.path
sys.path.insert(1, os.path.join(sys.path[0], '..'))
from all_scripts import get_all_scripts
from project_root import get_project_root

root = get_project_root()
data_path = root / '.tools/target/dynamic_analysis.jsonl'
input_size_path = root / '.tools/data/size_inputs.jsonl'

figsize = (5, 3)

def get_input_sizes_df(df):
    if df.empty or df.columns.empty:
        return None 
    sizes_df = pd.read_json(input_size_path, lines=True)
    dupes = (
        sizes_df
        .groupby(['category', 'path'], as_index=False)
        .size()
        .query('size > 1') 
    ) # in case something went wrong with the input sizes file, we can still plot the rest of the data

    if not dupes.empty:
        print("Duplicate (category, path) pairs in size_inputs.jsonl:", file=stderr)
        print(dupes.to_string(index=False), file=stderr)
    def find_input_size(row):
        total = 0
        for file in row['all_input_files']:
            file_path = file
            try:
                file = Path(file).relative_to(row['category'])
            except ValueError:
                continue
            file_rest = str(Path(*file.parts[1:]))
            relevant = sizes_df[(sizes_df['path'] == file_rest) & (sizes_df['category'] == row['category'])]
            if relevant.empty:
                if 'sort' in str(file_path): # one of them sort files
                    continue
                if 'ci-cd/input' in str(file_path): 
                    # these should all be in the file, 
                    # everything else is in an intermediate
                    continue 
                if 'pkg/outputs' in str(file_path):
                    # these are intemediate files
                    continue
                if 'bio/outputs' in str(file_path):
                    # these are intemediate files
                    continue
                if 'test_result' in str(file_path):
                    # these are final files
                    continue
                if 'outputs/thumbnail.small' in str(file_path):
                    # these are intermediate files
                    continue
                if 'repl/inputs/chromium' in str(file_path):
                    # these are intermediate files
                    continue
                #print('could not find input size for', file, row['script'], file=stderr)
                continue
            size = relevant['size_bytes'].iloc[0]
            total += size
        return total
    df['input_size'] = df.apply(find_input_size, axis=1)
    return df

def get_map_df():
    items = [
        (str(script.relative_to(root)), benchmark_name)
        for benchmark_name, scripts in get_all_scripts().items()
        for script in scripts
    ]
    return pd.DataFrame(items, columns=['script', 'benchmark'])

def plot_benchmark_times(df,
                         ax,
                         legend=True,
                         ticks = ([0, 0.1, 1, 10, 100, 1000, 10000], 
                                  ['0', '0.1s', '1s', '10s', '100s', '1,000s', '10,000s']),
                         ylabel='CPU time',
                         linthresh=0.1):
    sns.set(style="whitegrid")
    ax.grid(True, which='both', axis='y')
    data = df.copy()
    # pivot
    data = data.melt(id_vars=['benchmark'], value_vars=['time_in_shell', 'time_in_commands'], var_name='type', value_name='timeSorC')
    data['type'] = data['type'].str.replace('_', ' ')
    data['type'] = data['type'].str.replace('time in commands', 'time in cmds')
    bar = sns.barplot(x='benchmark', y='timeSorC', hue='type', data=data, palette=['#56B4E9', '#009E73'],  ax=ax, zorder=3)
    first_color = ax.patches[0].get_facecolor()
    for i, bar in enumerate(ax.patches):
        if bar.get_facecolor() == first_color:
            bar.set_hatch('//')
        else:
            bar.set_hatch('\\\\')
    ax.set_xticklabels(ax.get_xticklabels(), rotation=60, ha='right')
    ax.set_xlabel('')
    ax.set_yscale('symlog', linthresh=linthresh)
    ax.set_yticks(ticks[0])
    ax.set_yticklabels(ticks[1])
    ax.set_ylabel(ylabel)
    ax.set_ybound(lower=0)
    if legend is True:
        ax.legend(loc='upper left')
    elif isinstance(legend, tuple):
        ax.legend(loc='upper left')
    else:
        ax.legend().set_visible(False)

def plot_io(df,
            ax,
            ticks=([0, 100000000, 1000000000, 10000000000, 100000000000, 1000000000000], 
                   ['0', '100MB', '1GB', '10GB', '100GB', '1TB']),
            ylabel='IO bytes',
            linthresh=100000000):
    sns.set(style="whitegrid")
    ax.grid(True, which='both', axis='y')
    sns.barplot(x='benchmark', y='io_chars', data=df, color='#CC79A7', ax=ax, zorder=3)
    ax.set_yscale('symlog', linthresh=linthresh)
    ax.set_yticks(ticks[0])
    ax.set_yticklabels(ticks[1])
    ax.set_ylabel(ylabel)
    #ax.set_xticklabels(ax.get_xticklabels(), rotation=60, ha='right')
    ax.set_xlabel('')

def plot_memory(df,
                ax,
                ticks=([0, 1000000, 10000000, 100000000, 1000000000, 10000000000, 100000000000], 
                       ['0', '1MB', '10MB', '100MB', '1GB', '10GB', '100GB']),
                ylabel='Memory (high water, bytes)',
                linthresh=1000000):
    sns.set(style="whitegrid")
    ax.grid(True, which='both', axis='y')
    sns.barplot(x='benchmark', y='max_unique_set_size', data=df, color='#D55E00', ax=ax, zorder=3)
    #ax.set_xticklabels(ax.get_xticklabels(), rotation=60, ha='right')
    ax.set_xlabel('')
    ax.set_yscale('symlog', linthresh=linthresh)
    ax.set_yticks(ticks[0])
    ax.set_yticklabels(ticks[1])
    ax.set_ylabel(ylabel)

def plot_time_vs_wall(df, ax):
    # what fraction of the real (wall) runtime of the process is user or system time?
    df['time_occupied'] = (df['user_time'] + df['system_time']) / df['wall_time']
    
    # The net benchmark is mostly I/O waiting, so CPU/Wall ratio is near 0.
    # We force it to 0.1 so it appears on the graph.
    df.loc[(df['benchmark'] == 'net') & (df['time_occupied'] < 0.1), 'time_occupied'] = 0.1

    sns.set(style="whitegrid")
    ax.grid(True, which='both', axis='y')
    sns.barplot(x='benchmark', y='time_occupied', data=df, color='#0072B2', ax=ax, zorder=3)
    #ax.set_xticklabels(ax.get_xticklabels(), rotation=60, ha='right')
    ax.set_xlabel('')
    ax.set_yticks(np.linspace(0, 7, 8))
    ax.set_ylabel('CPU time / wall time')

dynamic_analysis_script_translations = {
    "ci-cd/riker/vim/execute.sh": "ci-cd/riker/vim/build.sh",
    "ci-cd/riker/xz/execute.sh": "ci-cd/riker/xz/build.sh",
    "ci-cd/riker/redis/execute.sh": "ci-cd/riker/redis/build.sh",
    "ci-cd/riker/xz-clang/execute.sh": "ci-cd/riker/xz-clang/build.sh",
    "ci-cd/riker/lua/execute.sh": "ci-cd/riker/lua/build.sh",
    "ci-cd/riker/memcached/execute.sh": "ci-cd/riker/memcached/build.sh",
    "ci-cd/riker/sqlite/execute.sh": "ci-cd/riker/sqlite/build.sh",
    "ci-cd/riker/lsof/execute.sh": "ci-cd/riker/lsof/build.sh",
}

def read_data():
    df = pd.read_json(data_path, lines=True)
    for col in list(df.columns[1:7]) + list(df.columns[9:10]):
        df[col] = df[col].astype(float)

    df = get_input_sizes_df(df)
    if df is None:
        return None, None

    # translate any script names that need it
    # unfortunately this is a bit of a hack to cover up some inconsistency between what the dynamic analysis sees as the "main script" run by a benchmark, 
    # and what really is the main script that the syntax analysis considers
    # TODO: move this mapping above into script_globs.json to make this discrepancy a little more explicit
    df['script'] = df['script'].apply(lambda x: dynamic_analysis_script_translations.get(x, x))

    # aggregate by benchmark
    map_df = get_map_df()
    df = df.merge(map_df, on='script')

    # report any benchmarks where the wall time is not approximately equal to the sum of user and system time
    # for _, row in df.iterrows():
    #     if abs(row['wall_time'] - (row['user_time'] + row['system_time'])) > 0.1:
    #         print(f"Wall time for benchmark {row['benchmark']} maybe suspicious: {row['wall_time']} vs (u{row['user_time']} + s{row['system_time']})", file=stderr)

    # merge the read and write_chars
    df['io_chars'] = df['read_chars'] + df['write_chars']
    # calculate time in shell and time in commands
    df['time'] = df['user_time'] + df['system_time']
    df['time_in_shell'] = df['user_time_in_shell'] + df['system_time_in_shell']
    df['time_in_commands'] = df['time'] - df['time_in_shell']

    # sum all times
    bench_df = df.groupby('benchmark').agg({'user_time': 'sum', 
                                      'system_time': 'sum',
                                      'max_unique_set_size': 'max',
                                      'read_chars': 'sum', 
                                      'write_chars': 'sum', 
                                      'user_time_in_shell': 'sum', 
                                      'system_time_in_shell': 'sum', 
                                      'input_size': 'sum',
                                      'io_chars': 'sum',
                                      'time': 'sum',
                                      'time_in_shell': 'sum',
                                      'time_in_commands': 'sum',
                                      'wall_time': 'sum',
                                      'children_num_fds': 'sum'}).reset_index()

    df = df.sort_values("benchmark")
    bench_df = bench_df.sort_values("benchmark")
    return df, bench_df

def main(output_dir=None, text_mode=False):
    _, df = read_data()
    if df is None:
        print('Dynamic analysis failed, no data to plot', file=stderr)
        return
    # if text_mode:
    stats_filename = os.path.join(output_dir, "benchmark_stats.txt") if output_dir else "benchmark_stats.txt"

    with open(stats_filename, "w") as f:
        f.write("Benchmark Statistics\n")
        f.write("=" * 50 + "\n")

        for benchmark in df["benchmark"].unique():
            bench_df = df[df["benchmark"] == benchmark]
            f.write(f"\nBenchmark: {benchmark}\n")
            f.write("-" * 50 + "\n")
            f.write(f"Total CPU time: {bench_df['time'].sum():.2f} sec\n")
            f.write(f"Total Wall time: {bench_df['wall_time'].sum():.2f} sec\n")
            f.write(f"Total IO bytes: {bench_df['io_chars'].sum():.2f}\n")
            f.write(f"Max Memory Usage: {bench_df['max_unique_set_size'].max():.2f} bytes\n")
                
            input_size_sum = bench_df['input_size'].sum()

            if input_size_sum > 0:
                f.write(f"CPU time per input byte: {bench_df['time'].sum() / input_size_sum:.6f} sec/byte\n")
                f.write(f"Memory per input byte: {bench_df['max_unique_set_size'].sum() / input_size_sum:.6f} bytes/byte\n")
                f.write(f"IO per input byte: {bench_df['io_chars'].sum() / input_size_sum:.6f} bytes/byte\n")
            else:
                f.write("CPU time per input byte: N/A (no input bytes recorded)\n")
                f.write("Memory per input byte: N/A (no input bytes recorded)\n")
                f.write("IO per input byte: N/A (no input bytes recorded)\n")

            f.write(f"Time in Shell: {bench_df['time_in_shell'].sum():.2f} sec\n")
            f.write(f"Time in Commands: {bench_df['time_in_commands'].sum():.2f} sec\n")
            f.write("=" * 50 + "\n")

    print(f"Benchmark stats written to {stats_filename}")


    def name(str):
        return os.path.join(output_dir, f"koala-dyn-{str}.pdf") if output_dir else None
    
    
#     # this metric is bad in the cases that we don't have the data for the inputs
#     # the benchmark has a specific input on disk that it processed. how much of this input did it process per second?
#     df['bytes_per_second_input'] = df['input_size'] / (df['wall_time'])
#     sns.set(style="whitegrid")
#     plt.figure(figsize=figsize)
#     sns.barplot(x='benchmark', y='bytes_per_second_input', data=df, color='blue', label='Commands')
#     plt.xticks(rotation=60, ha='right')
#     plt.title('missing input')
#     plt.yscale('symlog', linthresh=1e1)
#     plt.yticks(np.logspace(1, 12, 12))
#     plt.ylabel('bytes (input file size) per second (wall time)')
#     plt.legend()
#     plt.show()

    # # fraction of the actual scheduled (user + system) time is in the shell. how much cpu work is in the launnched shell
    # df['time_in_shell_frac'] = (df['user_time_in_shell'] + df['system_time_in_shell']) / (df['user_time'] + df['system_time'])
    # sns.set(style="whitegrid")
    # plt.figure(figsize=figsize)
    # sns.barplot(x='benchmark', y='time_in_shell_frac', data=df, color='blue', label='Commands')
    # plt.xticks(rotation=60, ha='right')
    # plt.subplots_adjust(bottom=0.25)
    # plt.yticks(np.linspace(0, 1, 10))
    # plt.ylabel('fraction of time (utime + stime) in the shell')
    # plt.legend()
    # plt.show()

    num_plots = 8
    cols = 2
    rows = num_plots // cols
    fig, axes = plt.subplots(rows, cols, figsize=(12 , 9), sharex=True)
    axes = axes.flatten()
    
    # the benchmark did a certain amount of io. how many bytes per second was this?
    df_rel_to_wall = df.copy()
    df_rel_to_wall['io_chars'] = (df_rel_to_wall['read_chars'] + df_rel_to_wall['write_chars']) / (df_rel_to_wall['wall_time'])

    df_rel_to_input = df.copy()
    df_rel_to_input['io_chars'] = df_rel_to_input['io_chars'] / df_rel_to_input['input_size']
    df_rel_to_input['max_unique_set_size'] = df_rel_to_input['max_unique_set_size'] / df_rel_to_input['input_size']
    df_rel_to_input['time_in_shell'] = df_rel_to_input['time_in_shell'] / df_rel_to_input['input_size']
    df_rel_to_input['time_in_commands'] = df_rel_to_input['time_in_commands'] / df_rel_to_input['input_size']

    plot_io(df_rel_to_wall, 
            axes[1],
            ylabel='IO per second wall time',
            ticks=([0, 1000000, 10000000, 100000000, 1000000000, 10000000000], 
                   ['0', '1MB', '10MB', '100MB', '1GB', '10GB']),
            linthresh=1000000)

    plot_time_vs_wall(df, axes[0])
    plot_benchmark_times(df, axes[2], legend=False)
    plot_memory(df, axes[4])
    plot_io(df, axes[6])

    plot_benchmark_times(df_rel_to_input, 
                         axes[3],
                         legend=True,
                         ylabel='CPU time per input byte',
                         ticks=([0, 0.00000001, 0.0000001, 0.000001, 0.00001, 0.0001, 0.001], 
                                ['0', '10ns', '100ns',    '1µs',    '10µs', '100µs',  '1ms']),
                                linthresh=0.00000001)
    plot_io(df_rel_to_input, 
            axes[7],
            ylabel='IO per input byte',
            ticks=([0,    1,   10,     100,    1000,  10000, 100000], 
                   ['0', '1B', '10B', '100B', '1KB', '10KB', '100KB']),
                   linthresh=1)
    plot_memory(df_rel_to_input, 
                axes[5],
                ylabel='Memory per input byte',
                ticks=([0,   0.001,   0.01,     0.1,  1,    10,    100,   1000], 
                       ['0', '0.001B', '0.01B', '0.1B', '1B', '10B', '100B', '1KB']),
                linthresh=0.001)
    
    plt.setp(axes[6].get_xticklabels(), visible=True, rotation=60, ha='right')
    plt.setp(axes[7].get_xticklabels(), visible=True, rotation=60, ha='right')
    
    plt.rcParams.update({
        "text.usetex": True,
        "font.family": "serif",
        "font.serif": ["Times New Roman"],  # Replace with your LaTeX font if different
    })
    benchmarks = df["benchmark"].unique()
    for ax in axes:
        ax.set_xticks(range(len(benchmarks)))
        ax.set_xticklabels(benchmarks, rotation=60, ha='right')

    plt.tight_layout(rect=[0, 0.05, 1, 1]) 
    fig.align_ylabels(axes)
    # for i in range(2, len(axes)):
    #     # adjust the position of the axes down a little bit
    #     pos = axes[i].get_position()
    #     pos.y0 -= 0.05
    #     pos.y1 -= 0.05
    #     axes[i].set_position(pos)
    if output_dir:
        plt.savefig(name('trellis'))
    else:
        plt.show()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate dynamic characterization plots or print stats.')
    parser.add_argument('output_dir', nargs='?', help='Directory to save the plots as PDF or text file')
    parser.add_argument('--text', action='store_true', help='Save benchmark stats as a text file instead of plotting')

    args = parser.parse_args()
    main(args.output_dir, args.text)