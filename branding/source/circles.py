"""Smooth round textures for Codex (round icons, portraits, the minimap ring, buff rings).

  python circles.py <codexDir>

Writes 256x256 white RGBA TGAs with anti-aliased edges (drawn at 8x and scaled down):
  Media/Circle.tga                 a filled circle (masks, discs, round swipes)
Blizzard's TempPortraitAlphaMask is small and showed jagged edges at portrait and icon sizes.
(A smooth 256px ring was tried for Modules/Buffs/Media/Ring.tga too; the user preferred the original double-line
ring from Buff Tracker, so that file stays the original. `render(..., ring_width=0.09)` still makes one.)
"""
import os
import sys

from PIL import Image, ImageDraw

SIZE, SCALE = 256, 8


def disc(draw, size, inset, fill):
    draw.ellipse((inset, inset, size - 1 - inset, size - 1 - inset), fill=fill)


def render(path, ring_width=None):
    big = SIZE * SCALE
    alpha = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(alpha)
    disc(draw, big, SCALE, 255)  # a 1px margin so the edge never touches the texture border
    if ring_width:
        disc(draw, big, SCALE + ring_width * big, 0)
    alpha = alpha.resize((SIZE, SIZE), Image.LANCZOS)
    image = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    image.putalpha(alpha)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print("wrote", path)


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
    render(os.path.join(root, "Media", "Circle.tga"))
