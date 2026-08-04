#!/usr/bin/env bash
#
# install_uv.sh - Step 8 of https://aikaryashala.com/system_setup
#
# uv: package management, projects, and Python versions.
#
# uv is a single fast binary that replaces pip, venv, virtualenv, pyenv, pipx
# and poetry. It also downloads and manages Python interpreters of its own, so
# it never touches the system Python that Ubuntu itself depends on.
#
# This step is independent. Step 4 gives you python3 and pdb, which is all you
# need to run and debug a script. Come here when a script needs a library, or
# when you want a Python version other than the one Ubuntu ships.
#
# Run inside Ubuntu:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_uv.sh | bash
#
# Safe to run more than once.
#
# Optional environment variables:
#   PYTHON_VERSION=3.14   which Python uv should install
#   UV_TOOLS="ruff"       command line tools to install globally with uv

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

PYTHON_VERSION="${PYTHON_VERSION:-3.14}"
UV_TOOLS="${UV_TOOLS:-ruff}"

install_prerequisites() {
    banner "Checking prerequisites"
    apt_install ca-certificates curl
}

install_uv() {
    banner "Installing uv"

    if have uv; then
        skip "uv is already installed ($(uv --version))"
        log "Updating uv to the latest release"
        uv self update 2>/dev/null || warn "Could not self-update uv; keeping the installed version"
    else
        # The official installer places uv and uvx in ~/.local/bin. No sudo, and
        # nothing lands in system directories.
        curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh \
            || die "The uv installer failed. Check your network connection."
        ok "uv installed"
    fi

    # The installer writes to ~/.local/bin, which is not on PATH on a fresh
    # Ubuntu until that directory exists at login. Fix it for this shell and for
    # every future one.
    ensure_local_bin_on_path

    have uv || die "uv was installed but is not on PATH. Open a new terminal and re-run this script."

    # Shell completion for uv itself. Single quotes on purpose - these lines are
    # written verbatim into ~/.bashrc and evaluated there, not here.
    # shellcheck disable=SC2016
    add_to_rc "uv-completion" \
        'command -v uv >/dev/null 2>&1 && eval "$(uv generate-shell-completion bash)"' \
        'command -v uvx >/dev/null 2>&1 && eval "$(uvx --generate-shell-completion bash)"'
}

install_python() {
    banner "Installing Python $PYTHON_VERSION with uv"

    # uv downloads a standalone build; it does not touch /usr/bin/python3.
    if uv python install "$PYTHON_VERSION"; then
        ok "Python $PYTHON_VERSION installed"
    else
        warn "Could not install Python $PYTHON_VERSION - installing the latest version uv offers instead"
        uv python install || die "uv could not install any Python interpreter."
    fi

    log "Python interpreters uv now knows about:"
    uv python list --only-installed || true
}

install_tools() {
    [ -z "$UV_TOOLS" ] && return 0

    banner "Installing Python command line tools"
    # uv tool install is the replacement for pipx: each tool gets its own
    # isolated environment, and its executables are linked into ~/.local/bin.
    local tool
    for tool in $UV_TOOLS; do
        if uv tool install --quiet "$tool"; then
            ok "$tool"
        else
            warn "Could not install $tool"
        fi
    done
}

smoke_test() {
    banner "Checking that uv runs Python"

    local dir
    dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$dir'" RETURN

    cat >"$dir/check.py" <<'EOF'
import sys
print(f"uv-managed Python {sys.version.split()[0]} works")
EOF

    if uv run --python "$PYTHON_VERSION" --no-project "$dir/check.py" 2>"$dir/err"; then
        ok "uv run executed a script successfully"
    else
        warn "uv run failed:"
        cat "$dir/err" >&2
        VERIFY_FAILED=1
    fi
}

summary() {
    banner "Installed"
    verify "uv"     uv --version
    verify "uvx"    uvx --version
    verify_present "ruff" ruff
    printf '  %s%-14s%s %s\n' "$C_BOLD" "python" "$C_RESET" \
        "$(uv run --python "$PYTHON_VERSION" --no-project python -V 2>/dev/null || echo 'managed by uv')"
}

main() {
    require_linux
    require_apt
    require_sudo

    install_prerequisites
    install_uv
    install_python
    install_tools
    smoke_test
    summary

    finish "Start a project - no pip, no venv, no activate:

  uv init myproject          # create a project
  cd myproject
  uv add requests            # add a dependency
  uv run main.py             # run it, in the right environment automatically
  uv run python              # an interactive interpreter
  uvx ruff check .           # run a tool without installing it

Guide: https://aikaryashala.com/system_setup/08_install_uv/"
}

main "$@"
