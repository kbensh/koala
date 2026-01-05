#!/usr/bin/env python3

from typing import Optional
import lzma
from collections import defaultdict
from pathlib import Path
import json
import math
import sys
from dataclasses import dataclass

from project_root import get_project_root

def correct_base(path):
    return Path(path).is_relative_to('/koala')

def rebase(path):
    return Path(path).relative_to('/koala')

def is_shell(pid, processes):
    a = next(iter(processes[pid].values()))
    return len(a.cmdline) > 0 and a.cmdline[0].endswith('sh')

def get_input_files(record):
    s = set()
    for file_path, _, _, mode, _ in record.open_files:
        known_modes = {'r', 'r+', 'w', 'a'}
        assert mode in known_modes, f"unknown mode {mode}"
        is_a_script = '.sh' in Path(file_path).suffixes
        if mode != 'w' and not is_a_script and correct_base(file_path):
            s.add(file_path)
    return s

@dataclass(slots=True)
class MortemEntry:
    io_zombie: str
    stat_zombie: str
    elapsed_secs: str
    stat_before: str
    stat_after: str
    script: str
    pid: int
    benchmark_experiment_start: str
    category: str
    input_file: Optional[str]
    sc_clk_tck: int

@dataclass(slots=True)
class LogEntry:
    pid: int
    parent: int
    times: list
    log_current_time: str
    benchmark_experiment_start: str
    cmdline: list[str]
    cwd: str
    create_time: float
    uss: int
    num_fds: int
    open_files: list

def read_log_file(path):
    parents = defaultdict(lambda: None)
    children = defaultdict(set)
    processes = defaultdict(list)
    with lzma.open(path, 'r') as lines:
        for entries in lines:
            for data in json.loads(entries): 
                data = LogEntry(**data)
                processes[data.pid].append(data)
                children[data.parent].add(data.pid)
                parents[data.pid] = data.parent
    processes = defaultdict(lambda: None, {pid: {r.log_current_time: r for r in rs} for pid, rs in processes.items()})
    return processes, parents, children

def get_descendents(pid: int, children: dict[int, set[int]]) -> set[int]:
    descendents = set()
    stack = [pid]
    while len(stack) > 0:
        pid = stack.pop()
        descendents.add(pid)
        stack += children[pid]
    return descendents

@dataclass
class Stat:
    utime: int
    stime: int
    cutime: int
    cstime: int

@dataclass
class PsutilTimes:
    user: float
    system: float
    children_user: float
    children_system: float
    iowait: float

def get_stat(stat_file_contents: str, sc_clk_tck: int):
    # https://linux.die.net/man/5/proc
    stat = stat_file_contents.split()
    return Stat(
        utime=float(stat[13]) / sc_clk_tck,
        stime=float(stat[14]) / sc_clk_tck,
        cutime=float(stat[15]) / sc_clk_tck,
        cstime=float(stat[16]) / sc_clk_tck,
    )

@dataclass
class Io:
    rchar: int
    wchar: int

def get_io(io_file_contents: str):
    io_file_contents = io_file_contents.splitlines()
    _, rchar = next(l for l in io_file_contents if l.startswith('rchar')).split()
    _, wchar = next(l for l in io_file_contents if l.startswith('wchar')).split()
    return Io(
        rchar=int(rchar),
        wchar=int(wchar),
    )

def get_desc(pid, processes):
    return next(p for p in processes[pid].values())

def find_shell_process(pid, processes):
    children = [
        p for p in processes
        if get_desc(p, processes).parent == pid
    ]
    if len(children) != 1:
        return None
    assert get_desc(children[0], processes).cmdline[0].endswith("sh")
    return children[0]

def print_statistics(pid, processes, parents, children, mortem):
    pid = find_shell_process(pid, processes)
    if pid is None:
        print(f"No shell process logged for script {mortem.script}", file=sys.stderr)
        return
    assert is_shell(pid, processes)
    descendents = get_descendents(pid, children)

    all_readings = list(processes[pid].keys())

    stat_zombie = get_stat(mortem.stat_zombie, mortem.sc_clk_tck)
    stat_before = get_stat(mortem.stat_before, mortem.sc_clk_tck)
    stat_after = get_stat(mortem.stat_after, mortem.sc_clk_tck)
    io_zombie = get_io(mortem.io_zombie)

    script = str(rebase(mortem.script))
    user = stat_after.cutime - stat_before.cutime
    system = stat_after.cstime - stat_before.cstime
    uss = max(
        sum(processes[d][r].uss for d in descendents if r in processes[d])
        for r in all_readings
    )
    read_chars = io_zombie.rchar
    write_chars = io_zombie.wchar

    tis_user = sum(max(PsutilTimes(*r.times).user for r in processes[d].values()) for d in descendents - {pid} if is_shell(d, processes))
    tis_system = sum(max(PsutilTimes(*r.times).system for r in processes[d].values()) for d in descendents - {pid} if is_shell(d, processes))
    tis_user += stat_zombie.utime # we have a more accurate measurement of the first process
    tis_system += stat_zombie.stime # we have a more accurate measurement of the first process

    input_files = set(p for d in descendents for r in processes[d].values() for p in get_input_files(r)) 
    if mortem.input_file is not None and correct_base(mortem.input_file):
        input_files |= {mortem.input_file}
    input_files = list(str(rebase(p)) for p in input_files)

    duration = float(mortem.elapsed_secs)

    start = mortem.benchmark_experiment_start

    category = mortem.category

    num_fds = max(r.num_fds for r in processes[pid].values())
    children_num_fds = max(
        sum(processes[d][r].num_fds for d in descendents if r in processes[d])
        for r in all_readings
    )

    data = dict(
        script=script,
        user_time=user,
        system_time=system,
        max_unique_set_size=uss,
        read_chars=read_chars,
        write_chars=write_chars,
        user_time_in_shell=tis_user,
        system_time_in_shell=tis_system,
        all_input_files=input_files,
        wall_time=duration,
        start_time=start,
        category=category,
        num_fds=num_fds,
        children_num_fds=children_num_fds,
    )
    print(json.dumps(data))

if __name__ == '__main__':
    root = get_project_root()
    process_logs = root / '.tools' / 'target' / 'process-logs'
    for mortem_path in process_logs.glob('*.mortem'):
        print('processing log', mortem_path.relative_to(root), file=sys.stderr)
        mortems = [
            MortemEntry(**json.loads(line)) 
            for line in mortem_path.read_text().splitlines()
        ]
        mortems = {
            mortem.pid: mortem
            for mortem in mortems 
        }
        path = mortem_path.with_suffix('.jsonl.xz')
        processes, parents, children = read_log_file(path)
        top_level = [pid for pid in processes if parents[parents[pid]] is None]
        for pid in top_level:
            print_statistics(pid, processes, parents, children, mortem=mortems[pid])
