#!/bin/bash
# Optional: lay a thin PARA + MOC layer on top of the import.
# Consensus advice for 10k+ imported notes: DO NOT refile by hand. Drop the whole
# import into an Archive and build a small structure on top; surface with search + MOCs.
#
# This creates the skeleton and moves every imported notebook into 04_Archive/Imported.
# Promote the few notebooks you actually use into 02_Areas / 03_Resources yourself.
#
#   ./40_reorg_para.sh /path/to/vault
set -u
ROOT="$1"; cd "$ROOT" || { echo "no vault: $ROOT"; exit 1; }

mkdir -p 00_Inbox 01_Projects 02_Areas 03_Resources 04_Archive/Imported \
         05_Templates 06_Attachments 07_MOC

# Move every existing top-level notebook folder into the archive.
for d in */; do
  case "$d" in
    00_Inbox/|01_Projects/|02_Areas/|03_Resources/|04_Archive/|05_Templates/|06_Attachments/|07_MOC/) ;;
    *) mv "$d" "04_Archive/Imported/" && echo "archived ${d%/}";;
  esac
done

[ -f Home.md ] || cat > Home.md <<'MD'
# 🏠 Home

- 🗺️ [[Index]] — vault map
- 🔍 Full-text search (Ctrl/Cmd+Shift+F) — how you reach old notes; don't dig folders.

`00_Inbox` new/unsorted · `01_Projects` deadline work · `02_Areas` ongoing ·
`03_Resources` reference · `04_Archive/Imported` the whole legacy import.
MD

[ -f 07_MOC/Index.md ] || cat > 07_MOC/Index.md <<'MD'
# 🗺️ Index (Map of Content)

Build this by hand over time. Add `MOC-<topic>.md` files that link related notes
across folders. Start rough.
MD

echo "done. top-level:"; ls -1
