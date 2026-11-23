"""Codex art: the proc art beside your character, one original piece per proc Codex knows (ProcArt.lua, look "codex").

  python proc-codex-art.py <codexDir> [sheet.png]

Writes Modules/QoL/Media/ProcArt/<key>.tga: 128x256 coloured RGBA for the LEFT side (the right side is the same file
mirrored, like the game's side art). Each is the arc of the "arc" look (the circle round (230, 128), radius 190, a "("
fading out at both ends) in the proc's own colours, the proc's emblem just inside the arc's middle (drawn shapes, a
soft glow and a lighter inner edge), and a few particles of its own along the arc. All drawn here, nothing taken from
the game's art. With a second argument it also writes a contact sheet of every piece (for a look).

Stacking procs (STAGED: Heating Up and the seal echoes, 3 stacks) are built up in steps (2026-11-24, the user's
"one stack the inner arc, the second arc with the second, and the symbol when the stacks are full"): their inner arc
is a little brighter (as thin as the others'), and two more files show the steps: <key>_s1.tga = the inner arc alone,
<key>_s2.tga = both arcs; <key>.tga (full) adds the emblem and the particles.

Keys (ProcArt.lua, A.CODEX): overpower, revenge, execute, victory_rush, riposte, counterattack, mongoose_bite,
hammer_of_wrath, unsealed_wrath, shadow_trance, clearcasting_mage, clearcasting_druid, clearcasting_shaman,
missile_barrage, heating_up.
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

W, H, S = 128, 256, 4  # final size; drawn at S times
CX, CY, R = 230, 128, 190  # the arc (as ProcSide.tga)
EX, EY = 70, 128  # the emblem's middle, just inside the arc (76 put long rays against the inner edge)
EDGE_FADE = 16  # px: every piece fades to nothing towards the texture's inner (right) edge, 6 px at the outer one
EMBLEM = 1.3  # emblem shapes are drawn in units of this many px


def P(x, y, cx=EX, cy=EY):
    return ((cx + x * EMBLEM) * S, (cy + y * EMBLEM) * S)


def rotate(points, degrees):
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    return [(x * c - y * s, x * s + y * c) for x, y in points]


def poly(draw, points, degrees=0, dx=0, dy=0, fill=255):
    pts = rotate(points, degrees) if degrees else points
    draw.polygon([P(x + dx, y + dy) for x, y in pts], fill=fill)


def disc(draw, x, y, r, fill=255):
    draw.ellipse([P(x - r, y - r)[0], P(x - r, y - r)[1], P(x + r, y + r)[0], P(x + r, y + r)[1]], fill=fill)


def ring(draw, x, y, r, width, fill=255):
    box = [P(x - r, y - r)[0], P(x - r, y - r)[1], P(x + r, y + r)[0], P(x + r, y + r)[1]]
    draw.ellipse(box, outline=fill, width=int(width * S * EMBLEM))


def stroke(draw, points, width0, width1, fill=255):
    """A tapering stroke along points (a curve), as overlapping discs."""
    n = len(points)
    for i in range(n - 1):
        (x0, y0), (x1, y1) = points[i], points[i + 1]
        steps = 6
        for k in range(steps):
            t = (i + k / steps) / (n - 1)
            x, y = x0 + (x1 - x0) * k / steps, y0 + (y1 - y0) * k / steps
            disc(draw, x, y, (width0 + (width1 - width0) * t) / 2, fill)


def bezier(p0, p1, p2, count=24):
    out = []
    for i in range(count + 1):
        t = i / count
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        out.append((x, y))
    return out


def lens(length, width, segments=16):
    """A leaf / blade lens pointing up, centred on 0,0."""
    pts = []
    for i in range(segments + 1):
        t = i / segments
        y = -length / 2 + length * t
        pts.append((width / 2 * math.sin(math.pi * t), y))
    for i in range(segments, -1, -1):
        t = i / segments
        y = -length / 2 + length * t
        pts.append((-width / 2 * math.sin(math.pi * t), y))
    return pts


def star(points, outer, inner, offset=-90):
    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(offset + i * 180 / points)
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


# Emblems: each draws white on an L mask (`d`) round the emblem's middle, in final px --------------------------------

def sword(d, degrees, length=1.0):
    k = length
    blade = [(0, -34 * k), (3, -28 * k), (3, 10), (-3, 10), (-3, -28 * k)]
    guard = [(-11, 10), (11, 10), (11, 14), (-11, 14)]
    grip = [(-2, 14), (2, 14), (2, 24), (-2, 24)]
    for part in (blade, guard, grip):
        poly(d, part, degrees)
    x, y = rotate([(0, 27)], degrees)[0]
    disc(d, x, y, 3.2)


def e_overpower(d):
    sword(d, -32)
    sword(d, 32)


def e_revenge(d):
    poly(d, star(10, 31, 20, -90))
    # the shield cut out of the burst, then drawn again inside it with a rim
    shield = [(-17, -21), (17, -21), (17, 1), (0, 25), (-17, 1)]
    poly(d, [(x * 1.18, y * 1.18) for x, y in shield], fill=0)
    poly(d, shield)
    poly(d, [(x * 0.62, y * 0.62 - 2) for x, y in shield], fill=0)
    poly(d, [(-2, -11), (2, -11), (2, 9), (-2, 9)])


def e_execute(d):
    # a great axe: the haft, a broad crescent blade on one side, a spike on the other
    poly(d, [(-2.2, -32), (2.2, -32), (2.2, 32), (-2.2, 32)], 18)
    blade = [(2, -26)]
    for i in range(13):
        a = math.radians(-70 + i * 140 / 12)
        blade.append((8 + 24 * math.cos(a), -12 + 24 * math.sin(a)))
    blade.append((2, 2))
    poly(d, blade, 18)
    # the cut that leaves a crescent: towards the haft, so the blade stays broad at its edge
    poly(d, [(-2 + 13 * math.cos(math.radians(-90 + i * 15)), -12 + 13 * math.sin(math.radians(-90 + i * 15)))
             for i in range(13)], 18, fill=0)
    poly(d, [(-2.2, -32), (2.2, -32), (2.2, 32), (-2.2, 32)], 18)
    poly(d, [(-2, -22), (-13, -16), (-2, -10)], 18)


def e_victory_rush(d):
    for side in (-1, 1):
        for i in range(6):
            t = i / 5
            x = 22 * math.cos(math.radians(110 + t * 120)) if side < 0 else 22 * math.cos(math.radians(70 - t * 120))
            y = 22 * math.sin(math.radians(110 + t * 120)) if side < 0 else 22 * math.sin(math.radians(70 - t * 120))
            degrees = math.degrees(math.atan2(y, x)) + 90 + (25 if side < 0 else -25)
            poly(d, lens(13, 6), degrees, x, y + 2)
    poly(d, [(0, -22), (11, -8), (5, -8), (5, 10), (-5, 10), (-5, -8), (-11, -8)])


def e_riposte(d):
    poly(d, [(0, -38), (2.4, -32), (2.4, 12), (-2.4, 12), (-2.4, -32)], -20)
    x, y = rotate([(0, 15)], -20)[0]
    ring(d, x, y, 7.5, 2.2)
    stroke(d, bezier(rotate([(-8, 12)], -20)[0], rotate([(-14, 22)], -20)[0], rotate([(-4, 26)], -20)[0]), 2.6, 1.4)
    x, y = rotate([(0, 26)], -20)[0]
    disc(d, x, y, 2.8)


def e_counterattack(d):
    for i, off in enumerate((-12, 0, 12)):
        pts = bezier((off - 8, -26), (off + 10, -2), (off - 4, 28))
        stroke(d, pts, 7.5 - abs(i - 1) * 1.2, 0.6)


def e_mongoose_bite(d):
    for side in (-1, 1):
        fang = [(side * 4, -20), (side * 16, -20), (side * 12, -4), (side * 8, 10), (side * 4, 22)]
        fang = fang + [(side * 2, 8), (side * 2, -8)]
        poly(d, fang)
    stroke(d, bezier((-20, -24), (0, -30), (20, -24)), 4, 4)


def e_hammer_of_wrath(d):
    for i in range(12):
        a = math.radians(i * 30 + 15)
        poly(d, [(0, -2), (2.2, 0), (0, 2), (-2.2, 0)], 0, 0, 0)
        poly(d, [(-1.6, 0), (1.6, 0), (0.6, -36), (-0.6, -36)], math.degrees(a))
    poly(d, [(-2.6, -6), (2.6, -6), (2.6, 30), (-2.6, 30)], -15, 0, 0, fill=0)
    poly(d, [(-2.6, -6), (2.6, -6), (2.6, 30), (-2.6, 30)], -15)
    head = [(-17, -24), (17, -24), (19, -20), (19, -9), (17, -5), (-17, -5), (-19, -9), (-19, -20)]
    poly(d, [(x * 1.15, y * 1.12) for x, y in head], -15, fill=0)
    poly(d, head, -15)


def e_unsealed_wrath(d):
    for i in range(16):
        a = i * 22.5
        long = i % 2 == 0
        poly(d, [(-1.8, -24), (1.8, -24), (0.4, -36 if long else -31), (-0.4, -36 if long else -31)], a)
    ring(d, 0, 0, 21, 3)
    ring(d, 0, 0, 14, 1.6)
    poly(d, [(-2.4, -10), (2.4, -10), (2.4, 10), (-2.4, 10)])
    poly(d, [(-10, -2.4), (10, -2.4), (10, 2.4), (-10, 2.4)])
    disc(d, 0, 0, 4)


# Unsealed Wrath: one piece per seal's echo, each on a thin seal ring (the family's mark)
def seal_ring(d):
    ring(d, 0, 0, 30, 1.3)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        disc(d, 30 * math.cos(a), 30 * math.sin(a), 1.6)


def e_echo_of_command(d):
    seal_ring(d)
    poly(d, [(-18, 6), (18, 6), (18, 14), (-18, 14)])
    poly(d, [(-18, 6), (-18, -10), (-9, -1), (0, -18), (9, -1), (18, -10), (18, 6)])
    for x, y in ((-18, -12), (0, -21), (18, -12)):
        disc(d, x, y, 3)
    disc(d, 0, 10, 2, fill=0)


def e_echo_of_righteousness(d):
    seal_ring(d)
    sword(d, 180, 0.95)


def e_echo_of_justice(d):
    seal_ring(d)
    poly(d, [(-1.6, -22), (1.6, -22), (1.6, 20), (-1.6, 20)])
    poly(d, [(-20, -15), (20, -15), (20, -12), (-20, -12)])
    poly(d, [(-8, 20), (8, 20), (8, 23), (-8, 23)])
    disc(d, 0, -23, 3)
    for side in (-1, 1):
        x = side * 17
        stroke(d, [(x, -13), (x - 6, 4)], 1, 1)
        stroke(d, [(x, -13), (x + 6, 4)], 1, 1)
        poly(d, [(x - 9, 4)] + [(x + 9 * math.cos(math.radians(a)), 4 + 6 * math.sin(math.radians(a)))
                                 for a in range(0, 181, 20)] + [(x + 9, 4)])


def e_echo_of_fury(d):
    seal_ring(d)
    flame(d, 0, 50, 22, 0.15)
    flame(d, -9, 30, 11, -0.6)
    flame(d, 9, 30, 11, 0.6)


def e_echo_of_light(d):
    seal_ring(d)
    for i in range(12):
        long = i % 2 == 0
        poly(d, [(-2.2, -13), (2.2, -13), (0, -25 if long else -20)], i * 30)
    disc(d, 0, 0, 11)
    disc(d, 0, 0, 6.5, fill=0)
    disc(d, 0, 0, 4)


def e_echo_of_wisdom(d):
    seal_ring(d)
    poly(d, [(-1.5, -8), (-20, -12), (-20, 12), (-1.5, 16)])
    poly(d, [(1.5, -8), (20, -12), (20, 12), (1.5, 16)])
    for y in (-4, 1, 6):
        stroke(d, [(-16, y - 2), (-5, y)], 1, 1, fill=0)
        stroke(d, [(5, y), (16, y - 2)], 1, 1, fill=0)
    poly(d, star(4, 6, 2, -90), 0, 0, -19)


def flame(d, x0, height, width, lean):
    pts = []
    for i in range(21):
        t = i / 20
        y = 24 - height * t
        w = width * math.sin(math.pi * (1 - t) ** 0.8) * (1 - t * 0.35)
        x = x0 + lean * t * t * height * 0.4
        pts.append((x + w / 2, y))
    for i in range(20, -1, -1):
        t = i / 20
        y = 24 - height * t
        w = width * math.sin(math.pi * (1 - t) ** 0.8) * (1 - t * 0.35)
        x = x0 + lean * t * t * height * 0.4
        pts.append((x - w / 2, y))
    poly(d, pts)


def e_shadow_trance(d):
    flame(d, -11, 40, 15, -0.5)
    flame(d, 11, 38, 15, 0.5)
    flame(d, 0, 56, 20, 0.1)
    poly(d, lens(14, 7), 0, 0, 10, fill=0)
    disc(d, -4, 6, 2.2, fill=0)
    disc(d, 4, 6, 2.2, fill=0)


def e_clearcasting_mage(d):
    ring(d, 0, 0, 25, 2.2)
    ring(d, 0, 0, 19, 1.2)
    poly(d, star(6, 17, 7, -90))
    for i in range(6):
        a = math.radians(-90 + i * 60 + 30)
        disc(d, 22 * math.cos(a), 22 * math.sin(a), 1.8)
    disc(d, 0, 0, 3.2, fill=0)


def e_clearcasting_druid(d):
    disc(d, -2, -6, 20)
    disc(d, 7, -10, 17, fill=0)
    poly(d, lens(26, 11), 35, 6, 14)
    stroke(d, [(6 - 7, 14 + 10), (6 + 6, 14 - 9)], 1.4, 0.6, fill=0)


def e_clearcasting_shaman(d):
    bolt = [(6, -34), (-10, -2), (1, -2), (-7, 32), (13, -8), (2, -8), (12, -34)]
    poly(d, bolt)
    for x, y, r in ((-16, -18, 1.8), (16, 12, 1.6), (-14, 20, 1.3)):
        disc(d, x, y, r)


def e_missile_barrage(d):
    # three arcane missiles flying up and out: a thin trail widening to a bright round head
    for dx, dy, length in ((-11, 9, 26), (0, 0, 32), (11, -9, 26)):
        tail = rotate([(0, length / 2)], -40)[0]
        head = rotate([(0, -length / 2)], -40)[0]
        stroke(d, [(dx + tail[0], dy + tail[1]), (dx + head[0], dy + head[1])], 1.4, 3.6)
        disc(d, dx + head[0], dy + head[1], 4.6)
        disc(d, dx + head[0], dy + head[1], 1.6, fill=0)


def e_heating_up(d):
    # a fireball: a solid orb with a tall flame rising from it, and three pips under it (the three stacks)
    flame(d, 0, 58, 22, 0.15)
    flame(d, -9, 36, 11, -0.6)
    flame(d, 9, 34, 11, 0.6)
    disc(d, 0, 10, 15)
    disc(d, -3, 7, 5, fill=0)
    for x, y in ((-13, 33), (0, 36), (13, 33)):
        disc(d, x, y, 3.6)


# The procs: key -> emblem, colours { core, glow, arc, particles }, particle kind -----------------------------------

ARTS = {
    "overpower": (e_overpower, (255, 214, 170), (255, 92, 36), (255, 140, 60), "embers"),
    "revenge": (e_revenge, (255, 226, 190), (240, 110, 40), (255, 165, 70), "embers"),
    "execute": (e_execute, (255, 200, 200), (210, 20, 30), (240, 60, 50), "embers"),
    "victory_rush": (e_victory_rush, (255, 244, 200), (230, 180, 40), (250, 210, 90), "sparks"),
    "riposte": (e_riposte, (235, 245, 255), (120, 170, 255), (170, 200, 255), "sparks"),
    "counterattack": (e_counterattack, (255, 236, 200), (230, 150, 40), (250, 190, 90), "sparks"),
    "mongoose_bite": (e_mongoose_bite, (236, 255, 210), (120, 210, 60), (170, 230, 110), "motes"),
    "hammer_of_wrath": (e_hammer_of_wrath, (255, 248, 220), (255, 196, 60), (255, 220, 120), "sparks"),
    "echo_of_command": (e_echo_of_command, (255, 246, 214), (255, 150, 30), (255, 196, 90), "sparks"),
    "echo_of_righteousness": (e_echo_of_righteousness, (255, 252, 236), (255, 206, 90), (255, 232, 160), "sparks"),
    "echo_of_justice": (e_echo_of_justice, (232, 242, 255), (90, 150, 255), (170, 200, 255), "motes"),
    "echo_of_fury": (e_echo_of_fury, (255, 228, 200), (240, 60, 30), (255, 120, 60), "embers"),
    "echo_of_light": (e_echo_of_light, (255, 255, 236), (255, 226, 80), (255, 240, 150), "sparks"),
    "echo_of_wisdom": (e_echo_of_wisdom, (230, 248, 255), (70, 170, 240), (150, 210, 255), "motes"),
    "shadow_trance": (e_shadow_trance, (232, 200, 255), (130, 40, 220), (170, 90, 255), "motes"),
    "clearcasting_mage": (e_clearcasting_mage, (226, 236, 255), (90, 120, 255), (150, 170, 255), "motes"),
    "clearcasting_druid": (e_clearcasting_druid, (230, 255, 225), (60, 190, 90), (130, 225, 140), "motes"),
    "clearcasting_shaman": (e_clearcasting_shaman, (225, 252, 255), (40, 180, 240), (120, 220, 255), "sparks"),
    # (new pieces go last: each piece's particles come from its place in this list)
    "missile_barrage": (e_missile_barrage, (255, 228, 255), (200, 80, 255), (225, 145, 255), "sparks"),
    "heating_up": (e_heating_up, (255, 236, 196), (255, 96, 20), (255, 160, 60), "embers"),
}


def fade_mask():
    """The arc's fade towards both ends (as ProcSide.tga)."""
    column = []
    for y in range(H * S):
        t = abs(y + 0.5 - H * S / 2) / (H * S / 2)
        column.append(int(255 * max(0.0, 1 - t ** 2.2) ** 1.4))
    strip = Image.new("L", (1, H * S))
    strip.putdata(column)
    return strip.resize((W * S, H * S))


