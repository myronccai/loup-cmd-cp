# Design: cp

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the
arguments into `Options`, handles `--help` and `--version`, and calls
`commands.cp.run_cp`. `run_cp` asks `run_jobs` for an `Outcome` (the -v
lines, the error messages, the exit status and whether a usage error wants
the "Try" line) and then prints it. `run_jobs` first plans every job with
the pure `plan_copy`, then copies job by job, carrying on after failures.

## Modules

| Module | Contents |
|---|---|
| `source/cli/args.loup` | `Options`, `parse_args` (getopt_long rules, `-t DIR` / `-tDIR`), `match_long` |
| `source/cli/usage.loup` | `usage()`, `version_line()` |
| `source/cli/app.loup` | `run()`, `wants_try()` |
| `source/commands/plan.loup` | `Job`, `Plan`, `destination_operand`, `plan_copy`: target resolution, pure |
| `source/commands/cp.loup` | `Outcome`, `combine`, `copy_file`, `copy_dir`, `copy_entry`, `copy_operand`, `run_jobs`, `run_cp` |
| `source/commands/fsinfo.loup` | `Kind`, `path_kind`, `entry_kind`, `entry_present`, `missing_reason`, `absolute`, `is_within` |
| `source/commands/quote.loup` | `quote()`: GNU's quoting of names in messages |

### Target resolution

`plan_copy(opts, dest_kind)` needs only one fact from the disk, the kind of
the destination operand, which `run_jobs` passes in. It returns a list of
`Job(src, dst)` or a single error with a flag for the "Try" line.

### Copying

- A **new file** is copied with `io.fs.copy`, then must exist. Its parent
  must already be a directory (checked first, for GNU's messages).
- An **existing file** is overwritten from the source's bytes, read into
  memory before the destination is opened: when the two names are the same
  file through a link, opening the destination truncates the source, and
  `io.fs.copy` would leave it empty. The destination must then hold those
  bytes; with -f a failed write is retried after removing the destination.
- A **directory** is created with `io.fs.createDir` (after checking the
  parent, since `createDir` would create missing parents), then each entry
  is copied in name order. `io.fs.walk` is not used: it lists only files
  (empty directories would be lost) and follows links to directories.
- Kinds come from `fsinfo`: `path_kind` follows links (command-line
  operands); `entry_kind` recognises dangling links and links to
  directories (by listing `link/..`), which are skipped so that a link back
  up the tree cannot make -r loop.
- "Same file" and "into itself" compare absolute, normalised paths built
  from `$PWD` (`env("PWD")`), since there are no inode numbers.

Every operation is verified afterwards because the native `io.fs` reports
nothing when it fails, while the Stage0 interpreter (`make test`) throws
`IoError`; both are handled.

## Differences from GNU cp

- Modes, owners and times are not copied: new files get mode 0644 (minus the
  umask), so an executable copy is not executable (T1, no `stat()`).
- Symbolic links inside a tree cannot be recreated (`io.fs` has no
  `symlink`): links to files are copied as files, links to sibling
  directories as directories, and other recognised links are reported
  (`Operation not supported`, status 1). GNU copies them as links.
- Command-line symbolic links are always followed (GNU's `-H`).
- Entries are copied in name order; GNU uses directory order, which changes
  the order of -v lines.
- "Into itself" is refused before anything is copied; GNU copies what it
  can first. Two names for the same file through a link or a hard link are
  not recognised as the same file (the copy still keeps the data intact).
- The reason in `cannot create regular file 'X': ...` is inferred (no errno):
  `Permission denied` whenever the parent directory exists.
- Special files (FIFOs, sockets, devices) are reported, not copied.
- No `-i`, `-p`, `-a`, `-l`, `-s`, `-u`, `-L`, `-H`, `-P`, `--backup`,
  `--parents`, `--update`, and no GNU 9.5 warning that `-n` is deprecated.

## Error handling

Errors that stop cp before copying (from `plan_copy` and `parse_args`) exit
1, most followed by the "Try" line. Per-operand errors are collected, the
remaining operands are still copied, and the exit status is 1. Warnings
(`specified more than once`) leave the status at 0. An unexpected exception
is reported by `run()` with status 1. In the native build, reading an
unreadable source to overwrite a file stops the program with
`IoError: read_text failed ...` and status 1.

## Testing

- `tests/args_test.loup`: clusters, `-t` forms, `--`, long prefixes and
  their errors.
- `tests/plan_test.loup`: every target-resolution rule with the destination
  kind given directly.
- `tests/cp_test.loup`: path helpers, and copies under `.temp/cp-unit/`
  (files, -n, -r, errors).
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: rebuilds a fixture under `$TMP` for each case (read-only
  file and directory, links of every kind) and checks the native binary's
  output, messages, status and the files it leaves.
