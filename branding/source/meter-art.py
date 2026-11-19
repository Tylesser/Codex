"""Glyphs for the damage meter's segment button (Skins/DamageMeter.lua).

  python meter-art.py <codexDir>

Writes 64x64 white RGBA TGAs (drawn at 8x and scaled down; the skin tints them):
  Media/MeterCurrent.tga   crossed swords: the current fight
  Media/MeterOverall.tga   a sigma: everything since the meter was last reset
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw

SIZE, SCALE = 64, 8
BIG = SIZE * SCALE


def P(x, y):
    return (x * BIG, y * BIG)


def sword(draw, hilt, tip, fill, grow=0.0):
    """One sword from `hilt` to `tip` (unit coordinates); `grow` widens every part (for the gap at the crossing)."""
    hx, hy = hilt
    tx, ty = tip
    length = math.hypot(tx - hx, ty - hy)
    dx, dy = (tx - hx) / length, (ty - hy) / length
    nx, ny = -dy, dx

    def at(s, w):
        return (hx + dx * s + nx * w, hy + dy * s + ny * w)

    def bar(s0, s1, width):
        half = width / 2 + grow
        quad = [at(s0 - grow, -half), at(s1 + grow, -half), at(s1 + grow, half), at(s0 - grow, half)]
        draw.polygon([P(*q) for q in quad], fill=fill)

    # blade with a point
    half = 0.045 + grow
    blade = [at(0.20, -half), at(length - 0.12, -half), at(length + grow * 1.5, 0), at(length - 0.12, half), at(0.20, half)]
    draw.polygon([P(*q) for q in blade], fill=fill)
    bar(0.17, 0.215, 0.27)  # cross-guard
    bar(0.05, 0.18, 0.055)  # grip
    cx, cy = at(0.035, 0)
    r = 0.045 + grow
    draw.ellipse((*P(cx - r, cy - r), *P(cx + r, cy + r)), fill=fill)  # pommel


def save(alpha, path):
    alpha = alpha.resize((SIZE, SIZE), Image.LANCZOS)
    image = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    image.putalpha(alpha)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print("wrote", path)


def current(path):
    a = Image.new("L", (BIG, BIG), 0)
    sword(ImageDraw.Draw(a), (0.14, 0.86), (0.88, 0.12), 255)
    # the second sword (mirrored) cuts a thin gap into the first where they cross
    gap = Image.new("L", (BIG, BIG), 0)
    sword(ImageDraw.Draw(gap), (0.86, 0.86), (0.12, 0.12), 255, grow=0.03)
    a = ImageChops.subtract(a, gap)
    sword(ImageDraw.Draw(a), (0.86, 0.86), (0.12, 0.12), 255)
    save(a, path)


def overall(path):
    a = Image.new("L", (BIG, BIG), 0)
    draw = ImageDraw.Draw(a)
    width = int(0.12 * BIG)
    draw.line([P(0.20, 0.17), P(0.80, 0.17)], fill=255, width=width)
    draw.line([P(0.80, 0.14), P(0.80, 0.30)], fill=255, width=width)
    draw.line([P(0.26, 0.19), P(0.56, 0.50), P(0.26, 0.81)], fill=255, width=width, joint="curve")
    draw.line([P(0.20, 0.83), P(0.80, 0.83)], fill=255, width=width)
    draw.line([P(0.80, 0.70), P(0.80, 0.86)], fill=255, width=width)
    save(a, path)


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
    current(os.path.join(root, "Media", "MeterCurrent.tga"))
    overall(os.path.join(root, "Media", "MeterOverall.tga"))
