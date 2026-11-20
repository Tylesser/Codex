"""The scene behind the Quest windows page's three style pictures (Modules/Dialogue/Page.lua).

  python dialogue-art.py <codexDir>

Writes Modules/Dialogue/Media/PreviewScene.tga (512x256: an evening sky, far mountains, hills, a meadow with a path,
trees at the sides) and PreviewNpc.tga (128x256: a robed figure with a warm rim light and a quest mark above it).
Drawn at 4x and scaled down (smooth edges). The windows on top stay drawn in the theme's colours by Page.lua. They
replaced flat boxes (the user's screenshot of the style cards, 2026-11-21: "update images in here").
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 4


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def vertical(draw, box, top, bottom):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        draw.line([(x0, y), (x1, y)], fill=lerp(top, bottom, t))


def ridge(width, base, amp, seed, step, smooth=3):
    rnd = random.Random(seed)
    points = []
    heights = [rnd.uniform(-1, 1) for _ in range(width // step + 3)]
    for _ in range(smooth):
        heights = [(heights[max(0, i - 1)] + heights[i] * 2 + heights[min(len(heights) - 1, i + 1)]) / 4
                   for i in range(len(heights))]
    for i, h in enumerate(heights):
        points.append((i * step, base + h * amp))
    return points


def scene(path):
    W, H = 512 * S, 256 * S
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    horizon = int(H * 0.58)
    vertical(d, (0, 0, W, horizon), (58, 72, 108), (214, 168, 120))
    # the sun's glow low in the sky
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse([W * 0.55, horizon - 160 * S, W * 0.95, horizon + 60 * S], fill=170)
    glow = glow.filter(ImageFilter.GaussianBlur(50 * S))
    img = Image.composite(Image.new("RGB", (W, H), (255, 214, 150)), img, glow)
    d = ImageDraw.Draw(img)
    # soft clouds
    clouds = Image.new("L", (W, H), 0)
    cd = ImageDraw.Draw(clouds)
    rnd = random.Random(7)
    for _ in range(14):
        x, y = rnd.uniform(0, W), rnd.uniform(20 * S, horizon * 0.55)
        cd.ellipse([x - 60 * S, y - 7 * S, x + 60 * S, y + 7 * S], fill=rnd.randint(20, 50))
    clouds = clouds.filter(ImageFilter.GaussianBlur(8 * S))
    img = Image.composite(Image.new("RGB", (W, H), (236, 214, 200)), img, clouds)
    d = ImageDraw.Draw(img)
    # far mountains, hills, meadow
    far = ridge(W, horizon - 34 * S, 26 * S, 3, 24 * S)
    d.polygon(far + [(W, H), (0, H)], fill=(84, 96, 130))
    mid = ridge(W, horizon - 4 * S, 14 * S, 11, 30 * S)
    d.polygon(mid + [(W, H), (0, H)], fill=(58, 74, 62))
    vertical(d, (0, horizon + 6 * S, W, H), (78, 102, 52), (34, 46, 22))
    near = ridge(W, horizon + 8 * S, 6 * S, 19, 40 * S)
    d.polygon(near + [(W, horizon + 40 * S), (0, horizon + 40 * S)], fill=(70, 94, 46))
    vertical(d, (0, horizon + 26 * S, W, H), (66, 88, 42), (30, 40, 20))
    # a path winding to the horizon
    road = [(W * 0.47, horizon + 8 * S), (W * 0.53, horizon + 8 * S), (W * 0.6, H), (W * 0.4, H)]
    d.polygon(road, fill=(138, 118, 84))
    # trees at both sides
    for x, base, size in ((40, 0.78, 1.0), (88, 0.74, 0.7), (440, 0.80, 1.1), (478, 0.75, 0.8)):
        cx, by = x * S, H * base
        d.rectangle([cx - 3 * S * size, by - 30 * S * size, cx + 3 * S * size, by], fill=(34, 24, 18))
        for k, r in enumerate((26, 22, 16)):
            yy = by - (34 + k * 16) * S * size
            d.ellipse([cx - r * S * size, yy - r * S * size * 0.8, cx + r * S * size, yy + r * S * size * 0.8],
                      fill=(30 + k * 6, 52 + k * 8, 30 + k * 4))
    # grass blades in front
    rnd = random.Random(23)
    for _ in range(900):
        x, y = rnd.uniform(0, W), rnd.uniform(horizon + 30 * S, H)
        h = rnd.uniform(3, 9) * S * (0.4 + (y - horizon) / (H - horizon))
        d.line([(x, y), (x + rnd.uniform(-2, 2) * S, y - h)], fill=(96, 124, 58), width=S)
    # a soft vignette
    vig = Image.new("L", (W, H), 0)
    ImageDraw.Draw(vig).ellipse([-W * 0.2, -H * 0.4, W * 1.2, H * 1.4], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(60 * S))
    img = Image.composite(img, Image.new("RGB", (W, H), (14, 14, 20)), vig)
    img = img.resize((512, 256), Image.LANCZOS)
    img.save(path)
    print("wrote", path)


def npc(path):
    W, H = 128 * S, 256 * S
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    cx = W / 2
    # robe, shoulders, hood and head
    d.polygon([(cx - 22 * S, 104 * S), (cx + 22 * S, 104 * S), (cx + 40 * S, 250 * S), (cx - 40 * S, 250 * S)], fill=255)
    d.ellipse([cx - 30 * S, 92 * S, cx + 30 * S, 128 * S], fill=255)
    d.ellipse([cx - 17 * S, 62 * S, cx + 17 * S, 104 * S], fill=255)
    d.polygon([(cx - 19 * S, 80 * S), (cx, 54 * S), (cx + 19 * S, 80 * S)], fill=255)
    # a staff
    d.rectangle([cx + 34 * S, 70 * S, cx + 38 * S, 250 * S], fill=255)
    d.ellipse([cx + 29 * S, 62 * S, cx + 43 * S, 76 * S], fill=255)
    body = Image.new("RGBA", (W, H), (30, 22, 20, 255))
    # warm rim light on the left edge (the sun is low on the right: rim on the right)
    rim = mask.filter(ImageFilter.GaussianBlur(3 * S))
    shifted = Image.new("L", (W, H), 0)
    shifted.paste(mask, (-4 * S, 0))
    edge = Image.eval(Image.composite(Image.new("L", (W, H), 0), mask, shifted), lambda v: v)
    edge = edge.filter(ImageFilter.GaussianBlur(2 * S))
    lit = Image.new("RGBA", (W, H), (230, 170, 110, 255))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(body, (0, 0), mask)
    out.paste(lit, (0, 0), Image.eval(edge, lambda v: int(v * 0.8)))
    alpha = Image.composite(mask, Image.new("L", (W, H), 0), mask)
    out.putalpha(alpha)
    # the quest mark above the head
    mark = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    md = ImageDraw.Draw(mark)
    md.polygon([(cx - 7 * S, 14 * S), (cx + 7 * S, 14 * S), (cx + 4 * S, 40 * S), (cx - 4 * S, 40 * S)], fill=(255, 209, 0, 255))
    md.ellipse([cx - 5 * S, 43 * S, cx + 5 * S, 53 * S], fill=(255, 209, 0, 255))
    glow = mark.split()[3].filter(ImageFilter.GaussianBlur(5 * S))
    halo = Image.new("RGBA", (W, H), (255, 220, 90, 0))
    halo.putalpha(Image.eval(glow, lambda v: int(v * 0.6)))
    out = Image.alpha_composite(out, halo)
    out = Image.alpha_composite(out, mark)
    out = out.resize((128, 256), Image.LANCZOS)
    out.save(path)
    print("wrote", path)


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
    folder = os.path.join(root, "Modules", "Dialogue", "Media")
    os.makedirs(folder, exist_ok=True)
    scene(os.path.join(folder, "PreviewScene.tga"))
    npc(os.path.join(folder, "PreviewNpc.tga"))
