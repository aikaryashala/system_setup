#!/usr/bin/env bash
#
# report_completion.sh - Step 5.5 of https://aikaryashala.com/system_setup
#
# Checks that everything from steps 2 to 5 is installed AND actually works, then
# reports the result.
#
# It does not merely look for the commands. It compiles and runs a C program,
# runs a Python script under pdb, compiles and runs a Java program, and asks
# jshell to evaluate an expression - the same tests each installer runs. A
# command that exists but cannot do its job is reported as a failure.
#
# Run inside Ubuntu, after finishing step 5:
#   curl -fsSL https://aikaryashala.com/system_setup/scripts/report_completion.sh | bash
#
# Safe to run more than once. Nothing is installed or changed.
#
# Optional environment variables (useful for testing - skips the prompts):
#   STUDENT_NAME="Your Name"
#   ROLL_NUMBER="24CS042"
#   DRY_RUN=1                 check everything, print the result, send nothing

# NOTE: deliberately NOT `set -e`. Every other script here stops at the first
# failure; this one has to keep going and collect them, because reporting *what*
# is broken is the entire point.
# shellcheck source-path=SCRIPTDIR
set -uo pipefail

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
# Where the report goes. The hash identifies this assignment.

FORM_URL="https://docs.google.com/forms/d/e/1FAIpQLSe3Oh_J5I_S7P_3SDR-j3CyynLfI1NzyEhNM3-foLWZaXdG3Q/formResponse"
HASH="AIKSUBMIT"

ENTRY_NAME="entry.593511266"
ENTRY_ROLL="entry.1983325759"
ENTRY_STATUS="entry.596716444"
ENTRY_HASH="entry.242912875"

# Collected as the checks run, and turned into the reported status at the end.
FAILURES=()

fail_check() {
    warn "$1"
    FAILURES+=("$2")
}

# A scratch directory for the compile-and-run tests.
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Step 2 - the core commands

check_step2() {
    banner "Step 2 - core command line tools"

    local cmd missing=()
    for cmd in curl ssh ip ping dig git nano vim less file jq tree zip unzip htop; do
        if have "$cmd"; then
            ok "$cmd"
        else
            warn "$cmd is missing"
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        FAILURES+=("step2 missing: ${missing[*]}")
        return 0
    fi

    # jq exists - but does it work? This is the check step 2 teaches.
    printf '{"name":"test","roll_number":"1"}\n' >"$WORK/student.json"
    if jq . "$WORK/student.json" >/dev/null 2>&1; then
        ok "jq validated a JSON file"
    else
        fail_check "jq could not read a valid JSON file" "step2 jq broken"
    fi
}

# ---------------------------------------------------------------------------
# Step 3 - clang and lldb

check_step3() {
    banner "Step 3 - clang and lldb"

    if ! have clang; then
        fail_check "clang is missing" "step3 clang missing"
        return 0
    fi
    ok "clang"

    cat >"$WORK/hello.c" <<'EOF'
#include <stdio.h>

int main(void)
{
    printf("c works\n");
    return 0;
}
EOF

    if ! clang -g "$WORK/hello.c" -o "$WORK/hello" 2>"$WORK/cc_err"; then
        fail_check "clang could not compile a program" "step3 clang cannot compile"
        head -n 3 "$WORK/cc_err" >&2
        return 0
    fi
    ok "clang compiled a program"

    if [ "$("$WORK/hello" 2>/dev/null)" = "c works" ]; then
        ok "the compiled program ran"
    else
        fail_check "the compiled program did not run correctly" "step3 compiled program fails"
    fi

    if ! have lldb; then
        fail_check "lldb is missing" "step3 lldb missing"
        return 0
    fi
    ok "lldb"

    lldb --batch -o "breakpoint set --name main" -o run -o quit "$WORK/hello" \
        >"$WORK/lldb_out" 2>&1

    if grep -q "stop reason = breakpoint" "$WORK/lldb_out"; then
        ok "lldb stopped at a breakpoint"
    elif grep -qE "personality set failed|ptrace|Operation not permitted" "$WORK/lldb_out"; then
        # No ptrace permission. Normal inside a container, and not the student's
        # fault - do not report it as a failure.
        skip "lldb cannot debug in this environment (no ptrace permission)"
    else
        fail_check "lldb did not stop at a breakpoint" "step3 lldb cannot debug"
    fi
}

# ---------------------------------------------------------------------------
# Step 4 - python3 and pdb

check_step4() {
    banner "Step 4 - Python and pdb"

    if ! have python3; then
        fail_check "python3 is missing" "step4 python3 missing"
        return 0
    fi
    ok "python3"

    cat >"$WORK/check.py" <<'EOF'
total = 0
for n in range(1, 5):
    total += n

print(f"python works total={total}")
EOF

    if python3 "$WORK/check.py" 2>/dev/null | grep -q "total=10"; then
        ok "python3 ran a script"
    else
        fail_check "python3 could not run a script" "step4 python3 cannot run"
        return 0
    fi

    python3 -m pdb -c "break 5" -c continue -c "print(f'PDBTOTAL={total}')" -c quit \
        "$WORK/check.py" >"$WORK/pdb_out" 2>&1

    if grep -q "PDBTOTAL=10" "$WORK/pdb_out"; then
        ok "pdb stopped at a breakpoint and read the program's state"
    else
        fail_check "pdb did not stop at a breakpoint" "step4 pdb not working"
    fi
}

