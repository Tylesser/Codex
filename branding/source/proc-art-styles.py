"""Proc art styles: pieces for any proc (the user's request, 2026-11-23: "generate more arts and let the user select
between those arts for procs"), next to the per-proc Codex art of proc-codex-art.py.

  python proc-art-styles.py <codexDir> [sheet.png]

Writes Modules/QoL/Media/ProcArt/style_<key>.tga: 128x256 RGBA for the LEFT side (the right side is the same file
mirrored), white with a soft glow, so the game tints it in the proc glow's colour (ProcArt.lua: tint, ADD blend).
Each follows the arc of the "arc" look (the circle round (230, 128), radius 190), fades out towards both of its
ends and towards the texture's edges like the Codex art. All drawn here. Keys and names: ProcArt.lua A.STYLES.
"""
import importlib.util
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("codexart", os.path.join(HERE, "proc-codex-art.py"))
art = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(art)

W, H, S, CX, CY, R = art.W, art.H, art.S, art.CX, art.CY, art.R


def on_arc(degrees, radius=R):
    """A point on the arc's circle (180 = the middle of the "(", left edge)."""
    a = math.radians(degrees)
    return CX + radius * math.cos(a), CY + radius * math.sin(a)


def out_dir(degrees):
    a = math.radians(degrees)
    return math.cos(a), math.sin(a)  # away from the circle's centre (to the left)


def px(points):
    return [(x * S, y * S) for x, y in points]


def line(d, points, width, fill=255):
    d.line(px(points), fill=fill, width=max(1, int(width * S)), joint="curve")


def dot(d, x, y, r, fill=255):
    d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=fill)


def shape_at(d, points, degrees, x, y, fill=255):
    """points drawn rotated by `degrees` round (0, 0), then moved to x, y."""
    pts = art.rotate(points, degrees)
    d.polygon(px([(x + a, y + b) for a, b in pts]), fill=fill)


def arc_line(d, radius, width, start=140, end=220, fill=255):
    pts = [on_arc(start + (end - start) * i / 60, radius) for i in range(61)]
    line(d, pts, width, fill)


# The styles: each draws white on an L mask at S times ---------------------------------------------------------------

def st_flames(d):
    # a burning rim: a band along the arc whose outer edge rises into tongues licking outwards and up
    rng = random.Random(11)
    tongues = [(rng.uniform(0.75, 1.15), rng.uniform(-0.12, 0.12)) for _ in range(9)]

    def rim(base, amp, shade):
        inner, outer = [], []
        for k in range(181):
            a = 142 + k * 76 / 180
            t = (k / 180) * len(tongues)
            n = min(int(t), len(tongues) - 1)
            f = t - n
            height, skew = tongues[n]
            f = min(1.0, max(0.0, f + skew))
            peak = (1 - abs(2 * f - 1)) ** 2.2 * height
            end = math.sin(math.pi * k / 180) ** 0.6  # smaller towards the arc's ends
            r = R + base + amp * peak * end
            x, y = on_arc(a, r)
            outer.append((x, y - amp * peak * end * 0.55))  # the tongues curl upwards
            inner.append(on_arc(a, R - 3))
        d.polygon(px(inner + outer[::-1]), fill=shade)

    rim(4, 24, 140)
    rim(2, 13, 255)


RUNES = [
    [((0, -12), (0, 12)), ((0, -12), (8, -4)), ((0, -2), (8, 6))],
    [((-6, -12), (-6, 12)), ((6, -12), (6, 12)), ((-6, -12), (6, 4))],
    [((0, -12), (0, 12)), ((-8, -6), (8, 6)), ((8, -6), (-8, 6))],
    [((-7, 12), (0, -12)), ((0, -12), (7, 12)), ((-4, 2), (4, 2))],
    [((0, -12), (0, 12)), ((0, -12), (8, -6)), ((8, -6), (0, 0)), ((0, 0), (8, 6))],
]


