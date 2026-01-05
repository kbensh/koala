#!/usr/bin/env python3

import pandas as pd
import fnmatch
import viz.syntax as stx
import viz.dynamic as dyn
import sys
import ast

from project_root import get_project_root

root = get_project_root()
data_path = root / '.tools/target/dynamic_analysis.jsonl'
input_size_path = root / '.tools/data/size_inputs.jsonl'
loc_data_path = root / '.tools/target/lines_of_code.csv'
syscall_data_path = root / '.tools/target/benchmarks_syscalls_fds.csv'
input_size_full_path = root / '.tools/data/input_sizes.full.csv'
input_size_small_path = root / '.tools/data/input_sizes.small.csv'
EPSILON = 1e-9

def read_sys_results():
    df = pd.read_csv(syscall_data_path)
    df.rename(columns={'Benchmark': 'benchmark', 'Sys Calls': 'sys_calls'}, inplace=True)
    return df

benchmark_category_style = {
    'analytics': ('System admin.', 'Data analysis', '\\cite{dgsh:ieee:2017,posh:atc:2020,drake2014command}'),
    'bio': ('Data analysis', 'Bio Informatics', '\\cite{Cappellini2019,puritz2019bio594,ibrahim2021tera}'),
    'ci-cd': ('Continuous Integration', 'Build scripts', '\\cite{riker2022,makeself}'),
    'covid': ('Data analysis', 'Data extraction', '\\cite{covid-mts-source}'),
    'edgy': ('Misc. Idk', 'Misc. Idk', '\\cite{mcilroy2014coroutine,hs:hotos:2023}'),
    'file-mod': ('Automation Now', 'Misc. Idk', '\\cite{cito2020empirical,dgsh:ieee:2017,posh:atc:2020}'),
    'inference': ('Machine learning', 'Data analysis', '\\cite{lamprou2025foundation,tunney2023bash}'),
    'interact': ('System admin.', 'Misc. Idk', '\\cite{shnake,ohmyzsh}'),
    'ml': ('Machine learning', 'Data analysis', '\\cite{scikit-learn}'),
    'net': ('Net Work', 'System admin.', '\\cite{Nemeth2017-uf}'),
    'nlp': ('Text processing', 'Machine learning', '\\cite{unix-for-poets-church}'),
    'oneliners': ('Automation Now', 'Text processing', ''),
    'pkg': ('Continuous Integration', 'Automation Now', '\\cite{pacaur,vasilakis2021preventing}'),
    'repl': ('System admin.', 'Misc. Idk', '\\cite{posh:atc:2020,vpsaudit}'),
    'rand': ('Misc. Idk', 'Misc. Idk', '\\cite{cito2020empirical}'),
    'unixfun': ('Misc. Idk', 'Text processing', '\\cite{bhandari2020solutions}'),
    'weather': ('Data analysis', 'Data extraction', '\\cite{hadoop-guide-2009}'),
    'web-search': ('Misc. Idk', 'Text processing', '\\cite{csci1380}'),
}

script_to_citation = {
        'oneliners/scripts/spell.sh': '\\cite{bentley-pearl-cacm-1985}',
        'oneliners/scripts/uniq-ips.sh': '\\cite{majkowski2020bloom}',
        'oneliners/scripts/top-n.sh': '\\cite{bentley-pearl-cacm-1986}',
        'oneliners...': '\\cite{unix-cacm-1974, wicked-cool-shell-scripts}'
}

def short_category(benchmark):
    dom, style, _ = benchmark_category_style[benchmark]
    def shorten(str):
        return ''.join([x[0].upper() for x in str.split(' ')])
    return shorten(dom) + '/' + shorten(style)

def citation(benchmark):
    citation = benchmark_category_style[benchmark][2]
    if 'cite' in citation: 
        return citation
    return ''

benchmark_input_description = {
    'analytics': 'log files',
    'bio': '\\xxx',
    'ci-cd': 'application sources',
    'covid': 'transit data',
    'file-mod': 'media files',
    'inference': '\\xxx',
    'ml': '\\xxx',
    'nlp': 'books',
    'oneliners': '\\xxx',
    'pkg': 'packages',
    'repl': None,
    'unixfun': 'challenge inputs',
    'weather': 'temperature data',
    'web-search': 'root webpages',
    'rand': '\\xxx',
    'edgy': '\\xxx',
    'interact': '\\xxx',
    'net': '\\xxx',
}

def roundk(n):
    if n % 1000 == 0:
        return n // 1000
    return round(n/1000, 1)

def roundm(n):
    if n % 1000000 == 0:
        return n // 1000000
    return round(n/1000000, 1)

