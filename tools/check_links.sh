#!/usr/bin/env bash
#
# check_links.sh - three checks over docs/:
#
#   1. Every relative href and src points at a file that exists.
#   2. Every page-nav label still describes the page it links to.
#   3. Every "On this page" list is complete and every entry resolves.
#
# The second check exists because the first one cannot catch a whole class of
# mistake. Rename a page's heading and its links keep working perfectly - they
# just describe something that no longer exists. That is how "Python with uv"
# survived on step 3 long after step 4 stopped being about uv.
#
# External links (http, https, mailto) are not fetched; only local paths are
# checked. Run from the repository root:
#
#   ./tools/check_links.sh

set -euo pipefail

DOCS_DIR="${1:-docs}"
status=0
checked=0
nav_checked=0
toc_checked=0

[ -d "$DOCS_DIR" ] || { echo "No such directory: $DOCS_DIR" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Do the links resolve?

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

# ---------------------------------------------------------------------------
# 2. Do the page-nav labels still match what they point at?

# Lowercase, strip HTML entities and punctuation, leaving bare words.
words_of() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/&[a-z][a-z]*;/ /g' \
        | tr -cs 'a-z0-9' ' '
}

# Words that carry no information about which page is being linked to.
is_noise() {
    case "$1" in
        step|steps|the|a|an|and|to|of|in|on|for|with|from|back|all|next|\
        install|installing|guide|page|here|it|is|are|your|you|my|more|\
        pairs|needs|builds|started|finished|reference|practice|extras|\
        [0-9]*) return 0 ;;
    esac
    # Two letters is the shortest a real tool name gets - uv, jq. Anything
    # shorter is punctuation left over from something like "C:".
    [ ${#1} -lt 2 ] && return 0
    return 1
}

# True when two words describe the same thing, allowing for plurals:
# "command" matches "commands".
same_word() {
    [ "$1" = "$2" ] && return 0
    case "$2" in "$1"*) [ ${#1} -ge 4 ] && return 0 ;; esac
    case "$1" in "$2"*) [ ${#2} -ge 4 ] && return 0 ;; esac
    return 1
}

while IFS= read -r page; do
    page_dir="$(dirname "$page")"

    # Only the prev/next block at the foot of a page. Header and breadcrumb
    # links are navigation furniture, not descriptions of a page.
    nav_block="$(sed -n '/<nav class="page-nav">/,/<\/nav>/p' "$page")"
    [ -n "$nav_block" ] || continue

    while IFS= read -r anchor; do
        [ -n "$anchor" ] || continue

        href="$(printf '%s' "$anchor" | sed -E 's/.*href="([^"]*)".*/\1/')"
        label="$(printf '%s' "$anchor" | sed -E 's/.*<span class="title">([^<]*)<\/span>.*/\1/')"

        # Only compare against numbered pages - steps and book chapters. Links
        # to "../", "../../" and "../scripts/" are "go back" links, and their
        # labels are meant to be generic rather than repeat a heading.
        #
        # Three shapes, because pages sit at different depths: a book chapter
        # reaches a step with ../../, and the contents page reaches a chapter
        # with no prefix at all.
        case "$href" in
            [0-9]*/|../[0-9]*/|../../[0-9]*/) : ;;
            *) continue ;;
        esac

        # A label may opt out when it is deliberately descriptive rather than
        # a restatement of the heading:
        #   <a class="next" data-nav-label="free" href="...">
        case "$anchor" in
            *'data-nav-label="free"'*) continue ;;
        esac

        target_page="$page_dir/${href}index.html"
        [ -f "$target_page" ] || continue

        heading="$(grep -o '<h1>[^<]*</h1>' "$target_page" | head -n 1 | sed 's/<[^>]*>//g')"
        [ -n "$heading" ] || continue

        nav_checked=$((nav_checked + 1))

        # Every meaningful word in the label must appear in the heading.
        #
        # An overlap rule is not enough: "Python with uv" and "Python 3, and
        # tracing it with pdb" share the word "python", so an overlap test calls
        # that a match - which is exactly the stale label this check exists to
        # find. A label may say less than the heading, but it may not introduce
        # a word the page has nothing to do with.
        stray=""
        for lw in $(words_of "$label"); do
            is_noise "$lw" && continue
            found=0
            for hw in $(words_of "$heading"); do
                is_noise "$hw" && continue
                if same_word "$lw" "$hw"; then
                    found=1
                    break
                fi
            done
            if [ "$found" -eq 0 ]; then
                stray="$lw"
                break
            fi
        done

        if [ -n "$stray" ]; then
            echo "stale nav label: $page"
            echo "    links to  : $href"
            echo "    label says: \"$label\""
            echo "    page is   : \"$heading\""
            echo "    stray word: \"$stray\" appears nowhere in that heading"
            status=1
        fi
    done < <(printf '%s' "$nav_block" | grep -oE '<a [^>]*href="[^"]*"[^>]*>.*?</a>' || true)

done < <(find "$DOCS_DIR" -name '*.html' | sort)

# ---------------------------------------------------------------------------
# 3. Is every "On this page" list complete, and does every entry resolve?
#
# A contents list that is missing sections is the failure nobody notices: the
# page looks fine, every link works, and the list quietly stops describing it.
# That is what happens when the list is written by hand and the page grows.

# The ids listed in a page's toc block, one per line, sorted.
toc_entries() {
    sed -n '/<nav class="toc"/,/<\/nav>/p' "$1" \
        | grep -oE 'href="#[^"]*"' \
        | sed 's/href="#//; s/"$//' \
        | grep -v '^next$' \
        | sort
}

# The ids of the sections actually on the page, sorted. "next" is deliberately
# left out of contents lists - it is navigation, and page-nav already has it.
section_ids() {
    grep -oE '<h2 id="[^"]*"' "$1" \
        | sed 's/<h2 id="//; s/"$//' \
        | grep -v '^next$' \
        | sort
}

while IFS= read -r page; do
    grep -q '<nav class="toc"' "$page" || continue
    toc_checked=$((toc_checked + 1))

    listed="$(toc_entries "$page")"
    present="$(section_ids "$page")"

    while IFS= read -r id; do
        [ -n "$id" ] || continue
        echo "contents entry points at no such section: $page -> #$id"
        status=1
    done < <(comm -23 <(printf '%s\n' "$listed") <(printf '%s\n' "$present"))

    while IFS= read -r id; do
        [ -n "$id" ] || continue
        echo "section missing from the contents list: $page -> #$id"
        status=1
    done < <(comm -13 <(printf '%s\n' "$listed") <(printf '%s\n' "$present"))

done < <(find "$DOCS_DIR" -name '*.html' | sort)

# ---------------------------------------------------------------------------

if [ "$status" -eq 0 ]; then
    echo "All $checked local links resolve."
    echo "All $nav_checked page-nav labels match the page they point at."
    echo "All $toc_checked contents lists are complete."
else
    echo "Problems found." >&2
fi

exit "$status"