def st_runes(d):
    arc_line(d, R, 2.4)
    arc_line(d, R - 30, 1.2, 150, 210, fill=170)
    for k, rune in enumerate(RUNES):
        a = 152 + k * 14
        x, y = on_arc(a, R - 15)
        turn = a - 180
        for (x0, y0), (x1, y1) in rune:
            (ax, ay), (bx, by) = art.rotate([(x0 * 0.8, y0 * 0.8), (x1 * 0.8, y1 * 0.8)], turn)
            line(d, [(x + ax, y + ay), (x + bx, y + by)], 2.4)


def st_wings(d):
    # feathers fanning out of the arc's middle, longest in the middle
    for k in range(11):
        a = 145 + k * 7
        x, y = on_arc(a, R - 6)
        ox, oy = out_dir(a)
        length = 34 - abs(a - 180) * 0.45
        feather = art.lens(length, 9)
        angle = math.degrees(math.atan2(oy, ox)) + 90
        cx, cy = x + ox * length * 0.42, y + oy * length * 0.42
        shape_at(d, feather, angle, cx, cy, fill=210)
        line(d, [(x, y), (x + ox * length * 0.85, y + oy * length * 0.85)], 1.0, fill=255)
    arc_line(d, R - 6, 3.0, 145, 215)


def st_blades(d):
    arc_line(d, R, 1.6, fill=170)
    for a in (158, 180, 202):
        x, y = on_arc(a, R - 6)
        ox, oy = out_dir(a)
        # a crescent blade: a big disc minus a shifted one, pointing out
        blade = Image.new("L", (W * S, H * S), 0)
        b = ImageDraw.Draw(blade)
        dot(b, x + ox * 12, y + oy * 12, 20)
        dot(b, x + ox * 20, y + oy * 20, 18, fill=0)
        cut = Image.new("L", (W * S, H * S), 0)
        ImageDraw.Draw(cut).rectangle([0, (y - 28) * S, W * S, (y + 28) * S], fill=255)
        d._image.paste(255, (0, 0), ImageChops.multiply(blade, cut))
        dot(d, x, y, 3.2)


def st_lightning(d):
    rng = random.Random(23)
    pts = []
    for k in range(17):
        a = 142 + k * 4.75
        r = R + rng.uniform(-9, 9) if 0 < k < 16 else R
        pts.append(on_arc(a, r))
    line(d, pts, 3.0)
    for start in (4, 8, 12):
        x, y = pts[start]
        ox, oy = out_dir(142 + start * 4.75)
        branch = [(x, y)]
        for _ in range(3):
            x += ox * rng.uniform(7, 11) + rng.uniform(-5, 5)
            y += oy * rng.uniform(7, 11) + rng.uniform(-6, 6)
            branch.append((x, y))
        line(d, branch, 1.6, fill=220)


