# make_placeholder_tarot_frame.py - Story 4.2 (D-1, DH-5): the PLACEHOLDER Tarot card frame.
#
# Writes assets/ui/tarot/placeholder_tarot_frame.png from the numbers in data/config/tarot_card.json (aspect, header,
# window, footer), so the window it leaves transparent is exactly where scenes/ui/TarotCard.tscn draws the art, and the
# two bands are where it writes the numeral / suit and the card's name. Story 25.22's frame set replaces this file by
# changing tarot_card.json's "frame" (and the band/window fractions if its layout differs); nothing in code changes.
#
# The look (DRAFT, placeholder): rounded corners, an ink border, a gold rule inset, dark-wood bands and sides, a thin
# gold line round the art window. Pure Python with Pillow:  python tools/ui/make_placeholder_tarot_frame.py
# Then import it headless (Godot --headless --import) before a game run sees it.
import json
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CONFIG = os.path.join(ROOT, "data", "config", "tarot_card.json")
OUT = os.path.join(ROOT, "assets", "ui", "tarot", "placeholder_tarot_frame.png")

WIDTH = 340                      # pixels; the height follows the configured aspect
CORNER = 16                      # rounded corner radius
INK = (27, 20, 16, 255)          # #1b1410, the outer border
WOOD = (42, 31, 23, 255)         # #2a1f17, bands and sides
BAND = (51, 38, 28, 255)         # #33261c, a shade lighter inside the bands
GOLD = (176, 141, 87, 255)       # #b08d57, the rules
BORDER = 6                       # ink border width
RULE_INSET = 10                  # the gold rule's distance from the edge
RULE = 2                         # gold rule width


def rect_px(frac, w, h):
    x, y, fw, fh = frac
    return [round(x * w), round(y * h), round((x + fw) * w) - 1, round((y + fh) * h) - 1]


def main():
    with open(CONFIG, encoding="utf-8") as f:
        cfg = json.load(f)
    aspect = float(cfg["aspect"])
    w = WIDTH
    h = round(WIDTH / aspect)
    header = rect_px(cfg["header"], w, h)
    window = rect_px(cfg["window"], w, h)
    footer = rect_px(cfg["footer"], w, h)

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=CORNER, fill=INK)
    d.rounded_rectangle([BORDER, BORDER, w - 1 - BORDER, h - 1 - BORDER], radius=CORNER - 4, fill=WOOD)
    d.rounded_rectangle([RULE_INSET, RULE_INSET, w - 1 - RULE_INSET, h - 1 - RULE_INSET], radius=CORNER - 6,
                        outline=GOLD, width=RULE)
    for band in (header, footer):
        d.rectangle(band, fill=BAND)
        d.rectangle(band, outline=GOLD, width=1)
    # The art window: a gold line round it, then cut out (transparent: the card draws the field and the art there).
    d.rectangle([window[0] - 3, window[1] - 3, window[2] + 3, window[3] + 3], fill=GOLD)
    d.rectangle([window[0] - 1, window[1] - 1, window[2] + 1, window[3] + 1], fill=INK)
    d.rectangle(window, fill=(0, 0, 0, 0))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("wrote %s (%dx%d), window %s" % (OUT, w, h, window))
    return 0


if __name__ == "__main__":
    sys.exit(main())
