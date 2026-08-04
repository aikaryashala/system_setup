#!/usr/bin/env bash
#
# install_java.sh - Step 5 of https://aikaryashala.com/system_setup
#
# Installs a Temurin JDK (the OpenJDK build from Eclipse Adoptium), plus Maven
# and Gradle for building larger projects.
#
# The JDK gives you javac (compiler), java (runtime), jshell (an interactive
# Java prompt, ideal for trying things out) and jar (packaging).
#
# Run inside Ubuntu:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_java.sh | bash
#
# Safe to run more than once.
#
# Optional environment variables:
#   JDK_VERSION=25        which Temurin LTS release to install
#   SKIP_GRADLE=1         do not install Gradle
#   SKIP_MAVEN=1          do not install Maven

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

JDK_VERSION="${JDK_VERSION:-25}"        # current long term support release
JDK_FALLBACK_VERSION="21"               # previous LTS, available everywhere
ADOPTIUM_KEYRING="/etc/apt/keyrings/adoptium.gpg"
ADOPTIUM_LIST="/etc/apt/sources.list.d/adoptium.list"
GRADLE_ROOT="/opt/gradle"

install_prerequisites() {
    banner "Checking prerequisites"
    apt_install ca-certificates curl gnupg unzip
}

# Adoptium publishes a Debian repository. Ubuntu's own openjdk packages lag
# behind and do not offer every LTS, so we prefer this source.
add_adoptium_repo() {
    banner "Adding the Eclipse Adoptium package repository"

    local codename
    # shellcheck disable=SC1091  # /etc/os-release only exists on the target system
    codename="$( (. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") 2>/dev/null || true)"
    [ -n "$codename" ] || die "Could not determine the Ubuntu release codename."

    if [ -f "$ADOPTIUM_KEYRING" ] && [ -f "$ADOPTIUM_LIST" ]; then
        skip "the Adoptium repository is already configured"
        return 0
    fi

    $SUDO install -d -m 0755 /etc/apt/keyrings

    curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
        | gpg --dearmor \
        | $SUDO tee "$ADOPTIUM_KEYRING" >/dev/null \
        || die "Could not download the Adoptium signing key."
    $SUDO chmod 0644 "$ADOPTIUM_KEYRING"
    ok "signing key installed"

    printf 'deb [signed-by=%s] https://packages.adoptium.net/artifactory/deb %s main\n' \
        "$ADOPTIUM_KEYRING" "$codename" \
        | $SUDO tee "$ADOPTIUM_LIST" >/dev/null
    ok "repository added for $codename"

    APT_UPDATED=0   # the new source has to be picked up
}

install_jdk() {
    banner "Installing the JDK"

    if apt_install_quiet "temurin-${JDK_VERSION}-jdk"; then
        ok "Temurin JDK $JDK_VERSION"
        return 0
    fi

    warn "Temurin $JDK_VERSION is not available here - trying Temurin $JDK_FALLBACK_VERSION"
    if apt_install_quiet "temurin-${JDK_FALLBACK_VERSION}-jdk"; then
        ok "Temurin JDK $JDK_FALLBACK_VERSION"
        return 0
    fi

    warn "Falling back to Ubuntu's own OpenJDK packages"
    apt_install "openjdk-${JDK_FALLBACK_VERSION}-jdk" \
        || die "No JDK could be installed."
}

# Like apt_install, but returns non-zero instead of exiting so the caller can
# fall back to another package.
apt_install_quiet() {
    local pkg="$1"
    if pkg_installed "$pkg"; then
        skip "$pkg is already installed"
        return 0
    fi
    apt_update
    $SUDO apt-get install -y -qq --no-install-recommends "$pkg" >/dev/null 2>&1
}

