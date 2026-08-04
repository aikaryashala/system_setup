"""hello.py - the example from https://aikaryashala.com/system_setup/04_install_py/

Run it with uv. There is no environment to create and nothing to activate:

    uv run hello.py
"""

import sys


def main() -> None:
    print(f"Hello from Python {sys.version.split()[0]}")


if __name__ == "__main__":
    main()
