"""Textures for Quality of life > Glow on proc abilities (Modules/QoL/ProcGlow.lua).

  python glow-art.py <codexDir>

Writes white RGBA TGAs (tinted in game with SetVertexColor) to Modules/QoL/Media/:
  GlowSquare.tga   128x128 soft halo round a square icon: the icon is the middle 64x64 (drawn at twice the
                   button's size), clear inside, brightest at the icon's edge, gone 32 px out
  GlowRound.tga    the same round a round icon (radius 32)
  GlowDot.tga      32x32 soft dot (the marching sparkles when the game's autocast art is missing, or round icons)
  GlowRing1..3.tga 128x128 anti-aliased ring touching the texture edge, 3 / 6 / 9 px wide (the pulsing border on
                   round icons, thickness 1-3; drawn at the icon's size + 6)
  ProcSide.tga     128x256 glowing arc, "(" shaped, for the art beside your character (ProcArt.lua) when the
                   game's own art for a proc is missing or not wanted; the right side uses it mirrored
  ProcIconMask.tga 64x64 mask for the "spell's icon" look: a disc, solid to 60 % of its radius, then fading out
                   (the spell's icons sit along the arc with soft round edges)
Action buttons are square in every Codex look; the round ones are for the cooldown manager's icons, which are round
with the "Round icons" part.
"""
import math
import os
import sys

from PIL import Image, ImageDraw


def save(alpha, path):
    image = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    image.putalpha(alpha)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print("wrote", path)


def falloff(d, reach):
    """1 at the edge, 0 at `reach` outside (smooth); a short ramp just inside the edge."""
    if d < -2.5:
        return 0.0
    if d < 0:
        return (d + 2.5) / 2.5
    t = min(1.0, d / reach)
    return (1 - t) ** 2 * (1 + 2 * t) * 0.95


def halo(path, round_icon=False):
    size, half, inner, reach, corner = 128, 64, 32, 30, 4
    alpha = Image.new("L", (size, size), 0)
    pixels = alpha.load()
    for y in range(size):
        for x in range(size):
            px, py = x + 0.5 - half, y + 0.5 - half
            if round_icon:
                d = math.hypot(px, py) - inner
            else:
                # distance outside a rounded square of half-size `inner`
                qx, qy = abs(px) - (inner - corner), abs(py) - (inner - corner)
                outside = math.hypot(max(qx, 0), max(qy, 0))
                d = outside + min(max(qx, qy), 0) - corner
            pixels[x, y] = int(round(255 * falloff(d, reach)))
    save(alpha, path)


def dot(path):
    size = 32
    half = size / 2
    alpha = Image.new("L", (size, size), 0)
    pixels = alpha.load()
    for y in range(size):
        for x in range(size):
            t = min(1.0, math.hypot(x + 0.5 - half, y + 0.5 - half) / half)
            pixels[x, y] = int(round(255 * (1 - t) ** 2))
    save(alpha, path)


def ring(path, width):
    size, scale = 128, 8
    big = size * scale
    alpha = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(alpha)
    margin = scale
    draw.ellipse((margin, margin, big - 1 - margin, big - 1 - margin), fill=255)
    inset = margin + width * scale
    draw.ellipse((inset, inset, big - 1 - inset, big - 1 - inset), fill=0)
    save(alpha.resize((size, size), Image.LANCZOS), path)


def side_arc(path):
    """A "(" arc: a bright core line with a soft glow and a fainter inner echo, fading out at both ends."""
    width, height, scale = 128, 256, 2
    w, h = width * scale, height * scale
    alpha = Image.new("L", (w, h), 0)
    pixels = alpha.load()
    cx, cy, r = 230 * scale, h / 2, 190 * scale
    for y in range(h):
        t = abs(y + 0.5 - cy) / cy                     # 0 in the middle, 1 at the ends
        fade = max(0.0, 1 - t ** 2.2) ** 1.4
        if fade <= 0:
            continue
        for x in range(w):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) - r
            core = math.exp(-(d / (3.2 * scale)) ** 2)
            glow = math.exp(-(d / (16 * scale)) ** 2) * 0.45
            echo = math.exp(-((d + 18 * scale) / (2.2 * scale)) ** 2) * 0.35
            value = min(1.0, core + glow + echo) * fade
            pixels[x, y] = int(round(255 * value))
    save(alpha.resize((width, height), Image.LANCZOS), path)


def icon_mask(path):
    size = 64
    half = size / 2
    alpha = Image.new("L", (size, size), 0)
    pixels = alpha.load()
    for y in range(size):
        for x in range(size):
            t = math.hypot(x + 0.5 - half, y + 0.5 - half) / (half - 1)
            value = 1.0 if t <= 0.6 else max(0.0, 1 - (t - 0.6) / 0.4)
            pixels[x, y] = int(round(255 * value * value * (3 - 2 * value)))
    save(alpha, path)


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
    media = os.path.join(root, "Modules", "QoL", "Media")
    halo(os.path.join(media, "GlowSquare.tga"))
    halo(os.path.join(media, "GlowRound.tga"), True)
    dot(os.path.join(media, "GlowDot.tga"))
    for index, width in enumerate((3, 6, 9), start=1):
        ring(os.path.join(media, "GlowRing%d.tga" % index), width)
    side_arc(os.path.join(media, "ProcSide.tga"))
    icon_mask(os.path.join(media, "ProcIconMask.tga"))
