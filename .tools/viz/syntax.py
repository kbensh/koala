#!/usr/bin/env python3 

import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

#from all_scripts import get_all_scripts
#from project_root import get_project_root
import sys, os
# Add the parent directory to sys.path
sys.path.insert(1, os.path.join(sys.path[0], '..'))
from all_scripts import get_all_scripts
from project_root import get_project_root
import argparse

# Data format example:
# covid-mts/scripts/1.sh,command(cat):1;quoted_control:5;command(sed):1;command(cut):2;command(sort):2;command(uniq):1;command(awk):1;pipeline:1
# file-enc/scripts/encrypt_files.sh,command(mkdir):1;variable_use:4;command(openssl):1;quoted_control:2;function_command:1;command(export):1;assignment:1;command(cat):1;command(pure_func):1;file_redirection:1;pipeline:1;for_command:1
# ...

root = get_project_root()
data_path = root / '.tools/target/nodes_in_scripts.csv'

special_commands = ['eval', 'alias']

node_types = """
pipeline
background
subshell_command
while_command
for_command
case_command
if_command
and_command
or_command
negate_command
function_command
assignment
variable_use
file_redirection
dup_redirection
heredoc_redirection
home_tilde_control
dollar_paren_shell_control
dollar_paren_paren_arith_control
""".strip().split("\n") + special_commands
# Omitted these because they don't seem to be useful:
# ---
# redirection
# raw_command
# escaped_char
# quoted_control

nodes_to_omit = [
    'redirection',
    'raw_command',
    'escaped_char',
    'quoted_control'
]

node_rename_map = {
    'home_tilde_control': 'home_tilde',
    'dollar_paren_shell_control': '$(substitution)',
    'dollar_paren_paren_arith_control': '$((arithmetic))',
    'file_redirection': 'file_redir',
    'dup_redirection': 'dup_redir',
    'heredoc_redirection': 'heredoc_redir',
}

node_order = [
    'command',
    'pipeline',
    'variable_use',
    'assignment',
    'function',
    '$(substitution)',
    #'$((arithmetic))',
    'file_redir',
    'dup_redir',
    'heredoc_redir',
    'negate',
    'or',
    'and',
    'if',
    'case',
    'for',
    'while',
]


def normalize_node_name(node):
    # remove "_command" suffix if present
    renamed = node_rename_map.get(node, node)
    return renamed.replace('_command', '')

def get_map_df():
    items = [
        (str(script.relative_to(root)), benchmark_name)
        for benchmark_name, scripts in get_all_scripts().items()
        for script in scripts
    ]
    return pd.DataFrame(items, columns=['script', 'benchmark'])

def node_heatmap(df, outdir=None):
    # todo which of these are missing entirely?
    #unique_node_names = list(set(df['nodes'].apply(lambda x: [x for x in x.keys()]).sum()))

    heatmap_data = pd.DataFrame(index=list(map(normalize_node_name, node_types)), columns=df['benchmark'])
    for _, row in df.iterrows():
        for node, count in row['nodes'].items():
            if node not in nodes_to_omit:
                heatmap_data.at[normalize_node_name(node), row['benchmark']] = count

    heatmap_data = heatmap_data.fillna(0)
    limit = 5
    # create annotations before capping values then cap the values for display
    annot_data = heatmap_data.applymap(lambda x: '*' if x > limit else '')
    heatmap_data = heatmap_data.applymap(lambda x: min(x, limit))
    
    # order the y-axis of the heatmap according to the node_order, any nodes not in that list can appear after in any order
    heatmap_data = heatmap_data.loc[[x for x in heatmap_data.index if x not in node_order] + list(reversed(node_order))]
    annot_data = annot_data.loc[[x for x in annot_data.index if x not in node_order] + list(reversed(node_order))]

    # Sort the columns by the sum of the values in each column
    # heatmap_data = heatmap_data[heatmap_data.sum().sort_values(ascending=True).index]
    # annot_data = annot_data[heatmap_data.columns]

    # Sort the columns alphabetically
    cols_sorted = sorted(heatmap_data.columns)
    heatmap_data = heatmap_data[cols_sorted]
    annot_data = annot_data[cols_sorted]
    # Add an overall total column, this should be outside the normalizations
    heatmap_data['ALL'] = heatmap_data.sum(axis=1)
    # Create annotation for the ALL column
    annot_data['ALL'] = heatmap_data['ALL'].apply(lambda x: '*' if x > limit else '')
    # Cap the ALL column values for display
    heatmap_data['ALL'] = heatmap_data['ALL'].apply(lambda x: min(x, limit))

    # Set the color limit to be 5
    
    plt.figure(figsize=(5.5, 6))
    sns.heatmap(heatmap_data, 
                cmap='Reds',
                annot=annot_data, 
                fmt='', 
                cbar_kws={'label': 'Occurrences (* denotes more than 5)',
                          'location': 'top'
                        })
    # sns.clustermap(heatmap_data, col_cluster=False, cmap='Reds', annot=annot_data, fmt='', cbar_kws={'label': 'Occurrences (* denotes more than 5)'})
    plt.xlabel('')
    plt.xticks(rotation=60, ha='right')
    plt.ylabel('')
    plt.title('')
    plt.subplots_adjust(bottom=0.15)
    plt.tight_layout()
    if outdir:
        plt.rcParams.update({
            "text.usetex": True,
            "font.family": "serif",
            "font.serif": ["Times New Roman"],  # Replace with your LaTeX font if different
        })
        plt.savefig(os.path.join(outdir, 'koala-stx-analysis.pdf'))
    else:
        plt.show()

def extract_special_command(node):
    for sc in special_commands:
        if node == f'command({sc})':
            return sc
    return node

def merge_node_counts(series):
    merged_dict = {}
    for d in series:
        for k, v in d.items():
            merged_dict[k] = merged_dict.get(k, 0) + v
    return merged_dict

def read_data(merge_commands=True):
    df = pd.read_csv(data_path, header=None)
    df.columns = ['script', 'nodes']
    # Unpack node counts (use rsplit(':', 1) to split from the right, handling colons in command names like command(:))
    df['nodes'] = df['nodes'].apply(lambda x: dict([tuple(i.rsplit(':', 1)) for i in x.split(';')]) if isinstance(x, str) else {})
    # Transform nodes entries for 'command(eval)' and 'command(alias)' into 'eval' and 'alias'
    df['nodes'] = df['nodes'].apply(lambda x: {extract_special_command(k): int(v) for k, v in x.items()})
    if merge_commands:
        # Merge all the "command" nodes, we don't care about the individual commands here
        df['nodes'] = df['nodes'].apply(lambda x: {k: v for k, v in x.items() if 'command(' not in k} | {'command': sum([v for k, v in x.items() if 'command(' in k])})

    # Aggregate by benchmark
    map_df = get_map_df()
    df = df.merge(map_df, on='script')
    bench_df = df.groupby('benchmark').agg({'nodes': merge_node_counts}).reset_index()

    return (df, bench_df)

def main(outdir=None):
    _, df = read_data()
    node_heatmap(df, outdir)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate node heatmap.')
    parser.add_argument('output_dir', nargs='?', help='Directory to save the plot as PDF')
    args = parser.parse_args()
    main(args.output_dir)