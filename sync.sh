#!/usr/bin/env bash
# Copy the live files listed in MANIFEST from this machine back into the repo.
# settings/*.patch.json are curated by hand (only the theme keys), so they are not synced.
# Use after changing something, then review with `git diff` and commit.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
awk '!/^[[:space:]]*(#|$)/ {print $2}' "$HERE/MANIFEST" | while read -r entry; do
  [ -e "$HOME/$entry" ] || { echo "missing, skipped: $entry" >&2; continue; }
  rm -rf "$HERE/files/$entry"; mkdir -p "$HERE/files/$(dirname "$entry")"
  cp -a "$HOME/$entry" "$HERE/files/$entry"
done
echo "Synced. Review: git -C '$HERE' status"
