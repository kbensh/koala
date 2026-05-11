## pass

This benchmark generates a configurable number of random passwords of a fixed length, exercising a tight `tr`/`head` pipeline over `/dev/urandom`.

### Inputs

- No external inputs. The number of passwords and password length are set by the input size flag (`--min` = 5,000 × 16, `--small` = 500,000 × 24, `--full` = 50,000,000 × 32).

### Running

`pass.sh` loops `n` times and, for each iteration, draws random bytes from `/dev/urandom`, filters them through `tr` to the alphabet
`A-Za-z0-9_@#$%&*-`, and trims to the requested length with `head -c`.

Outputs are stored as `outputs/pass_<size>.txt`.

### Validation

This benchmark produces non-deterministic output by design. Validation checks the structural properties of the result (line count and per-line length / alphabet) rather than a fixed SHA-256 hash.

## pickname

This benchmark samples random teams of 10 people from the U.S. Social Security Administration baby-name list, writing one file per team.

### Inputs

- `inputs/all_names.txt`: A flattened list of names produced by `fetch.sh` from the SSA [`names.zip`](https://www.ssa.gov/oact/babynames/names.zip) archive (the first column of each per-year `.txt` file). The number of teams is controlled by the input size flag (`--min` = 100, `--small` = 10,000, `--full` = 100,000).

### Running

`pickname.sh` loops over the requested number of teams and, for each one, pipes the names file through `shuf | head -n 10` and writes the sample to `outputs/pickname_<size>/team_<i>.txt`. Note that the same name may appear across multiple teams.

### Validation

This benchmark produces non-deterministic output by design. Validation checks the structural properties of the result (number of team files and per-file line count) rather than a fixed SHA-256 hash.

### References

- https://www.ssa.gov/oact/babynames/