STAGED = {"heating_up", "echo_of_command", "echo_of_righteousness", "echo_of_justice", "echo_of_fury",
          "echo_of_light", "echo_of_wisdom"}


def arc_masks(strong=False):
    """The outer arc (core) and the thin inner one (echo); `strong`: the inner one as a full arc of its own (the
    first stack of a stacking proc)."""
    core = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(core)
    box = [(CX - R) * S, (CY - R) * S, (CX + R) * S, (CY + R) * S]
    d.ellipse(box, outline=255, width=int(3 * S))
    echo = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(echo)
    r2 = R - 18
    d.ellipse([(CX - r2) * S, (CY - r2) * S, (CX + r2) * S, (CY + r2) * S], outline=170 if strong else 95,
              width=int(2 * S))  # (thin as ever: a thicker one looked too big, the user 2026-11-24)
    fade = fade_mask()
    core = ImageChops.multiply(core, fade)
    echo = ImageChops.multiply(echo, fade)
    return core, echo


def particles(kind, seed):
    rng = random.Random(seed)
    mask = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(mask)
    count = {"embers": 16, "sparks": 12, "motes": 14}[kind]
    for _ in range(count):
        a = math.radians(rng.uniform(150, 210))
        r = R + rng.uniform(-30, 8)
        x, y = CX + r * math.cos(a), CY + r * math.sin(a)
        if not (6 < x < W - 6 and 18 < y < H - 18):
            continue
        fade = max(0.0, 1 - (abs(y - CY) / CY) ** 2)
        value = int(255 * fade * rng.uniform(0.45, 1))
        if kind == "embers":
            size = rng.uniform(0.9, 2.0)
            d.ellipse([(x - size) * S, (y - size * 1.5) * S, (x + size) * S, (y + size * 1.5) * S], fill=value)
        elif kind == "sparks":
            size = rng.uniform(1.6, 3.4)
            pts = [(x, y - size), (x + size * 0.3, y - size * 0.3), (x + size, y), (x + size * 0.3, y + size * 0.3),
                   (x, y + size), (x - size * 0.3, y + size * 0.3), (x - size, y), (x - size * 0.3, y - size * 0.3)]
            d.polygon([(px * S, py * S) for px, py in pts], fill=value)
        else:
            size = rng.uniform(0.8, 1.8)
            d.ellipse([(x - size) * S, (y - size) * S, (x + size) * S, (y + size) * S], fill=value)
    return mask


