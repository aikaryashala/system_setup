#!/usr/bin/env bash
# common.sh - shared helpers for the system_setup installers.
#
# Not meant to be run on its own. Every installer sources this file, either from
# the directory next to it or over the network from the published website.
#
#   https://aikaryashala.com/system_setup

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
else
    C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
fi

log()  { printf '%s==>%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
skip() { printf '%s skip%s %s\n' "$C_DIM"   "$C_RESET" "$*"; }
warn() { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%sfail%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; exit 1; }

banner() {
    printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"
    printf '%s%s%s\n' "$C_DIM" "------------------------------------------------------------" "$C_RESET"
}

# ---------------------------------------------------------------------------
# Environment checks
# ---------------------------------------------------------------------------

# Set by require_sudo. Declared here so `set -u` never trips over it.
SUDO="${SUDO:-}"
RC_CHANGED="${RC_CHANGED:-0}"

# have <command> - true if the command exists on PATH.
have() { command -v "$1" >/dev/null 2>&1; }

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

require_linux() {
    [ "$(uname -s)" = "Linux" ] || die "These scripts run on Ubuntu (Linux). Detected: $(uname -s).
On Windows, install Ubuntu with WSL first:
  https://aikaryashala.com/system_setup/01_install_ubuntu/"
}

require_apt() {
    # shellcheck disable=SC1091  # /etc/os-release only exists on the target system
    have apt-get || die "apt-get was not found. These scripts target Debian/Ubuntu.
Detected: $( (. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || echo unknown)"
}

# Ask for sudo once, up front, so the rest of the run does not stall on a
# password prompt buried in the middle of an install.
require_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
        return 0
    fi
    have sudo || die "sudo is not installed and you are not root."
    if ! sudo -n true 2>/dev/null; then
        log "Administrator access is needed to install packages."
        sudo -v || die "Could not obtain sudo access."
    fi
    SUDO="sudo"
}

# ---------------------------------------------------------------------------
# APT
# ---------------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive
APT_UPDATED="${APT_UPDATED:-0}"

apt_update() {
    if [ "$APT_UPDATED" = "1" ]; then
        return 0
    fi
    log "Refreshing the package list"
    $SUDO apt-get update -qq || die "apt-get update failed. Check your network connection."
    APT_UPDATED=1
}

# pkg_installed <package> - true if the .deb is installed and configured.
pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed'
}

# apt_install <package>... - installs only what is missing.
apt_install() {
    local pkg missing=()
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            skip "$pkg is already installed"
        else
            missing+=("$pkg")
        fi
    done

    [ ${#missing[@]} -eq 0 ] && return 0

    apt_update
    log "Installing: ${missing[*]}"
    $SUDO apt-get install -y -qq --no-install-recommends "${missing[@]}" \
        || die "Failed to install: ${missing[*]}"
    for pkg in "${missing[@]}"; do
        ok "$pkg"
    done
}

# apt_install_optional <package>... - same, but a failure is a warning.
# For packages that are not in every Ubuntu release.
apt_install_optional() {
    local pkg
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            skip "$pkg is already installed"
            continue
        fi
        apt_update
        if $SUDO apt-get install -y -qq --no-install-recommends "$pkg" 2>/dev/null; then
            ok "$pkg"
        else
            warn "$pkg is not available on this Ubuntu release - skipping it"
        fi
    done
}

# ---------------------------------------------------------------------------
# Shell configuration
# ---------------------------------------------------------------------------

shell_rc() { printf '%s/.bashrc' "$HOME"; }

# add_to_rc <marker> <line...> - appends to ~/.bashrc exactly once. The marker
# is a unique string used to detect a previous run, so re-running this script
# never duplicates the entry.
add_to_rc() {
    local marker="$1"; shift
    local rc; rc="$(shell_rc)"

    [ -f "$rc" ] || touch "$rc"

    if grep -qF "# system_setup:$marker" "$rc"; then
        skip "$marker is already set up in ~/.bashrc"
        return 0
    fi

    {
        printf '\n# system_setup:%s\n' "$marker"
        printf '%s\n' "$@"
    } >>"$rc"
    ok "Added $marker to ~/.bashrc"
    RC_CHANGED=1
}

# Make sure ~/.local/bin is on PATH, now and in future shells.
ensure_local_bin_on_path() {
    mkdir -p "$HOME/.local/bin"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) : ;;
        *) PATH="$HOME/.local/bin:$PATH"; export PATH ;;
    esac
    # Single quotes on purpose: $HOME and $PATH must reach ~/.bashrc unexpanded,
    # so the line stays correct if the home directory ever moves.
    # shellcheck disable=SC2016
    add_to_rc "local-bin" 'export PATH="$HOME/.local/bin:$PATH"'
}

# ---------------------------------------------------------------------------
# Verification summary
# ---------------------------------------------------------------------------

VERIFY_FAILED=0

# verify <label> <command> [args...] - runs the command and prints the first
# meaningful line of its output next to the label. Used for the version summary
# at the end of each installer.
#
# "First meaningful line" is doing real work here:
#   - `mvn -version` wraps its banner in ANSI bold codes,
#   - `gradle --version` opens with a blank line, then a row of dashes, and only
#     then the version - so both "first line" and "first non-blank line" print
#     something useless.
# Strip the colour, then take the first line containing an actual character.
verify() {
    local label="$1"; shift
    local out esc
    if ! have "$1"; then
        printf '  %s%-14s%s %sNOT FOUND%s\n' "$C_BOLD" "$label" "$C_RESET" "$C_RED" "$C_RESET"
        VERIFY_FAILED=1
        return 1
    fi
    esc="$(printf '\033')"
    out="$("$@" 2>&1 \
        | sed "s/${esc}\[[0-9;]*m//g" \
        | grep -m 1 '[[:alnum:]]')" || true
    printf '  %s%-14s%s %s\n' "$C_BOLD" "$label" "$C_RESET" "${out:-installed}"
}

# verify_present <label> <command> - just confirms the command exists.
verify_present() {
    local label="$1" cmd="$2"
    if have "$cmd"; then
        printf '  %s%-14s%s %s\n' "$C_BOLD" "$label" "$C_RESET" "$(command -v "$cmd")"
    else
        printf '  %s%-14s%s %sNOT FOUND%s\n' "$C_BOLD" "$label" "$C_RESET" "$C_RED" "$C_RESET"
        VERIFY_FAILED=1
    fi
}

# finish <next-step-message> - closing summary for an installer.
finish() {
    if [ "$VERIFY_FAILED" = "1" ]; then
        printf '\n%sSome tools did not install correctly (see NOT FOUND above).%s\n' "$C_YELLOW" "$C_RESET"
        printf 'Try opening a new terminal and running this script again.\n'
    else
        printf '\n%sDone.%s\n' "$C_GREEN" "$C_RESET"
    fi
    if [ "${RC_CHANGED:-0}" = "1" ]; then
        printf '\n%sYour ~/.bashrc changed.%s Load it into this terminal with:\n' "$C_BOLD" "$C_RESET"
        printf '  source ~/.bashrc\n'
    fi
    [ $# -gt 0 ] && printf '\n%s\n' "$*"
    return 0
}
