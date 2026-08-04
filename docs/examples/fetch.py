# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx"]
# ///
"""fetch.py - a standalone script that declares its own dependencies.

The block at the top of this file is inline script metadata. uv reads it,
builds a throwaway environment containing httpx, and runs the script:

    uv run fetch.py

Nothing is installed permanently, and nothing is left behind. To add another
dependency to the header, use:

    uv add --script fetch.py <package>
"""

import httpx

response = httpx.get("https://api.github.com/repos/aikaryashala/system_setup")
response.raise_for_status()
print(response.json()["full_name"])
