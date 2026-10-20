# Tasks: cp

- [x] 1. Parse GNU options: `-r -R -n -f -v -T`, `-t DIR`/`-tDIR`, long
      options with prefixes, `--`, permutation
  - _Requirements: 5.1, 5.2_
- [x] 2. Resolve targets: onto a name, into a directory, `-t`, `-T`, and
      their errors
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_
- [x] 3. Copy files: new and existing, verified; -n, -f; same file, dangling
      and directory destinations, parent errors
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_
- [x] 4. Copy directories with -r: create, merge, into-itself, links inside
      the tree
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
- [x] 5. -v lines, error aggregation, repeated and just-created operands,
      exit statuses
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
- [x] 6. Unit tests and end-to-end tests of the native binary
  - _Requirements: all_
