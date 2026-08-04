# system_setup

Setup scripts and a companion website that take a **fresh Windows machine** to a
working **Ubuntu (WSL2)** development environment with toolchains for **C**,
**Python**, and **Java**.

- **Website:** <https://aikaryashala.com/system_setup>
- **Scripts:** [`docs/scripts/`](docs/scripts) — served directly from the site, so
  every script is `curl`-able at `https://aikaryashala.com/system_setup/scripts/<name>`

Everything is designed for someone starting from zero: run one command per step,
in order, and read the matching page on the website if you want to know what it did.

---

## Quick start

### Step 1 — Ubuntu on Windows (run in Windows PowerShell **as Administrator**)

```powershell
irm https://aikaryashala.com/system_setup/scripts/install_ubuntu_wsl.ps1 | iex
```

Reboot when asked, then open **Ubuntu** from the Start menu and create your Linux
username and password. Everything from here on runs *inside* Ubuntu.

### Steps 2–5 — toolchains (run inside Ubuntu)

```bash
# Everything at once
curl -fsSL https://aikaryashala.com/system_setup/scripts/install_all.sh | bash

# …or one step at a time
curl -fsSL https://aikaryashala.com/system_setup/scripts/install_cmds.sh | bash   # essential commands
curl -fsSL https://aikaryashala.com/system_setup/scripts/install_c.sh    | bash   # clang + lldb + hex tools
curl -fsSL https://aikaryashala.com/system_setup/scripts/install_py.sh   | bash   # python3 + uv
curl -fsSL https://aikaryashala.com/system_setup/scripts/install_java.sh | bash   # JDK + maven + gradle
```

Prefer to read before you run? Every script is plain text — open the URL in a
browser first, or clone this repo and run the files locally.

---

## What gets installed

| Step | Page | Installs |
| --- | --- | --- |
| 1 | [Install Ubuntu](docs/01_install_ubuntu) | WSL2, Ubuntu, virtualization features |
| 2 | [Essential commands](docs/02_install_cmds) | `git` `curl` `wget` `vim` `tmux` `jq` `tree` `ripgrep` `fd` `fzf` `bat` `htop` `unzip` `rsync` `ssh` and friends |
| 3 | [C toolchain](docs/03_install_c) | `clang` `lldb` `lld` `make` `cmake` `ninja` `valgrind` + binary inspection: `xxd` `hexdump` `od` `hexyl` `objdump` `readelf` `nm` `strings` `strace` `ltrace` |
| 4 | [Python toolchain](docs/04_install_py) | [`uv`](https://docs.astral.sh/uv/) and a `uv`-managed Python 3, plus `ruff` |
| 5 | [Java toolchain](docs/05_install_java) | Temurin JDK (LTS), `javac` `java` `jshell` `jar`, Maven, Gradle |

### Tooling choices, and why

- **`clang` + `lldb`** rather than `gcc` + `gdb`. Clang's diagnostics are far
  friendlier to a beginner, and LLDB pairs with it naturally.
- **`uv` for Python — always.** `uv` replaces `pip`, `venv`, `virtualenv`,
  `pyenv`, `pipx`, and `poetry` in one fast binary. It also installs and manages
  the Python interpreter itself, so there is no reason to touch the system
  Python. Every Python example in this project uses `uv`; none use `pip`.
- **Temurin JDK** from the Adoptium APT repository, because Ubuntu's packaged JDK
  lags behind and the repo gives you clean upgrades.

---

## Repository layout

```
.
├── README.md
├── CLAUDE.md                        # working conventions for this repo
├── tools/check_links.sh             # verifies every relative link in docs/
├── .github/workflows/shellcheck.yml # lints scripts and links on push
└── docs/                            # ← GitHub Pages root
    ├── index.html                   # landing page
    ├── assets/                      # shared css + js (no external CDNs)
    ├── examples/                    # downloadable versions of the sample programs
    ├── scripts/                     # every installer, publicly curl-able
    │   ├── common.sh                # shared helpers, sourced by the others
    │   ├── install_ubuntu_wsl.ps1   # step 1 (Windows PowerShell)
    │   ├── install_cmds.sh          # step 2
    │   ├── install_c.sh             # step 3
    │   ├── install_py.sh            # step 4
    │   ├── install_java.sh          # step 5
    │   └── install_all.sh           # steps 2–5, in order
    ├── 01_install_ubuntu/index.html
    ├── 02_install_cmds/index.html
    ├── 03_install_c/index.html
    ├── 04_install_py/index.html
    └── 05_install_java/index.html
```

The numbered directories are both the site's URL structure and the intended
install order. Adding a step means adding a `NN_install_<topic>/index.html` page,
a matching `install_<topic>.sh`, and a card on the landing page.

---

## Script contract

Every `.sh` file in `docs/scripts/` follows the same rules:

1. **Idempotent** — safe to re-run; already-installed packages are skipped.
2. **Non-interactive** — no prompts; `sudo` is requested once, up front.
3. **Strict** — `set -euo pipefail`, and it fails loudly rather than half-installing.
4. **Dual-mode** — works when executed locally *and* when piped from `curl`.
   Scripts locate `common.sh` next to themselves, or fetch it from the site.
5. **Self-verifying** — ends by printing the version of everything it installed.

Override the fetch location when testing a fork:

```bash
export SYSTEM_SETUP_BASE_URL="https://<you>.github.io/system_setup/scripts"
```

---

## Local development

```bash
git clone https://github.com/aikaryashala/system_setup.git
cd system_setup

# Preview the website exactly as GitHub Pages serves it
python3 -m http.server 8000 --directory docs
# → http://localhost:8000

# The same checks CI runs
shellcheck -x docs/scripts/*.sh tools/*.sh
./tools/check_links.sh docs

# Run a script from your working copy instead of the network
bash docs/scripts/install_c.sh
```

The site is static HTML and CSS with a small amount of vanilla JavaScript. There
is no build step, no framework, and no external requests — what is in `docs/` is
exactly what ships.

### Publishing

GitHub Pages is configured as **Deploy from a branch → `main` / `docs`**. Pushing
to `main` publishes. The custom domain is inherited from the organisation's user
pages site, which is why project pages land at `aikaryashala.com/system_setup`
and no `CNAME` file is needed here.

`docs/.nojekyll` is present so GitHub serves the directory verbatim instead of
running it through Jekyll.

---

## Supported platforms

Written for **Ubuntu 24.04 LTS** under **WSL2** on Windows 11.

The Linux scripts are exercised end to end against a clean `ubuntu:24.04`
container, running as an unprivileged account with sudo — the same shape as a
fresh WSL install. They are plain Debian/Ubuntu APT underneath, so they work on
a native Ubuntu install or in a container just as well; WSL is only the assumed
starting point.

The PowerShell installer for step 1 cannot be exercised that way, since it needs
real Windows. It is linted with PSScriptAnalyzer in CI and is written to be safe
to re-run, but treat it as less battle-tested than the rest.

---

## Contributing

Keep changes consistent with `CLAUDE.md`: `uv` for anything Python, no external
CDNs on the website, and every script must survive `shellcheck` and a second run.
