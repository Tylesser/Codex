"""The soft outer shadow behind Codex panels and skinned windows (Look options: "Soft shadows").

  python shadow.py <codexDir>

Writes Media/Shadow.tga: 64x64, black, alpha falling off from the centre (1) to the edge (0). Widgets.lua cuts it
into a nine-slice: the four quadrants are the round corners, a one-pixel column / row through the middle are the
edges (stretched along each side). The centre is never drawn, so the panel's own see-through fill stays as it is.
"""
import math
import os
import sys

from PIL import Image

SIZE = 64


def render(path):
    half = SIZE / 2
    alpha = Image.new("L", (SIZE, SIZE), 0)
    pixels = alpha.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r = math.hypot(x + 0.5 - half, y + 0.5 - half) / half
            t = min(1.0, r)
            # smooth falloff: dark next to the panel, gone at the outer edge
            value = (1 - t) ** 2 * (1 + 2 * t) if t < 1 else 0  # 1 - smoothstep
            pixels[x, y] = int(round(255 * value))
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    image.putalpha(alpha)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print("wrote", path)


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..")
    render(os.path.join(root, "Media", "Shadow.tga"))
