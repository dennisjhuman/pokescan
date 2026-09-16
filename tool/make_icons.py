#!/usr/bin/env python3
"""Generate the PokeScan app icons.

A Pokeball drawn from maths and written straight to PNG with the standard
library, so the repo needs no image toolchain. Rerun after changing colours:

    python3 tool/make_icons.py
"""
import math
import struct
import zlib
from pathlib import Path

RED = (227, 53, 13)
DARK = (26, 20, 18)
WHITE = (245, 245, 245)
BAND = (20, 16, 14)


def _blend(bg, fg, a):
    return tuple(round(b + (f - b) * a) for b, f in zip(bg, fg))


def _coverage(dist, edge, feather=1.2):
    """1 inside, 0 outside, smooth across `feather` pixels."""
    return max(0.0, min(1.0, (edge - dist) / feather + 0.5))


def render(size, padding_ratio):
    cx = cy = (size - 1) / 2
    r = size * (0.5 - padding_ratio)
    band = max(1.5, r * 0.11)
    # The dark ring must be the larger of the two, or the white core covers it.
    ring = r * 0.30
    inner = r * 0.185

    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            px = (0, 0, 0)
            alpha = _coverage(d, r)
            if alpha <= 0:
                row += bytes((0, 0, 0, 0))
                continue

            # Top half red, bottom half white.
            px = RED if y < cy else WHITE
            # Horizontal band across the middle.
            px = _blend(px, BAND, _coverage(abs(y - cy), band))
            # Outer rim.
            px = _blend(px, DARK, _coverage(d, r) - _coverage(d, r - max(1.0, r * 0.045)))
            # Centre button: dark ring, white core.
            px = _blend(px, DARK, _coverage(d, ring))
            px = _blend(px, WHITE, _coverage(d, inner))

            row += bytes((*px, round(alpha * 255)))
        rows.append(bytes(row))
    return rows


def write_png(path, rows, size):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    Path(path).write_bytes(png)


def main():
    web = Path(__file__).resolve().parent.parent / "web"
    # Maskable icons need generous padding: launchers crop to a circle or squircle.
    targets = [
        ("icons/Icon-192.png", 192, 0.04),
        ("icons/Icon-512.png", 512, 0.04),
        ("icons/Icon-maskable-192.png", 192, 0.18),
        ("icons/Icon-maskable-512.png", 512, 0.18),
        ("favicon.png", 64, 0.02),
    ]
    for rel, size, pad in targets:
        out = web / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        write_png(out, render(size, pad), size)
        print(f"wrote {rel} ({size}px)")


if __name__ == "__main__":
    main()
