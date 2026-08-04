#!/usr/bin/env bash
#
# install_c.sh - Step 3 of https://aikaryashala.com/system_setup
#
# The two tools you need to write C: clang to compile it, lldb to debug the
# program that comes out.
#
# Everything else that works on a compiled file - reading it as hex, taking it
# apart, checking it for memory errors, build systems - is step 7, installed
# separately.
#
# Run inside Ubuntu:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_c.sh | bash
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

# The compiler, the debugger, and the bare minimum for them to work. apt pulls
# in the assembler and linker clang needs as dependencies.
PKGS_C=(
    clang               # the C compiler
    lld                 # LLVM's linker, much faster than the default
    lldb                # the debugger
    libc6-dev           # the C standard library headers
)

install_toolchain() {
    banner "Installing clang and lldb"
    apt_install "${PKGS_C[@]}"
}

# -fsanitize=address is the single most useful flag a C beginner can learn, and
# the guide recommends it. Ubuntu ships the runtime it links against in a
# separate, version-suffixed package: without it clang compiles the program and
# then fails at the link step with a missing libclang_rt.asan. Derive the
# version from clang itself so this keeps working on future releases.
install_sanitizer_runtime() {
    banner "Installing the sanitizer runtime"

    local major
    major="$(clang --version 2>/dev/null \
        | sed -n 's/.*clang version \([0-9][0-9]*\).*/\1/p' \
        | head -n 1)"

    if [ -z "$major" ]; then
        warn "Could not determine the clang version - skipping the sanitizer runtime"
        return 0
    fi

    apt_install_optional "libclang-rt-${major}-dev"
}

# Prove the toolchain actually works end to end, rather than only checking that
# the binaries exist.
smoke_test() {
    banner "Compiling and debugging a test program"
    local dir
    dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$dir'" RETURN

    cat >"$dir/hello.c" <<'EOF'
#include <stdio.h>

int main(void) {
    printf("clang works\n");
    return 0;
}
EOF

    if ! clang -g -O0 -Wall -Wextra -o "$dir/hello" "$dir/hello.c" 2>"$dir/err"; then
        warn "clang could not compile a test program:"
        cat "$dir/err" >&2
        VERIFY_FAILED=1
        return 0
    fi
    ok "clang compiled hello.c"

    if [ "$("$dir/hello")" = "clang works" ]; then
        ok "the compiled program ran correctly"
    else
        warn "the compiled program did not produce the expected output"
        VERIFY_FAILED=1
    fi

    # Drive lldb non-interactively: set a breakpoint, run, and confirm it
    # stopped where it was asked to. This checks the debugger can actually read
    # the debug information clang produced, not merely that it is installed.
    lldb --batch -o "breakpoint set --name main" -o run -o quit "$dir/hello" \
        >"$dir/lldb_out" 2>&1 || true

    if grep -q "stop reason = breakpoint" "$dir/lldb_out"; then
        ok "lldb stopped at a breakpoint in main"
    elif grep -qE "personality set failed|ptrace|Operation not permitted" "$dir/lldb_out"; then
        # Starting a process under a debugger needs ptrace, which container
        # runtimes block by default. The debugger is installed and working - the
        # sandbox simply will not let it take control of another process.
        warn "lldb is installed but this environment forbids debugging"
        warn "(no ptrace permission - normal inside a container)."
        warn "It will work normally on a real Ubuntu or WSL machine."
    else
        warn "lldb did not stop at a breakpoint as expected. It printed:"
        head -n 5 "$dir/lldb_out" >&2
        VERIFY_FAILED=1
    fi

    # The guide tells people to use -fsanitize=address, so prove it links and
    # actually catches something.
    cat >"$dir/overflow.c" <<'EOF'
int main(void) {
    int numbers[4] = {1, 2, 3, 4};
    numbers[4] = 99;
    return numbers[0];
}
EOF

    if ! clang -g -O0 -fsanitize=address -o "$dir/overflow" "$dir/overflow.c" 2>"$dir/asan_err"; then
        # Failing to link is a genuine installation problem: it means the
        # sanitizer runtime package is missing.
        warn "Could not build with -fsanitize=address:"
        head -n 3 "$dir/asan_err" >&2
        VERIFY_FAILED=1
        return 0
    fi

    # `|| status=$?` rather than a bare call: this program is meant to die, and
    # under `set -e` a bare call would abort the whole script before we could
    # look at how it died.
    local status=0
    "$dir/overflow" >"$dir/asan_out" 2>&1 || status=$?

    if grep -q "AddressSanitizer" "$dir/asan_out"; then
        ok "AddressSanitizer works and caught a buffer overflow"
    elif [ "$status" -eq 137 ] || [ "$status" -eq 139 ]; then
        # AddressSanitizer reserves an enormous shadow memory mapping. Emulated
        # containers and memory-capped environments kill it before it can start.
        # The toolchain is installed correctly - it just cannot run here, which
        # is not something this script can fix and not an install failure.
        warn "AddressSanitizer is installed but cannot run in this environment"
        warn "(the test program was killed - usually emulation or a memory limit)."
        warn "It will work normally on a real Ubuntu or WSL machine."
    else
        warn "AddressSanitizer linked but did not report a known-bad write."
        warn "The program printed:"
        head -n 5 "$dir/asan_out" >&2
        VERIFY_FAILED=1
    fi
}

summary() {
    banner "Installed"
    verify "clang" clang --version
    verify "lldb"  lldb --version
}

main() {
    require_linux
    require_apt
    require_sudo

    install_toolchain
    install_sanitizer_runtime
    smoke_test
    summary

    finish "Try it out:

  clang -g -O0 -Wall -Wextra -o hello hello.c   # compile with debug info
  ./hello                                       # run it
  lldb ./hello                                  # debug it

Next step - Python and uv:

  curl -fsSL $SYSTEM_SETUP_BASE_URL/install_py.sh | bash

Guide: https://aikaryashala.com/system_setup/03_install_c/"
}

main "$@"
