#!/usr/bin/env bash
#
# install_cmds.sh - Step 2 of https://aikaryashala.com/system_setup
#
# The essential command line tools every other step assumes are present:
# fetching, editing, searching, archiving, and looking at the network.
#
# Run inside Ubuntu:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_cmds.sh | bash
#
# Safe to run more than once.

# shellcheck source-path=SCRIPTDIR
set -euo pipefail

SYSTEM_SETUP_BASE_URL="${SYSTEM_SETUP_BASE_URL:-https://aikaryashala.com/system_setup/scripts}"

# Load common.sh from beside this script, or from the website when this script
# was piped straight into bash.
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

# Fetching things and talking to servers.
PKGS_NETWORK=(
    ca-certificates     # the trusted certificate bundle, needed for https
    curl                # fetch a URL
    wget                # fetch a URL, good at large downloads
    openssh-client      # ssh, scp, ssh-keygen
    rsync               # copy directories efficiently, locally or over ssh
    iproute2            # ip addr, ip route
    iputils-ping        # ping
    dnsutils            # dig, nslookup
    netcat-openbsd      # nc: raw tcp/udp connections
    traceroute          # see the hops between you and a host
)

# Version control and package sources.
PKGS_SOURCE=(
    git
    gnupg               # verify signatures on third-party apt repositories
    software-properties-common
    lsb-release
)

# Editing and reading files.
PKGS_EDIT=(
    vim
    nano                # the friendlier editor; good default for git commits
    less                # page through long output
    file                # identify what a file actually is
    dos2unix            # fix Windows line endings, common when using WSL
)

# Archives.
PKGS_ARCHIVE=(
    zip
    unzip
    xz-utils
    tar
)

# Working in the terminal.
PKGS_TERMINAL=(
    tmux                # keep sessions alive, split the terminal
    tree                # show a directory as a tree
    htop                # interactive process viewer
    ncdu                # find what is using your disk
    procps              # ps, top, watch, free
    man-db              # the manual pages
    bc                  # calculator
    time                # measure how long a command takes
)

# Searching, faster and friendlier than the classics.
PKGS_SEARCH=(
    ripgrep             # rg: search file contents
    fd-find             # fd: find files by name
    fzf                 # fuzzy-pick from any list
    bat                 # cat with syntax highlighting
    jq                  # read and reshape JSON
)

install_packages() {
    banner "Installing essential command line tools"
    apt_install "${PKGS_NETWORK[@]}"
    apt_install "${PKGS_SOURCE[@]}"
    apt_install "${PKGS_EDIT[@]}"
    apt_install "${PKGS_ARCHIVE[@]}"
    apt_install "${PKGS_TERMINAL[@]}"
    apt_install "${PKGS_SEARCH[@]}"

    # Only useful inside WSL: wslview opens Windows apps from the Linux shell.
    if is_wsl; then
        apt_install_optional wslu
    fi
}

# Ubuntu ships bat and fd under different names because those names were already
# taken by other packages. Put the expected names on PATH.
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
    verify "git"      git --version
    verify "curl"     curl --version
    verify "vim"      vim --version
    verify "tmux"     tmux -V
    verify "jq"       jq --version
    verify "ripgrep"  rg --version
    verify "fzf"      fzf --version
    verify_present "fd"   fd
    verify_present "bat"  bat
    verify_present "tree" tree
    verify_present "htop" htop
    verify_present "ssh"  ssh
}

main() {
    require_linux
    require_apt
    require_sudo

    install_packages
    fix_renamed_commands
    summary

    finish "Next step - the C toolchain (clang and lldb):

  curl -fsSL $SYSTEM_SETUP_BASE_URL/install_c.sh | bash

Guide: https://aikaryashala.com/system_setup/03_install_c/"
}

main "$@"
