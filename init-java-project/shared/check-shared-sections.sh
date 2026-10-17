#!/usr/bin/env bash
# Checks that the shared build sections in a project match the canonical copies.
#
# usage: check-shared-sections.sh PROJECT_DIR SECTIONS_DIR
#
# Each shared block is wrapped in "// shared:begin NAME" and "// shared:end NAME" lines in the project's
# build.gradle and settings.gradle, and in the canonical *.gradle.sections files. Blocks are compared as
# code only: indentation, blank lines and comment lines are ignored, so a project may nest a block inside
# subprojects {} or document it differently. Every canonical section must appear in the matching project
# file, so deleting a marker fails the check instead of skipping it.

set -u

project="$1"
sections="$2"
rc=0
diffout=$(mktemp)
trap 'rm -f "$diffout"' EXIT

# Print the normalized code lines of section NAME in FILE.
extract() {
    awk -v name="$2" '
        $0 ~ "^[ \t]*// shared:begin " name "[ \t]*$" { on = 1; next }
        $0 ~ "^[ \t]*// shared:end " name "[ \t]*$" { on = 0; next }
        on {
            sub(/^[ \t]+/, "")
            sub(/[ \t]+$/, "")
            if ($0 == "" || $0 ~ /^\/\//) next
            print
        }' "$1"
}

# Print the section names that FILE begins.
names() {
    awk '/^[ \t]*\/\/ shared:begin [a-z-]+[ \t]*$/ { sub(/^[ \t]*\/\/ shared:begin /, ""); sub(/[ \t]+$/, ""); print }' "$1"
}

check_file() {
    file="$1"
    canon="$2"
    [ -f "$project/$file" ] || { echo "error: $project/$file is missing"; rc=1; return; }

    begins=$(grep -c '^[ \t]*// shared:begin ' "$project/$file")
    ends=$(grep -c '^[ \t]*// shared:end ' "$project/$file")
    if [ "$begins" != "$ends" ]; then
        echo "error: $file has $begins shared:begin and $ends shared:end markers"
        rc=1
    fi

    for name in $(names "$canon"); do
        if ! names "$project/$file" | grep -qx "$name"; then
            echo "error: $file is missing shared section '$name'"
            rc=1
            continue
        fi
        if ! diff -u <(extract "$canon" "$name") <(extract "$project/$file" "$name") > "$diffout" 2>&1; then
            echo "error: $file section '$name' differs from the canonical copy:"
            cat "$diffout"
            rc=1
        fi
    done

    for name in $(names "$project/$file"); do
        if ! names "$canon" | grep -qx "$name"; then
            echo "error: $file has shared section '$name' that is not in $(basename "$canon")"
            rc=1
        fi
    done
}

check_file build.gradle "$sections/build.gradle.sections"
check_file settings.gradle "$sections/settings.gradle.sections"

[ "$rc" = 0 ] && echo "shared build sections match the canonical copies in $project"
exit "$rc"
