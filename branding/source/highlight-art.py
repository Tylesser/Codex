"""Textures for the Highlights module (round-2 design, board R2-Frames "Gathering nodes" and R2-Bags quest mark).

  python highlight-art.py <codexDir>

Writes white RGBA TGAs (tinted in game with SetVertexColor; black parts stay black) to Modules/Highlight/Media:
  NodeRing.tga   64x64, shown at 56px: a 30px disc with a soft inner glow (.35 at the centre to .06 at 70%), a 1px
                 black line and a 2px colour line round it, and a 12px outer glow at .45 (the board's box-shadows)
  Herb.tga, Ore.tga, Chest.tga, Fish.tga
                 64x64 glyphs, the board's 24-unit SVG paths stroked 2.2 wide with round ends (Fish is ours: the
                 board has no pool)
  Corner.tga     32x32 right triangle in the top-left corner (the bag slot's quest mark)
  Bang.tga       64x64 "!" for quest objects, quest mobs and quest-starting items: a tapered bar with round ends
                 and a dot, white with a 4px black edge baked in (it replaced a font "!", blurry in game, 2026-11-28)
"""
import math
import os
import sys

from PIL import Image, ImageDraw

SS = 8  # supersampling


def save(image, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print("wrote", path)


# Node ring -------------------------------------------------------------------------------------------------

def over(dst, src):
    """Premultiplied 'over': src on top of dst. Colours are (r, a) with r the grey level (white or black)."""
    r, a = src
    dr, da = dst
    return (r * a + dr * (1 - a), a + da * (1 - a))


def ring_sample(d):
    """d: distance from the centre in design px (the texture spans 56)."""
    px = (0.0, 0.0)  # premultiplied grey, alpha
    if d > 15:
        glow = 0.45 * math.exp(-((d - 15) ** 2) / (2 * 5.0 ** 2))
        px = over(px, (1.0, glow))
    if d < 15:
        t = d / 15
        inner = 0.35 + (0.06 - 0.35) * min(1, t / 0.7)
        px = over(px, (1.0, inner))
    if 15 <= d < 17:
        px = over(px, (1.0, 1.0))
    if 15 <= d < 16:
        px = over(px, (0.0, 1.0))
    return px


def node_ring(path, size=64, span=56.0):
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    n = 4
    for y in range(size):
        for x in range(size):
            grey = alpha = 0.0
            for sy in range(n):
                for sx in range(n):
                    u = (x + (sx + 0.5) / n) / size * span - span / 2
                    v = (y + (sy + 0.5) / n) / size * span - span / 2
                    g, a = ring_sample(math.hypot(u, v))
                    grey += g
                    alpha += a
            grey /= n * n
            alpha /= n * n
            level = int(round(255 * (grey / alpha))) if alpha > 0 else 255
            pixels[x, y] = (level, level, level, int(round(255 * alpha)))
    save(image, path)


# Glyphs -----------------------------------------------------------------------------------------------------

def cubic(p0, p1, p2, p3, steps=24):
    out = []
    for i in range(steps + 1):
        t = i / steps
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def glyph(path, polylines, size=64, view=24.0, width=2.2):
    big = size * SS
    k = big / view
    alpha = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(alpha)
    w = width * k
    for line in polylines:
        points = [(x * k, y * k) for x, y in line]
        draw.line(points, fill=255, width=int(round(w)), joint="curve")
        for x, y in points:  # round ends and joins
            draw.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=255)
    alpha = alpha.resize((size, size), Image.LANCZOS)
    image = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    image.putalpha(alpha)
    save(image, path)


def herb():
    leaf = cubic((5, 19), (5, 11), (10, 6), (19, 5)) + cubic((19, 5), (18, 14), (13, 19), (5, 19))[1:]
    return [leaf, [(5, 19), (13, 11)]]


def ore():
    head = cubic((4, 9), (8, 5.5), (16, 5.5), (20, 9))
    return [head, [(12, 6.5), (12, 21)]]


def chest():
    box = [(4, 11), (20, 11), (20, 19), (4, 19), (4, 11)]
    lid = [(12 - 8 * math.cos(t), 11 - 4 * math.sin(t)) for t in [i * math.pi / 24 for i in range(25)]]
    lock = [(11, 14), (13, 14), (13, 16), (11, 16), (11, 14)]
    return [box, lid, lock]


def fish():
    body = cubic((3, 12), (6, 8), (13, 7), (17, 12)) + cubic((17, 12), (13, 17), (6, 16), (3, 12))[1:]
    tail = [(17, 12), (21, 9), (21, 15), (17, 12)]
    return [body, tail]


# Corner -----------------------------------------------------------------------------------------------------

def corner(path, size=32):
    big = size * SS
    alpha = Image.new("L", (big, big), 0)
    ImageDraw.Draw(alpha).polygon([(0, 0), (big, 0), (0, big)], fill=255)
    alpha = alpha.resize((size, size), Image.LANCZOS)
    image = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    image.putalpha(alpha)
    save(image, path)


# Bang -------------------------------------------------------------------------------------------------------

def bang_shape(draw, k, grow):
    """The "!" in 64-unit design space, every edge pushed out by grow units."""
    top, bottom, half_top, half_bottom = 12.5, 40.0, 7.0, 4.75
    ht, hb = half_top + grow, half_bottom + grow
    draw.polygon([((32 - ht) * k, top * k), ((32 + ht) * k, top * k),
                  ((32 + hb) * k, bottom * k), ((32 - hb) * k, bottom * k)], fill=255)
    draw.ellipse(((32 - ht) * k, (top - ht) * k, (32 + ht) * k, (top + ht) * k), fill=255)
    draw.ellipse(((32 - hb) * k, (bottom - hb) * k, (32 + hb) * k, (bottom + hb) * k), fill=255)
    r = 6.0 + grow
    draw.ellipse(((32 - r) * k, (53 - r) * k, (32 + r) * k, (53 + r) * k), fill=255)


def bang(path, size=64, edge=4.0):
    big = size * SS
    k = big / 64.0
    outer = Image.new("L", (big, big), 0)
    inner = Image.new("L", (big, big), 0)
    bang_shape(ImageDraw.Draw(outer), k, edge)
    bang_shape(ImageDraw.Draw(inner), k, 0)
    outer = outer.resize((size, size), Image.LANCZOS)
    inner = inner.resize((size, size), Image.LANCZOS)
    image = Image.new("RGBA", (size, size))
    for y in range(size):
        for x in range(size):
            a, w = outer.getpixel((x, y)), inner.getpixel((x, y))
            a = max(a, w)
            grey = int(round(255 * w / a)) if a else 0
            image.putpixel((x, y), (grey, grey, grey, a))
    save(image, path)


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
    media = os.path.join(root, "Modules", "Highlight", "Media")
    node_ring(os.path.join(media, "NodeRing.tga"))
    glyph(os.path.join(media, "Herb.tga"), herb())
    glyph(os.path.join(media, "Ore.tga"), ore())
    glyph(os.path.join(media, "Chest.tga"), chest())
    glyph(os.path.join(media, "Fish.tga"), fish())
    corner(os.path.join(media, "Corner.tga"))
    bang(os.path.join(media, "Bang.tga"))
