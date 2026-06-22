#!/usr/bin/env python3
"""
GOTCHA #2 — iCloud Drive (Windows) renames files it is uploading to
`.<original-name>.<6 random chars>` (hidden dotfile + random suffix). While that
upload is in flight the note/attachment LOOKS missing (it no longer matches *.md),
even though it is a COMPLETE copy on local disk. This restores the final names.

Safe: only renames when the final name does not already exist; never deletes.
Run it again after iCloud creates more staging files (it does so continuously
while it works through a large initial upload).

    python3 31_recover_icloud_temp.py "/path/to/iCloud/YourVault"
"""
import os, re, sys

TEMP = re.compile(r"\.[A-Za-z0-9]{6}$")   # trailing .<6 alnum>

def main(root):
    renamed = skipped = 0
    for dp, _, fs in os.walk(root):
        for f in fs:
            if f.startswith(".") and TEMP.search(f):
                final = TEMP.sub("", f[1:])          # strip leading '.' and trailing '.RANDOM'
                src, dst = os.path.join(dp, f), os.path.join(dp, final)
                if os.path.exists(dst):
                    skipped += 1
                    continue
                try:
                    os.rename(src, dst); renamed += 1
                except OSError as e:
                    print(f"  ERR {src}: {e}")
    print(f"recovered {renamed} staging file(s); skipped {skipped} (final already present)")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: 31_recover_icloud_temp.py <vault_dir_on_icloud>")
    main(sys.argv[1])
