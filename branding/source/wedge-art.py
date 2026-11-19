"""The ring menus' selected-slice wedges, in the look of Blizzard's ping wheel (Radial_Wheel_Select_Wedge_Count_4).

  python wedge-art.py <codexDir>

Forever only has Blizzard's wedge for 4 slices; a Codex ring has 2 to 12. Writes Modules/Rings/Media/Wedge<N>.tga
(N = 2..12): 256x256 white RGBA, a sector pointing right (+x) with its apex at the centre, 360/N degrees wide (a
little narrower, so it never covers the divider lines), its alpha rising from the hub out to a brighter rim. The
texture is square, so SetRotation turns it to any slice without changing its shape; it is tinted gold in game.
"""
import math
import os
import sys

from PIL import Image

SIZE, SCALE = 256, 2
INNER, OUTER, RIM = 0.16, 0.95, 0.05  # radii as parts of the half size: hub edge, outer edge, rim width
GAP = math.radians(1.2)  # left free on each side of the sector


def smooth(edge0, edge1, x):
    if edge1 == edge0:
        return 1.0 if x >= edge1 else 0.0
    t = min(1.0, max(0.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def render(path, count):
    big = SIZE * SCALE
    half = big / 2
    alpha = Image.new("L", (big, big), 0)
    pixels = alpha.load()
    spread = math.pi / count - GAP  # half the sector's angle
    soft = 1.5 / half  # about one final pixel of anti-aliasing
    for py in range(big):
        dy = (py + 0.5 - half) / half
        for px in range(big):
            dx = (px + 0.5 - half) / half
            r = math.hypot(dx, dy)
            if r < INNER - soft or r > OUTER + soft:
                continue
            angle = abs(math.atan2(dy, dx))
            if angle > spread + 0.05:
                continue
            # inside the sector: soft side edges (in pixels along the arc), soft inner and outer edges
            side = smooth(0, soft * 2, (spread - angle) * r)
            radial = smooth(INNER - soft, INNER + soft, r) * (1 - smooth(OUTER - soft, OUTER + soft, r))
            # the glow: faint near the hub, strong towards the rim, the rim itself brightest
            glow = 0.08 + 0.52 * max(0.0, (r - INNER) / (OUTER - INNER)) ** 1.6
            rim = smooth(OUTER - RIM - soft * 2, OUTER - RIM, r) * 0.12
            value = min(1.0, glow + rim) * side * radial
            if value > 0:
                pixels[px, py] = int(value * 255 + 0.5)
    alpha = alpha.resize((SIZE, SIZE), Image.LANCZOS)
    image = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    image.putalpha(alpha)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print("wrote", path)


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
    for count in range(2, 13):
        render(os.path.join(root, "Modules", "Rings", "Media", "Wedge%d.tga" % count), count)
