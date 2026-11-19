"""Icons for Quality of life > Map extras (Modules/QoL/MapExtras.lua): dungeon and raid entrances and town services.

  python map-art.py <codexDir>

Writes Modules/QoL/Media/MapIcons.tga: 512x256, 8 columns x 4 rows of 64 px cells, white glyphs on a clear ground
(tinted in game with SetVertexColor, drawn on our own dark disc). Each glyph is drawn at 4x (256 px) with Pillow's
shapes and scaled down, so the edges are smooth. Cell order (index = row * 8 + column; MapExtras.lua's ICONS):
  0 dungeon (gate)    1 raid (skull)     2 inn (mug)         3 flight (wings)   4 bank (coins)     5 auction (gavel)
  6 mail (envelope)   7 class trainer (book)                 8 profession trainer (open book)      9 repair (anvil)
 10 vendor (bag)     11 stable (paw)    12 battlemaster (crossed swords)        13 spirit healer (ankh)
 14 guild (banner)   15 weapon master (sword)               16 riding (horseshoe)                 17 barber (scissors)
 18 transmog (hanger) 19 disc (the pin's ground)            20 ring (the pin's edge)              21 filter (funnel)
 22 food (drumstick) 23 reagent (flask)
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw

BIG = 256  # drawing size of one cell
CELL = 64
COLS, ROWS = 8, 4


def canvas():
    image = Image.new("L", (BIG, BIG), 0)
    return image, ImageDraw.Draw(image)


def sword():
    image, d = canvas()
    d.polygon([(128, 8), (146, 40), (146, 168), (110, 168), (110, 40)], fill=255)  # blade
    d.rectangle((72, 168, 184, 186), fill=255)  # guard
    d.rectangle((118, 186, 138, 228), fill=255)  # grip
    d.ellipse((112, 222, 144, 252), fill=255)  # pommel
    return image


def glyph(index):
    image, d = canvas()
    if index == 0:  # dungeon: a gate with a portcullis
        d.rectangle((40, 104, 216, 232), fill=255)
        d.pieslice((40, 24, 216, 200), 180, 360, fill=255)
        d.rectangle((80, 132, 176, 232), fill=0)
        d.pieslice((80, 84, 176, 180), 180, 360, fill=0)
        for x in (104, 128, 152):
            d.rectangle((x - 5, 100, x + 5, 232), fill=255)
        for y in (150, 190):
            d.rectangle((80, y - 5, 176, y + 5), fill=255)
    elif index == 1:  # raid: a skull
        d.ellipse((48, 20, 208, 172), fill=255)
        d.rounded_rectangle((84, 136, 172, 220), 18, fill=255)
        d.ellipse((76, 84, 120, 132), fill=0)
        d.ellipse((136, 84, 180, 132), fill=0)
        d.polygon([(128, 136), (114, 162), (142, 162)], fill=0)
        for x in (110, 128, 146):
            d.rectangle((x - 4, 188, x + 4, 222), fill=0)
    elif index == 2:  # inn: a mug with foam
        d.rounded_rectangle((52, 84, 168, 228), 18, fill=255)
        d.ellipse((138, 104, 220, 196), outline=255, width=22)
        for cx in (70, 104, 138, 160):
            d.ellipse((cx - 26, 46, cx + 26, 100), fill=255)
        d.rectangle((84, 120, 96, 204), fill=0)
        d.rectangle((124, 120, 136, 204), fill=0)
    elif index == 3:  # flight: wings
        left = [(122, 156), (96, 104), (60, 70), (12, 56), (34, 90), (8, 100), (40, 122), (20, 138), (56, 150),
                (44, 172), (90, 176), (112, 196)]
        d.polygon(left, fill=255)
        d.polygon([(256 - x, y) for x, y in left], fill=255)
        d.ellipse((108, 120, 148, 204), fill=255)
    elif index == 4:  # bank: a stack of coins
        for i, y in enumerate((178, 140, 102)):
            d.ellipse((48, y - 4, 208, y + 60), fill=0)
            d.rectangle((52, y + 20, 204, y + 44), fill=255)
            d.ellipse((52, y + 20, 204, y + 68), fill=255)
            d.ellipse((52, y, 204, y + 44), fill=255)
            d.ellipse((52, y, 204, y + 44), outline=0, width=8)
            d.ellipse((92, y + 12, 164, y + 32), outline=0, width=6)
    elif index == 5:  # auction: a gavel on a block
        head, hd = canvas()
        hd.rounded_rectangle((60, 36, 196, 104), 10, fill=255)
        hd.rectangle((48, 28, 76, 112), fill=255)
        hd.rectangle((180, 28, 208, 112), fill=255)
        hd.rectangle((116, 100, 140, 236), fill=255)
        image = head.rotate(40, resample=Image.BICUBIC, center=(128, 128))
        d = ImageDraw.Draw(image)
        d.rounded_rectangle((28, 206, 156, 238), 8, fill=255)
    elif index == 6:  # mail: an envelope
        d.rounded_rectangle((20, 60, 236, 196), 14, fill=255)
        d.line([(28, 70), (128, 146), (228, 70)], fill=0, width=14, joint="curve")
    elif index == 7:  # class trainer: a closed book with a gem
        d.rounded_rectangle((56, 24, 200, 232), 12, fill=255)
        d.rectangle((76, 24, 88, 232), fill=0)
        d.rectangle((188, 44, 200, 212), fill=0)
        d.polygon([(140, 92), (168, 128), (140, 164), (112, 128)], fill=0)
    elif index == 8:  # profession trainer: an open book
        d.polygon([(16, 60), (122, 84), (122, 220), (16, 196)], fill=255)
        d.polygon([(240, 60), (134, 84), (134, 220), (240, 196)], fill=255)
        for i in range(4):
            y = 104 + i * 24
            d.line([(36, y - 10), (104, y + 6)], fill=0, width=7)
            d.line([(220, y - 10), (152, y + 6)], fill=0, width=7)
    elif index == 9:  # repair: an anvil
        d.polygon([(12, 64), (64, 64), (64, 112), (40, 100)], fill=255)
        d.rectangle((64, 64, 236, 112), fill=255)
        d.rectangle((112, 112, 176, 170), fill=255)
        d.polygon([(84, 170), (204, 170), (224, 216), (64, 216)], fill=255)
    elif index == 10:  # vendor: a bag
        d.ellipse((40, 88, 216, 236), fill=255)
        d.rectangle((100, 56, 156, 108), fill=255)
        d.polygon([(76, 24), (180, 24), (160, 64), (96, 64)], fill=255)
        d.rectangle((92, 96, 164, 108), fill=0)
        d.ellipse((108, 142, 148, 182), outline=0, width=8)
    elif index == 11:  # stable: a paw
        d.ellipse((72, 120, 184, 220), fill=255)
        d.ellipse((28, 76, 80, 140), fill=255)
        d.ellipse((76, 28, 124, 100), fill=255)
        d.ellipse((132, 28, 180, 100), fill=255)
        d.ellipse((176, 76, 228, 140), fill=255)
    elif index == 12:  # battlemaster: crossed swords
        one = sword()
        image = ImageChops.lighter(one.rotate(40, resample=Image.BICUBIC, center=(128, 128)),
                                   one.rotate(-40, resample=Image.BICUBIC, center=(128, 128)))
    elif index == 13:  # spirit healer: an ankh
        d.ellipse((84, 16, 172, 120), outline=255, width=24)
        d.rectangle((52, 112, 204, 138), fill=255)
        d.polygon([(114, 112), (142, 112), (152, 240), (104, 240)], fill=255)
    elif index == 14:  # guild: a banner
        d.rounded_rectangle((40, 20, 216, 40), 8, fill=255)
        d.polygon([(64, 40), (192, 40), (192, 224), (128, 184), (64, 224)], fill=255)
        d.polygon([(128, 72), (156, 112), (128, 152), (100, 112)], fill=0)
    elif index == 15:  # weapon master: a sword
        image = sword().rotate(-40, resample=Image.BICUBIC, center=(128, 128))
    elif index == 16:  # riding: a horseshoe
        d.ellipse((36, 20, 220, 204), fill=255)
        d.ellipse((84, 68, 172, 156), fill=0)
        d.rectangle((84, 112, 172, 240), fill=0)
        d.rectangle((36, 112, 84, 228), fill=255)
        d.rectangle((172, 112, 220, 228), fill=255)
        for x, y in ((58, 150), (58, 196), (198, 150), (198, 196), (78, 60), (178, 60)):
            d.ellipse((x - 8, y - 8, x + 8, y + 8), fill=0)
    elif index == 17:  # barber: scissors
        d.line([(92, 168), (186, 20)], fill=255, width=26)
        d.line([(164, 168), (70, 20)], fill=255, width=26)
        d.ellipse((28, 150, 112, 234), outline=255, width=20)
        d.ellipse((144, 150, 228, 234), outline=255, width=20)
    elif index == 18:  # transmogrifier: a hanger
        d.arc((100, 20, 156, 76), 180, 90, fill=255, width=16)
        d.line([(128, 76), (128, 106)], fill=255, width=16)
        d.line([(20, 196), (128, 106), (236, 196)], fill=255, width=18, joint="curve")
        d.rounded_rectangle((16, 188, 240, 208), 8, fill=255)
    elif index == 19:  # disc
        d.ellipse((4, 4, 252, 252), fill=255)
    elif index == 20:  # ring
        d.ellipse((4, 4, 252, 252), fill=255)
        d.ellipse((20, 20, 236, 236), fill=0)
    elif index == 21:  # filter: a funnel
        d.polygon([(24, 40), (232, 40), (152, 136), (152, 224), (104, 196), (104, 136)], fill=255)
    elif index == 22:  # food: a drumstick
        d.ellipse((24, 24, 172, 172), fill=255)
        d.line([(130, 130), (200, 200)], fill=255, width=30)
        d.ellipse((186, 166, 230, 210), fill=255)
        d.ellipse((166, 186, 210, 230), fill=255)
    elif index == 23:  # reagent: a flask
        d.rectangle((104, 20, 152, 104), fill=255)
        d.rounded_rectangle((92, 12, 164, 34), 6, fill=255)
        d.ellipse((48, 84, 208, 244), fill=255)
        d.rectangle((60, 150, 196, 160), fill=0)
    return image


def main(codex_dir):
    atlas = Image.new("L", (CELL * COLS, CELL * ROWS), 0)
    for index in range(COLS * ROWS):
        if index > 23:
            break
        cell = glyph(index).resize((CELL, CELL), Image.LANCZOS)
        atlas.paste(cell, ((index % COLS) * CELL, (index // COLS) * CELL))
    image = Image.new("RGBA", atlas.size, (255, 255, 255, 0))
    image.putalpha(atlas)
    path = os.path.join(codex_dir, "Modules", "QoL", "Media", "MapIcons.tga")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)
    print("wrote", path)
    preview = os.environ.get("MAP_ART_PREVIEW")
    if preview:
        sheet = Image.new("RGBA", (atlas.width * 2, atlas.height * 2), (40, 44, 52, 255))
        big = image.resize(sheet.size, Image.LANCZOS)
        sheet.alpha_composite(big)
        sheet.save(preview)
        print("preview", preview)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1])
