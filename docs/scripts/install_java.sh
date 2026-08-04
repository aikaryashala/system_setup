#!/usr/bin/env bash
#
# install_java.sh - Step 5 of https://aikaryashala.com/system_setup
#
# A Temurin JDK (the OpenJDK build from Eclipse Adoptium): javac to compile,
# java to run, and jshell for trying an idea out without writing a file.
#
# Maven and Gradle are step 9, installed separately. You do not need a build
# tool to compile and run Java source files.
#
# Run inside Ubuntu:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/install_java.sh | bash
#
# Safe to run more than once.
#
# Optional environment variables:
#   JDK_VERSION=25        which Temurin LTS release to install

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

install_prerequisites() {
    banner "Checking prerequisites"
    apt_install ca-certificates curl gnupg
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

# Two files, because one class calling another is where javac stops being
# trivial: compiling Report.java pulls in Stats.java automatically.
write_samples() {
    banner "Writing two sample files to work with"

    local dest="${SAMPLE_DIR:-$HOME/java-samples}"
    mkdir -p "$dest"

    cat >"$dest/Stats.java" <<'EOF'
/* Stats.java - a small class for Report.java to use. */
public class Stats {

    /** The average. Returns 0 for an empty array. */
    public static double mean(int[] numbers) {
        if (numbers.length == 0) {
            return 0;
        }
        int total = 0;
        for (int n : numbers) {
            total += n;
        }
        return (double) total / numbers.length;
    }

    /** The largest value. */
    public static int max(int[] numbers) {
        int best = numbers[0];
        for (int n : numbers) {
            if (n > best) {
                best = n;
            }
        }
        return best;
    }

    /** The smallest value. */
    public static int min(int[] numbers) {
        int worst = numbers[0];
        for (int n : numbers) {
            if (n < worst) {
                worst = n;
            }
        }
        return worst;
    }

    /** How far apart the largest and smallest values are. */
    public static int spread(int[] numbers) {
        return max(numbers) - min(numbers);
    }
}
EOF

    cat >"$dest/Report.java" <<'EOF'
/* Report.java - the program that uses Stats.java.
 *
 *   javac Report.java          # javac finds and compiles Stats.java too
 *   java Report
 *   java Report 4 8 15 16 23 42
 */
public class Report {

    public static void main(String[] args) {
        int[] readings = parse(args);

        System.out.println("--- readings ---");
        System.out.printf("  count: %d%n", readings.length);
        System.out.printf("   mean: %.2f%n", Stats.mean(readings));
        System.out.printf("    max: %d%n", Stats.max(readings));
        System.out.printf("    min: %d%n", Stats.min(readings));
        System.out.printf(" spread: %d%n", Stats.spread(readings));
    }

    /** Use the numbers given on the command line, or a default set. */
    private static int[] parse(String[] args) {
        if (args.length == 0) {
            return new int[] {12, 7, 3, 21, 9, 15};
        }

        int[] numbers = new int[args.length];
        for (int i = 0; i < args.length; i++) {
            numbers[i] = Integer.parseInt(args[i]);
        }
        return numbers;
    }
}
EOF

    ok "$dest/Stats.java"
    ok "$dest/Report.java"
    SAMPLE_DEST="$dest"
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
        return 0
    fi

    # jshell runs a script file given as an argument. Use a real file rather
    # than stdin: this script's own stdin is already spoken for when curl-piped.
    # Note -q is a "feedback" option and jshell rejects more than one of those,
    # so do not add -s alongside it.
    cat >"$dir/check.jsh" <<'EOF'
int x = 21;
System.out.println("jshell says " + (x * 2));
/exit
EOF

    jshell -q "$dir/check.jsh" >"$dir/jshell_out" 2>&1 || true

    if grep -q "jshell says 42" "$dir/jshell_out"; then
        ok "jshell evaluated an expression"
    else
        warn "jshell did not produce the expected result. It printed:"
        head -n 5 "$dir/jshell_out" >&2
        VERIFY_FAILED=1
    fi
}

summary() {
    banner "Installed"
    verify "java"    java -version
    verify "javac"   javac -version
    verify_present "jshell" jshell
    verify_present "jar"    jar
    verify_present "javap"  javap
    printf '  %s%-14s%s %s\n' "$C_BOLD" "JAVA_HOME" "$C_RESET" "${JAVA_HOME:-not set}"
    printf '  %s%-14s%s %s\n' "$C_BOLD" "samples" "$C_RESET" "${SAMPLE_DEST:-not written}"
}

main() {
    require_linux
    require_apt
    require_sudo

    install_prerequisites
    add_adoptium_repo
    install_jdk
    configure_java_home
    write_samples
    smoke_test
    summary

    finish "Two sample files are waiting in ${SAMPLE_DEST:-~/java-samples}:

  cd ${SAMPLE_DEST:-~/java-samples}
  javac Report.java             # compiles Stats.java too, automatically
  java Report                   # run it
  java Report 4 8 15 16 23 42   # run it with your own numbers
  jshell                        # or try an idea with no file at all

That is the last step of the main sequence. Everything from
https://aikaryashala.com/system_setup steps 1 to 5 is now installed."
}

main "$@"
