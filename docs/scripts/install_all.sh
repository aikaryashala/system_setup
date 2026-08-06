#!/usr/bin/env bash
#
# install_all.sh - steps 2 to 5 of https://aikaryashala.com/system_setup
#
# Runs the essential commands, C, Python and Java installers back to back.
# Step 1 (installing Ubuntu itself) has to happen on Windows first - if you can
# read this inside a terminal, you have already done it.
#
# Run inside Ubuntu:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_all.sh | bash
#
# Safe to run more than once.
#
# Steps 6 to 12 are independent extras and are deliberately NOT part of this
# run. Ask for them by name if you want them:
#   STEPS="more_cmds binary uv maven_gradle sanitizers py_debug" bash install_all.sh
#
# Optional environment variables:
#   STEPS="cmds c py java"   run only some of the steps, in this order

# shellcheck source-path=SCRIPTDIR
set -euo pipefail

SYSTEM_SETUP_BASE_URL="${SYSTEM_SETUP_BASE_URL:-https://aikaryashala.com/system_setup/scripts}"

_bootstrap_common() {
    local here=""
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    if [ -n "$here" ] && [ -f "$here/common.sh" ]; then
        SCRIPT_DIR="$here"
        # shellcheck source=common.sh
        . "$here/common.sh"
    elif command -v curl >/dev/null 2>&1; then
        SCRIPT_DIR=""
        # shellcheck disable=SC1090
        . <(curl -fsSL "$SYSTEM_SETUP_BASE_URL/common.sh")
    else
        echo "Cannot find common.sh, and curl is not installed to fetch it." >&2
        echo "Run: sudo apt-get update && sudo apt-get install -y curl" >&2
        exit 1
    fi
}
_bootstrap_common

# ---------------------------------------------------------------------------

STEPS="${STEPS:-cmds c py java}"
FAILED_STEPS=()
RAN_STEPS=()

step_label() {
    case "$1" in
        cmds)      echo "Core command line tools" ;;
        c)         echo "C toolchain: clang and lldb" ;;
        py)        echo "Python 3" ;;
        java)      echo "Java: JDK, javac, java, jshell" ;;
        more_cmds) echo "The wider command line toolkit" ;;
        binary)    echo "Binary, analysis and build tools" ;;
        uv)           echo "uv: Python packages, projects and versions" ;;
        maven_gradle) echo "Java build tools: Maven and Gradle" ;;
        sanitizers)   echo "clang warnings and AddressSanitizer" ;;
        py_debug)     echo "Python debugging with pdb" ;;
        *)         echo "$1" ;;
    esac
}

# Run one installer, from disk when we have a checkout, otherwise from the site.
run_step() {
    local step="$1"
    local script="install_${step}.sh"

    banner "$(step_label "$step")"

    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$script" ]; then
        # Each installer runs in its own bash so a failure inside one cannot
        # abort this script, and so their variables stay separate.
        if bash "$SCRIPT_DIR/$script"; then
            RAN_STEPS+=("$step")
            return 0
        fi
    else
        if curl -fsSL "$SYSTEM_SETUP_BASE_URL/$script" | bash; then
            RAN_STEPS+=("$step")
            return 0
        fi
    fi

    warn "$script did not finish successfully"
    FAILED_STEPS+=("$step")
    return 0
}

main() {
    require_linux
    require_apt
    require_sudo

    banner "system_setup - installing everything"
    printf 'Steps to run: %s\n' "$STEPS"
    printf 'This takes a few minutes and downloads roughly 1 GB.\n'

    local step
    for step in $STEPS; do
        run_step "$step"
    done

    banner "Summary"
    if [ ${#RAN_STEPS[@]} -gt 0 ]; then
        for step in "${RAN_STEPS[@]}"; do
            ok "$(step_label "$step")"
        done
    fi
    if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
        for step in "${FAILED_STEPS[@]}"; do
            printf '%sfail%s %s\n' "$C_RED" "$C_RESET" "$(step_label "$step")"
        done
        printf '\nRe-run the failed step on its own to see the full error:\n'
        for step in "${FAILED_STEPS[@]}"; do
            printf '  curl -fsSL %s/install_%s.sh | bash\n' "$SYSTEM_SETUP_BASE_URL" "$step"
        done
        exit 1
    fi

    printf '\n%sEverything installed.%s Load the new settings into this terminal with:\n' \
        "$C_GREEN" "$C_RESET"
    printf '  source ~/.bashrc\n\n'
    printf 'Guides for each tool: https://aikaryashala.com/system_setup\n'
}

main "$@"