def st_vines(d):
    pts = []
    for k in range(81):
        a = 142 + k * 0.95
        r = R - 8 + 7 * math.sin(k / 80 * math.pi * 5)
        pts.append(on_arc(a, r))
    line(d, pts, 2.6)
    for k in range(6, 80, 9):
        x, y = pts[k]
        a = 142 + k * 0.95
        side = 1 if (k // 9) % 2 == 0 else -1
        ox, oy = out_dir(a)
        leaf = art.lens(16, 7)
        angle = math.degrees(math.atan2(oy, ox)) + 90 + side * 40
        shape_at(d, leaf, angle, x + ox * 7 * side, y + oy * 7 * side + 4 * side, fill=230)


def st_crystals(d):
    arc_line(d, R + 4, 1.4, fill=150)
    rng = random.Random(31)
    for k in range(8):
        a = 150 + k * 8.6 + rng.uniform(-2, 2)
        x, y = on_arc(a, R - 2)
        ox, oy = out_dir(a)
        length = 32 - abs(a - 180) * 0.35 + rng.uniform(-4, 4)
        angle = math.degrees(math.atan2(oy, ox)) + 90 + rng.uniform(-12, 12)
        shard = [(0, -length / 2), (4.5, -length / 5), (2.2, length / 2), (-2.2, length / 2), (-4.5, -length / 5)]
        shape_at(d, shard, angle, x + ox * length * 0.35, y + oy * length * 0.35, fill=200)
        shape_at(d, [(0, -length / 2), (2, -length / 4), (0, length / 2)], angle, x + ox * length * 0.35,
                 y + oy * length * 0.35, fill=255)


def st_stars(d):
    spots = [on_arc(a, R - 12 + off) for a, off in ((148, 0), (160, 10), (172, -4), (184, 12), (196, -2), (208, 9),
                                                     (216, -6))]
    for (x0, y0), (x1, y1) in zip(spots, spots[1:]):
        line(d, [(x0, y0), (x1, y1)], 1.0, fill=140)
    for k, (x, y) in enumerate(spots):
        size = 9 if k in (1, 3, 5) else 5.5
        shape_at(d, art.star(4, size, size * 0.28, -90), 0, x, y)
        dot(d, x, y, size * 0.25)
    rng = random.Random(41)
    for _ in range(16):
        a = rng.uniform(146, 214)
        x, y = on_arc(a, R - rng.uniform(-6, 34))
        dot(d, x, y, rng.uniform(0.6, 1.4), fill=int(255 * rng.uniform(0.4, 1)))


# Game themes (2026-11-23, the user's "add more arts more related to the game"): weapons, claws, schools of magic ------

def outward_angle(degrees):
    ox, oy = out_dir(degrees)
    return math.degrees(math.atan2(oy, ox)) + 90  # a shape drawn tip up (-y) then points away from the centre


def upward_angle(degrees):
    tx, ty = -math.sin(math.radians(degrees)), math.cos(math.radians(degrees))  # along the arc, upwards
    return math.degrees(math.atan2(ty, tx)) + 90


def taper(d, points, w0, w1, fill=255):
    n = len(points)
    for i in range(n - 1):
        (x0, y0), (x1, y1) = points[i], points[i + 1]
        for k in range(6):
            t = (i + k / 6) / (n - 1)
            x, y = x0 + (x1 - x0) * k / 6, y0 + (y1 - y0) * k / 6
            dot(d, x, y, (w0 + (w1 - w0) * t) / 2, fill)


SWORD = [
    [(0, -27), (3, -21), (3, 7), (-3, 7), (-3, -21)],
    [(-10, 7), (10, 7), (10, 10.5), (-10, 10.5)],
    [(-1.7, 10.5), (1.7, 10.5), (1.7, 18), (-1.7, 18)],
]


def st_swords(d):
    arc_line(d, R + 2, 1.4, fill=150)
    for a in (156, 180, 204):
        x, y = on_arc(a, R - 16)
        angle = outward_angle(a)
        for part in SWORD:
            shape_at(d, part, angle, x, y)
        px_, py_ = art.rotate([(0, 20.5)], angle)[0]
        dot(d, x + px_, y + py_, 2.6)


def st_daggers(d):
    blade = [(0, -17), (2.2, -11), (2.2, 4), (-2.2, 4), (-2.2, -11)]
    guard = [(-6, 4), (6, 4), (6, 6.5), (-6, 6.5)]
    grip = [(-1.3, 6.5), (1.3, 6.5), (1.3, 12), (-1.3, 12)]
    for k, a in enumerate((150, 165, 180, 195, 210)):
        x, y = on_arc(a, R - 10)
        angle = outward_angle(a) + (24 if k % 2 == 0 else -24)
        for part in (blade, guard, grip):
            shape_at(d, part, angle, x, y)


def st_arrows(d):
    for k, a in enumerate((150, 163, 176, 189, 202)):
        x, y = on_arc(a, R - 6 - (k % 2) * 14)
        angle = upward_angle(a)
        shape_at(d, [(-0.9, -12), (0.9, -12), (0.9, 14), (-0.9, 14)], angle, x, y)  # the shaft
        shape_at(d, [(0, -20), (4.5, -11), (-4.5, -11)], angle, x, y)  # the head
        for side in (-1, 1):  # the fletching
            shape_at(d, [(0, 8), (side * 4.5, 12), (side * 4.5, 17), (0, 13)], angle, x, y, fill=210)


def st_claws(d):
    # three claw marks slashed down across the arc's middle, apart, thick in the middle, sharp at both ends
    for k in range(3):
        dx = (k - 1) * 13
        top = (58 + dx, 74 + k * 4)
        bottom = (30 + dx, 182 - (2 - k) * 4)
        mid = ((top[0] + bottom[0]) / 2 - 9, (top[1] + bottom[1]) / 2)
        pts = art.bezier(top, mid, bottom, 30)
        half = len(pts) // 2
        taper(d, pts[:half + 1], 0.5, 6.0)
        taper(d, pts[half:], 6.0, 0.5)


def skull(d, x, y, size):
    dot(d, x, y - size * 0.15, size)  # the head
    d.rectangle([(x - size * 0.55) * S, (y + size * 0.4) * S, (x + size * 0.55) * S, (y + size * 0.95) * S], fill=255)
    for side in (-1, 1):
        dot(d, x + side * size * 0.38, y - size * 0.1, size * 0.28, fill=0)  # the eyes
    d.polygon(px([(x, y + size * 0.15), (x + size * 0.14, y + size * 0.42), (x - size * 0.14, y + size * 0.42)]), fill=0)
    for k in (-1, 0, 1):  # the teeth
        d.line(px([(x + k * size * 0.22, y + size * 0.6), (x + k * size * 0.22, y + size * 0.95)]), fill=0,
               width=max(1, int(0.9 * S)))


def st_skulls(d):
    rng = random.Random(51)
    for _ in range(14):  # wisps of smoke round them
        a = rng.uniform(146, 214)
        x, y = on_arc(a, R - rng.uniform(-4, 22))
        pts = art.bezier((x, y), (x - rng.uniform(4, 10), y - 8), (x + rng.uniform(-3, 3), y - 18), 10)
        taper(d, pts, 2.2, 0.4, fill=140)
    for a, size in ((158, 8.5), (180, 11), (202, 8.5)):
        x, y = on_arc(a, R - 14)
        skull(d, x, y, size)


def snowflake(d, x, y, r):
    for k in range(6):
        a = math.radians(k * 60 - 90)
        ex, ey = x + r * math.cos(a), y + r * math.sin(a)
        line(d, [(x, y), (ex, ey)], 1.6)
        for f in (0.45, 0.7):
            bx, by = x + r * f * math.cos(a), y + r * f * math.sin(a)
            for side in (-1, 1):
                b = a + side * math.radians(45)
                line(d, [(bx, by), (bx + r * 0.3 * math.cos(b), by + r * 0.3 * math.sin(b))], 1.1)
    dot(d, x, y, r * 0.16)


def st_snowflakes(d):
    arc_line(d, R, 1.4, fill=140)
    for a, r in ((150, 7), (164, 9.5), (180, 12), (196, 9.5), (210, 7)):
        x, y = on_arc(a, R - 13)
        snowflake(d, x, y, r)


def st_light(d):
    # rays of light fanning out of the arc's middle, long and short in turn
    x, y = on_arc(180, R - 4)
    for k in range(-6, 7):
        a = math.radians(180 + k * 8)
        length = (44 if k % 2 == 0 else 30) - abs(k) * 2.5
        half = math.radians(1.6 if k % 2 == 0 else 1.1)
        start = 7
        p0 = (x + start * math.cos(a - half * 3), y + start * math.sin(a - half * 3))
        p1 = (x + start * math.cos(a + half * 3), y + start * math.sin(a + half * 3))
        tip = (x + (start + length) * math.cos(a), y + (start + length) * math.sin(a))
        d.polygon(px([p0, p1, tip]), fill=255 if k % 2 == 0 else 200)
    dot(d, x, y, 7)
    arc_line(d, R, 2.0, 146, 214, fill=170)


def sigil(d, x, y, r):
    # an arcane circle: two rings, a diamond inside, four small marks round it
    for rr, width in ((r, 1.6), (r * 0.68, 1.0)):
        d.ellipse([(x - rr) * S, (y - rr) * S, (x + rr) * S, (y + rr) * S], outline=255, width=max(1, int(width * S)))
    diamond = [(x, y - r * 0.5), (x + r * 0.32, y), (x, y + r * 0.5), (x - r * 0.32, y)]
    d.polygon(px(diamond), fill=255)
    for k in range(4):
        a = math.radians(45 + k * 90)
        mx, my = x + r * 0.84 * math.cos(a), y + r * 0.84 * math.sin(a)
        dot(d, mx, my, max(0.8, r * 0.09))


def st_sigils(d):
    arc_line(d, R - 13, 1.2, fill=150)
    for a, r in ((154, 8), (180, 12.5), (206, 8)):
        x, y = on_arc(a, R - 13)
        sigil(d, x, y, r)
    rng = random.Random(61)
    for _ in range(10):
        a = rng.uniform(148, 212)
        x, y = on_arc(a, R - 13 + rng.uniform(-14, 14))
        dot(d, x, y, rng.uniform(0.6, 1.3), fill=int(255 * rng.uniform(0.5, 1)))


STYLES = {
    "flames": st_flames, "runes": st_runes, "feathers": st_wings, "moons": st_blades, "lightning": st_lightning,
    "vines": st_vines, "crystals": st_crystals, "stars": st_stars, "swords": st_swords, "daggers": st_daggers,
    "arrows": st_arrows, "claws": st_claws, "skulls": st_skulls, "snowflakes": st_snowflakes, "light": st_light,
    "sigils": st_sigils,
}


def render(draw_style):
    size = (W * S, H * S)
    mask = Image.new("L", size, 0)
    draw_style(ImageDraw.Draw(mask))
    mask = ImageChops.multiply(mask, art.fade_mask())
    glow = mask.filter(ImageFilter.GaussianBlur(7 * S))
    halo = mask.filter(ImageFilter.GaussianBlur(16 * S))
    alpha = ImageChops.lighter(ImageChops.lighter(art.scaled(halo, 1.2), art.scaled(glow, 1.9)), mask)
    alpha = ImageChops.multiply(alpha, art.edge_mask())
    out = Image.new("RGBA", size, (255, 255, 255, 0))
    out.putalpha(alpha)
    return out.resize((W, H), Image.LANCZOS)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..")
    folder = os.path.join(root, "Modules", "QoL", "Media", "ProcArt")
    os.makedirs(folder, exist_ok=True)
    images = []
    for key, draw_style in STYLES.items():
        image = render(draw_style)
        path = os.path.join(folder, "style_" + key + ".tga")
        image.save(path)
        images.append(image)
        print("wrote", path)
    if len(sys.argv) > 2:
        sheet = Image.new("RGBA", (len(images) * (W * 2 + 20), H + 20), (24, 22, 28, 255))
        for i, image in enumerate(images):
            tinted = Image.new("RGBA", image.size, (120, 200, 255, 0))
            tinted.putalpha(image.getchannel("A"))
            sheet.alpha_composite(tinted, (i * (W * 2 + 20), 10))
            sheet.alpha_composite(tinted.transpose(Image.FLIP_LEFT_RIGHT), (i * (W * 2 + 20) + W, 10))
        sheet.save(sys.argv[2])
        print("sheet", sys.argv[2])


if __name__ == "__main__":
    main()