benchmark_input_override = {
    'ci-cd': { 'small': None, 'full': None },
    'pkg': { 'small': f'{(100 + 10)} pkgs', 'full': f'{roundk(1768 + 195)}k pkgs' },
    'repl': { 'small': None, 'full': None },
    'nlp': { 'small': f'{roundk(3000)}k bks', 'full': f'{roundk(115916)}k bks' },
}

scripts_to_include = [
    # ml is just 1
    'analytics/scripts/nginx.sh',
    'bio/scripts/bio.sh',
    'bio/scripts/data.sh',
    'ci-cd/makeself/test/lsmtest/lsmtest.sh'
    'ci-cd/riker/redis/build.sh',
    'covid/scripts/1.sh',
    'file-mod/scripts/encrypt_files.sh',
    'file-mod/scripts/img_convert.sh',
    'nlp/scripts/bigrams.sh',
    'oneliners/scripts/spell.sh',
    'oneliners/scripts/top-n.sh',
    'oneliners/scripts/uniq-ips.sh',
    'pkg/scripts/pacaur.sh',
    'pkg/scripts/proginf.sh',
    # 'repl/scripts/vps-audit.sh',
    'unixfun/scripts/1.sh',
    'unixfun/scripts/2.sh',
    # 'weather/scripts/temp-analytics.sh',
    # 'weather/scripts/tuft-weather.sh',
    'web-search/scripts/ngrams.sh',
]

def script_name(script):
    script_name_map = {
            "encrypt_files.sh": "encrypt.sh",
            "img_convert.sh": "img-conv.sh",
    }
    if script in script_name_map:
        return script_name_map[script]
    else:
        return script

def script_citation(script):
    if script in script_to_citation:
        return script_to_citation[script]
    return ''


def count_unique_cmds(series):
    return len({node for node in series if 'command(' in node})

def format_time(n):
    if n < EPSILON:
        return r'\textasciitilde 0'
    elif n < 1e-6:
        return f"{int(n * 1e9)}\\text{{ns}}"
    elif n < 1e-3:
        return f"{int(n * 1e6)}\\text{{µs}}"
    elif n < 1:
        return f"{int(n * 1e3)}\\text{{ms}}"
    else:
        return f"{int(n)}\\text{{s}}"

def count_constructs(series):
    return len(set(series))

def read_loc_data():
    loc_data = pd.read_csv(loc_data_path, header=None)
    loc_data.columns = ['script', 'loc']
    map_df = stx.get_map_df()
    loc_data = loc_data.merge(map_df, on='script')
    loc_data_bench = loc_data.groupby('benchmark').agg({
        'loc': 'sum',
        'script': 'count'
    }).reset_index()
    loc_data_bench.rename(columns={'script': 'number_of_scripts'}, inplace=True)
    return loc_data, loc_data_bench

def prettify_bytes_number(n):
    if n < 1024:
        value, unit = n, "B"
    elif n < 1024 * 1024:
        value, unit = n / 1024, "KB"
    elif n < 1024 * 1024 * 1024:
        value, unit = n / (1024 * 1024), "MB"
    else:
        value, unit = n / (1024 * 1024 * 1024), "GB"
    
    if value < 10:
        decimals = 2
    elif value < 100:
        decimals = 1
    else:
        decimals = 0
    
    color = 'black' if unit == 'GB' else 'gray'
    return f"{value:.{decimals}f}\\textcolor{{{color}}}{{{unit}}}"

def prettify_big_count(n):
    if n < 1000:
        return str(n)
    elif n >= 1000 and n < 10**6:
        return f"{(n/1000):.1f}k"
    elif n >= 10**6 and n < 10**9:
        return f"{n/(10**6):.1f}m"
    else:
        return f"{n/(10**9):.1f}g"

def make_input_description(row):
    # Outputs two columns!

    if row['benchmark'] in benchmark_input_override:
        override = benchmark_input_override[row['benchmark']]
        if override['small'] is None and override['full'] is None:
            return "\\multicolumn{2}{c}{N/A}"
        return f"{override['small']} & {override['full']}"

    if row['input_size_full'] is not None and row['input_size_small'] is not None:
        input_size_full = row['input_size_full']
        input_size_small = row['input_size_small']
        return f"{prettify_bytes_number(input_size_small)} & {prettify_bytes_number(input_size_full)}"
    else:
        # Center the N/A
        return "\\multicolumn{2}{c}{N/A}"

