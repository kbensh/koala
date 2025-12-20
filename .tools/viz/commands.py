import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import os
from syntax import *

# Data format example:
# covid-mts/scripts/1.sh,command(cat):1;quoted_control:5;command(sed):1;command(cut):2;command(sort):2;command(uniq):1;command(awk):1;pipeline:1
# file-enc/scripts/encrypt_files.sh,command(mkdir):1;variable_use:4;command(openssl):1;quoted_control:2;function_command:1;command(export):1;assignment:1;command(cat):1;command(pure_func):1;file_redirection:1;pipeline:1;for_command:1
# ...

# from wikipedia
coreutil_cmds = 'chcon chgrp chown chmod cp dd df dir dircolors install ln ls mkdir mkfifo mknod mktemp mv realpath rm rmdir shred sync touch truncate vdir b2sum base32 base64 basenc cat cksum comm csplit cut expand fmt fold head join md5sum nl numfmt od paste ptx pr sha1sum sha224sum sha256sum sha384sum sha512sum shuf sort split sum tac tail tr tsort unexpand uniq wc arch basename chroot date dirname du echo env expr factor false groups hostid id link logname nice nohup nproc pathchk pinky printenv printf pwd readlink runcon seq sleep stat stdbuf stty tee test timeout true tty uname unlink uptime users who whoami yes ['.split()
shell_builtins = ['read', 'exit', 'cd', 'export', 'wait', '[[', '.',
                  'set', 'unset', 'exec', 'trap', 'return', 'eval', 'source', 'shift',
                  'pushd', 'popd', 'dirs', 'umask', 'type', 'command', 'enable',
                  'break', 'continue', 'declare', 'export', 'readonly',]
standard_linux_tools = [
    'egrep', 'hostname', 'libtool', 'tcpdump', 'openssl', 'rev', 'ar', 'xargs', 
    'ffmpeg', 'gzip', 'grep', 'iconv', 'git', 'gcc', 'sed', 'col', 'convert', 
    'diff', 'ranlib', 'pandoc', 'clang', 'awk', 'tar', 'make', 'curl', 'perl',
    'top',
    'sh', 'bc', 'which','find', 
    'readonly', 'strings', 'cmp', 
    'gpg', 'lscpu', 'free', 'sysctl', 'ufw', 'firewall-cmd', 'sudo', 
    'nft', 'dpkg', 'pgrep', 'apt-get', 'ps', 'netstat', 'ss'
]

def command_distribution(df, outdir=None):
    command_counts_d = df.agg({'nodes': merge_node_counts})['nodes']
    # turn the command_counts dict into a DataFrame, with keys as the 'command' column and values as the 'count' column
    command_counts = pd.DataFrame(list(command_counts_d.items()), columns=['command', 'count'])
    command_counts = command_counts[command_counts['command'].isin(coreutil_cmds + shell_builtins + standard_linux_tools)]
    command_counts = command_counts.sort_values('count', ascending=False)
    # trim commands with fewer than 10 occurrences
    command_counts = command_counts[command_counts['count'] >= 30]
    # Plot the distribution of commands
    plt.figure(figsize=(6, 5))
    sns.barplot(x='count', y='command', data=command_counts)
    plt.title('')
    plt.xlabel('Count')
    plt.ylabel('')
    plt.subplots_adjust(bottom=0.15, left=0.2)
    if outdir:
        plt.rcParams.update({
            "text.usetex": True,
            "font.family": "serif",
            "font.serif": ["Times New Roman"],  # Replace with your LaTeX font if different
        })
        plt.savefig(os.path.join(outdir, 'koala-cmd-distribution.pdf'), facecolor='none', edgecolor='none')
    else:
        plt.show()

