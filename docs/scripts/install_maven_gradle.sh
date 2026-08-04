#!/usr/bin/env bash
#
# install_maven_gradle.sh - Step 9 of https://aikaryashala.com/system_setup
#
# Maven and Gradle: the two build tools you will meet in real Java projects.
#
# This step is independent. Step 5 gives you javac, java and jshell, which is
# all you need to compile and run source files. Come here when a project has a
# pom.xml or a build.gradle, or when you need to pull in a library.
#
# It does need a JDK. Install step 5 first if you have not:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_java.sh | bash
#
# Run inside Ubuntu:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_maven_gradle.sh | bash
#
# Safe to run more than once.
#
# Optional environment variables:
#   SKIP_MAVEN=1          do not install Maven
#   SKIP_GRADLE=1         do not install Gradle

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

GRADLE_ROOT="/opt/gradle"

install_prerequisites() {
    banner "Checking prerequisites"
    apt_install ca-certificates curl unzip

    if ! have javac; then
        warn "No JDK found. Maven and Gradle both need one to do anything useful."
        warn "Install step 5 first:"
        warn "  curl -fsSL $SYSTEM_SETUP_BASE_URL/install_java.sh | bash"
    fi
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
    elif [ -n "$meta" ]; then
        # jq lives in step 6, which is optional - fall back to plain text
        # matching so this script does not depend on it.
        version="$(printf '%s' "$meta" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
        url="$(printf '%s' "$meta" | sed -n 's/.*"downloadUrl"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
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

summary() {
    banner "Installed"
    [ "${SKIP_MAVEN:-0}" = "1" ]  || verify "maven"  mvn -version
    [ "${SKIP_GRADLE:-0}" = "1" ] || verify "gradle" gradle --version
    printf '  %s%-14s%s %s\n' "$C_BOLD" "JAVA_HOME" "$C_RESET" "${JAVA_HOME:-not set}"
}

main() {
    require_linux
    require_apt
    require_sudo

    install_prerequisites
    install_maven
    install_gradle
    summary

    finish "Start a project:

  mvn archetype:generate \\
      -DgroupId=com.example -DartifactId=myapp \\
      -DarchetypeArtifactId=maven-archetype-quickstart -DinteractiveMode=false

  gradle init --type java-application

Then build with 'mvn package' or './gradlew build'.

Guide: https://aikaryashala.com/system_setup/09_install_maven_gradle/"
}

main "$@"
