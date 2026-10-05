#!/usr/bin/env python3
"""Writes the header icons the addon ships (Media/Icon*.tga): white line
art on transparent, 32 x 32, tinted in the game with vertex colours. Drawn
four times larger and scaled down, so the edges are soft. Uncompressed
32-bit TGA, rows bottom to top, like the other files in Media/. Also the
minimap button's icon (Media/MinimapIcon.tga).

Needs Pillow (python3 -m pip install pillow). Run from the repository
root:  python3 tools/make_icons.py
"""
import math
import os
import struct

from PIL import Image, ImageDraw

SIZE = 32
SUB = 4
BIG = SIZE * SUB
WHITE = (255, 255, 255, 255)


def scaled(v):
    return v * SUB


def line_width(px):
    return max(1, int(px * SUB))


def new():
    img = Image.new("RGBA", (BIG, BIG), (255, 255, 255, 0))
    return img, ImageDraw.Draw(img)


def poly(draw, points, width=2.4):
    pts = [(scaled(x), scaled(y)) for x, y in points]
    draw.line(pts, fill=WHITE, width=line_width(width), joint="curve")
    r = line_width(width) / 2
    for x, y in (pts[0], pts[-1]):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=WHITE)


def chevron_down(draw):
    poly(draw, [(9, 13), (16, 20), (23, 13)], 2.8)


def chevron_up(draw):
    poly(draw, [(9, 19), (16, 12), (23, 19)], 2.8)


def chevron_right(draw):
    poly(draw, [(13, 9), (20, 16), (13, 23)], 3.2)


def lock_body(draw):
    draw.rounded_rectangle((scaled(8), scaled(15), scaled(24), scaled(27)), radius=scaled(2.5),
                           outline=WHITE, width=line_width(2.4))


def lock(draw):
    lock_body(draw)
    draw.arc((scaled(11), scaled(6), scaled(21), scaled(20)), 180, 360, fill=WHITE, width=line_width(2.4))
    poly(draw, [(11, 13), (11, 15)])
    poly(draw, [(21, 13), (21, 15)])


def unlock(draw):
    lock_body(draw)
    draw.arc((scaled(11), scaled(6), scaled(21), scaled(20)), 180, 320, fill=WHITE, width=line_width(2.4))
    poly(draw, [(11, 13), (11, 15)])


def gear(draw):
    cx = cy = scaled(16)
    teeth, outer, inner = 8, scaled(11.5), scaled(8.5)
    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        r = outer if (i % 4) in (0, 1) else inner
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    draw.polygon(pts, fill=WHITE)
    hole = scaled(4)
    draw.ellipse((cx - hole, cy - hole, cx + hole, cy + hole), fill=(255, 255, 255, 0))


def grip(draw):
    for x in (12, 20):
        for y in (9, 16, 23):
            r = scaled(1.9)
            draw.ellipse((scaled(x) - r, scaled(y) - r, scaled(x) + r, scaled(y) + r), fill=WHITE)


def zones(draw):
    # Three stacked layers: grouping.
    for y in (9, 16, 23):
        poly(draw, [(7, y), (25, y)], 2.6)
    for y in (9, 16, 23):
        r = scaled(1.8)
        draw.ellipse((scaled(4) - r, scaled(y) - r, scaled(4) + r, scaled(y) + r), fill=WHITE)


def sort_level(draw):
    # Bars rising left to right, and an arrow: sorted by level.
    for i, h in enumerate((7, 12, 17)):
        x = 6 + i * 6
        draw.rectangle((scaled(x), scaled(26 - h), scaled(x + 3.5), scaled(26)), fill=WHITE)
    poly(draw, [(26, 7), (26, 25)], 2.4)
    poly(draw, [(22.5, 21.5), (26, 25), (29.5, 21.5)], 2.4)


def sort_watch(draw):
    # A map pin: Blizzard's order, by distance.
    draw.ellipse((scaled(9), scaled(5), scaled(23), scaled(19)), outline=WHITE, width=line_width(2.6))
    poly(draw, [(10.5, 15.5), (16, 27), (21.5, 15.5)], 2.6)
    r = scaled(2.3)
    draw.ellipse((scaled(16) - r, scaled(12) - r, scaled(16) + r, scaled(12) + r), fill=WHITE)


def check(draw):
    poly(draw, [(7, 17), (13, 23), (25, 10)], 3.4)


def resize(draw):
    poly(draw, [(27, 13), (13, 27)], 2.2)
    poly(draw, [(27, 20), (20, 27)], 2.2)


ICONS = {
    "IconChevronDown": chevron_down,
    "IconChevronUp": chevron_up,
    "IconChevronRight": chevron_right,
    "IconLock": lock,
    "IconUnlock": unlock,
    "IconGear": gear,
    "IconGrip": grip,
    "IconZones": zones,
    "IconSortLevel": sort_level,
    "IconSortWatch": sort_watch,
    "IconCheck": check,
    "IconResize": resize,
}


def write_tga(img, path):
    w, h = img.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    rows = []
    px = img.load()
    for y in range(h - 1, -1, -1):
        row = bytearray()
        for x in range(w):
            r, g, b, a = px[x, y]
            row += bytes((b, g, r, a))
        rows.append(bytes(row))
    with open(path, "wb") as f:
        f.write(header)
        f.write(b"".join(rows))


def minimap_icon(root):
    """The minimap button's icon, 64 x 64: a gold quest mark on a dark
    disc, cut to a circle since the button's border is round."""
    size = 64
    big = size * SUB
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse((SUB, SUB, big - SUB, big - SUB), fill=(18, 16, 14, 255))
    draw.ellipse((SUB * 3, SUB * 3, big - SUB * 3, big - SUB * 3), outline=(199, 150, 33, 255), width=SUB * 3)
    gold = (255, 205, 60, 255)
    # The exclamation mark of an available quest.
    cx = big / 2
    draw.rounded_rectangle((cx - SUB * 5, SUB * 13, cx + SUB * 5, SUB * 41), radius=SUB * 4, fill=gold)
    draw.ellipse((cx - SUB * 5.5, SUB * 45, cx + SUB * 5.5, SUB * 56), fill=gold)
    small = img.resize((size, size), Image.LANCZOS)
    write_tga(small, os.path.join(root, "MinimapIcon.tga"))
    print("MinimapIcon")


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Media")
    for name, fn in ICONS.items():
        img, draw = new()
        fn(draw)
        small = img.resize((SIZE, SIZE), Image.LANCZOS)
        write_tga(small, os.path.join(root, name + ".tga"))
        print(name)
    minimap_icon(root)


if __name__ == "__main__":
    main()
