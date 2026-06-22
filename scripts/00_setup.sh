#!/bin/bash
# Install the two upstream tools into ./tools (Linux/WSL/macOS).
set -e
ROOT="${WORK:-$HOME/evernote-migration}"
mkdir -p "$ROOT"; cd "$ROOT"
python3 -m venv .venv && . .venv/bin/activate && pip install -q --upgrade pip evernote-backup
npm init -y >/dev/null 2>&1 || true
npm install yarle-evernote-to-md
# GOTCHA #4: yarle looks for ./sampleTemplate.tmpl relative to CWD.
cp node_modules/yarle-evernote-to-md/sampleTemplate.tmpl ./sampleTemplate.tmpl
echo "setup done in $ROOT"
