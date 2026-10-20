#!/usr/bin/env bash
# End-to-end tests: run the built binary on a fresh fixture tree under $TMP
# for every case, and compare its standard output (byte for byte), standard
# error, exit status and the resulting files with the expected ones.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
W=$TMP/w
pass=0
fail=0

# The fixture, rebuilt before every case:
#   a b             files holding A and B
#   ro              a read-only file holding "old"
#   rodir/          a read-only directory
#   exec.sh         an executable file
#   other/a         a second file named a, holding O
#   d/  x .h sub/y  a directory to copy
#   e/              an empty directory
#   e2/a/           a directory named like the file a
#   links/  real/f  flink -> real/f  far -> ../d  up -> ..  dang -> nowhere
#   dang -> nowhere, alink -> a
setup() {
    chmod -R u+w "$W" 2>/dev/null
    rm -rf "$W"
    mkdir -p "$W/d/sub" "$W/e" "$W/e2/a" "$W/other" "$W/rodir" "$W/links/real"
    cd "$W" || exit 1
    echo A > a
    echo B > b
    echo old > ro
    chmod 444 ro
    chmod 555 rodir
    printf '#!/bin/sh\n' > exec.sh
    chmod 755 exec.sh
    echo O > other/a
    echo X > d/x
    echo H > d/.h
    echo Y > d/sub/y
    echo F > links/real/f
    ln -s real/f links/flink
    ln -s ../d links/far
    ln -s .. links/up
    ln -s nowhere links/dang
    ln -s nowhere dang
    ln -s a alink
}

# The files under PATHS... (relative to $W), one per line: `dir/`,
# `file: content` or `link -> target`.
snap() {
    (cd "$W" && find "$@" 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
        if [ -L "$f" ]; then
            printf '%s -> %s\n' "$f" "$(readlink "$f")"
        elif [ -d "$f" ]; then
            printf '%s/\n' "$f"
        else
            printf '%s: %s\n' "$f" "$(cat "$f")"
        fi
    done)
}

