"""Rounded-corner pieces for the flat themes (Dusk, Dawn): a smooth disc and a thin ring, cut into quarters by
Widgets.lua (UI.RoundFill / UI.RoundLine) for the corners of windows, buttons and boxes.

  python round-art.py <codexDir>

Writes 64x64 white RGBA TGAs (tinted in game), drawn at 8x and scaled down:
  Media/Round.tga      a filled disc touching the texture's edges (a quarter = one rounded corner of a fill)
  Media/RoundLine.tga  a ring of the same size; its line is 3.2 px wide, so a 10 px corner (20 px circle) shows a
                       1 px hairline and a 6 px corner a slightly finer one
  Media/RoundMask<r>.tga (r = 2, 3, 4, 6)  32x32 rounded-rectangle alpha masks with an r px corner, used nine-sliced
                       (MaskTexture:SetTextureSliceMargins(r, r, r, r)) to round icons and status bars at any size
"""
import os
import sys

from PIL import Image, ImageDraw

SIZE, SCALE = 64, 8
LINE = 3.2  # px at SIZE


def render(path, ring=False):
    big = SIZE * SCALE
    alpha = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(alpha)
    draw.ellipse((0, 0, big - 1, big - 1), fill=255)
    if ring:
        inset = LINE * SCALE
        draw.ellipse((inset, inset, big - 1 - inset, big - 1 - inset), fill=0)
    alpha = alpha.resize((SIZE, SIZE), Image.LANCZOS)
    image = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    image.putalpha(alpha)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print("wrote", path)


def rounded_mask(path, radius, size=32):
    big = size * SCALE
    alpha = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(alpha)
    draw.rounded_rectangle((0, 0, big - 1, big - 1), radius=radius * SCALE, fill=255)
    alpha = alpha.resize((size, size), Image.LANCZOS)
    image = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    image.putalpha(alpha)
    image.save(path)
    print("wrote", path)


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
    render(os.path.join(root, "Media", "Round.tga"))
    render(os.path.join(root, "Media", "RoundLine.tga"), ring=True)
    for radius in (2, 3, 4, 6):
        rounded_mask(os.path.join(root, "Media", "RoundMask%d.tga" % radius), radius)
