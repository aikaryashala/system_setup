#!/usr/bin/env bash
#
# check_links.sh - verify that every relative link in docs/ points at a file
# that exists. Catches the usual mistake of renaming a page directory and
# leaving a stale href behind.
#
# External links (http, https, mailto) are not fetched; only local paths are
# checked. Run from the repository root:
#
#   ./tools/check_links.sh

set -euo pipefail

DOCS_DIR="${1:-docs}"
status=0
checked=0

[ -d "$DOCS_DIR" ] || { echo "No such directory: $DOCS_DIR" >&2; exit 1; }

while IFS= read -r page; do
    page_dir="$(dirname "$page")"

    # Pull the value out of every href="..." and src="..." on the page.
    while IFS= read -r ref; do
        [ -n "$ref" ] || continue

        case "$ref" in
            http://*|https://*|mailto:*|'#'*|data:*|//*) continue ;;
        esac

        # Drop any fragment or query string before resolving.
        target="${ref%%#*}"
        target="${target%%\?*}"
        [ -n "$target" ] || continue

        # A link ending in / means that directory's index.html.
        case "$target" in
            */) target="${target}index.html" ;;
        esac

        checked=$((checked + 1))
        if [ ! -e "$page_dir/$target" ]; then
            echo "broken: $page -> $ref"
            status=1
        fi
    done < <(grep -oE '(href|src)="[^"]*"' "$page" | sed -E 's/^(href|src)="//; s/"$//')

done < <(find "$DOCS_DIR" -name '*.html' | sort)

if [ "$status" -eq 0 ]; then
    echo "All $checked local links resolve."
else
    echo "Some links are broken." >&2
fi

exit "$status"
