# evernote-to-obsidian-largevault

A field-tested **playbook + reference scripts** for migrating a **large** Evernote
account (10,000+ notes, many GB of attachments) to **Obsidian** — including the
parts that break when your vault lives on **iCloud Drive (Windows)**.

This is **not** a new converter. The heavy lifting is done by two excellent upstream
tools — [`evernote-backup`](https://github.com/vzhd1701/evernote-backup) and
[`yarle`](https://github.com/akosbalazs/yarle). What's collected here is the
**orchestration and the non-obvious failure modes** that the official Obsidian
Importer and most "switch to Obsidian" guides don't cover at scale.

> Real run behind this: **11,238 Evernote notes + 34,017 attachments (≈16 GB of ENEX)
> → 11,168 Markdown notes**, verified lossless, vault on iCloud.

## Who needs this

You'll hit these problems if **all** of the following are true; otherwise just use the
[official Obsidian Importer](https://help.obsidian.md/import/evernote):

- 🗂️ **Thousands** of notes / **many GB** of attachments (a single notebook export can exceed Node's string limit).
- ☁️ Vault on **iCloud Drive on Windows** (the staging/rename behaviour below).
- 🌏 Non-ASCII (e.g. Japanese) note titles.

## Pipeline

```
evernote-backup            yarle (per notebook)        iCloud
┌──────────────┐  single   ┌──────────────┐  Markdown  ┌──────────────┐
│ full account │ ─notes──▶ │ ENEX → .md   │ ─────────▶ │ vault        │
│ download     │  ENEX      │ + attachments│            │ (verify!)    │
└──────────────┘           └──────────────┘            └──────────────┘
   10_                          20_                        30_/31_
```

```bash
export WORK=~/evernote-migration
./scripts/00_setup.sh
# one-time interactive login in a REAL terminal (OAuth needs a TTY):
( cd $WORK && . .venv/bin/activate && evernote-backup init-db )
./scripts/10_backup_export.sh      # sync (rate-limit retry) + --single-notes export
./scripts/20_convert.sh            # per-notebook yarle loop -> $WORK/vault
# copy $WORK/vault to your iCloud vault, then:
python3 scripts/31_recover_icloud_temp.py "/path/to/iCloud/YourVault"
python3 scripts/30_verify_parity.py "$WORK/vault" "/path/to/iCloud/YourVault"
./scripts/40_reorg_para.sh "/path/to/iCloud/YourVault"   # optional PARA + MOC layer
```

## The 6 gotchas (the actual point of this repo)

### 1. A single notebook can export to a 9.8 GB `.enex` that yarle cannot read
yarle reads each `.enex` into memory as one string. Node's max string length (~512 M
chars) means a multi-GB ENEX throws before any note is written.
**Fix:** export with `evernote-backup export --single-notes` (one tiny ENEX per note),
then run yarle **one notebook at a time** (`20_convert.sh`) to bound memory.

### 2. iCloud (Windows) hides in-flight files as `.<name>.<6 random>`
While uploading, the iCloud client renames each file to a hidden
`.original.AbC123` staging name. Mid-upload, notes/attachments look **missing**
(they no longer match `*.md`) — but they are **complete** copies on disk.
**Fix:** `31_recover_icloud_temp.py` renames them back (idempotent, non-destructive).
iCloud keeps creating new ones as it works through a big upload, so re-run as needed.

### 3. A note titled `…​.app…` gets its folder mangled by iCloud
iCloud treats `.app` as a macOS bundle: `Foo.appBar/` becomes `FooBar(1).app/`.
Data is intact; only the folder name changes (and it may spawn an empty `.app` stub).
**Fix:** rename the parent folder to drop the dot (`.app` → `_app`) so iCloud leaves it alone.

### 4. yarle: it's `--configFile`, not `--config`, and it needs `./sampleTemplate.tmpl`
`--config` is silently ignored → yarle loads its default config and dies looking for
`./test-template.enex`. Also, by default it opens `./sampleTemplate.tmpl` **relative to
your CWD**, not the package — copy it next to where you run.

### 5. Big accounts hit Evernote's API rate limit mid-sync
`evernote-backup sync` aborts with `Rate limit reached. Restart program in MM:SS`.
It's **resumable**. `10_backup_export.sh` parses the wait and retries until complete.

### 6. Prove it's lossless
After all the renaming above, eyeballing is not enough. `30_verify_parity.py`
compares source vs iCloud by **total file count** and exact path diffs, normalising
**NFC/NFD** (macOS/Evernote titles are often NFD; some filesystems re-normalise to NFC).

## Organising 10k notes afterwards

Don't refile by hand. Consensus from the Obsidian community: drop the whole import into
an **Archive**, build a thin **PARA** structure on top, and navigate with **Maps of
Content (MOC)** + full-text search. `40_reorg_para.sh` creates that skeleton.
See [`articles/`](articles/) for the long-form writeups.

## Credits / license

- [`evernote-backup`](https://github.com/vzhd1701/evernote-backup) — full-account download & ENEX export.
- [`yarle`](https://github.com/akosbalazs/yarle) — ENEX → Markdown.

MIT. These scripts are glue around the tools above; treat them as a starting point, not a product.
