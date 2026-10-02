#!/usr/bin/env bash
# Copy the live files listed in MANIFEST from this machine back into the repo.
# settings/*.patch.json are curated by hand (only the theme keys), so they are not synced; that
# includes ryogami.patch.json, which the «palette» component merges. The palette scheme itself
# (~/.local/share/ryoku/themes/valorant) is a MANIFEST entry, so it is synced like any other file.
# Before committing, check that no blue/teal/violet crept back in (hex AND decimal RGB forms):
#   grep -rnIE '3dd6c6|61;214;198|61, ?214, ?198|5e56c9|94;86;201|1f2a36|0f1923|b04fd0' files settings
# Use after changing something, then review with `git diff` and commit.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
awk '!/^[[:space:]]*(#|$)/ {print $2}' "$HERE/MANIFEST" | while read -r entry; do
  [ -e "$HOME/$entry" ] || { echo "missing, skipped: $entry" >&2; continue; }
  rm -rf "$HERE/files/$entry"; mkdir -p "$HERE/files/$(dirname "$entry")"
  cp -a "$HOME/$entry" "$HERE/files/$entry"
done
echo "Synced. Review: git -C '$HERE' status"
