#!/usr/bin/env bash
#
# install_py.sh - Step 4 of https://aikaryashala.com/system_setup
#
# Python 3, so you can write a program and run it.
#
# Deliberately minimal. Debugging with pdb is step 12, and managing packages,
# projects and extra Python versions is step 8. Neither is needed to write a
# program and run it.
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
    else
        # shellcheck disable=SC1090
        . <(curl -fsSL "$SYSTEM_SETUP_BASE_URL/common.sh")
    fi

    if ! declare -F apt_install >/dev/null 2>&1; then
        echo "Could not load common.sh from $SYSTEM_SETUP_BASE_URL" >&2
        echo "Check your network connection and try again." >&2
        exit 1
    fi
}
_bootstrap_common

# ---------------------------------------------------------------------------

PKGS_PYTHON=(
    python3             # the interpreter, and the standard library
)

install_python() {
    banner "Installing Python 3"
    apt_install "${PKGS_PYTHON[@]}"
}

# The same program as sum.c from step 3, so the two can be compared directly.
write_sample() {
    banner "Writing a sample program"

    local dest="${SAMPLE_DIR:-$HOME/python-samples}"
    mkdir -p "$dest"

    cat >"$dest/sum.py" <<'EOF'
print("To add two numbers.")

num1 = int(input("Enter the first number: "))
num2 = int(input("Enter the second number: "))

num1 = num1 + num2

print(f"The sum of two numbers is {num1}.")
EOF

    ok "$dest/sum.py"
    SAMPLE_DEST="$dest"
}

smoke_test() {
    banner "Checking that Python runs"

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

    if python3 "$dir/check.py" >"$dir/out" 2>&1 && grep -q "total=10" "$dir/out"; then
        ok "python3 ran a script and got the right answer"
    else
        warn "python3 could not run a test script:"
        head -n 5 "$dir/out" >&2
        VERIFY_FAILED=1
        return 0
    fi

    # Run the sample the reader was just given, feeding it two numbers, so a
    # typo in the heredoc above fails here rather than in front of a student.
    if printf '3\n4\n' | python3 "${SAMPLE_DEST:-$HOME/python-samples}/sum.py" 2>&1 \
        | grep -q "is 7"; then
        ok "sum.py added two numbers correctly"
    else
        warn "sum.py did not produce the expected answer"
        VERIFY_FAILED=1
    fi
}

summary() {
    banner "Installed"
    verify "python3" python3 --version
    printf '  %s%-14s%s %s\n' "$C_BOLD" "sample" "$C_RESET" "${SAMPLE_DEST:-not written}/sum.py"
}

main() {
    require_linux
    require_apt
    require_sudo

    install_python
    write_sample
    smoke_test
    summary

    finish "Try it out:

  cd ${SAMPLE_DEST:-~/python-samples}
  python3 sum.py               # run the program
  python3                      # an interactive prompt - type exit() to leave

Next step - the Java toolchain:

  curl -fsSL $SYSTEM_SETUP_BASE_URL/install_java.sh | bash

Guide: https://aikaryashala.com/system_setup/04_install_py/"
}

main "$@"
