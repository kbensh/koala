## sieve

This benchmark generates all prime numbers up to a given upper bound using a shell-only Sieve of Eratosthenes built from `awk`, `sort`, `comm`, and a named pipe coordinating a composite-number producer with a primes consumer.

### Inputs

- No external inputs. The upper bound is set by the input size flag
  (`--min` = 10,000,000, `--small` = 100,000,000, `--full` = 500,000,000).

### Running

`sieve.sh` accepts an upper bound and an output path. It generates all composites up to `sqrt(n)` worth of primes through a FIFO, then subtracts them from the sequence `2..n` with `comm` to produce the prime list, which is formatted into 4-column tabular output via `pr`.

Outputs are stored as `outputs/sieve_<size>.txt`.

### Validation

Correctness is determined by computing the SHA-256 hash of each output file and comparing it against a reference hash stored in `hashes/`.

## try

This benchmark exercises a sandboxed command-execution workflow that runs an arbitrary shell command inside an `overlayfs` (or `unionfs-fuse` fallback) sandbox built on top of the host filesystem, then summarizes and optionally commits the resulting changes.

### Overview

`try.sh` constructs a per-invocation sandbox by:

- Creating an overlay of the root filesystem under a temporary `upperdir` /
  `workdir` / `temproot` layout,
- Bind-mounting `/dev` devices and `/proc` inside the sandbox,
- Entering a new user / mount / PID namespace via `unshare`,
- Executing the user-supplied command against the overlay,
- Diffing the upperdir to enumerate added, modified, deleted, new-directory,
  and symlink changes, and
- Either committing the diff back to the host (with `-y`) or discarding it.

### Inputs

- No external inputs. The command run inside the sandbox is supplied on the command line by `execute.sh`.

### Output

A textual changes report is written to `outputs/try_out.txt`, and the file produced inside the sandbox (`try_status.txt`) is committed back from the overlay.

### Validation

Correctness is determined by computing the SHA-256 hash of each output file and comparing it against a reference hash stored in `hashes/`.

### References

- https://github.com/rpodgorny/unionfs-fuse
