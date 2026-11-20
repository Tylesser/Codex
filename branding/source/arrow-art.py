"""The fold arrow for Codex's foldable headings (sections, quest tracker zones, Commerce Authority zones).

  python arrow-art.py <codexDir>

Writes Media/FoldArrow.tga: a 32x32 white RGBA triangle pointing right, with anti-aliased edges (drawn at 8x and
scaled down), tinted in game (UI.FoldArrow turns it a quarter for "open"). It replaced an arrow drawn from 1 px
texture columns, whose slanted edges stepped at the screen's pixels (the user's "arrows are low quality",
2026-11-21).
"""
import os
import sys

from PIL import Image, ImageDraw

SIZE, SCALE = 32, 8


def render(path):
    big = SIZE * SCALE
    alpha = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(alpha)
    # pointing right, centred on the texture's middle (so a quarter turn keeps it in place): 14 wide, 18 tall
    s = SCALE
    cx, cy = SIZE / 2, SIZE / 2
    points = [((cx - 6) * s, (cy - 9) * s), ((cx + 8) * s, cy * s), ((cx - 6) * s, (cy + 9) * s)]
    draw.polygon(points, fill=255)
    alpha = alpha.resize((SIZE, SIZE), Image.LANCZOS)
    image = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    image.putalpha(alpha)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print("wrote", path)


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
    render(os.path.join(root, "Media", "FoldArrow.tga"))
