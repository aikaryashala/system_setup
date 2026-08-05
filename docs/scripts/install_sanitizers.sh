#!/usr/bin/env bash
#
# install_sanitizers.sh - Step 11 of https://aikaryashala.com/system_setup
#
# The compiler options that find bugs for you: warnings, and AddressSanitizer.
#
# Warnings need nothing installed - they are options you pass to clang. The
# sanitizer does: Ubuntu ships its runtime library in a separate package, and
# without it clang compiles your program and then fails to link it.
#
# This step is independent, but it needs clang from step 3:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_c.sh | bash
#
# Run inside Ubuntu:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_sanitizers.sh | bash
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

require_clang() {
    banner "Checking prerequisites"

    if ! have clang; then
        die "clang is not installed. Run step 3 first:
  curl -fsSL $SYSTEM_SETUP_BASE_URL/install_c.sh | bash"
    fi
    ok "clang is installed"
}

# Ubuntu ships the sanitizer runtime in a separate, version-suffixed package.
# Without it clang accepts -fsanitize=address and then fails at the link step
# with a missing libclang_rt.asan. Derive the version from clang itself so this
# keeps working on future Ubuntu releases.
install_sanitizer_runtime() {
    banner "Installing the AddressSanitizer runtime"

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

# The sample the guide walks through: an array written one element past its end.
write_sample() {
    banner "Writing the sample program"

    local dest="${SAMPLE_DIR:-$HOME/c-samples}"
    mkdir -p "$dest"

    cat >"$dest/overflow.c" <<'EOF'
/* overflow.c - a deliberate bug.
 *
 * Compiled plainly, this often appears to work, which is what makes this kind
 * of bug dangerous:
 *
 *     clang -g overflow.c -o overflow
 *     ./overflow
 *
 * Compiled with the address sanitizer, it stops and names the exact line:
 *
 *     clang -g -fsanitize=address overflow.c -o overflow
 *     ./overflow
 */

#include <stdio.h>

int main(void)
{
    int numbers[4] = {1, 2, 3, 4};

    numbers[4] = 99;              /* one past the end of the array */

    printf("%d\n", numbers[0]);
    return 0;
}
EOF

    ok "$dest/overflow.c"
    SAMPLE_DEST="$dest"
}

check_sanitizer() {
    banner "Checking that AddressSanitizer catches a real bug"

    local dir
    dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$dir'" RETURN

    cp "${SAMPLE_DEST:-$HOME/c-samples}/overflow.c" "$dir/overflow.c"

    if ! clang -g -fsanitize=address "$dir/overflow.c" -o "$dir/overflow" 2>"$dir/err"; then
        warn "Could not build with -fsanitize=address:"
        head -n 3 "$dir/err" >&2
        VERIFY_FAILED=1
        return 0
    fi
    ok "clang linked a program with -fsanitize=address"

    # This program is meant to die. `|| status=$?` keeps `set -e` from aborting
    # the script before we can look at how it died.
    local status=0
    "$dir/overflow" >"$dir/out" 2>&1 || status=$?

    if grep -q "AddressSanitizer" "$dir/out"; then
        ok "AddressSanitizer caught the buffer overflow"
    elif [ "$status" -eq 137 ] || [ "$status" -eq 139 ]; then
        # AddressSanitizer reserves an enormous shadow memory mapping. Emulated
        # containers and memory-capped environments kill it before it starts.
        warn "AddressSanitizer is installed but cannot run in this environment"
        warn "(the test program was killed - usually emulation or a memory limit)."
        warn "It will work normally on a real Ubuntu or WSL machine."
    else
        warn "AddressSanitizer linked but did not report the known-bad write."
        warn "The program printed:"
        head -n 5 "$dir/out" >&2
        VERIFY_FAILED=1
    fi
}

# Warnings need no package - prove they actually fire.
check_warnings() {
    banner "Checking that warnings work"

    local dir
    dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$dir'" RETURN

    cat >"$dir/warn.c" <<'EOF'
#include <stdio.h>

int main(void)
{
    int counted;                  /* never given a value */
    printf("%d\n", counted);
    return 0;
}
EOF

    clang -Wall -Wextra -g "$dir/warn.c" -o "$dir/warn" 2>"$dir/warn_out" || true

    if grep -q "uninitialized" "$dir/warn_out"; then
        ok "-Wall -Wextra reported an uninitialised variable"
    else
        warn "clang did not warn about an uninitialised variable. It printed:"
        head -n 5 "$dir/warn_out" >&2
        VERIFY_FAILED=1
    fi
}

summary() {
    banner "Installed"
    verify "clang" clang --version
    printf '  %s%-14s%s %s\n' "$C_BOLD" "sample" "$C_RESET" "${SAMPLE_DEST:-not written}/overflow.c"
}

main() {
    require_linux
    require_apt
    require_sudo

    require_clang
    install_sanitizer_runtime
    write_sample
    check_warnings
    check_sanitizer
    summary

    finish "The sample is in ${SAMPLE_DEST:-~/c-samples}:

  cd ${SAMPLE_DEST:-~/c-samples}
  clang -g overflow.c -o overflow                 # looks fine, runs, prints 1
  clang -g -fsanitize=address overflow.c -o overflow
  ./overflow                                      # now it names the exact line

Also worth adding to every compile while you learn:

  clang -g -Wall -Wextra overflow.c -o overflow   # let the compiler warn you

Guide: https://aikaryashala.com/system_setup/11_clang_options/"
}

main "$@"