# run_case NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
# Rebuilds the fixture, runs BINARY ARGS... in $W, and compares standard
# output, standard error (without its final newline) and the exit status.
run_case() {
    local name=$1 want_status=$2 want_out=$3 want_err=$4
    shift 4
    setup
    "$BIN" "$@" < /dev/null > "$TMP/out" 2> "$TMP/err"
    local status=$?
    printf '%s' "$want_out" > "$TMP/want"
    if [ "$status" -eq "$want_status" ] && cmp -s "$TMP/want" "$TMP/out" \
        && [ "$(cat "$TMP/err")" = "$want_err" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$TMP/want" "$TMP/out" | sed 's/^/    stdout /' | head -10
        [ "$(cat "$TMP/err")" = "$want_err" ] || {
            echo "    expected stderr: $want_err"
            sed 's/^/    actual stderr:   /' "$TMP/err" | head -5
        }
    fi
}

# tree_is NAME EXPECTED PATHS...
# Checks the files left by the last run_case.
tree_is() {
    local name=$1 want=$2
    shift 2
    local got
    got=$(snap "$@")
    if [ "$got" = "$want" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (files)"
        diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /' | head -10
    fi
}

# Files
run_case "new name"            0 '' '' a new
tree_is  "new name"            'new: A' new
run_case "-v"                  0 $'\'a\' -> \'new\'\n' '' -v a new
run_case "overwrite"           0 '' '' a b
tree_is  "overwrite"           'b: A' b
run_case "into a directory"    0 $'\'a\' -> \'e/a\'\n\'b\' -> \'e/b\'\n' '' -v a b e
tree_is  "into a directory"    $'e/\ne/a: A\ne/b: B' e
run_case "trailing slash dir"  0 '' '' a e/
tree_is  "trailing slash dir"  $'e/\ne/a: A' e
run_case "-t"                  0 $'\'a\' -> \'e/a\'\n' '' -vt e a
run_case "--target-directory=" 0 '' '' --target-directory=e a b
tree_is  "--target-directory=" $'e/\ne/a: A\ne/b: B' e
run_case "-T onto a name"      0 '' '' -T a new
tree_is  "-T onto a name"      'new: A' new
run_case "-n keeps"            0 '' '' -n a b
tree_is  "-n keeps"            'b: B' b
run_case "-n wins over -f"     0 '' '' -fn a b
tree_is  "-n wins over -f"     'b: B' b
run_case "link source"         0 '' '' alink z
tree_is  "link source"         'z: A' z
run_case "options anywhere"    0 $'\'a\' -> \'new\'\n' '' a -v new

# Directories
run_case "-r new"              0 '' '' -r d copy
tree_is  "-r new"              $'copy/\ncopy/.h: H\ncopy/sub/\ncopy/sub/y: Y\ncopy/x: X' copy
run_case "-rv new" 0 $'\'d\' -> \'copy\'\n\'d/.h\' -> \'copy/.h\'\n\'d/sub\' -> \'copy/sub\'\n\'d/sub/y\' -> \'copy/sub/y\'\n\'d/x\' -> \'copy/x\'\n' '' -rv d copy
run_case "-R into"             0 '' '' -R d e
tree_is  "-R into"             $'e/\ne/d/\ne/d/.h: H\ne/d/sub/\ne/d/sub/y: Y\ne/d/x: X' e
run_case "-rv slash" 0 $'\'d/\' -> \'copy\'\n\'d/.h\' -> \'copy/.h\'\n\'d/sub\' -> \'copy/sub\'\n\'d/sub/y\' -> \'copy/sub/y\'\n\'d/x\' -> \'copy/x\'\n' '' -rv d/ copy
run_case "-rTv merge" 0 $'\'d/.h\' -> \'e/.h\'\n\'d/sub\' -> \'e/sub\'\n\'d/sub/y\' -> \'e/sub/y\'\n\'d/x\' -> \'e/x\'\n' '' -rTv d e
run_case "-rn new name"         0 '' '' -rn d d2
setup; echo old > "$W/e/x"; "$BIN" -rnT d e; tree_is "-rn keeps an existing file" 'e/x: old' e/x
run_case "no -r"               1 '' "cp: -r not specified; omitting directory 'd'" d e
tree_is  "no -r"               'e/' e
run_case "into itself"         1 '' "cp: cannot copy a directory, 'd', into itself, 'd/sub/d'" -r d d/sub
tree_is  "into itself"         $'d/sub/\nd/sub/y: Y' d/sub
run_case "into itself -T"      1 '' "cp: cannot copy a directory, 'd', into itself, 'd'" -rT d d
run_case "dir onto file"       1 '' "cp: cannot overwrite non-directory 'a' with directory 'd'" -r d a
run_case "parent missing -r"   1 '' "cp: cannot create directory 'nodir/x': No such file or directory" -r d nodir/x
tree_is  "parent not created"  '' nodir

# Symbolic links inside a tree: links to files are copied as files; links
# that can be recognised (dangling, to directories elsewhere) are skipped
run_case "-r links" 1 '' "cp: cannot create symbolic link 'copy/dang': Operation not supported
cp: cannot create symbolic link 'copy/far': Operation not supported
cp: cannot create symbolic link 'copy/up': Operation not supported" -r links copy
tree_is  "-r links"            $'copy/\ncopy/flink: F\ncopy/real/\ncopy/real/f: F' copy

# Errors
run_case "same file"           1 '' "cp: 'a' and './a' are the same file" a ./a
run_case "missing source"      1 $'\'a\' -> \'e/a\'\n' "cp: cannot stat 'nope': No such file or directory" -v nope a e
tree_is  "missing source"      $'e/\ne/a: A' e
run_case "target not a dir"    1 '' "cp: target 'a': Not a directory" a b a
run_case "target missing"      1 '' "cp: target 'zz': No such file or directory" a b zz
run_case "parent missing"      1 '' "cp: cannot create regular file 'nodir/x': No such file or directory" a nodir/x
run_case "file in path"        1 '' "cp: cannot stat 'b/x': Not a directory" a b/x
run_case "file onto dir"       1 $'\'b\' -> \'e2/b\'\n' "cp: cannot overwrite directory 'e2/a' with non-directory 'a'" -v a b e2
run_case "-T onto dir"         1 '' "cp: cannot overwrite directory 'e' with non-directory 'a'" -T a e
run_case "read-only file"      1 '' "cp: cannot create regular file 'ro': Permission denied" a ro
tree_is  "read-only file"      'ro: old' ro
run_case "-f read-only file"   0 '' '' -f a ro
tree_is  "-f read-only file"   'ro: A' ro
run_case "read-only dir"       1 '' "cp: cannot create regular file 'rodir/x': Permission denied" -f a rodir/x
run_case "dangling source"     1 '' "cp: cannot stat 'dang': No such file or directory" dang z
run_case "dangling target"     1 '' "cp: not writing through dangling symlink 'dang'" a dang
run_case "repeated source"     0 $'\'a\' -> \'e/a\'\n' "cp: warning: source file './a' specified more than once" -v a ./a e
run_case "just created"        1 $'\'a\' -> \'e/a\'\n' "cp: will not overwrite just-created 'e/a' with 'other/a'" -v a other/a e
tree_is  "just created"        'e/a: A' e/a

# Contents and modes
setup
printf 'a\0b\377c\n' > "$W/bin"
"$BIN" bin bin2 && "$BIN" bin b
if cmp -s "$W/bin" "$W/bin2" && cmp -s "$W/bin" "$W/b"; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: binary content (new file and overwrite)"
fi
"$BIN" exec.sh copy.sh
if [ -f "$W/copy.sh" ] && [ ! -x "$W/copy.sh" ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: the mode is not copied (T1)"
fi

# Usage errors: status 1, as in GNU cp
run_case "no operands"         1 '' $'cp: missing file operand\nTry \'cp --help\' for more information.'
run_case "one operand"         1 '' $'cp: missing destination file operand after \'a\'\nTry \'cp --help\' for more information.' a
run_case "-T extra operand"    1 '' $'cp: extra operand \'c\'\nTry \'cp --help\' for more information.' -T a b c
run_case "-t and -T"           1 '' "cp: cannot combine --target-directory (-t) and --no-target-directory (-T)" -T -t e a
run_case "-t not a dir"        1 '' "cp: target directory 'a': Not a directory" -t a b
run_case "-t twice"            1 '' "cp: multiple target directories specified" -t e -t e a
run_case "-t no argument"      1 '' $'cp: option requires an argument -- \'t\'\nTry \'cp --help\' for more information.' a -t
run_case "invalid option"      1 '' $'cp: invalid option -- \'z\'\nTry \'cp --help\' for more information.' -z
run_case "ambiguous"           1 '' $'cp: option \'--no\' is ambiguous; possibilities: \'--no-clobber\' \'--no-target-directory\'\nTry \'cp --help\' for more information.' --no a b
run_case "-- ends options"     1 '' "cp: cannot stat '-v': No such file or directory" -- -v a e
run_case "version"             0 $'cp (loup-cmd-cp) 0.1.0\n' '' --version
"$BIN" --help | head -1 > "$TMP/help"
if [ "$(cat "$TMP/help")" = "Usage: cp [OPTION]... [-T] SOURCE DEST" ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: --help first line: $(cat "$TMP/help")"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
