# CLAUDE.md

Guidance for working in this repository.

## What this project is

A set of installer scripts plus a static website that walks a beginner from a
fresh Windows machine to a working Ubuntu/WSL2 development environment with C,
Python, and Java toolchains.

The website is published by GitHub Pages from the `docs/` directory on `main` and
served at **https://aikaryashala.com/system_setup**. There is no build step: the
files in `docs/` are byte-for-byte what visitors receive.

`docs/scripts/` is both the source directory for the scripts *and* their
public download location. A script committed there is immediately live at
`https://aikaryashala.com/system_setup/scripts/<name>`. Never move the
scripts outside `docs/` — that would break every published `curl` one-liner.

## Layout and ordering

The numbered directories under `docs/` are the install order *and* the URL
structure. They must stay aligned:

```
01_install_ubuntu   →  install_ubuntu_wsl.ps1
02_install_cmds     →  install_cmds.sh
03_install_c        →  install_c.sh
04_install_py       →  install_py.sh
05_install_java     →  install_java.sh
```

Adding a step means adding all three: the numbered page directory, the script in
`scripts/`, a card on `docs/index.html`, and a row in the README table.
Renumbering is disruptive — it changes public URLs — so append rather than insert
unless there is a real reason.

## Non-negotiable conventions

### Python: `uv`, never anything else

`uv` is the only Python package and interpreter manager used in this project.
This applies to scripts, website examples, documentation, and any code written
here. Do not introduce, suggest, or write examples using `pip`, `pip3`,
`virtualenv`, `python -m venv`, `pyenv`, `pipx`, `poetry`, `pipenv`, or `conda` —
including "you could also…" asides.

| Instead of | Use |
| --- | --- |
| `python3 -m venv .venv` | `uv venv` |
| `pip install X` | `uv add X` |
| `pip install -r requirements.txt` | `uv sync` |
| `pipx install X` / `pipx run X` | `uv tool install X` / `uvx X` |
| `pyenv install 3.14` | `uv python install 3.14` |
| `python script.py` | `uv run script.py` |

`uv pip` exists as a compatibility shim; use it only when demonstrating migration
from a legacy project, and say so explicitly.

### C: `clang` and `lldb`

Compile with `clang`, debug with `lldb`. Do not write `gcc` or `gdb` into
examples. LLDB command syntax differs from GDB's — use `b`, `r`, `n`, `s`, `p`,
`frame variable`, `memory read`, not GDB spellings.

Binary/hex inspection is a first-class topic, not a footnote: `xxd`, `hexdump
-C`, `od -A x -t x1z`, `hexyl`, `strings`, `nm`, `objdump -d`, `readelf -h`,
`size`, `file`.

### Java

Temurin JDK from the Adoptium APT repository. Prefer `jshell` for short examples
so readers do not need a build file to try something.

### Website

- No external requests of any kind: no CDN scripts, no Google Fonts, no remote
  images, no analytics. Everything ships from `docs/assets/`.
- Shared styling lives in `docs/assets/style.css`; shared behaviour in
  `docs/assets/site.js`. Do not inline per-page `<style>` or `<script>` blocks
  when the rule belongs in the shared file. The one deliberate exception is the
  three-line theme snippet in each `<head>`: it has to run before first paint,
  so it cannot live in the deferred shared script. Keep it identical on every
  page.
- Every page must work in both light and dark mode
  (`prefers-color-scheme`) and read cleanly on a phone.
- Asset and page links use paths relative to the page (`../assets/style.css`),
  not absolute paths — absolute paths break local `python3 -m http.server`
  previews and any fork served from a different base path.
- Every runnable command gets a copy button, which `site.js` attaches
  automatically to `<pre>` blocks. Just write the `<pre><code>`.

## Script contract

Every `.sh` file in `docs/scripts/` must:

1. Start with `#!/usr/bin/env bash` and `set -euo pipefail`.
2. Be **idempotent** — re-running is a no-op, not a reinstall or a duplicated
   line in `~/.bashrc`. Guard `.bashrc` edits with a marker-string grep.
3. Be **non-interactive** — no prompts. Use `DEBIAN_FRONTEND=noninteractive` and
   `apt-get install -y`. If a value is needed, take it from an environment
   variable with a sensible default.
4. Work **both** ways: executed as a local file and piped via
   `curl … | bash`. That means never assuming `$0` is a real path, and never
   reading from stdin (a piped script has already consumed it — read from
   `/dev/tty` if you truly must prompt, but prefer not to).
5. Source `common.sh` through the standard bootstrap block used by the existing
   scripts, which finds it next to the script or fetches it from
   `$SYSTEM_SETUP_BASE_URL`.
6. End by calling the verification helpers so the user sees versions of what was
   just installed.
7. Pass `shellcheck` cleanly. CI runs it on every push.

Shared helpers live in `common.sh` (`log`, `warn`, `die`, `have`,
`apt_install`, `require_sudo`, `verify`, …). Add to it rather than redefining
helpers per script.

## Testing

There is no test suite. Before committing:

```bash
shellcheck -x docs/scripts/*.sh tools/*.sh
./tools/check_links.sh docs                    # every relative href resolves
python3 -m http.server 8000 --directory docs   # then click through every page
```

CI (`.github/workflows/shellcheck.yml`) runs all three, plus PSScriptAnalyzer on
the PowerShell installer.

The scripts target Ubuntu and cannot be executed on macOS. When changing a
script from a Mac, verify it by reading and by `shellcheck`; do not claim it was
run.

For a real end-to-end run, use a container. Two things matter for the test to
mean anything:

- **Run as an unprivileged account with sudo, not as root.** As root the
  `require_sudo` path, every `$SUDO` expansion, and the `~/.local/bin` PATH
  handling all take a different branch than a real user hits.
- **Run it twice.** Idempotency is a promise this project makes, and the second
  pass is the only thing that checks it. Pass 2 should report `skip` almost
  everywhere, and `~/.bashrc` must still contain exactly one of each
  `# system_setup:<marker>` line.

```bash
docker run --rm -v "$PWD/docs/scripts:/scripts:ro" ubuntu:24.04 bash -c '
  apt-get update -qq >/dev/null && apt-get install -y -qq sudo curl ca-certificates >/dev/null
  useradd -m -s /bin/bash student
  echo "student ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/student
  cp -r /scripts /home/student/s && chown -R student:student /home/student
  su - student -c "cd ~/s && bash install_all.sh && bash install_all.sh"'
```

Note that a Mac runs this on arm64 while the real audience is on x86_64 WSL.
That covers script logic but not architecture-specific package availability; add
`--platform linux/amd64` when a change touches an APT repository or a downloaded
binary.

Build test files with heredocs (`cat > t.c <<'EOF'`), never with nested `printf`
and escaped quotes — the escaping breaks in a way that looks like a toolchain
failure and wastes a debugging cycle.

## Tone of the website copy

The audience is a beginner who may never have opened a terminal. Explain what a
command does before showing it, prefer whole words to jargon on first use, and
keep every code block copy-paste-ready with no placeholders to fill in — unless
the placeholder is the point, in which case make it obviously a placeholder.