configure_java_home() {
    banner "Setting JAVA_HOME"

    have javac || die "javac is not on PATH after installing the JDK."

    local java_home
    java_home="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
    [ -x "$java_home/bin/java" ] || die "Could not work out JAVA_HOME from $java_home"

    export JAVA_HOME="$java_home"
    # JAVA_HOME is expanded now, PATH deliberately is not - it has to be
    # evaluated by the shell that reads ~/.bashrc.
    # shellcheck disable=SC2016
    add_to_rc "java-home" \
        "export JAVA_HOME=\"$java_home\"" \
        'export PATH="$JAVA_HOME/bin:$PATH"'
    ok "JAVA_HOME=$java_home"
}

install_maven() {
    [ "${SKIP_MAVEN:-0}" = "1" ] && return 0
    banner "Installing Maven"
    apt_install maven
}

install_gradle() {
    [ "${SKIP_GRADLE:-0}" = "1" ] && return 0
    banner "Installing Gradle"

    # Ubuntu's gradle package is usually several major versions behind, so take
    # the current release straight from Gradle. Their version endpoint tells us
    # what that is, which avoids hard-coding a version that will go stale.
    local meta version url
    meta="$(curl -fsSL https://services.gradle.org/versions/current 2>/dev/null || true)"

    if [ -n "$meta" ] && have jq; then
        version="$(printf '%s' "$meta" | jq -r '.version // empty')"
        url="$(printf '%s' "$meta" | jq -r '.downloadUrl // empty')"
    fi

    if [ -z "${version:-}" ] || [ -z "${url:-}" ]; then
        warn "Could not reach services.gradle.org - installing Ubuntu's gradle package instead"
        apt_install_optional gradle
        return 0
    fi

    if [ -d "$GRADLE_ROOT/gradle-$version" ]; then
        skip "Gradle $version is already installed"
    else
        local tmp
        tmp="$(mktemp -d)"
        # shellcheck disable=SC2064
        trap "rm -rf '$tmp'" RETURN

        log "Downloading Gradle $version"
        curl -fsSL -o "$tmp/gradle.zip" "$url" || die "Could not download Gradle from $url"

        $SUDO install -d -m 0755 "$GRADLE_ROOT"
        $SUDO unzip -q -o "$tmp/gradle.zip" -d "$GRADLE_ROOT" || die "Could not unpack Gradle."
        ok "Gradle $version unpacked into $GRADLE_ROOT/gradle-$version"
    fi

    # A stable symlink means upgrading Gradle later does not require touching
    # anyone's PATH.
    $SUDO ln -sfn "$GRADLE_ROOT/gradle-$version" "$GRADLE_ROOT/current"
    $SUDO ln -sfn "$GRADLE_ROOT/current/bin/gradle" /usr/local/bin/gradle
    ok "gradle is on PATH via /usr/local/bin/gradle"
}

smoke_test() {
    banner "Compiling and running a test program"

    local dir
    dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$dir'" RETURN

    cat >"$dir/Check.java" <<'EOF'
public class Check {
    public static void main(String[] args) {
        System.out.println("java works: " + System.getProperty("java.version"));
    }
}
EOF

    if (cd "$dir" && javac Check.java 2>"$dir/err" && java Check); then
        ok "javac compiled and java ran the result"
    else
        warn "Java could not compile and run a test program:"
        cat "$dir/err" >&2
        VERIFY_FAILED=1
    fi
}

summary() {
    banner "Installed"
    verify "java"    java -version
    verify "javac"   javac -version
    verify "maven"   mvn -version
    verify "gradle"  gradle --version
    verify_present "jshell" jshell
    verify_present "jar"    jar
    printf '  %s%-14s%s %s\n' "$C_BOLD" "JAVA_HOME" "$C_RESET" "${JAVA_HOME:-not set}"
}

main() {
    require_linux
    require_apt
    require_sudo

    install_prerequisites
    add_adoptium_repo
    install_jdk
    configure_java_home
    install_maven
    install_gradle
    smoke_test
    summary

    finish "Try it out:

  jshell                                  # an interactive Java prompt
  javac Hello.java && java Hello          # compile and run a single file
  java Hello.java                         # or run the source directly
  mvn archetype:generate                  # start a Maven project
  gradle init                             # start a Gradle project

That was the last step. Everything from https://aikaryashala.com/system_setup is
now installed."
}

main "$@"
