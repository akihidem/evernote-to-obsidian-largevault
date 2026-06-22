#!/usr/bin/env python3
"""
Prove the migration is lossless: compare a SOURCE vault (e.g. the local master in
~/evernote-migration/vault) against the DEST copy (e.g. the vault on iCloud).

Reports md count, total file count, and the exact path diffs both ways.

    python3 30_verify_parity.py <src_vault> <dst_vault>

Notes / gotchas this surfaces:
  - GOTCHA #2: leftover `.name.RANDOM` iCloud staging files show up as DEST-only
    "extra" paths and as SOURCE-only "missing" md. Run 31_recover_icloud_temp.py,
    then re-run this.
  - GOTCHA #3: a note whose title contains ".app" gets its folder renamed by iCloud
    (e.g. `Foo.appBar` -> `FooBar(1).app`). Data is intact, only the folder name
    differs; rename the parent to drop ".app" (use "_app") so iCloud stops touching it.
  - NFC vs NFD: macOS/Evernote titles are often NFD; some filesystems re-normalise to
    NFC, so byte-compare can mislead. This script normalises with unicodedata.
"""
import os, sys, unicodedata

def md_and_all(root):
    md, allf = set(), set()
    for dp, _, fs in os.walk(root):
        for f in fs:
            rel = os.path.relpath(os.path.join(dp, f), root)
            rel = unicodedata.normalize("NFC", rel)
            allf.add(rel)
            if f.endswith(".md"):
                md.add(rel)
    return md, allf

def main(src, dst):
    smd, sall = md_and_all(src)
    dmd, dall = md_and_all(dst)
    print(f"SOURCE  md={len(smd):>6}  all={len(sall):>6}  ({src})")
    print(f"DEST    md={len(dmd):>6}  all={len(dall):>6}  ({dst})")
    print("RESULT  " + ("MATCH ✅" if sall == dall else "DIFF ⚠"))
    miss, extra = sorted(sall - dall), sorted(dall - sall)
    if miss:
        print(f"\n-- in SOURCE, missing from DEST ({len(miss)}):")
        for p in miss[:40]:
            print("  -", p)
    if extra:
        print(f"\n-- in DEST, not in SOURCE ({len(extra)}):")
        for p in extra[:40]:
            print("  +", p)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: 30_verify_parity.py <src_vault> <dst_vault>")
    main(sys.argv[1], sys.argv[2])
