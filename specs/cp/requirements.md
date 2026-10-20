# Requirements: cp

## Introduction

`cp` copies files, and with -r whole directory trees. This repository
recreates GNU coreutils `cp` in Loup for its everyday options: recursion
(`-r`, `-R`), not overwriting (`-n`), forcing (`-f`), verbose output (`-v`),
and the three ways of naming the destination (`SOURCE DEST`, `SOURCE...
DIRECTORY`, `-t DIRECTORY`, with `-T` to forbid copying into a directory).
Loup 1.26.0's `io.fs` has no `stat()` and cannot create symbolic links, so
modes, times and links are not copied.

## Requirements

### Requirement 1: Choosing the destination

**User Story:** As a shell user, I want cp to copy onto a name or into a
directory the way GNU cp decides.

#### Acceptance Criteria

1. WHEN there are two operands and the second is not a directory, THE
   program SHALL copy the first onto that name.
2. WHEN the last operand is a directory, THE program SHALL copy every other
   operand into it as `DIR/basename(SOURCE)`.
3. WHEN -t DIR is given, THE program SHALL copy every operand into DIR; DIR
   SHALL be a directory, else `target directory 'DIR': ...`.
4. WHEN -T is given, THE program SHALL copy onto the second operand even if
   it is a directory, and SHALL reject a third operand (`extra operand`).
5. WHEN there are more than two operands and the last is not a directory,
   THE program SHALL fail with `target 'X': Not a directory` (or `No such
   file or directory`) before copying anything.
6. WHEN operands are missing, or -t and -T are combined, THE program SHALL
   print GNU's message and exit with status 1.

### Requirement 2: Copying files

**User Story:** As a shell user, I want byte-exact copies and safe
overwriting.

#### Acceptance Criteria

1. THE program SHALL copy the bytes of a regular file exactly, creating or
   overwriting the destination.
2. WHEN -n is given, THE program SHALL leave an existing destination file
   unchanged (and -n SHALL win over -f).
3. WHEN an existing destination cannot be written and -f is given, THE
   program SHALL remove it and write it again; without -f it SHALL report
   `cannot create regular file 'X': Permission denied`.
4. WHEN source and destination name the same path, THE program SHALL report
   `'A' and 'B' are the same file` and copy nothing.
5. WHEN the destination is a directory (with -T, or `DIR/NAME` that is a
   directory), THE program SHALL report `cannot overwrite directory`.
6. WHEN the destination is a dangling symbolic link, THE program SHALL report
   `not writing through dangling symlink`.
7. WHEN the destination's parent does not exist or is a file, THE program
   SHALL report it as GNU does (`cannot create regular file ...: No such file
   or directory`, `cannot stat ...: Not a directory`).

### Requirement 3: Copying directories

**User Story:** As a shell user, I want -r to copy a tree.

#### Acceptance Criteria

1. WHEN a source is a directory and -r is not given, THE program SHALL
   report `-r not specified; omitting directory 'D'`.
2. WHEN -r is given, THE program SHALL create the destination directory if
   needed (but not its parents) and copy every entry, including dot-files,
   recursively, merging into an existing directory.
3. WHEN the destination is inside the source, THE program SHALL report
   `cannot copy a directory, 'S', into itself, 'D'` and copy nothing of it.
4. WHEN the destination is an existing non-directory, THE program SHALL
   report `cannot overwrite non-directory`.
5. Inside a tree, THE program SHALL copy links to files as files, and SHALL
   NOT follow symbolic links it recognises (dangling links, links to
   directories that are not siblings), reporting each as `cannot create
   symbolic link 'X': Operation not supported`.

### Requirement 4: Reporting

**User Story:** As a script author, I want to see what was done and to know
whether everything worked.

#### Acceptance Criteria

1. WHEN -v is given, THE program SHALL print `'SRC' -> 'DST'` for each file
   copied and each directory created.
2. WHEN one operand fails, THE program SHALL report it on standard error,
   continue with the others, and exit with status 1.
3. WHEN the same source is given twice for the same destination, THE program
   SHALL warn `source file 'X' specified more than once` and copy it once.
4. WHEN a later file would overwrite one this run created, THE program SHALL
   report `will not overwrite just-created 'X' with 'Y'`.
5. THE program SHALL exit with 0 when every operand was copied (or skipped by
   -n) and 1 otherwise, usage errors included.

### Requirement 5: Command line

**User Story:** As a shell user, I want GNU's option syntax.

#### Acceptance Criteria

1. THE program SHALL accept options anywhere among the operands, combined
   short options, `-t DIR` and `-tDIR`, `--` to end options, and the long
   options `--recursive`, `--no-clobber`, `--force`, `--verbose`,
   `--target-directory[=]DIR`, `--no-target-directory`, `--help` and
   `--version`, abbreviated to any unambiguous prefix.
2. WHEN an option is unknown, ambiguous, missing its argument, or given an
   argument it does not take, THE program SHALL print GNU's message and
   `Try 'cp --help' for more information.` and exit with status 1.