def main():
    syntax_script, syntax_bench = stx.read_data(True)

    syntax_script_all_cmds, syntax_bench_all_cmds = stx.read_data(False)
    dyn_script, dyn_bench = dyn.read_data()
    loc_data_script, loc_data_bench = read_loc_data()
    sys_results = read_sys_results()

    # fill any benchmarks missing from sys_results
    for benchmark in syntax_bench['benchmark']:
        if benchmark not in sys_results['benchmark'].values:
            new_row = pd.DataFrame([{'benchmark': benchmark, 'sys_calls': '\\xxx'}])
            sys_results = pd.concat([sys_results, new_row], ignore_index=True)
    sys_results.reset_index(drop=True, inplace=True)
    # replace sys_results file_descriptors numbers with those from children_num_fds in dyn_bench
    sys_results = sys_results.merge(dyn_bench[['benchmark', 'children_num_fds']], on='benchmark')
    sys_results['file_descriptors'] = sys_results['children_num_fds']

    syntax_script_all_cmds['unique_cmds'] = syntax_script_all_cmds['nodes'].apply(count_unique_cmds)
    syntax_bench_all_cmds['unique_cmds'] = syntax_bench_all_cmds['nodes'].apply(count_unique_cmds)
    syntax_script['constructs'] = syntax_script['nodes'].apply(count_constructs)
    syntax_bench['constructs'] = syntax_bench['nodes'].apply(count_constructs)
    
    all_scripts = set(syntax_script['script'].unique())
    
    # missing_in_dyn = all_scripts - set(dyn_script['script'].unique())
    # missing_in_loc_data = all_scripts - set(loc_data_script['script'].unique())
    # missing_in_cmds = all_scripts - set(syntax_script_all_cmds['script'].unique())
    
    # print("Missing in dyn_script:", missing_in_dyn, file=sys.stderr)
    # print("Missing in loc_data_script:", missing_in_loc_data, file=sys.stderr)
    # print("Missing in syntax_script_all_cmds:", missing_in_cmds, file=sys.stderr)

    dyn_bench['input_description'] = dyn_bench['benchmark'].apply(lambda x: benchmark_input_description[x])

    big_bench = syntax_bench.merge(dyn_bench, on='benchmark')\
        .merge(loc_data_bench, on='benchmark')\
        .merge(syntax_bench_all_cmds[['benchmark', 'unique_cmds']], on='benchmark')\
        .merge(sys_results, on='benchmark')

    full_data_sizes = pd.read_csv(input_size_full_path, index_col=0)
    small_data_sizes = pd.read_csv(input_size_small_path, index_col=0)

    big_bench['input_size_full'] = big_bench['benchmark'].apply(lambda x: full_data_sizes.loc[x, 'size_bytes'] if x in full_data_sizes.index else None)
    big_bench['input_size_small'] = big_bench['benchmark'].apply(lambda x: small_data_sizes.loc[x, 'size_bytes'] if x in small_data_sizes.index else None)
    
    big_script = syntax_script.merge(dyn_script, on='script')\
        .merge(loc_data_script, on='script')\
        .merge(syntax_script_all_cmds[['script', 'unique_cmds']], on='script')

    # embedding_df = pd.read_csv(root / '.tools/data/embeddings.csv')
    # embedding_df['embedding'] = embedding_df['embedding'].apply(lambda x: ast.literal_eval(x) if isinstance(x, str) else x)
    # # Embedding is a list of numbers, turn them into columns
    # embedding_df = pd.concat([embedding_df['benchmark'], embedding_df['embedding'].apply(pd.Series)], axis=1)
    
    # Calculate summary statistics
    agg_order = ['min', 'max', 'mean', 'median']
    summary_names = [s.capitalize() for s in agg_order]
    summary_stats = big_bench[['loc', 'constructs', 'unique_cmds', 'number_of_scripts', 'input_size_full', 'input_size_small']].agg(agg_order).reset_index()
    summary_stats.rename(columns={
        'index': 'benchmark',
        'loc': 'loc',
        'constructs': 'constructs',
        'unique_cmds': 'unique_cmds',
        'number_of_scripts': 'number_of_scripts'
    }, inplace=True)

    print(big_bench['sys_calls'], file=sys.stderr)

    # Add placeholder values for non-numeric columns
    summary_stats['benchmark'] = summary_names
    summary_stats['sys_calls'] = big_bench['sys_calls'].agg(agg_order).values if big_bench['sys_calls'].dtype == 'int64' else '\\xxx'
    summary_stats['file_descriptors'] = big_bench['file_descriptors'].agg(agg_order).values if big_bench['file_descriptors'].dtype == 'int64' else '\\xxx'
    summary_stats['input_description'] = None
    summary_stats['time_in_shell'] = big_bench['time_in_shell'].agg(agg_order).values
    summary_stats['time_in_commands'] = big_bench['time_in_commands'].agg(agg_order).values
    summary_stats['max_unique_set_size'] = big_bench['max_unique_set_size'].agg(agg_order).values
    summary_stats['io_chars'] = big_bench['io_chars'].agg(agg_order).values
    summary_stats['number_of_scripts'] = big_bench['number_of_scripts'].agg(agg_order).values
    # Ignore rows that have no input_description
    # summary_stats['input_size'] = big_bench[big_bench['input_description'].notnull()]['input_size'].agg(agg_order).values
    summary_stats['input_description'] = '\\xxx' # Have something so that N/A doesn't show up

    # print sum of number_of_scripts on stderr
    print(f"Total number of scripts: {big_bench['number_of_scripts'].sum()}", file=sys.stderr)

    print("""
    \\begin{tabular}{@{}llrrrrrrrrrrrrl@{}}
    \\toprule
    \\multirow{2}{*}{Benchmark/Script} & \\multicolumn{3}{c}{Surface} & \\multicolumn{2}{c}{Inputs} & \\multicolumn{2}{c}{Syntax} & \\multicolumn{4}{c}{Dynamic} & \\multicolumn{2}{c}{System} & \\multirow{2}{*}{Source} \\\\
        \\cline{2-4} \\cline{5-6} \\cline{7-8} \\cline{9-12} \\cline{13-14}
                                      & \multicolumn{1}{c}{\\Dom}  & \\#.sh     & LoC     & Small & Full & \\#Cons & \\#Cmd & $t_{S}$  & $t_{C}$  & Mem   & I/O & \\#SC & \\#FD &   \\\\
        \\midrule
    """)
    # generate a big latex table with the following columns:
    # benchmark, short_category, number of scripts, LOC, number of constructs, number of unique commands, input description, time in shell, time in commands, max memory, IO
    for _, row in big_bench.iterrows():
        numscripts_shown = 0
        numscripts = row['number_of_scripts']
        print(f"\\bs{{{row['benchmark']}}} & {short_category(row['benchmark'])} & {row['number_of_scripts']} & {row['loc']} & {make_input_description(row)} & {row['constructs']} & {row['unique_cmds']} & {format_time(row['time_in_shell'])} & {format_time(row['time_in_commands'])} & {prettify_bytes_number(row['max_unique_set_size'])} & {prettify_bytes_number(row['io_chars'])} & {prettify_big_count(row['sys_calls'])} & {row['file_descriptors']} & {citation(row['benchmark'])} \\\\")
        # now print the details of all scripts in the benchmark
        for _, row_script in big_script.iterrows():
            if row_script['benchmark'] == row['benchmark'] and any([fnmatch.fnmatch(row_script['script'], pattern) for pattern in scripts_to_include]):
                # all columns except leave blank benchmark, category, number of scripts, input description
                print(f"\\hspace{{0.5em}} \\ttt{{{script_name(row_script['script'].split('/')[-1])}}} & & & {row_script['loc']} & & & {row_script['constructs']} & {row_script['unique_cmds']} & {format_time(row_script['time_in_shell'])} & {format_time(row_script['time_in_commands'])} & {prettify_bytes_number(row_script['max_unique_set_size'])} & {prettify_bytes_number(row_script['io_chars'])} & & & {script_citation(row_script['script'])} \\\\")
                numscripts_shown += 1
        if numscripts_shown < numscripts and numscripts > 1:
            print(f"\\hspace{{0.5em}} \\ldots & & & & & & & & & & & & & & {script_citation(row['benchmark'] + '...')} \\\\")

    print("\\midrule")
    for aggregate in ['Min', 'Mean', 'Median', 'Max']:
        row = summary_stats[summary_stats['benchmark'] == aggregate].iloc[0]
       
        def format_value(value):
            def round_whole(numstr):
                if numstr.endswith(".0"):
                    return numstr[:-2]
                return numstr
            if isinstance(value, (int, float)):
                return round_whole(f"{value:.1f}") if isinstance(value, float) else f"{int(value)}"
            return value  # For non-numeric values

        print(f"{{\\textbf{{\\centering {row['benchmark']}}}}} & & {format_value(row['number_of_scripts'])} & {format_value(row['loc'])} & {prettify_bytes_number(row['input_size_small'])} & {prettify_bytes_number(row['input_size_full'])} & {format_value(row['constructs'])} & {format_value(row['unique_cmds'])} & {format_value(row['time_in_shell'])} & {format_value(row['time_in_commands'])} & {prettify_bytes_number(row['max_unique_set_size'])} & {prettify_bytes_number(row['io_chars'])} & {prettify_big_count(row['sys_calls'])} & {format_value(row['file_descriptors'])} & \\\\")

    print("""
    \\bottomrule
  \\end{tabular}
""")
    
if __name__ == '__main__':
    main()
