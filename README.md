# loup-cmd-cp

GNU `cp` recreated in [Loup](https://code-craft.ai/references/loup): copy
files and directory trees with `-r`, `-n`, `-f`, `-v`, `-t DIR` and `-T`,
GNU's rules for choosing the destination, and its error messages.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                            # native binary: build/cp
make ci                               # check, unit tests, build, end-to-end tests
make run ARGS="-rv source build/copy" # run from source with loup run
```

In a directory holding `README.md`, `backup/` and `notes/` (with
`todo.txt`, `drafts/idea.md` and a link `drafts/up -> ..`):

```text
$ build/cp -v README.md notes/todo.txt backup; echo $?
'README.md' -> 'backup/README.md'
'notes/todo.txt' -> 'backup/todo.txt'
0
$ build/cp -rv notes archive; echo $?
'notes' -> 'archive'
'notes/drafts' -> 'archive/drafts'
'notes/drafts/idea.md' -> 'archive/drafts/idea.md'
'notes/todo.txt' -> 'archive/todo.txt'
cp: cannot create symbolic link 'archive/drafts/up': Operation not supported
1
$ build/cp -n README.md backup/README.md; echo $?
0
$ build/cp notes backup; echo $?
cp: -r not specified; omitting directory 'notes'
1
$ build/cp -r notes notes/drafts; echo $?
cp: cannot copy a directory, 'notes', into itself, 'notes/drafts/notes'
1
$ build/cp -vt backup README.md README.md; echo $?
'README.md' -> 'backup/README.md'
cp: warning: source file 'README.md' specified more than once
0
```

Forms:

```text
cp [OPTION]... [-T] SOURCE DEST          copy onto DEST (into it if it is a directory, unless -T)
cp [OPTION]... SOURCE... DIRECTORY       copy each SOURCE into DIRECTORY
cp [OPTION]... -t DIRECTORY SOURCE...    the same, directory first
```

| Option | Meaning |
|---|---|
| `-r`, `-R`, `--recursive` | copy directories recursively |
| `-n`, `--no-clobber` | never overwrite an existing file (wins over `-f`) |
| `-f`, `--force` | if an existing file cannot be written, remove it and write it again |
| `-v`, `--verbose` | print `'SRC' -> 'DST'` for each file copied and directory created |
| `-t DIR`, `--target-directory=DIR` | copy every operand into `DIR` |
| `-T`, `--no-target-directory` | treat `DEST` as a name, never as a directory to copy into |
| `--help`, `--version` | print help or the version and exit |

Options may appear anywhere and combine (`-rv`, `-vtDIR`); long options may
be abbreviated (`--rec`); `--` ends the options.

Exit status: `0` if everything was copied (or skipped by `-n`), `1`
otherwise, usage errors included. cp reports a failed operand and carries
on with the rest.

## Differences from GNU cp

Loup 1.26.0's `io.fs` has no `stat()`, cannot create symbolic links, and in
the native build does not report failures, so:

- **Modes, owners and times are not copied.** A new file gets mode 0644
  (less the umask): copying an executable gives a non-executable file.
- **Symbolic links inside a tree are not recreated.** Links to files are
  copied as files and links to sibling directories as directories; dangling
  links and links to other directories (found by checking where `link/..`
  leads) are reported with `cannot create symbolic link ...: Operation not
  supported` and status 1. This also keeps `-r` from looping on a link such
  as `up -> ..`. Symbolic links named on the command line are followed.
- Entries are copied in name order (GNU uses directory order), so `-v`
  lines can come out in a different order.
- Copying a directory into itself is refused before anything is copied;
  GNU copies what it can first.
- "The same file" is decided by comparing absolute paths (built from
  `$PWD`): two names for one file through a link are not recognised. The
  data stays intact, because an existing destination is written from the
  source's bytes read beforehand.
- Every write is checked afterwards. The reason given for `cannot create
  regular file` is inferred, not read from the system: `Permission denied`
  whenever the parent directory exists.
- FIFOs, sockets and devices are reported, not copied.
- No `-i`, `-p`, `-a`, `-u`, `-l`, `-s`, `-L`, `-H`, `-P`, `--backup` or
  `--parents`, and no GNU 9.5 warning that `-n` is deprecated.

## Layout

```text
source/main.loup              # entry point
source/appinfo.loup           # name, version, exit statuses
source/cli/args.loup          # GNU getopt_long-style option parsing
source/cli/usage.loup         # --help and --version text
source/cli/app.loup           # run(): parse, dispatch, exit status
source/commands/plan.loup     # target resolution (pure)
source/commands/cp.loup       # copying files and trees, verification, -v
source/commands/fsinfo.loup   # file kinds without stat(), path comparison
source/commands/quote.loup    # GNU-style quoting of names in messages
tests/*_test.loup             # unit tests (make test)
tests/e2e.sh                  # end-to-end tests of build/cp (make e2e)
specs/cp/                     # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
