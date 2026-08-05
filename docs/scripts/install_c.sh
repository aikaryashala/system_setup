#!/usr/bin/env bash
#
# install_c.sh - Step 3 of https://aikaryashala.com/system_setup
#
# The two tools you need to write C: clang to compile it, lldb to debug the
# program that comes out.
#
# Deliberately minimal. Compiler options that hunt for bugs - warnings,
# optimisation levels, -fsanitize=address - are step 11. Tools that work on the
# compiled file, such as hex viewers and disassemblers, are step 7. Both are
# installed separately.
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

    if ! clang -g "$dir/hello.c" -o "$dir/hello" 2>"$dir/err"; then
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
    smoke_test
    summary

    finish "Try it out:

  clang -g hello.c -o hello    # compile, keeping debug information
  ./hello                      # run it
  lldb ./hello                 # debug it

Next step - Python and the pdb debugger:

  curl -fsSL $SYSTEM_SETUP_BASE_URL/install_py.sh | bash

Guide: https://aikaryashala.com/system_setup/03_install_c/"
}

main "$@"
