"""Minimal, alignment-aware ZIP writer for APKs.

Python's zipfile cannot control the local-header extra field, which is what
zipalign uses to push entry payloads onto 4-byte boundaries.  Android 11+
refuses to install a package whose resources.arsc is compressed or unaligned,
so we emit the archive ourselves.

Entry payload offsets are aligned by padding the local header's extra field
with zero bytes - exactly what the classic `zipalign` did.
"""

import struct
import zlib

LFH_SIG = 0x04034B50
CDH_SIG = 0x02014B50
EOCD_SIG = 0x06054B50

STORED = 0
DEFLATED = 8


class Entry:
    def __init__(self, name, data, compress=True, align=None):
        self.name = name.encode("utf-8")
        self.data = data
        self.method = DEFLATED if compress else STORED
        # Stored entries are the only ones Android mmaps, so only they need
        # alignment; 4 bytes is the default, native libraries would want 4096.
        self.align = align if align is not None else (4 if self.method == STORED else 1)
        self.crc = zlib.crc32(data) & 0xFFFFFFFF
        if self.method == DEFLATED:
            co = zlib.compressobj(9, zlib.DEFLATED, -15)
            self.payload = co.compress(data) + co.flush()
            # Never let "compression" make an entry bigger.
            if len(self.payload) >= len(data):
                self.method = STORED
                self.payload = data
                self.align = align if align is not None else 4
        else:
            self.payload = data
        self.offset = 0


def _dos_time(ts=(1980, 1, 1, 0, 0, 0)):
    y, mo, d, h, mi, s = ts
    return ((h << 11) | (mi << 5) | (s // 2), ((y - 1980) << 9) | (mo << 5) | d)


def write_apk(path, entries):
    """Write `entries` (list of Entry) to `path` as a zip archive."""
    dtime, ddate = _dos_time()
    out = bytearray()

    for e in entries:
        # Padding goes in the extra field, so the payload lands on a boundary.
        head = 30 + len(e.name)
        pad = 0
        if e.align > 1:
            pad = (-(len(out) + head)) % e.align
        e.offset = len(out)
        out += struct.pack(
            "<IHHHHHIIIHH",
            LFH_SIG, 20, 0, e.method, dtime, ddate,
            e.crc, len(e.payload), len(e.data), len(e.name), pad,
        )
        out += e.name
        out += b"\0" * pad
        out += e.payload

    cd_offset = len(out)
    for e in entries:
        out += struct.pack(
            "<IHHHHHHIIIHHHHHII",
            CDH_SIG, 20, 20, 0, e.method, dtime, ddate,
            e.crc, len(e.payload), len(e.data), len(e.name), 0, 0, 0, 0,
            0, e.offset,
        )
        out += e.name
    cd_size = len(out) - cd_offset

    out += struct.pack(
        "<IHHHHIIH", EOCD_SIG, 0, 0, len(entries), len(entries), cd_size, cd_offset, 0
    )

    with open(path, "wb") as fh:
        fh.write(bytes(out))
    return len(out)


def check_alignment(path, names=("resources.arsc",), align=4):
    """Verify that the payload of each named stored entry is `align`-aligned."""
    with open(path, "rb") as fh:
        blob = fh.read()
    problems = []
    pos = 0
    seen = {}
    while True:
        idx = blob.find(struct.pack("<I", LFH_SIG), pos)
        if idx < 0:
            break
        (_, _, flags, method, _, _, _, csize, _, nlen, elen) = struct.unpack(
            "<IHHHHHIIIHH", blob[idx:idx + 30]
        )
        name = blob[idx + 30:idx + 30 + nlen].decode("utf-8", "replace")
        data_at = idx + 30 + nlen + elen
        seen[name] = (method, data_at)
        pos = idx + 30
    for n in names:
        if n not in seen:
            problems.append("%s: missing" % n)
            continue
        method, at = seen[n]
        if method != STORED:
            problems.append("%s: compressed (method=%d)" % (n, method))
        if at % align:
            problems.append("%s: payload at %d, not %d-aligned" % (n, at, align))
    return problems
