#!/usr/bin/env python3
"""
generate_size_inputs.py  –  write size_inputs.jsonl for selected benchmarks.

Edit `BENCHMARKS` below to control which benchmark trees are scanned.
"""

import argparse
import json
import os
import pathlib
import subprocess
import sys
from typing import Iterable, List

BENCHMARKS: List[str] = ["analytics", "bio", "ci-cd", "covid", "edgy", "file-mod", "inference", "interact", "ml", "net", "nlp", "oneliners", "pkg", "rand", "repl", "unixfun", "weather", "web-search"]

def git_root() -> pathlib.Path:
    try:
        root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"], text=True
        ).strip()
        return pathlib.Path(root)
    except subprocess.CalledProcessError:
        sys.exit("Not inside a Git repository.")


def du_size(path: str) -> int:
    try:
        out = subprocess.check_output(["du", "-b", path], text=True)
        return int(out.split()[0])
    except Exception:
        return os.stat(path).st_size


def walk_files(root: pathlib.Path):
    yield from (p for p in root.rglob("*") if p.is_file())

def emit_records(bench_root: pathlib.Path, out_file: pathlib.Path) -> None:
    skip_paths = [bench_root / "repl" / "inputs", 
                  bench_root / "ci-cd" / "inputs"]
    for bench in BENCHMARKS:
        inputs_dir = bench_root / bench / "inputs"
        if not inputs_dir.is_dir():
            sys.stderr.write(f"Skipped “{bench}” (no inputs/ directory)\n")
            continue
        if inputs_dir in skip_paths:
            sys.stderr.write(f"Skipped “{bench}” (inputs/ directory is in skip_paths)\n")
            continue
        with out_file.open("a", encoding="utf-8") as fh:
            for file in walk_files(inputs_dir):
                rel_path = file.relative_to(inputs_dir).as_posix()
                size = du_size(str(file))
                record = {
                    "size_bytes": size,
                    "category": bench,
                    "path": rel_path,
                }
                fh.write(json.dumps(record, ensure_ascii=False) + "\n")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate size_inputs.jsonl.")
    p.add_argument(
        "-r",
        "--root",
        default="benchmarks",
        help="Subdirectory (relative to repo root) that contains benchmarks "
             "(default: benchmarks/)",
    )
    p.add_argument(
        "-o",
        "--output",
        help="Output JSONL file (default: .tools/data/size_inputs.jsonl under repo root)",
    )
    return p.parse_args()


def main() -> None:
    args = parse_args()
    bench_root = git_root()

    output_path = (
        pathlib.Path(args.output).resolve()
        if args.output
        else bench_root / ".tools" / "data" / "size_inputs.jsonl"
    )

    emit_records(bench_root, output_path)

    tmp_path = output_path.parent / "tmp_size_inputs.jsonl"

    try:
        jq_cmd = (
            f"jq -c -n 'def key($l): \"\\($l.path)|\\($l.category)\"; "
            f"reduce inputs as $line ({{}}; "
            f"if has(key($line)) then . else .[key($line)] = $line end) "
            f"| to_entries[] | .value' "
            f'"{output_path}" > "{tmp_path}"'
        )
        subprocess.run(jq_cmd, shell=True, check=True)
        tmp_path.replace(output_path)
        print(f"Deduplicated (by path+category) output written to {output_path}")
    except Exception as e:
        sys.stderr.write(f"Deduplication with jq failed: {e}\n")


if __name__ == "__main__":
    main()
