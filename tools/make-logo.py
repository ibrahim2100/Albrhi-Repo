"""Renders the repo icon as a PNG, with no image libraries involved.

Sileo and Zebra show CydiaIcon.png next to the source name. Pillow is not
available on this machine and installing it in CI to draw one rounded square
would be silly, so the image is rasterised by hand and encoded with zlib — the
only dependency is the standard library.

If tools/logo.png exists it is used verbatim instead, so replacing this with a
real designed logo is a matter of dropping the file in.

Usage: python3 tools/make-logo.py <output.png> [size]
"""
import math
import os
import shutil
import struct
import sys
import zlib

out_path = sys.argv[1]
size = int(sys.argv[2]) if len(sys.argv) > 2 else 512

# A hand-made logo always loses to a real one; prefer the real one if present.
override = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logo.png')
if os.path.exists(override):
    shutil.copyfile(override, out_path)
    print('Using tools/logo.png')
    raise SystemExit(0)

ACCENT_TOP = (0xF2, 0x76, 0x21)
ACCENT_BOTTOM = (0xD1, 0x45, 0x03)

SS = 3  # supersampling factor, for edges that aren't jagged


def rounded_square(x, y, side, radius):
    """Is (x, y) inside a rounded square? Standard rounded-box distance field.

    The naive version -- treating "either axis inside" as inside -- carves the
    straight edges away and leaves only the corners, which is exactly what the
    first render looked like.
    """
    cx = cy = side / 2.0
    qx = abs(x - cx) - (side / 2.0 - radius)
    qy = abs(y - cy) - (side / 2.0 - radius)

    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)

    return outside + inside <= radius


def arrow(x, y, side):
    """A download glyph: an arrow pointing down onto a baseline."""
    cx = side / 2.0
    u = side / 100.0          # work in percentages of the icon
    dx = abs(x - cx)

    # Stem
    if dx <= 7 * u and 22 * u <= y <= 52 * u:
        return True

    # Head: a triangle narrowing to a point
    head_top, head_tip = 46 * u, 70 * u
    if head_top <= y <= head_tip:
        half = 23 * u * (1.0 - (y - head_top) / (head_tip - head_top))
        if dx <= half:
            return True

    # Baseline the arrow lands on
    if 78 * u <= y <= 86 * u and dx <= 25 * u:
        return True

    return False


rows = []
radius = size * 0.225

for py in range(size):
    row = bytearray()
    for px in range(size):
        r = g = b = a = 0

        for sy in range(SS):
            for sx in range(SS):
                x = px + (sx + 0.5) / SS
                y = py + (sy + 0.5) / SS

                if not rounded_square(x, y, size, radius):
                    continue

                t = y / size
                bg = tuple(int(ACCENT_TOP[i] + (ACCENT_BOTTOM[i] - ACCENT_TOP[i]) * t)
                           for i in range(3))

                if arrow(x, y, size):
                    pr, pg, pb = 255, 255, 255
                else:
                    pr, pg, pb = bg

                r += pr
                g += pg
                b += pb
                a += 255

        n = SS * SS
        # Colour is averaged over covered samples only, so edge pixels keep their
        # hue instead of fading towards black.
        covered = a / 255.0
        if covered:
            row += bytes((int(r / covered), int(g / covered), int(b / covered), int(a / n)))
        else:
            row += b'\x00\x00\x00\x00'

    rows.append(bytes(row))


def chunk(tag, data):
    return (struct.pack('>I', len(data)) + tag + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))


raw = b''.join(b'\x00' + r for r in rows)  # filter type 0 per scanline

png = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(raw, 9))
       + chunk(b'IEND', b''))

with open(out_path, 'wb') as f:
    f.write(png)

print('Logo written: %s (%dx%d, %d bytes)' % (out_path, size, size, len(png)))
