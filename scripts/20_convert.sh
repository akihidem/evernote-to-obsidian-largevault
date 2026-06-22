#!/bin/bash
# Convert ENEX -> Obsidian Markdown ONE NOTEBOOK AT A TIME.
# GOTCHA #1 (cont.): looping per notebook bounds yarle's memory (each single-note file is tiny).
# GOTCHA #4: the flag is --configFile (NOT --config); ./sampleTemplate.tmpl must exist in CWD.
set -u
ROOT="${WORK:-$HOME/evernote-migration}"; cd "$ROOT"
SRC="./enex_single"; OUT="./vault"
rm -rf "$OUT"; mkdir -p "$OUT"
cp -f node_modules/yarle-evernote-to-md/sampleTemplate.tmpl ./sampleTemplate.tmpl

while IFS= read -r nb; do
  name=$(basename "$nb")
  python3 - "$nb" "$name" "$OUT" > /tmp/yarle_nb.json <<'PY'
import json, sys, os
enex_dir, notebook, out = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = {
  "enexSources": [enex_dir],
  "outputDir": os.path.join(out, notebook),
  "keepOriginalHtml": False, "isMetadataNeeded": True, "isNotebookNameNeeded": False,
  "skipWebClips": False, "useHashTags": True,
  "nestedTags": {"separatorInEN": "_", "replaceSeparatorWith": "/", "replaceSpaceWith": "-"},
  "outputFormat": "OBSIDIAN", "useUniqueUnknownFileNames": True,
  "monkeyPatchDuplicateTitles": True, "sanitizeResourceNameSpaces": True, "replacementChar": "_",
}
print(json.dumps(cfg, ensure_ascii=False))
PY
  node --max-old-space-size=6144 node_modules/.bin/yarle --configFile /tmp/yarle_nb.json >/dev/null 2>&1
done < <(find "$SRC" -mindepth 1 -maxdepth 1 -type d | sort)

find "$OUT" -name '*.config' -delete 2>/dev/null
echo "converted $(find "$OUT" -name '*.md' | wc -l) markdown notes into $OUT"