def command_distribution_stacked(df):
    # Extract command counts for each benchmark
    command_counts = []
    for _, row in df.iterrows():
        benchmark = row['benchmark']
        for command, count in row['nodes'].items():
            command_counts.append({'benchmark': benchmark, 'command': command, 'count': count})

    command_counts_df = pd.DataFrame(command_counts)
    command_counts_df = command_counts_df.groupby(['command', 'benchmark']).sum().reset_index()
    command_counts_df = command_counts_df[command_counts_df['count'] >= 10]

    # Pivot the DataFrame to get the counts for each benchmark as columns
    command_pivot = command_counts_df.pivot(index='command', columns='benchmark', values='count').fillna(0)

    # sort by total count
    command_pivot['total'] = command_pivot.sum(axis=1)
    command_pivot = command_pivot.sort_values('total', ascending=False).drop(columns='total')

    # Plot the stacked bar chart
    command_pivot.plot(kind='bar', stacked=True, figsize=(12, 6))
    plt.title('Distribution of commands by benchmark')
    plt.xlabel('Command')
    plt.ylabel('Count')
    plt.legend(title='Benchmark')
    plt.show()

def scripts_using_command_distribution(df, by='benchmark'):
    # Extract unique commands used in each script
    command_usage = []
    for _, row in df.iterrows():
        script = row[by]
        for command in row['nodes'].keys():
            command_usage.append({by: script, 'command': command})

    command_usage_df = pd.DataFrame(command_usage)
    command_usage_counts = command_usage_df.groupby('command')[by].nunique().reset_index()
    command_usage_counts.columns = ['command', 'count']
    command_usage_counts = command_usage_counts.sort_values('count', ascending=False)

    command_usage_counts = command_usage_counts[command_usage_counts['count'] >= (2 if by == 'benchmark' else 5)]

    # Plot the number of scripts using each command
    plt.figure(figsize=(12, 6))
    sns.barplot(x='count', y='command', data=command_usage_counts)
    plt.title(f'Number of {by}s using each command')
    plt.xlabel(f'Number of {by}s')
    plt.ylabel('Command')
    plt.show()

def main(data_path, outdir=None):
    print("\n\nNote: this script will show three plots, one at a time. Close the current plot to show the next one.\n\n")

    df = pd.read_csv(data_path, header=None)
    df.columns = ['script', 'nodes']
    # Unpack node counts
    df['nodes'] = df['nodes'].apply(lambda x: dict([tuple(i.rsplit(':', 1)) for i in x.split(';')]) if isinstance(x, str) else {})
    # Transform nodes entries for 'command(eval)' and 'command(alias)' into 'eval' and 'alias'
    df['nodes'] = df['nodes'].apply(lambda x: {extract_special_command(k): int(v) for k, v in x.items()})
    # Filter out non-command nodes
    df['nodes'] = df['nodes'].apply(lambda x: {k[len('command('):-1]: v for k, v in x.items() if k.startswith('command(')})

    #scripts_using_command_distribution(df, 'script')
    
    # Aggregate by benchmark
    map_df = get_map_df()
    df = df.merge(map_df, on='script')
    df = df.groupby('benchmark').agg({'nodes': merge_node_counts}).reset_index()

    command_distribution(df, outdir)
    #scripts_using_command_distribution(df, 'benchmark')

    # print the total number of distinct commands
    distinct_cmds = df.agg({"nodes": merge_node_counts})["nodes"]
    print(f'Total number of distinct commands: {len(distinct_cmds)}')

    # divide distinct commands into coreutils, shell builtins, standard linux tools, and others
    # as a dataframe with columns type and count
    command_types = []
    for cmd in distinct_cmds.keys():
        if cmd in coreutil_cmds:
            command_types.append({'type': 'coreutil', 'command': cmd})
        elif cmd in shell_builtins:
            command_types.append({'type': 'shell builtin', 'command': cmd})
        elif cmd in standard_linux_tools:
            command_types.append({'type': 'standard linux tool', 'command': cmd})
        else:
            command_types.append({'type': 'other', 'command': cmd})
    command_types_df = pd.DataFrame(command_types)
    command_types_counts = command_types_df.groupby('type')['command'].count()
    print(command_types_counts)
    print()
    print(list(command_types_df[command_types_df['type'] == 'other']['command']))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate command distribution.')
    parser.add_argument('output_dir', nargs='?', help='Directory to save the plot as PDF')
    args = parser.parse_args()
    main(data_path, args.output_dir)