def layer(color, mask):
    image = Image.new("RGBA", mask.size, color + (0,))
    image.putalpha(mask)
    return image


def scaled(mask, factor):
    return mask.point(lambda v: min(255, int(v * factor)))


def render(key, emblem, core, glow, arc, kind, seed, stage=None):
    """stage: None = the full piece; 1 = the inner arc alone, 2 = both arcs (stacking procs, STAGED)."""
    size = (W * S, H * S)
    strong = key in STAGED
    arc_core, arc_echo = arc_masks(strong)
    arc_glow = arc_core.filter(ImageFilter.GaussianBlur(9 * S))
    mark = Image.new("L", size, 0)
    emblem(ImageDraw.Draw(mark))
    mark_glow = mark.filter(ImageFilter.GaussianBlur(6 * S))
    mark_halo = mark.filter(ImageFilter.GaussianBlur(16 * S))
    inner = mark.filter(ImageFilter.MinFilter(int(3 * S) | 1))  # the inner part: lighter
    dust = particles(kind, seed)
    dust_glow = dust.filter(ImageFilter.GaussianBlur(2 * S))

    full = stage is None
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    if full:
        out.alpha_composite(layer(glow, scaled(mark_halo, 1.1)))
    if full or stage >= 2:
        out.alpha_composite(layer(glow, scaled(arc_glow, 1.6)))
    out.alpha_composite(layer(arc, arc_echo))
    if full or stage >= 2:
        out.alpha_composite(layer(arc, arc_core))
        out.alpha_composite(layer(core, scaled(arc_core, 0.55)))
    if full:
        out.alpha_composite(layer(glow, scaled(dust_glow, 1.4)))
        out.alpha_composite(layer(core, dust))
        out.alpha_composite(layer(glow, scaled(mark_glow, 2.2)))
        out.alpha_composite(layer(arc, mark))
        out.alpha_composite(layer(core, scaled(inner, 0.9)))
    # a glow reaching the texture's edge was cut there in a straight line (the user's "glow is cut and looks
    # square", Hammer of Wrath, 2026-11-21): fade every piece out towards both edges
    alpha = out.getchannel("A")
    out.putalpha(ImageChops.multiply(alpha, edge_mask()))
    return out.resize((W, H), Image.LANCZOS)


