"""The name a font file carries in the backup "AvalonLotus Mac - Font", and when
another file already provides the same font.

A face is identified by the names its own name table gives it, never by the
file name, so the same font under two file names (msjh.ttf and its Chinese-named
copy) is recognised as one. A variable face counts as present only when the variable
font itself, or every one of its named styles, is present.
"""
import hashlib
import os
import re
import struct
import unicodedata
from collections import namedtuple

from fontTools.ttLib import TTFont

CJK = re.compile(r'[一-鿿]')
# Unreadable files are compared by content, with unreadable files only.
UNREAD = "\0unread:"

Font = namedtuple("Font", "own options provides families vendor")


def safe(name):
    name = unicodedata.normalize("NFC", name)
    return re.sub(r'[\x00-\x1f<>:"/\\|?*]', "-", name).strip(" .") or "font"


def _face_count(path):
    if not path.lower().endswith(".ttc"):
        return 1
    with open(path, "rb") as fh:
        head = fh.read(12)
    if head[:4] != b"ttcf" or len(head) < 12:
        return 1
    count = struct.unpack(">I", head[8:12])[0]
    # A count the file has no room for is a damaged header: read as one face, it fails fast.
    return count if 0 < count and 12 + 4 * count <= os.path.getsize(path) else 1


def read(path):
    """[(family, style, vendor, italic, instance styles)] for every readable face.

    OSError is raised: a file that cannot be read now is not a font without names.
    """
    faces = []
    # One face at a time with lazy tables: TTCollection parses every face at
    # once, and Sarasa-SuperTTC.ttc is 792 MB holding dozens of them.
    for number in range(_face_count(path)):
        font = None
        try:
            font = TTFont(path, fontNumber=number, lazy=True)
            picked = {}
            for rec in font["name"].names:
                if rec.nameID not in (1, 2, 8, 16, 17):
                    continue
                try:
                    value = rec.toUnicode()
                except Exception:
                    continue
                picked.setdefault((rec.nameID, rec.langID in (0x409, 0)), value.strip())
            get = lambda i: picked.get((i, True)) or picked.get((i, False))
            family = get(16) or get(1)
            if not family:
                continue
            style = get(17) or get(2) or "Regular"
            italic = "italic" in style.lower() or ("OS/2" in font and bool(font["OS/2"].fsSelection & 1))
            instances = []
            if "fvar" in font:
                for inst in font["fvar"].instances:
                    n = font["name"].getDebugName(inst.subfamilyNameID)
                    if n:
                        instances.append(n.strip())
            faces.append((family, style, get(8) or "", italic, instances))
        except OSError:
            raise
        except Exception:
            continue
        finally:
            if font is not None:
                font.close()
    return faces


def _plain(family, style):
    return safe(family if style.lower() == "regular" else f"{family} {style}")


def _variable(family, italic):
    return safe(f"{family} Italic Variable" if italic else f"{family} Variable")


def identify(path):
    """Font(own, options, provides, families, vendor) for one file.

    own: the stem the file gets in the backup. options: per face, the name sets
    of which any one being present means the face is present. provides: every
    name the file makes present.
    """
    stem = os.path.splitext(os.path.basename(path))[0]
    faces = read(path)
    if not faces:
        with open(path, "rb") as fh:
            name = UNREAD + hashlib.sha1(fh.read()).hexdigest()
        return Font(stem, [[{name}]], {name}, [], "")
    options, provides = [], set()
    for family, style, _, italic, instances in faces:
        plain = _plain(family, style)
        if instances:
            styles = {_plain(family, s) for s in instances}
            options.append([{_variable(family, italic)}, styles])
            provides |= styles | {plain, _variable(family, italic)}
        else:
            options.append([{plain}])
            provides.add(plain)
    family, style, vendor, italic, instances = faces[0]
    # A font whose name table is romanised but whose file name is Chinese keeps
    # the Chinese: a user searches for the Chinese name, not HanWangFangSongMedium.
    if CJK.search(stem) and not CJK.search(family):
        own = safe(stem)
    elif instances:
        own = _variable(family, italic)
    else:
        own = _plain(family, style)
    return Font(own, options, provides, [f[0] for f in faces], vendor)


def covered_by(font, known):
    """True when every face of font is present in known."""
    return all(any(option <= known for option in face) for face in font.options)
