"""Arc textures for Personal bars' "Arcs beside the character" layout (Modules/Resource/Media).

One band of a circle, 64 x 256: "(" in Arc.tga (the left bar, health), ")" in ArcRight.tga; the *Back files are the
same band 2 px wider on each side (the dark track, which shows as a rim around the fill). The band's centre line
runs from (ARC_END, 0) through (ARC_MID, 128) to (ARC_END, 256); Bars.lua's ArcX() uses the same numbers to put the
sparks on the curve, so keep them in step. White, alpha = coverage (4x4 supersampled).

  python -I arc_textures.py <Codex folder>
"""
import math, os, sys
from PIL import Image

W, H, BAND = 64, 256, 16
ARC_END, ARC_MID = W - BAND / 2 - 1, BAND / 2 + 1  # 55, 9: the centre line's x at the ends and in the middle
D, HALF = ARC_END - ARC_MID, H / 2
RADIUS = (D * D + HALF * HALF) / (2 * D)
CX, CY = ARC_MID + RADIUS, HALF
SS = 4


def band(width):
    img = Image.new("RGBA", (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            hit = 0
            for sy in range(SS):
                for sx in range(SS):
                    u, v = x + (sx + 0.5) / SS, y + (sy + 0.5) / SS
                    if abs(math.hypot(u - CX, v - CY) - RADIUS) <= width / 2:
                        hit += 1
            px[x, y] = (255, 255, 255, round(255 * hit / (SS * SS)))
    return img


def main(codex):
    out = os.path.join(codex, "Modules", "Resource", "Media")
    os.makedirs(out, exist_ok=True)
    for name, width in (("Arc", BAND), ("ArcBack", BAND + 4)):
        img = band(width)
        img.save(os.path.join(out, name + ".tga"))
        img.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(out, name.replace("Arc", "ArcRight") + ".tga"))
    print("radius %.2f, centre %.2f; written to %s" % (RADIUS, CX, out))


if __name__ == "__main__":
    main(sys.argv[1])
