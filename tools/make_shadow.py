#!/usr/bin/env python3
"""Writes the drop shadow texture the addon ships (Media/Shadow.tga).
No dependencies beyond the standard library.

512 x 32, uncompressed 32-bit TGA, black, the shadow in the alpha
channel, rows stored bottom to top (the TGA default). Sixteen 32 x 32
cells side by side. Each cell is the top-left corner piece of a soft
shadow around a rounded rectangle: the rounded corner's centre is the
cell's bottom-right corner, the shadow is full up to the distance
q * 32 from it (the rectangle's own radius) and fades out to nothing at
the distance 32. Cell k has q = k / 16, so one cell fits any ratio of
corner radius to shadow size: the fade always starts at the radius and
is always as wide as the shadow (Core/Border.lua picks the cell).

Cell 0 (q = 0) is a square corner; its right column and bottom row are
the plain fade across the shadow, which the edge pieces use.

Run from the repository root:  python3 tools/make_shadow.py
The output is deterministic; re-running it must not change the file.
"""
import math
import os
import struct

CELL = 32
CELLS = 16
WIDTH, HEIGHT = CELL * CELLS, CELL
SUB = 4  # sub-samples per axis


def fade(u):
    """1 inside, 0 outside, a smooth step in between (u from 0 to 1)."""
    if u <= 0:
        return 1.0
    if u >= 1:
        return 0.0
    return (1 - u) * (1 - u) * (1 + 2 * u)


def alpha(x, y):
    """Shadow at texel (x, y), x to the right, y downwards."""
    k, cx = divmod(x, CELL)
    q = k / CELLS
    start, width = q * CELL, (1 - q) * CELL
    total = 0.0
    for i in range(SUB):
        for j in range(SUB):
            dx = CELL - (cx + (i + 0.5) / SUB)
            dy = CELL - (y + (j + 0.5) / SUB)
            total += fade((math.sqrt(dx * dx + dy * dy) - start) / width)
    return total / (SUB * SUB)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Media")
    os.makedirs(root, exist_ok=True)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, WIDTH, HEIGHT, 32, 8)
    # Shadow.tga is black; Glow.tga the same fade in white, for the glows
    # (threat, target highlight) that take a colour: vertex colours multiply,
    # so a black texture stays black whatever colour it is given.
    for name, rgb in (("Shadow.tga", 0), ("Glow.tga", 255)):
        rows = []
        for y in range(HEIGHT - 1, -1, -1):  # bottom row first
            row = bytearray()
            for x in range(WIDTH):
                row += bytes((rgb, rgb, rgb, int(round(alpha(x, y) * 255))))  # B, G, R, A
            rows.append(bytes(row))
        with open(os.path.join(root, name), "wb") as fh:
            fh.write(header)
            fh.write(b"".join(rows))


if __name__ == "__main__":
    main()
