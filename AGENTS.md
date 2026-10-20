# AGENTS.md

This repository recreates GNU `cp` in the Loup programming language, as part
of the loup-cmd series of example applications. The program is `host.dual`
Loup built as a native executable.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses
│   ├── cli/
│   │   ├── args.loup            # struct Options, parse_args(): GNU getopt_long rules
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(): parse, --help/--version, run_cp, exit status
│   └── commands/
│       ├── plan.loup            # plan_copy(): which source goes where (pure)
│       ├── cp.loup              # copy_file(), copy_dir(), run_jobs(), run_cp()
│       ├── fsinfo.loup          # Kind, path_kind(), entry_kind(), absolute(): kinds without stat()
│       └── quote.loup           # quote(): names in messages
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void (cp_test writes under .temp/)
│   └── e2e.sh                   # end-to-end tests of the native binary (fixtures built under $TMP)
├── specs/cp/                    # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="-rv source build/copy"` | `loup run source/main.loup -- ARGS` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup` |
| Run matching tests | `make test TEST_ARGS="--filter value"` | tests whose name contains `value` |
| Run one test file | `make test TEST_ARGS="--file tests/args_test.loup"` | |
| Build | `make build` | native binary at `build/cp` |
| Run the binary | `build/cp --help` | |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/cp`: output compared byte for byte |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/cp --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests.

## Making a change

1. Update the spec in `specs/cp/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/cp/tasks.md`.

Keep behaviour in functions that return values (`plan_copy` returns a
`Plan`, `run_jobs` an `Outcome` with the -v lines, messages and exit status)
so unit tests can check it; only `run_cp` prints.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from cli.args import (Options);`. Tests import them the same way. Do not
  use relative imports (`from .args import ...`): the self-hosted `loup run`
  on Linux x86-64 fails on them.
- Struct fields read from another module must be `pub`.
- The native build supports less than `loup run` does. For example,
  `list.is_empty()` fails native codegen (`E-CODEGEN-UNHANDLED-METHOD`); use
  `len() == 0`.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The native `io.fs` never throws: `copy`, `createDir`, `writeBytes` and
  `remove` fail silently. Verify every write afterwards, as `cp.loup` does.
  The Stage0 interpreter used by `make test` throws `IoError` instead, so
  wrap calls in `try`. Native `readBytes`/`readText` on an unreadable file
  exit the program (not catchable).
- `io.fs.createDir` creates missing parents, and native `io.fs.removeDir`
  follows symbolic links; check parents first and never use `removeDir` on
  a tree that may hold links. Do not import `rename` from `io.fs` (it
  aborts natively); use `runtime.fs().rename(a, b)`.
- `io.fs` cannot tell a symbolic link from its target;
  `source/commands/fsinfo.loup` explains how links are recognised.
- Read the environment with the prelude `env("NAME")`; `system.env.get` and
  the `system.text` functions do not link natively.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
