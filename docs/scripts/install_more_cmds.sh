#!/usr/bin/env bash
#
# install_more_cmds.sh - Step 6 of https://aikaryashala.com/system_setup
#
# The rest of the everyday command line toolkit: fast search, archives,
# terminal multiplexing, and the remaining network utilities.
#
# This step is independent. Nothing in steps 1 to 5 needs it, and nothing here
# depends on the language toolchains. Install it whenever you want it.
#
# Run inside Ubuntu:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_more_cmds.sh | bash
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
        echo "Run: sudo apt-get update && sudo apt-get install -y curl" >&2
        exit 1
    fi
}
_bootstrap_common

# ---------------------------------------------------------------------------

# Searching, faster and friendlier than the classics.
PKGS_SEARCH=(
    ripgrep             # rg: search file contents
    fd-find             # fd: find files by name
    fzf                 # fuzzy-pick from any list
    bat                 # cat with syntax highlighting
)

# The remaining network utilities.
PKGS_NETWORK=(
    wget                # fetch a URL; better at large or resumable downloads
    rsync               # copy directories efficiently, locally or over ssh
    netcat-openbsd      # nc: raw tcp/udp connections
    traceroute          # see the hops between you and a host
)

# Archives beyond zip.
PKGS_ARCHIVE=(
    tar
    xz-utils
)

# Working in the terminal.
PKGS_TERMINAL=(
    tmux                # keep sessions alive, split the terminal
    ncdu                # find what is using your disk
    procps              # ps, top, watch, free
    man-db              # the manual pages
    bc                  # calculator
    time                # measure how long a command takes
)

# Package sources and text fixes.
PKGS_MISC=(
    gnupg               # verify signatures on third-party apt repositories
    software-properties-common
    lsb-release
    dos2unix            # fix Windows line endings, common when using WSL
)

install_packages() {
    banner "Installing the wider command line toolkit"
    apt_install "${PKGS_SEARCH[@]}"
    apt_install "${PKGS_NETWORK[@]}"
    apt_install "${PKGS_ARCHIVE[@]}"
    apt_install "${PKGS_TERMINAL[@]}"
    apt_install "${PKGS_MISC[@]}"

    # Only useful inside WSL: wslview opens Windows apps from the Linux shell.
    if is_wsl; then
        apt_install_optional wslu
    fi
}

# Ubuntu ships bat and fd under different names, because those names were
# already taken by other packages. Put the expected names on PATH.
fix_renamed_commands() {
    banner "Making 'bat' and 'fd' available under their usual names"
    ensure_local_bin_on_path

    if have batcat && ! have bat; then
        ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
        ok "bat -> batcat"
    else
        skip "bat"
    fi

    if have fdfind && ! have fd; then
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
        ok "fd -> fdfind"
    else
        skip "fd"
    fi
}

summary() {
    banner "Installed"
    verify "ripgrep" rg --version
    verify "fzf"     fzf --version
    verify "tmux"    tmux -V
    verify "wget"    wget --version
    verify "rsync"   rsync --version
    verify_present "fd"    fd
    verify_present "bat"   bat
    verify_present "ncdu"  ncdu
    verify_present "nc"    nc
    verify_present "tar"   tar
    verify_present "man"   man
}

main() {
    require_linux
    require_apt
    require_sudo

    install_packages
    fix_renamed_commands
    summary

    finish "Try them out:

  rg \"TODO\"                    # search file contents, fast
  fd \"\\.c\$\"                    # find files by name
  bat hello.c                  # cat, with syntax highlighting
  rsync -avP src/ host:dst/    # copy a folder, resuming if it breaks
  tmux                         # split the terminal, keep sessions alive

Guide: https://aikaryashala.com/system_setup/06_install_more_cmds/"
}

main "$@"
