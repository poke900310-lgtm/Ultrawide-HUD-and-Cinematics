#!/usr/bin/env python3
"""Package Dawnwalker Ultrawide into a distributable zip.

Reads the version from Scripts/main.lua and writes
dist/DawnwalkerUltrawide-<version>.zip. The zip carries the full game-relative
path so a manual install is just "extract into the game folder and merge".

No dependencies; standard library only. Run:  python build.py
"""
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MOD = ROOT / "Mods" / "DawnwalkerUltrawide"
DIST = ROOT / "dist"

# Where the mod lives under the game folder (PC / Steam). On Xbox / Game Pass the
# leaf "Win64" becomes "WinGDK"; the README documents that for the user.
GAME_PREFIX = "Dawnwalker/Binaries/Win64/ue4ss/Mods/DawnwalkerUltrawide"

# Files shipped inside the mod folder.
MOD_FILES = [
    "enabled.txt",
    "Scripts/main.lua",
    "Scripts/Ultrawide.defaults.ini",
]

# Docs placed at the zip root.
ROOT_DOCS = ["README.md", "CHANGELOG.md", "LICENSE.txt"]


def read_version() -> str:
    text = (MOD / "Scripts" / "main.lua").read_text(encoding="utf-8", errors="replace")
    m = re.search(r'local\s+VERSION\s*=\s*"([^"]+)"', text)
    if not m:
        sys.exit("error: could not find VERSION in main.lua")
    return m.group(1)


def main() -> int:
    version = read_version()

    missing = [f for f in MOD_FILES if not (MOD / f).is_file()]
    if missing:
        sys.exit("error: missing mod files: " + ", ".join(missing))

    DIST.mkdir(exist_ok=True)
    out = DIST / f"DawnwalkerUltrawide-{version}.zip"
    if out.exists():
        out.unlink()

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in MOD_FILES:
            z.write(MOD / rel, f"{GAME_PREFIX}/{rel}")
        for doc in ROOT_DOCS:
            p = ROOT / doc
            if p.is_file():
                z.write(p, doc)

    size = out.stat().st_size
    print(f"built {out.relative_to(ROOT)}  ({size:,} bytes, version {version})")
    with zipfile.ZipFile(out) as z:
        for name in z.namelist():
            print("  " + name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