# ---------------------------------------------------------------------------
# Step 5 - javac, java and jshell

check_step5() {
    banner "Step 5 - Java"

    if ! have javac || ! have java; then
        fail_check "javac or java is missing" "step5 jdk missing"
        return 0
    fi
    ok "javac and java"

    cat >"$WORK/Check.java" <<'EOF'
public class Check {
    public static void main(String[] args) {
        System.out.println("java works");
    }
}
EOF

    if ! (cd "$WORK" && javac Check.java 2>"$WORK/javac_err"); then
        fail_check "javac could not compile a program" "step5 javac cannot compile"
        head -n 3 "$WORK/javac_err" >&2
        return 0
    fi
    ok "javac compiled a program"

    if (cd "$WORK" && java Check 2>/dev/null) | grep -q "java works"; then
        ok "java ran the compiled program"
    else
        fail_check "java could not run the compiled program" "step5 java cannot run"
    fi

    if ! have jshell; then
        fail_check "jshell is missing" "step5 jshell missing"
        return 0
    fi

    cat >"$WORK/check.jsh" <<'EOF'
int x = 21;
System.out.println("jshell says " + (x * 2));
/exit
EOF

    jshell -q "$WORK/check.jsh" >"$WORK/jshell_out" 2>&1

    if grep -q "jshell says 42" "$WORK/jshell_out"; then
        ok "jshell evaluated an expression"
    else
        fail_check "jshell did not evaluate an expression" "step5 jshell not working"
    fi
}

# ---------------------------------------------------------------------------
# Who is reporting

ask_details() {
    banner "Your details"

    # `read` cannot use stdin here: when this script is piped from curl, stdin
    # is the script itself. Read from the terminal directly instead.
    if [ -z "${STUDENT_NAME:-}" ] || [ -z "${ROLL_NUMBER:-}" ]; then
        if [ ! -r /dev/tty ]; then
            die "No terminal to ask for your name. Run it like this instead:
  STUDENT_NAME=\"Your Name\" ROLL_NUMBER=\"24CS042\" bash report_completion.sh"
        fi
    fi

    while [ -z "${STUDENT_NAME:-}" ]; do
        printf 'Student Name : '
        read -r STUDENT_NAME </dev/tty
    done

    while [ -z "${ROLL_NUMBER:-}" ]; do
        printf 'Roll Number  : '
        read -r ROLL_NUMBER </dev/tty
    done
}

# ---------------------------------------------------------------------------
# Build the status line and send it

build_status() {
    if [ ${#FAILURES[@]} -eq 0 ]; then
        STATUS="Completed"
        return 0
    fi

    # Report what is actually broken, not just that something is. Joined with
    # commas and kept short enough to sit comfortably in a form field.
    local joined
    joined="$(printf '%s, ' "${FAILURES[@]}")"
    joined="${joined%, }"

    if [ ${#joined} -gt 300 ]; then
        joined="${joined:0:297}..."
    fi

    STATUS="Failed: $joined"
}

send_report() {
    banner "Reporting"

    printf '  %s%-14s%s %s\n' "$C_BOLD" "Name"   "$C_RESET" "$STUDENT_NAME"
    printf '  %s%-14s%s %s\n' "$C_BOLD" "Roll"   "$C_RESET" "$ROLL_NUMBER"
    printf '  %s%-14s%s %s\n' "$C_BOLD" "Status" "$C_RESET" "$STATUS"
    printf '\n'

    if [ "${DRY_RUN:-0}" = "1" ]; then
        skip "DRY_RUN is set - nothing was sent."
        return 0
    fi

    local http_code
    http_code="$(curl -s -L \
        -o /dev/null \
        -w "%{http_code}" \
        --data-urlencode "$ENTRY_NAME=$STUDENT_NAME" \
        --data-urlencode "$ENTRY_ROLL=$ROLL_NUMBER" \
        --data-urlencode "$ENTRY_STATUS=$STATUS" \
        --data-urlencode "$ENTRY_HASH=$HASH" \
        "$FORM_URL")"

    if [ "$http_code" = "200" ]; then
        ok "Reported successfully."
    else
        printf '%sfail%s Could not report (HTTP %s).\n' "$C_RED" "$C_RESET" "$http_code" >&2
        printf 'Check your network connection and run this again.\n' >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------

main() {
    require_linux

    banner "system_setup - checking your setup"
    printf 'This runs the same tests each installer runs. Nothing is installed.\n'

    check_step2
    check_step3
    check_step4
    check_step5

    build_status

    banner "Result"
    if [ ${#FAILURES[@]} -eq 0 ]; then
        printf '%sEverything works.%s\n' "$C_GREEN" "$C_RESET"
    else
        printf '%s%d thing(s) are not working:%s\n' "$C_YELLOW" "${#FAILURES[@]}" "$C_RESET"
        printf '  - %s\n' "${FAILURES[@]}"
        printf '\nThis will still be reported, so your teacher can see what to help with.\n'
        printf 'Re-run the step that failed, then run this again.\n'
    fi

    ask_details
    send_report
}

main "$@"
