#!/usr/bin/env bash
#
# install_c.sh - Step 3 of https://aikaryashala.com/system_setup
#
# A C toolchain built around clang (compiler) and lldb (debugger), plus the
# tools for looking at a compiled program as raw bytes: xxd, hexdump, od, hexyl,
# objdump, readelf, nm, strings.
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

# The compiler and its immediate friends.
PKGS_COMPILER=(
    clang               # the C and C++ compiler
    lld                 # LLVM's linker, much faster than the default
    llvm                # llvm-objdump, llvm-nm, llvm-readelf and friends
    libc6-dev           # the C standard library headers
    build-essential     # make, the C library, and the headers clang expects
    pkg-config          # locate the compiler flags for a library
)

# Debugging and inspecting a running program.
PKGS_DEBUG=(
    lldb                # the debugger
    valgrind            # find memory leaks and invalid reads/writes
    strace              # trace the system calls a program makes
    ltrace              # trace the library calls a program makes
)

# Reading a compiled file as bytes rather than as a program.
PKGS_BINARY=(
    binutils            # objdump, readelf, nm, strings, size, ar, ranlib
    coreutils           # od, the POSIX octal/hex dump
    file                # identify a file from its magic bytes
)

# Package names for the hex viewers moved around between Ubuntu releases: xxd
# split out of vim-common, and hexdump moved from bsdmainutils to bsdextrautils.
# Offer every spelling and take whichever the release actually has.
PKGS_BINARY_OPTIONAL=(
    xxd                 # the classic hex dump, and hex -> binary with -r
    vim-common          # older home of xxd
    bsdextrautils       # hexdump
    bsdmainutils        # older home of hexdump
    hexyl               # colourised hex viewer, much easier to read than xxd
)

# Build systems.
PKGS_TOOLING=(
    cmake
    ninja-build
)

# Code quality. Useful, but not required in order to compile anything.
PKGS_TOOLING_OPTIONAL=(
    clang-format        # format C source consistently
    clang-tidy          # static analysis, catches bugs before you run them
    clang-tools         # scan-build and friends
)

install_compiler() {
    banner "Installing the C compiler and linker"
    apt_install "${PKGS_COMPILER[@]}"
}

install_debuggers() {
    banner "Installing debuggers"
    apt_install "${PKGS_DEBUG[@]}"
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

install_binary_tools() {
    banner "Installing tools for viewing files in hex and binary"
    apt_install "${PKGS_BINARY[@]}"
    apt_install_optional "${PKGS_BINARY_OPTIONAL[@]}"
}

install_tooling() {
    banner "Installing build tools and static analysis"
    apt_install "${PKGS_TOOLING[@]}"
    apt_install_optional "${PKGS_TOOLING_OPTIONAL[@]}"
}

# Prove the toolchain actually works end to end, rather than only checking that
# binaries exist.
smoke_test() {
    banner "Compiling a test program"
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

    # The guide tells people to use -fsanitize=address, so prove it links and
    # actually catches something. This is the check that would have caught the
    # missing libclang-rt package.
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

    # The program is expected to abort, so ignore its exit status and judge by
    # what it printed. Capture to a file rather than piping, so the output can
    # be shown if this ever fails.
    "$dir/overflow" >"$dir/asan_out" 2>&1
    local status=$?

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

    # Show the reader what a hex dump of a real binary looks like.
    if have xxd; then
        printf '\n%sThe first 64 bytes of that binary, in hex:%s\n' "$C_DIM" "$C_RESET"
        xxd -l 64 "$dir/hello" || true
        printf '%sThose first four bytes - 7f 45 4c 46 - are .ELF, the marker\n' "$C_DIM"
        printf 'that tells Linux this file is an executable program.%s\n' "$C_RESET"
    fi
}

summary() {
    banner "Installed"
    verify "clang"       clang --version
    verify "lldb"        lldb --version
    verify "make"        make --version
    verify "cmake"       cmake --version
    verify "valgrind"    valgrind --version
    verify "objdump"     objdump --version
    verify_present "xxd"      xxd
    verify_present "hexdump"  hexdump
    verify_present "od"       od
    verify_present "hexyl"    hexyl
    verify_present "readelf"  readelf
    verify_present "nm"       nm
    verify_present "strings"  strings
    verify_present "strace"   strace
}

main() {
    require_linux
    require_apt
    require_sudo

    install_compiler
    install_debuggers
    install_sanitizer_runtime
    install_binary_tools
    install_tooling
    smoke_test
    summary

    finish "Try it out:

  clang -g -O0 -Wall -Wextra -o hello hello.c   # compile with debug info
  ./hello                                       # run it
  lldb ./hello                                  # debug it
  xxd hello | head                              # look at it as bytes

Next step - Python and uv:

  curl -fsSL $SYSTEM_SETUP_BASE_URL/install_py.sh | bash

Guide: https://aikaryashala.com/system_setup/03_install_c/"
}

main "$@"
