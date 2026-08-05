#!/usr/bin/env bash
#
# install_cmds.sh - Step 2 of https://aikaryashala.com/system_setup
#
# The core command line tools: fetching a file, reaching another machine,
# editing text, and looking around the filesystem.
#
# This list is deliberately short. The wider set of everyday tools - search,
# archives, terminal multiplexing, JSON - lives in step 6 and is installed
# separately.
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
#
# There is deliberately no "is curl installed" test here. Either this file came
# from the website, in which case curl fetched it and is plainly present, or it
# came from a clone, in which case common.sh is sitting next to it and curl is
# never touched. What is worth checking is the thing that actually matters:
# whether common.sh really loaded.
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

    # A failed download, a 404 or a missing curl all end up the same way: an
    # empty file that sources cleanly and leaves every helper undefined. Catch
    # that here rather than 100 lines later with "require_linux: command not
    # found".
    #
    # `declare -F` asks specifically "is this a shell function?". `command -v`
    # would not do: several of these helper names also exist as real binaries -
    # `banner` ships with macOS and with Ubuntu's sysvbanner - so it can answer
    # yes about a program that has nothing to do with us.
    if ! declare -F apt_install >/dev/null 2>&1; then
        echo "Could not load common.sh from $SYSTEM_SETUP_BASE_URL" >&2
        echo "Check your network connection and try again." >&2
        exit 1
    fi
}
_bootstrap_common

# ---------------------------------------------------------------------------

# Fetching things, and reaching other machines.
PKGS_NETWORK=(
    ca-certificates     # the trusted certificate bundle, needed for https
    curl                # fetch a URL
    openssh-client      # ssh, scp, ssh-keygen
    iproute2            # ip addr, ip route
    iputils-ping        # ping
    dnsutils            # dig, nslookup
)

# Version control.
PKGS_SOURCE=(
    git
)

# Reading and editing files.
PKGS_EDIT=(
    nano                # the friendlier editor; a good default for git commits
    vim                 # the powerful one
    less                # page through long output
    file                # identify what a file actually is
    jq                  # read, filter and reshape JSON
)

# Looking around, and archives.
PKGS_SYSTEM=(
    tree                # show a directory as a tree
    htop                # interactive process viewer
    zip
    unzip
)

install_packages() {
    banner "Installing the core command line tools"
    apt_install "${PKGS_NETWORK[@]}"
    apt_install "${PKGS_SOURCE[@]}"
    apt_install "${PKGS_EDIT[@]}"
    apt_install "${PKGS_SYSTEM[@]}"
}

summary() {
    banner "Installed"
    verify "git"   git --version
    verify "curl"  curl --version
    verify "vim"   vim --version
    verify "tree"  tree --version
    verify "jq"    jq --version
    verify_present "nano"  nano
    verify_present "less"  less
    verify_present "file"  file
    verify_present "htop"  htop
    verify_present "ssh"   ssh
    verify_present "ip"    ip
    verify_present "ping"  ping
    verify_present "dig"   dig
    verify_present "zip"   zip
    verify_present "unzip" unzip
}

main() {
    require_linux
    require_apt
    require_sudo

    install_packages
    summary

    finish "Next step - the C toolchain (clang and lldb):

  curl -fsSL $SYSTEM_SETUP_BASE_URL/install_c.sh | bash

Guide: https://aikaryashala.com/system_setup/03_install_c/"
}

main "$@"
