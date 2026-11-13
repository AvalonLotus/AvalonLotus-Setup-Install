"""Two-way sync of ~/Library/Fonts with "AvalonLotus Mac - Font" in Google Drive.

No font file is ever deleted, overwritten or renamed: a name, once written, stays.
"""
import datetime
import fcntl
import glob
import logging
import os
import re
import shutil
import sys
import time

if __name__ == "__main__":
    print(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"), end=" ", flush=True)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from font_names import covered_by, identify  # noqa: E402

logging.getLogger("fontTools").setLevel(logging.CRITICAL)

FOLDER_NAME = "AvalonLotus Mac - Font"
# The index file name, the group folder names and the index headings below are
# data already stored in the Drive backup and read back by read_index, so they
# keep their Traditional Chinese names; renaming them would split the backup.
INDEX = "字型清單.md"  # "Font list"
FONT = (".otf", ".ttf", ".ttc")
PARTIAL = ".partial"
OWN_PARTIAL = re.compile(r"^\..+\.(otf|ttf|ttc)\.partial$", re.I)
LOCK = os.path.expanduser("~/.local/state/font-sync/lock")
FONTS_DIR = os.path.expanduser("~/Library/Fonts")

# Grouping is by who made the font, because that is what decides whether it can
# ever be downloaded again. Adobe and Microsoft/DynaComware cannot; the rest can.
# Order matters. Noto Serif CJK is Source Han Serif under another name, so its
# vendor string says Adobe — testing the Adobe rule first would file the open
# CJK faces next to the licensed ones and misstate what has to be backed up.
# Each rule sees the family name, the vendor string, and the original file name,
# because the Shufajia and Microsoft JhengHei fonts carry romanised family names
# and are only identifiable by their Chinese file names.
# Group folders: "CJK 開源" = open-source CJK, "王漢宗" = Wang Han-tsung,
# "微軟與華康" = Microsoft and DynaComware, "其他" (below) = other.
GROUPS = [
    ("CJK 開源",   lambda f, v, n: any(k in f or k in n for k in ("Sarasa", "Noto", "Source Han", "更紗"))),
    ("Adobe",      lambda f, v, n: "adobe" in v.lower() or f.startswith("Adobe ")),
    ("王漢宗",      lambda f, v, n: f.lower().startswith("hanwang") or "王漢宗" in n),
    ("微軟與華康",  lambda f, v, n: any(k in f or k in n
                     for k in ("MingLiU", "Microsoft", "微軟", "書法家", "DFKai", "華康", "HoloLens"))),
]


def fonts_in(d, recursive):
    if not os.path.isdir(d):
        return []
    if recursive:
        return sorted(os.path.join(r, f) for r, _, fs in os.walk(d) for f in fs if f.lower().endswith(FONT))
    return sorted(os.path.join(d, f) for f in os.listdir(d)
                  if f.lower().endswith(FONT) and os.path.isfile(os.path.join(d, f)))


def known_names(paths):
    names = set()
    for p in paths:
        names |= identify(p).provides
    return names


def acquire(path):
    """An open file holding an exclusive lock on path, or None when another run holds it."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fh = open(path, "a+")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return fh
    except OSError:
        fh.close()
        return None


def place(src, out_dir, stem, ext):
    """Copy src into out_dir under a name no file has; return that name.

    The data goes to a .partial file first and is renamed into place only when
    complete, so an interrupted copy never leaves a truncated font under a
    real name.
    """
    os.makedirs(out_dir, exist_ok=True)
    name, n = stem + ext, 2
    while os.path.exists(os.path.join(out_dir, name)):
        name, n = f"{stem} ({n}){ext}", n + 1
    tmp = os.path.join(out_dir, f".{name}{PARTIAL}")
    shutil.copy2(src, tmp)
    if os.path.getsize(tmp) != os.path.getsize(src):
        os.remove(tmp)
        raise OSError(f"incomplete copy of {src}")
    final = os.path.join(out_dir, name)
    if os.path.exists(final):
        os.remove(tmp)
        return place(src, out_dir, stem, ext)
    os.rename(tmp, final)
    return name


def sweep_partials(d, max_age=86400):
    """Remove this program's own interrupted copies once they are a day old."""
    now = time.time()
    for r, _, fs in os.walk(d):
        for f in fs:
            if not OWN_PARTIAL.match(f):
                continue
            p = os.path.join(r, f)
            try:
                if now - os.path.getmtime(p) > max_age:
                    os.remove(p)
            except FileNotFoundError:
                pass


def read_index(dest):
    """{(group, file name): original file name} and unreadable entries from the index."""
    original, unread = {}, []
    index = os.path.join(dest, INDEX)
    if not os.path.exists(index):
        return original, unread
    group = section = ""
    for line in open(index, encoding="utf-8"):
        if line.startswith("## "):
            section = line
            group = re.sub(r"\(.*$", "", line[3:]).strip()
        m = re.match(r"^\| (.+?) \| (.+?) \|$", line.rstrip("\n"))
        if m and m.group(1) != "檔名":
            original[(group, m.group(1))] = m.group(2)
        if section.startswith("## 讀不到名稱表") and line.startswith("- "):
            unread.append(line[2:].strip())
    return original, unread


def export(src, dest):
    """Copy fonts from src into dest when dest does not cover them. Returns the added paths."""
    os.makedirs(dest, exist_ok=True)
    sweep_partials(dest)
    original, unread = read_index(dest)
    known = known_names(fonts_in(dest, True))
    added = []
    for path in fonts_in(src, False):
        entry = os.path.basename(path)
        font = identify(path)
        if covered_by(font, known):
            continue
        group = "其他"
        if font.families:
            group = next((label for label, test in GROUPS if test(font.families[0], font.vendor, entry)), "其他")
        else:
            unread.append(entry)
        name = place(path, os.path.join(dest, group), font.own, os.path.splitext(entry)[1].lower())
        original[(group, name)] = entry if entry != name else "—"
        known |= font.provides
        added.append(os.path.join(group, name))
    write_index(dest, original, unread)
    return added


def write_index(dest, original, unread):
    """Rewrite the index from the files in dest, only when its content changes."""
    rows = []
    for group in sorted(os.listdir(dest)):
        gdir = os.path.join(dest, group)
        if os.path.isdir(gdir):
            for p in fonts_in(gdir, False):
                f = os.path.basename(p)
                rows.append((group, f, original.get((group, f), "—"), os.path.getsize(p)))
    # A row whose file has not arrived from the other computer yet stays.
    # NOTE: a row whose file was deleted by hand stays too; delete the row by hand.
    present = {(r[0], r[1]) for r in rows}
    rows += [(g, f, o, 0) for (g, f), o in original.items() if (g, f) not in present]
    by_group = {}
    for group, filename, orig, size in rows:
        by_group.setdefault(group, []).append((filename, orig, size))
    out = ["# 字型清單\n\n",
           f"共 {len(rows)} 個檔案,{sum(r[3] for r in rows)/1073741824:.2f} GB。",
           "由 settings/font_sync.py 產生,新加入的字型檔名取自字型內部的 name table,既有的沿用備份檔名。\n\n"]
    for group in sorted(by_group, key=lambda g: (-len(by_group[g]), g)):
        items = sorted(by_group[group])
        out.append(f"## {group}({len(items)} 個,{sum(i[2] for i in items)/1048576:.0f} MB)\n\n")
        out.append("| 檔名 | 原始檔名 |\n|---|---|\n")
        out.extend(f"| {filename} | {orig} |\n" for filename, orig, _ in items)
        out.append("\n")
    restricted = [r for r in rows if "PERSONAL USE" in r[1].upper() or "DEMO" in r[1].upper()]
    if restricted:
        out.append("## 授權受限\n\n檔名本身標示了使用限制,公開發布前要確認:\n\n")
        out.extend(f"- {r[0]}/{r[1]}\n" for r in sorted(restricted))
        out.append("\n")
    if unread:
        out.append(f"## 讀不到名稱表({len(set(unread))} 個,沿用原始檔名)\n\n")
        out.extend(f"- {u}\n" for u in sorted(set(unread)))
    text = "".join(out)
    index = os.path.join(dest, INDEX)
    if os.path.exists(index) and open(index, encoding="utf-8").read() == text:
        return
    with open(index, "w", encoding="utf-8") as fh:
        fh.write(text)


def restore(src, dest):
    """Copy fonts from src into dest when this computer does not cover them. Returns (copied, skipped)."""
    os.makedirs(dest, exist_ok=True)
    sweep_partials(dest)
    known = known_names(fonts_in(dest, False) + fonts_in("/Library/Fonts", False))
    copied = skipped = 0
    for p in fonts_in(src, True):
        font = identify(p)
        if covered_by(font, known):
            skipped += 1
            continue
        place(p, dest, os.path.splitext(os.path.basename(p))[0], os.path.splitext(p)[1].lower())
        known |= font.provides
        copied += 1
    return copied, skipped


def drive_folder():
    """The backup folder inside a Google Drive for desktop mount, or None."""
    roots = glob.glob(os.path.expanduser("~/Library/CloudStorage/GoogleDrive-*/*"))
    for root in roots + [os.path.expanduser("~/Google Drive/My Drive")]:
        if not os.path.isdir(root):
            continue
        base = root.rstrip(os.sep).count(os.sep)
        for r, dirs, _ in os.walk(root):
            if os.path.basename(r) == FOLDER_NAME:
                return r
            if r.count(os.sep) - base >= 3:
                dirs[:] = []
    return None


def main():
    held = acquire(LOCK)
    if not held:
        print("Another sync is running; skipping this run", file=sys.stderr)
        return 0
    try:
        drive = drive_folder()
        if not drive:
            print(f'"{FOLDER_NAME}" not found in Google Drive; skipping')
            return 0
        added = export(FONTS_DIR, drive)
        copied, skipped = restore(drive, FONTS_DIR)
        print(f"Added to backup: {len(added)}, newly installed here: {copied}, already present: {skipped}"
              + "".join(f"\n  + {a}" for a in added))
    except (OSError, ValueError) as e:
        print(f"Cannot read {getattr(e, 'filename', None) or e}; skipping this run", file=sys.stderr)
        return 1
    finally:
        held.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
