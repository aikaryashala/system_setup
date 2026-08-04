#!/usr/bin/env bash
#
# install_py.sh - Step 4 of https://aikaryashala.com/system_setup
#
# Python 3, so you can run a script, and pdb so you can stop that script
# mid-flight and look at what it is doing.
#
# pdb is part of Python itself - there is nothing extra to install for it. This
# step is deliberately just the interpreter and the debugger.
#
# Managing packages, projects and multiple Python versions is step 8, which
# installs uv. You do not need any of that to run and debug a script.
#
# Run inside Ubuntu:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_py.sh | bash
#
# Safe to run more than once.

# shellcheck source-path=SCRIPTDIR
set -euo pipefail

SYSTEM_SETUP_BASE_URL="${SYSTEM_SETUP_BASE_URL:-https://aikaryashala.com/system_setup/scripts}"

_bootstrap_common() {
    local here=""
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    if [ -n "$here" ] && [ -f "$here/common.sh" ]; then
        # shellcheck source=common.sh
        . "$here/common.sh"
    elif command -v curl >/dev/null 2>&1; then
        # shellcheck disable=SC1090
        . <(curl -fsSL "$SYSTEM_SETUP_BASE_URL/common.sh")
    else
        echo "Cannot find common.sh, and curl is not installed to fetch it." >&2
        echo "Run step 2 first: sudo apt-get update && sudo apt-get install -y curl" >&2
        exit 1
    fi
}
_bootstrap_common

# ---------------------------------------------------------------------------

PKGS_PYTHON=(
    python3             # the interpreter, and the standard library that holds pdb
)

install_python() {
    banner "Installing Python 3"
    apt_install "${PKGS_PYTHON[@]}"
}

# Two files, because the interesting debugger skill is stepping from one file
# into another. Written to the current directory so the reader can keep using
# them after this script finishes.
write_samples() {
    banner "Writing two sample files to work with"

    local dest="${SAMPLE_DIR:-$HOME/python-samples}"
    mkdir -p "$dest"

    cat >"$dest/stats.py" <<'EOF'
"""stats.py - a small module for report.py to import."""


def mean(numbers):
    """The average. Raises ZeroDivisionError on an empty list."""
    return sum(numbers) / len(numbers)


def median(numbers):
    """The middle value once the numbers are in order."""
    ordered = sorted(numbers)
    middle = len(ordered) // 2

    if len(ordered) % 2 == 1:
        return ordered[middle]
    return (ordered[middle - 1] + ordered[middle]) / 2


def spread(numbers):
    """How far apart the largest and smallest values are."""
    return max(numbers) - min(numbers)


def summarise(numbers):
    """Everything above, in one dictionary."""
    return {
        "count": len(numbers),
        "mean": mean(numbers),
        "median": median(numbers),
        "spread": spread(numbers),
    }
EOF

    cat >"$dest/report.py" <<'EOF'
"""report.py - the program to run under the debugger.

    python3 report.py                      # run it - it crashes on purpose
    python3 -m pdb report.py               # walk through it a line at a time
    python3 -m pdb -c continue report.py   # let it crash, then inspect it
"""

import stats

READINGS = [12, 7, 3, 21, 9, 15]


def show(title, numbers):
    summary = stats.summarise(numbers)
    print(f"--- {title} ---")
    for key, value in summary.items():
        print(f"{key:>7}: {value}")


def main():
    show("readings", READINGS)

    # This one is empty, and mean() divides by len(numbers).
    missing = []
    show("missing", missing)


if __name__ == "__main__":
    main()
EOF

    ok "$dest/stats.py"
    ok "$dest/report.py"
    SAMPLE_DEST="$dest"
}

smoke_test() {
    banner "Checking Python and the debugger"

    local dir
    dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$dir'" RETURN

    cat >"$dir/check.py" <<'EOF'
import sys

total = 0
for n in range(1, 5):
    total += n

print(f"python works: {sys.version.split()[0]}, total={total}")
EOF

    if python3 "$dir/check.py" >"$dir/out" 2>&1 && grep -q "python works" "$dir/out"; then
        ok "python3 ran a script"
    else
        warn "python3 could not run a test script:"
        head -n 5 "$dir/out" >&2
        VERIFY_FAILED=1
        return 0
    fi

    # Drive pdb non-interactively with -c commands. Using stdin would not work
    # here: when this script is piped from curl, stdin is already spoken for.
    #
    # Break on line 7 - after the loop has finished - and print the total from
    # inside the debugger. If that reads 10, pdb stopped at the right line AND
    # could see the program's state, which is the whole point. Do not assert on
    # pdb's "> file(line)" banner: it is not printed when driven this way.
    python3 -m pdb -c "break 7" -c continue -c "print(f'PDBTOTAL={total}')" -c quit \
        "$dir/check.py" >"$dir/pdb_out" 2>&1 || true

    if grep -q "PDBTOTAL=10" "$dir/pdb_out"; then
        ok "pdb stopped at a breakpoint and read the program's state"
    else
        warn "pdb did not stop where expected. It printed:"
        head -n 8 "$dir/pdb_out" >&2
        VERIFY_FAILED=1
    fi
}

summary() {
    banner "Installed"
    verify "python3" python3 --version
    printf '  %s%-14s%s %s\n' "$C_BOLD" "pdb" "$C_RESET" \
        "$(python3 -c 'import pdb; print(pdb.__file__)' 2>/dev/null || echo 'NOT FOUND')"
    printf '  %s%-14s%s %s\n' "$C_BOLD" "samples" "$C_RESET" "${SAMPLE_DEST:-not written}"
}

main() {
    require_linux
    require_apt
    require_sudo

    install_python
    write_samples
    smoke_test
    summary

    finish "Two sample files are waiting in ${SAMPLE_DEST:-~/python-samples}:

  cd ${SAMPLE_DEST:-~/python-samples}
  python3 report.py                      # run it - it crashes on purpose
  python3 -m pdb report.py               # walk through it a line at a time
  python3 -m pdb -c continue report.py   # let it crash, then inspect it

Inside pdb: 'n' next line, 's' step into a call, 'l' list source,
'p NAME' print a value, 'w' show the call stack, 'c' continue, 'q' quit.

Next step - the Java toolchain:

  curl -fsSL $SYSTEM_SETUP_BASE_URL/install_java.sh | bash

Guide: https://aikaryashala.com/system_setup/04_install_py/"
}

main "$@"