def edge_mask():
    """1 inside, falling to 0 over EDGE_FADE px at the inner (right) edge and 6 px at the outer one."""
    row = []
    for x in range(W * S):
        px = (x + 0.5) / S
        right = min(1.0, (W - px) / EDGE_FADE)
        left = min(1.0, px / 6)
        t = max(0.0, min(right, left))
        row.append(int(255 * t * t * (3 - 2 * t)))  # smoothstep
    strip = Image.new("L", (W * S, 1))
    strip.putdata(row)
    return strip.resize((W * S, H * S))


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
    folder = os.path.join(root, "Modules", "QoL", "Media", "ProcArt")
    os.makedirs(folder, exist_ok=True)
    images = []
    for index, (key, (emblem, core, glow, arc, kind)) in enumerate(ARTS.items()):
        if key in STAGED:
            for stage in (1, 2):
                step = render(key, emblem, core, glow, arc, kind, 1000 + index, stage)
                path = os.path.join(folder, "%s_s%d.tga" % (key, stage))
                step.save(path)
                images.append(("%s_s%d" % (key, stage), step))
                print("wrote", path)
        image = render(key, emblem, core, glow, arc, kind, 1000 + index)
        path = os.path.join(folder, key + ".tga")
        image.save(path)
        images.append((key, image))
        print("wrote", path)
    if len(sys.argv) > 2:
        cols = 7
        rows = (len(images) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * (W * 2 + 20), rows * (H + 20)), (24, 22, 28, 255))
        for i, (key, image) in enumerate(images):
            x, y = (i % cols) * (W * 2 + 20), (i // cols) * (H + 20)
            sheet.alpha_composite(image, (x, y))
            sheet.alpha_composite(image.transpose(Image.FLIP_LEFT_RIGHT), (x + W, y))
        sheet.save(sys.argv[2])
        print("sheet", sys.argv[2])


if __name__ == "__main__":
    main()
