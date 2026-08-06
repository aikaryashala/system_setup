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
main sequence, runs in order
  01_install_ubuntu   →  install_ubuntu_wsl.ps1
  01_5_navigate       →  (no script - practice page only)
  02_install_cmds     →  install_cmds.sh
  03_install_c        →  install_c.sh
  04_install_py       →  install_py.sh
  05_install_java     →  install_java.sh
  05_5_report         →  report_completion.sh

independent extras
  06_install_more_cmds  →  install_more_cmds.sh
  07_install_binary     →  install_binary.sh
  08_install_uv         →  install_uv.sh
  09_install_maven_gradle → install_maven_gradle.sh
  10_jq_practice        →  (no script - practice page only)
  11_clang_options      →  install_sanitizers.sh
  12_python_debugging   →  install_py_debug.sh
```

Not every step installs something. Step 10 is a practice page for a tool step 2
already installed, so it has no script and its directory is named for its topic
rather than `NN_install_*`. That is fine; keep the numbering, drop the `install_`
prefix when a step installs nothing.

Adding a step means adding all three: the numbered page directory, the script in
`scripts/`, a card on `docs/index.html`, and a row in the README table.
Renumbering is disruptive — it changes public URLs — so append rather than insert
unless there is a real reason.

### Steps 6 to 12 are independent — keep them that way

They exist so the main sequence stays short. Two rules follow, and both are easy
to break by accident:

- **No script in the main sequence may link to steps 6 to 12.** The `finish`
  message of `install_cmds.sh` points at step 3, `install_c.sh` at step 4,
  `install_py.sh` at step 5, and `install_java.sh` ends the sequence. Do not add
  "and then install the extras" to any of them.
- **`install_all.sh` must not run them by default.** Its `STEPS` default stays
  `cmds c py java`. The extras are reachable by name
  (`STEPS="more_cmds binary uv maven_gradle"`) for people who want them.

Linking to them **from the website UI is fine and expected** — the landing page
carries cards for both, and step 2 and step 3 each point at where their moved
tools went. The restriction is about the scripted install chain, not navigation.

### What belongs where

- **Step 1.5** teaches the filesystem: `pwd cd ls mkdir touch cp mv rm rmdir
  cat head less`, plus `.` `..` `~` `/` and Tab completion. These ship with
  Ubuntu, so there is nothing to install and no script. It exists because every
  step from 3 onwards says things like "create hello.c" and assumes a student
  can. Do not use `nano` here — it only arrives in step 2, so this page uses
  `touch` and `echo >` instead.
- **Step 2** is the irreducible set: `curl ssh ip ping dig git nano vim less
  file jq tree zip unzip htop`. Anything else that is a general-purpose command
  belongs in step 6. `jq` is here, but **only** as a JSON validity check
  (`jq . file.json` — output means valid, an error means broken). Anything
  beyond that — field access, `select`, `add`, reshaping — belongs in step 10.
- **Step 3** is the compile/debug loop only, and exactly one compile line:
  `clang -g hello.c -o hello`. Do not add `-Wall`, `-Wextra`, `-O0` or
  `-fsanitize=address` to step 3 — those are step 11. A tool that operates on
  the *output* of compiling — hex viewers, `objdump`, `valgrind`, `strace`,
  `make` — belongs in step 7.
- **Step 4** is `python3` alone — writing a program and running it. Debugging
  with `pdb` is step 12; packages, environments and extra interpreter versions
  are step 8.
- **Step 5** is `javac`, `java` and `jshell` — compiling and running source
  files. Build tools (Maven, Gradle) are step 9.

Step 5 and step 12 each ship **two sample files** that the installer writes to
the user's home directory, because the interesting debugging skill is following
execution from one file into another. Steps 3 and 4 ship one file each, the same
`sum` program in two languages, so they can be compared directly. Keep the copy
in the script and the copy in `docs/examples/` identical.

Note that `binutils` arrives as a dependency of `clang`, so `objdump`, `nm` and
`readelf` exist after step 3 even though step 7 is what documents them. That is
unavoidable — do not try to work around it.

## Non-negotiable conventions

### Python: system `python3` for running, `uv` for everything else

Step 4 uses Ubuntu's `python3` deliberately — running and debugging a script
needs no package manager, and pdb is in the standard library.

The moment packages, environments or interpreter versions enter the picture, it
is `uv` and only `uv` (step 8). Do not introduce, suggest, or write examples
using `pip`, `pip3`, `virtualenv`, `python -m venv`, `pyenv`, `pipx`, `poetry`,
`pipenv`, or `conda` — including "you could also…" asides. Never install
packages into the system `python3`; modern Ubuntu refuses anyway.

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

### Ubuntu version is pinned

Step 1 installs `Ubuntu-24.04` by name, never the bare `Ubuntu` alias — that
alias tracks whatever Microsoft makes default and drifts over time.

It installs nothing at all when *any* `Ubuntu*` distribution is already present:
a second multi-hundred-megabyte download is not worth leaving someone with two
systems to keep straight. It warns that the guides target 24.04 and prints the
command to add it manually. Whichever Ubuntu ends up in use is then set as the
WSL default. Everything
else here is written and tested against 24.04 LTS. If the pin is ever moved,
re-test every step: package names differ between releases (this project has
already been bitten by `xxd`/`vim-common` and `bsdextrautils`/`bsdmainutils`).

### Java

Temurin JDK from the Adoptium APT repository. Prefer `jshell` for short examples
so readers do not need a build file to try something.

### Website

- No external requests of any kind: no CDN scripts, no Google Fonts, no remote
  images, no analytics. Everything ships from `docs/assets/`.
- **Videos are plain links**, opened with `target="_blank" rel="noopener"`.
  Never an `<iframe>`, and never a click-to-load placeholder either — both were
  tried and removed as more machinery than the job needs. A link keeps the
  no-external-requests rule absolute, with nothing to maintain.
- Diagrams are inline SVG using the `.dg-*` classes in `style.css`, so they
  follow the theme without a second dark-mode copy. Do not add image files for
  diagrams.
- **`docs/assets/aiklogo.png` is the one image on the site** — the AIKaryashala
  mark, at the head of every page of the book, inside `<p class="book-logo">`
  above the breadcrumb. It is the brand file copied in byte-for-byte: do not
  crop, recolour or re-export it. Its transparent background is what lets one
  copy serve both themes, so it must stay a PNG with an alpha channel.
- **Every SVG shape also carries a plain `fill` (and `stroke`) attribute.**
  Presentation attributes lose to any CSS rule, so the stylesheet still themes
  the diagram — but if it is missing, stale in a cache, or the SVG is viewed on
  its own, the shapes stay readable. Without them an unstyled `<rect>` or
  `<circle>` renders solid black, which is how this was found. Test by pointing
  the page at an empty stylesheet before shipping a new diagram.
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

1. Start with `#!/usr/bin/env bash` and `set -euo pipefail`. The one exception is
   `report_completion.sh`, which uses `set -uo pipefail`: it has to survive a
   failing check in order to report it, which is the whole point of that script.
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
./tools/check_links.sh docs                    # links resolve AND nav labels match
python3 -m http.server 8000 --directory docs   # then click through every page
```

CI runs all three in `.github/workflows/lint.yml`, plus PSScriptAnalyzer on the
PowerShell installer.

`check_links.sh` does three things. The second and third are the ones worth
knowing about.

It compares every `page-nav` label against the `<h1>` of the page it points at,
and fails when the label contains a word the heading has nothing to do with.
Renaming a page silently leaves its inbound labels describing something that no
longer exists — plain link checking cannot see that, because the URL still works.

It also checks every `.toc` block **in both directions**: no entry may point at a
section that is not there, and no section may be left out of the list. The second
half is the one that matters. A contents list that is missing sections looks
perfectly fine — every link works — it has just quietly stopped describing the
page. That is what happens when a list is written by hand and the page grows
afterwards.

The rule is a subset, not an overlap: **every** meaningful word in the label must
appear in the target heading. Overlap is too weak — "Python with uv" and
"Python 3, and tracing it with pdb" share "python", which is precisely the stale
label the check exists to find.

When a label is deliberately descriptive rather than a restatement of the
heading, opt it out instead of distorting the wording:

```html
<a class="next" data-nav-label="free" href="../05_install_java/">
```

**Deployment is separate on purpose.** `.github/workflows/pages.yml` publishes
`docs/` and does not depend on lint — a style warning must never be able to stop
the website going live. Do not merge the two workflows, and do not add a
`needs: lint` to the deploy job.

PSScriptAnalyzer runs against `.github/PSScriptAnalyzerSettings.psd1`. The
excluded rules are module-oriented ones that are wrong for a console installer
(`PSAvoidUsingWriteHost` above all — printing to the console is the script's
whole purpose). Do not lint the `.ps1` with bare `-Severity Error,Warning`: it
fails on every `Write-Host` and can never pass.

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

## report_completion.sh

Step 5.5 reports a student's progress to a Google Form. Three things about it
are load-bearing:

- **It reads from `/dev/tty`, never stdin.** The documented way to run it is
  `curl … | bash`, where stdin is the script itself — a plain `read` would
  swallow script text instead of waiting for the student.
- **It tests by doing, not by looking.** `command -v clang` proves nothing; the
  script compiles and runs a program. A tool that exists but cannot work is a
  failure, and gets named in the report.
- **It reports failures too**, with what broke, so a teacher can see where a
  student is stuck. Never change it to only submit on success.

`DRY_RUN=1` runs every check and sends nothing. Use it for any testing — do not
submit test rows to the live form.

## The book (`docs/book/`)

Chapter pages that explain *why* the steps work. The split matters:

- **Steps** answer "what do I type?" — read at a keyboard, a few minutes each.
- **Book** answers "why does that work?" — read away from the keyboard.

Never duplicate. A step may link to a chapter and a chapter may link to a step,
but the same explanation must not live in both.

### Very simple English, on purpose

Many readers are learning computing and English at the same time. This is a hard
constraint on the book, not a preference:

- Short sentences. One idea per sentence.
- Common words. Write "folder", not "hierarchy"; "list", not "enumerate".
- No idioms, no metaphors that need cultural knowledge to decode.
- Every technical word appears in **bold** the first time and is explained in the
  next sentence. The reader should never need to look anything up.
- Prefer a concrete example over an abstract rule.

The step pages have a slightly richer voice. Do not carry that voice into the
book.

### Chapter layout

Every chapter opens with a `.toc` block listing **all** of its `<h2>` sections,
sitting directly above the first heading. The step pages carry the same block.
Generate it from the headings rather than writing it by hand — a partial or stale
contents list is worse than none, and nothing in CI checks it.

Two rules the generator follows:

- A heading with `id="next"` is left out. It is navigation, and the `page-nav`
  block at the foot of the page already carries it.
- `<li class="toc-key">` marks the one section a reader is most likely to have
  arrived hunting for — step 1's *Forgotten your Ubuntu password?* is the only
  one so far. It renders bold with an arrow. Use it sparingly; if everything is
  highlighted, nothing is.

Each chapter ends with two sections: **Try it**, pointing at the step that
practises the ideas, and **You can now explain**, a short self-check list. No
quizzes and no grading — the book is not assessed.

Chapters live in `docs/book/NN-slug/`, numbered to match the contents page. A
chapter that is not written yet is listed on the contents page as plain muted
text, not a link.

## Tone of the website copy

The audience is a **first-time terminal user**. Steps 1 to 5 in particular must
assume no prior knowledge: no shell scripting, no pipes, no regular expressions,
and no jargon that is not explained on the spot. When a tool can do far more than
the step needs, teach only the part the step needs and point at a later step for
the rest — as step 2 does with `jq`.

The audience is a beginner who may never have opened a terminal. Explain what a
command does before showing it, prefer whole words to jargon on first use, and
keep every code block copy-paste-ready with no placeholders to fill in — unless
the placeholder is the point, in which case make it obviously a placeholder.
