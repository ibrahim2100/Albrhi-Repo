"""Draws the licence app's icon, with no image libraries involved.

Same reasoning as tools/make-logo.py, which this borrows its PNG writer from: Pillow is not on
this machine, and installing an imaging stack to draw one key is silly when the standard library
already has zlib.

**Full-bleed, no rounded corners of our own.** iOS masks an app icon itself, and an icon that
arrives already rounded is rounded twice -- a dark seam around the shape on every home screen.
That is the one thing a hand-drawn icon reliably gets wrong.

Usage: python3 tools/make-app-icon.py <output.png> <size>
"""
import math
import struct
import sys
import zlib

out_path = sys.argv[1]
size = int(sys.argv[2])

TOP = (0x1E, 0x3A, 0x8A)      # deep blue, so the white key reads at 60 points
BOTTOM = (0x0B, 0x14, 0x2E)

SS = 3


def key(x, y, side):
    """A key: a ring at the top, a shaft down the middle, two teeth to one side."""
    u = side / 100.0
    cx = side / 2.0
    dx = x - cx

    # Ring -- an annulus, not a disc: a solid head reads as a lollipop at small sizes.
    ring_y = 30 * u
    d = math.hypot(dx, y - ring_y)
    if 12 * u <= d <= 21 * u:
        return True

    # Shaft, starting at the ring's *inner* edge rather than its centre: begun at the centre it
    # puts a white tab inside the hole, and the hole is the only thing that says "key".
    if abs(dx) <= 6 * u and ring_y + 12 * u <= y <= 82 * u:
        return True

    # Teeth, both on the same side, which is what makes it read as a key rather than a cross.
    for top in (58 * u, 70 * u):
        if top <= y <= top + 8 * u and 6 * u <= dx <= 24 * u:
            return True

    return False


rows = []
for py in range(size):
    row = bytearray()
    for px in range(size):
        r = g = b = 0

        for sy in range(SS):
            for sx in range(SS):
                x = px + (sx + 0.5) / SS
                y = py + (sy + 0.5) / SS

                t = y / size
                bg = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))

                pr, pg, pb = (255, 255, 255) if key(x, y, size) else bg
                r += pr
                g += pg
                b += pb

        n = SS * SS
        row += bytes((r // n, g // n, b // n, 255))

    rows.append(bytes(row))


def chunk(tag, data):
    return (struct.pack('>I', len(data)) + tag + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))


raw = b''.join(b'\x00' + r for r in rows)

png = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(raw, 9))
       + chunk(b'IEND', b''))

with open(out_path, 'wb') as f:
    f.write(png)

print('Icon written: %s (%dx%d, %d bytes)' % (out_path, size, size, len(png)))
