#!/bin/bash
# Download the WHOLE Evernote account, then export ONE ENEX PER NOTE.
# GOTCHA #1: per-notebook export can produce a 9.8GB .enex that yarle CANNOT read
#            (Node string limit). --single-notes keeps every file tiny.
# GOTCHA #5: big accounts hit Evernote API rate limits; sync is resumable -> retry loop.
set -u
ROOT="${WORK:-$HOME/evernote-migration}"; cd "$ROOT"; . .venv/bin/activate

# Login once (interactive OAuth; run in a REAL terminal, not headless):
#   evernote-backup init-db
[ -f en_backup.db ] || { echo "Run 'evernote-backup init-db' in a real terminal first."; exit 1; }

while true; do
  out=$(evernote-backup sync 2>&1); echo "$out" | tail -3
  if echo "$out" | grep -q "Rate limit reached"; then
    w=$(echo "$out" | grep -oE '[0-9]+:[0-9]+' | head -1)
    secs=$(( 10#${w%%:*}*60 + 10#${w##*:} + 20 )); echo "rate limited, sleep ${secs}s"; sleep "$secs"; continue
  fi
  break
done
evernote-backup export --single-notes ./enex_single
echo "exported $(find ./enex_single -name '*.enex' | wc -l) single-note enex files"
