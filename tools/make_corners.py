#!/usr/bin/env python3
"""Writes the corner art and masks the addon ships (Media/Corner.tga,
the four Media/CornerInverse*.tga and the Media/RoundedNN*.tga masks). No
dependencies beyond the standard library.

All are uncompressed 32-bit TGA, white, the shape in the alpha
channel, rows stored bottom to top (the TGA default).

Corner.tga: the top-left corner of a rounded rectangle. A quarter disc
of radius 64 centred on the texture's bottom-right corner is opaque,
the rest transparent. The outer corner piece of a rounded border ring
shows it (mirrored for the other corners).

CornerInverseTopLeft.tga: transparent inside a quarter disc of radius 63
around the texture's bottom-right corner, opaque outside. One texel
smaller than the texture, so the whole left column and top row stay
opaque: a CLAMP mask of it lets everything left of and above it through.
The inner edge of a rounded border's top-left corner.
CornerInverseTopRight/BottomLeft/BottomRight.tga: the same shape for the
other corners, mirrored in the file. Masks ignore texture coordinates in
the client (a mirrored mask drew unmirrored), so each corner has its own.

Corner.tga and CornerInverse*.tga are 64 x 64.

RoundedNN.tga (NN = 01..12, the corner radius in UI units): a 32 x 32
rounded rectangle whose corner arcs have a radius of NN texels, for a
nine-slice mask with margins of NN on each side. In the client a sliced
mask draws each corner cell as margin texels = that many UI units of the
box (measured in game; SetScale on a mask is ignored), so the arc's
radius in texels is the radius on screen in UI units, at any UI scale.
Every texel between the corner cells is opaque.
RoundedNNTop.tga / RoundedNNBottom.tga: the same with only the top or only
the bottom corners round, the other two square (a frame whose other side
continues into a docked castbar).

Run from the repository root:  python3 tools/make_corners.py
The output is deterministic; re-running it must not change the files.
"""
import os
import struct

SIZE = 64
SUB = 4  # sub-samples per axis for the anti-aliased edge
MASK_SIZE = 32  # the Rounded masks: room for two corner cells of MAX_RADIUS
MAX_RADIUS = 12  # the cornerRadius setting's maximum (Core/Settings.lua)


def coverage(x, y, radius=SIZE):
    """Share of texel (x, y) (x to the right, y downwards) inside the disc
    of the given radius around the texture's bottom-right corner."""
    inside = 0
    for i in range(SUB):
        for j in range(SUB):
            px = x + (i + 0.5) / SUB
            py = y + (j + 0.5) / SUB
            dx, dy = SIZE - px, SIZE - py
            if dx * dx + dy * dy <= radius * radius:
                inside += 1
    return inside / (SUB * SUB)


def rounded(radius, round_top, round_bottom):
    """Alpha of a MASK_SIZE rounded-rectangle mask whose top and/or bottom
    corners are round with the given radius in texels, the others square."""
    def alpha_of(x, y):
        top, bottom = y < radius, y >= MASK_SIZE - radius
        left, right = x < radius, x >= MASK_SIZE - radius
        if not ((top and round_top) or (bottom and round_bottom)) or not (left or right):
            return 1
        # Mirror into the top-left cell: the arc's centre is (radius, radius).
        mx = x if left else MASK_SIZE - 1 - x
        my = y if top else MASK_SIZE - 1 - y
        inside = 0
        for i in range(SUB):
            for j in range(SUB):
                dx = radius - (mx + (i + 0.5) / SUB)
                dy = radius - (my + (j + 0.5) / SUB)
                if dx * dx + dy * dy <= radius * radius:
                    inside += 1
        return inside / (SUB * SUB)
    return alpha_of


# Corner name, mirrored left-right, mirrored top-bottom.
INVERSE_CORNERS = (("TopLeft", False, False), ("TopRight", True, False),
                   ("BottomLeft", False, True), ("BottomRight", True, True))


def inverse(flip_x, flip_y):
    """Alpha of the inverse arc for one corner: the top-left shape,
    mirrored as asked."""
    def alpha_of(x, y):
        mx = SIZE - 1 - x if flip_x else x
        my = SIZE - 1 - y if flip_y else y
        return 1 - coverage(mx, my, SIZE - 1)
    return alpha_of


def write_tga(path, alpha_of, size=SIZE):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 8)
    rows = []
    for y in range(size - 1, -1, -1):  # bottom row first
        row = bytearray()
        for x in range(size):
            a = int(round(alpha_of(x, y) * 255))
            row += bytes((255, 255, 255, a))  # B, G, R, A
        rows.append(bytes(row))
    with open(path, "wb") as fh:
        fh.write(header)
        fh.write(b"".join(rows))


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Media")
    os.makedirs(root, exist_ok=True)
    write_tga(os.path.join(root, "Corner.tga"), coverage)
    for name, flip_x, flip_y in INVERSE_CORNERS:
        write_tga(os.path.join(root, "CornerInverse" + name + ".tga"), inverse(flip_x, flip_y))
    for radius in range(1, MAX_RADIUS + 1):
        name = "Rounded%02d" % radius
        for suffix, top, bottom in (("", True, True), ("Top", True, False), ("Bottom", False, True)):
            write_tga(os.path.join(root, name + suffix + ".tga"), rounded(radius, top, bottom), MASK_SIZE)


if __name__ == "__main__":
    main()
