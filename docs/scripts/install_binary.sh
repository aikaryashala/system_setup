#!/usr/bin/env bash
#
# install_binary.sh - Step 7 of https://aikaryashala.com/system_setup
#
# Tools for working on a compiled file rather than on source: reading it as
# hexadecimal, taking it apart, checking it for memory errors, watching what it
# asks the operating system for, and building larger projects.
#
# This step is independent. It pairs naturally with step 3 (clang and lldb), but
# it does not require it and nothing in steps 1 to 5 depends on it.
#
# Run inside Ubuntu:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_binary.sh | bash
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

# Watching a running program.
PKGS_RUNTIME=(
    valgrind            # find memory leaks and invalid reads/writes
    strace              # trace the system calls a program makes
    ltrace              # trace the library calls a program makes
)

# Building more than one file at a time.
PKGS_BUILD=(
    make
    cmake
    ninja-build
    pkg-config          # locate the compiler flags for a library
)

# Code quality.
PKGS_QUALITY=(
    clang-format        # format C source consistently
    clang-tidy          # static analysis, catches bugs before you run them
    clang-tools         # scan-build and friends
)

install_binary_tools() {
    banner "Installing tools for viewing files in hex and binary"
    apt_install "${PKGS_BINARY[@]}"
    apt_install_optional "${PKGS_BINARY_OPTIONAL[@]}"
}

install_runtime_tools() {
    banner "Installing runtime analysis tools"
    apt_install "${PKGS_RUNTIME[@]}"
}

install_build_tools() {
    banner "Installing build tools"
    apt_install "${PKGS_BUILD[@]}"
}

install_quality_tools() {
    banner "Installing static analysis and formatting"
    apt_install_optional "${PKGS_QUALITY[@]}"
}

# Show these tools doing their job on a real binary. Needs a compiler, which is
# step 3 - if clang is not here, fall back to a program the system already has.
demo() {
    banner "A look at a real binary"

    local target="" dir=""

    if have clang; then
        dir="$(mktemp -d)"
        # shellcheck disable=SC2064
        trap "rm -rf '$dir'" RETURN

        cat >"$dir/hello.c" <<'EOF'
#include <stdio.h>

int main(void) {
    printf("hello\n");
    return 0;
}
EOF
        if clang -g -O0 -o "$dir/hello" "$dir/hello.c" 2>/dev/null; then
            target="$dir/hello"
        fi
    fi

    if [ -z "$target" ]; then
        skip "clang is not installed - using /bin/ls instead of a freshly compiled program"
        target="/bin/ls"
    fi

    if have file; then
        printf '\n%s$ file %s%s\n' "$C_DIM" "$target" "$C_RESET"
        file "$target"
    fi

    if have xxd; then
        printf '\n%s$ xxd -l 64 %s%s\n' "$C_DIM" "$target" "$C_RESET"
        xxd -l 64 "$target" || true
        printf '%sThose first four bytes - 7f 45 4c 46 - are .ELF, the marker\n' "$C_DIM"
        printf 'that tells Linux this file is an executable program.%s\n' "$C_RESET"
    fi

    if have size; then
        printf '\n%s$ size %s%s\n' "$C_DIM" "$target" "$C_RESET"
        size "$target" || true
    fi

    if have readelf; then
        printf '\n%s$ readelf -h %s | head -6%s\n' "$C_DIM" "$target" "$C_RESET"
        readelf -h "$target" 2>/dev/null | head -n 6 || true
    fi
}

summary() {
    banner "Installed"
    verify "objdump"  objdump --version
    verify "valgrind" valgrind --version
    verify "make"     make --version
    verify "cmake"    cmake --version
    verify_present "xxd"     xxd
    verify_present "hexdump" hexdump
    verify_present "od"      od
    verify_present "hexyl"   hexyl
    verify_present "readelf" readelf
    verify_present "nm"      nm
    verify_present "strings" strings
    verify_present "size"    size
    verify_present "strace"  strace
    verify_present "ltrace"  ltrace
    verify_present "ninja"   ninja
}

main() {
    require_linux
    require_apt
    require_sudo

    install_binary_tools
    install_runtime_tools
    install_build_tools
    install_quality_tools
    demo
    summary

    finish "Try it out on any program you have compiled:

  file hello                  # what kind of file is this?
  xxd hello | head            # the raw bytes, in hexadecimal
  hexyl -n 64 hello           # the same, colour-coded and far easier to read
  strings hello               # the readable text hiding inside
  nm hello                    # function and variable names
  objdump -d hello            # disassemble it back to assembly
  readelf -h hello            # explain the file's structure
  valgrind ./hello            # find memory errors
  strace ./hello              # every request it makes to the kernel

Guide: https://aikaryashala.com/system_setup/07_install_binary/"
}

main "$@"
