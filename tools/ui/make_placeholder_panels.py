# make_placeholder_panels.py - Story 10.1's PLACEHOLDER art for the illustrated story panels (data/narrative/panels.json).
#
# Writes assets/ui/panels/placeholder_panel_<name>.png, 1280x720: simple inked shapes in each panel's planned composition,
# no text but a small "PLACEHOLDER" mark in a corner (the words are Labels beside the art, never baked into it:
# narrative-design.md, asset-catalogue section 12). The real art (Raphael's n8n inked pipeline, 08_ASSET_PROMPT_PACK.md)
# replaces a file at the same path, or panels.json points the panel (or page) elsewhere; nothing in code changes.
#   the_inheritance_tavern    the opening, page 1: the marked place, a tavern at dusk, its sign blank, one window teal
#   the_inheritance           the opening, page 2: the pale pillar, its hourglass of teal sand, firelight at one side
#   the_inheritance_stranger  the opening, page 3: the hearth, a very tall figure seated with his back to us
#   the_kings_request         the King's panel: a cream letter, a red wax seal, dark wood
#   the_first_death           one candle on dark (shipped off in panels.json)
# Canon kept: no faces, no names, the stranger only from behind.
# Pure Python with Pillow:  python tools/ui/make_placeholder_panels.py
# Then import headless (Godot --headless --import) before a game run sees them.
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_placeholder_intro import (AMBER, INK, PAPER, STONE, TEAL, H, OUT_DIR, ROOT, W,   # noqa: E402
                                    glow, gradient, mark, planks, vignette)

COAT = (46, 92, 112)


def save(img, name):
    vignette(img)
    mark(img)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "placeholder_panel_%s.png" % name)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT))


def hourglass(d, cx, cy, w, h, sand=TEAL):
    """A bronze frame, two glass bulbs, teal sand low in the lower one."""
    d.rectangle([cx - w / 2 - 8, cy - h / 2 - 12, cx + w / 2 + 8, cy - h / 2], fill=(150, 110, 54), outline=INK, width=3)
    d.rectangle([cx - w / 2 - 8, cy + h / 2, cx + w / 2 + 8, cy + h / 2 + 12], fill=(150, 110, 54), outline=INK, width=3)
    glass = [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + 5, cy), (cx + w / 2, cy + h / 2),
             (cx - w / 2, cy + h / 2), (cx - 5, cy)]
    d.polygon(glass, fill=(70, 84, 90), outline=INK)
    d.polygon([(cx - w / 2 + 6, cy + h / 2 - 2), (cx + w / 2 - 6, cy + h / 2 - 2), (cx + w * 0.18, cy + h * 0.2),
               (cx - w * 0.18, cy + h * 0.2)], fill=sand)
    d.polygon([(cx - w * 0.3, cy - h * 0.3), (cx + w * 0.3, cy - h * 0.3), (cx + 3, cy - 2), (cx - 3, cy - 2)], fill=sand)
    d.line([(cx, cy), (cx, cy + h * 0.2)], fill=sand, width=2)


def fire(img, x0, y0, x1, y1):
    glow(img, [lambda d: d.ellipse([x0 - 140, y0 - 160, x1 + 140, y1 + 120], fill=255)], AMBER, 90, 0.75)
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2
    for k, (dx, hh) in enumerate([(-34, 0.7), (0, 1.0), (30, 0.8)]):
        top = y1 - (y1 - y0) * hh
        d.polygon([(cx + dx - 26, y1), (cx + dx, top), (cx + dx + 26, y1)], fill=(255, 150 + k * 25, 70), outline=INK)
    d.rectangle([x0 - 10, y1, x1 + 10, y1 + 14], fill=(60, 34, 20), outline=INK, width=3)   # the logs


# ── the panels ────────────────────────────────────────────────────────────────

def inheritance_tavern():
    img = gradient((30, 24, 52), (176, 104, 70), horizon=430)
    d = ImageDraw.Draw(img)
    d.polygon([(0, 470), (300, 430), (700, 446), (1280, 420), (1280, 720), (0, 720)], fill=(34, 30, 26), outline=INK)
    d.polygon([(560, 720), (700, 720), (660, 520), (612, 520)], fill=(104, 86, 60), outline=INK)   # the path to the door
    # the tavern: timber walls, a steep roof, a chimney with smoke
    d.rectangle([420, 300, 880, 530], fill=(76, 54, 38), outline=INK, width=5)
    for x in range(440, 880, 44):
        d.line([(x, 304), (x, 526)], fill=(60, 42, 30), width=2)
    d.polygon([(390, 304), (650, 150), (910, 304)], fill=(58, 40, 36), outline=INK)
    d.rectangle([760, 150, 800, 240], fill=(90, 82, 74), outline=INK, width=4)
    for k in range(4):
        d.ellipse([768 + k * 18, 110 - k * 34, 812 + k * 22, 146 - k * 30], outline=(120, 110, 120), width=3)
    d.rectangle([612, 430, 668, 530], fill=(40, 26, 18), outline=INK, width=4)   # the door
    d.ellipse([654, 476, 662, 484], fill=(200, 170, 90))
    windows = [[470, 360, 540, 420], [740, 360, 810, 420]]
    glow(img, [lambda dd, b=windows[0]: dd.rectangle(b, fill=255)], AMBER, 22, 1.0)
    glow(img, [lambda dd, b=windows[1]: dd.rectangle(b, fill=255)], TEAL, 26, 1.2)   # the pillar's light, inside
    d = ImageDraw.Draw(img)
    d.rectangle(windows[0], fill=AMBER, outline=INK, width=3)
    d.rectangle(windows[1], fill=TEAL, outline=INK, width=3)
    for b in windows:
        d.line([((b[0] + b[2]) / 2, b[1]), ((b[0] + b[2]) / 2, b[3])], fill=INK, width=3)
    # the sign: hung from a bracket, blank (the guild has no name yet)
    d.line([(420, 330), (330, 330)], fill=INK, width=6)
    d.line([(350, 330), (350, 352)], fill=INK, width=3)
    d.line([(400, 330), (400, 352)], fill=INK, width=3)
    d.rectangle([330, 352, 420, 410], fill=(120, 92, 60), outline=INK, width=4)
    save(img, "the_inheritance_tavern")


def inheritance_pillar():
    img = Image.new("RGB", (W, H), (26, 20, 18))
    planks(img, (34, 26, 22), vertical=True, n=12, seed=13)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 560, W, H], fill=(40, 30, 24))
    d.line([(0, 560), (W, 560)], fill=INK, width=4)
    fire(img, 40, 430, 200, 560)   # firelight at one side
    glow(img, [lambda dd: dd.ellipse([440, 40, 840, 640], fill=255)], TEAL, 90, 0.6)
    d = ImageDraw.Draw(img)
    d.rectangle([570, 60, 710, 590], fill=STONE, outline=INK, width=6)   # the pillar
    d.rectangle([550, 560, 730, 600], fill=(150, 145, 130), outline=INK, width=5)
    d.rectangle([550, 50, 730, 86], fill=(150, 145, 130), outline=INK, width=5)
    for k in range(5):
        y = 110 + k * 92
        if 260 < y < 420:
            continue
        d.line([(626, y), (640, y + 26), (654, y)], fill=TEAL, width=4)
    d.rectangle([586, 262, 694, 420], fill=(40, 46, 48), outline=INK, width=4)   # the niche
    hourglass(d, 640, 341, 64, 118)
    glow(img, [lambda dd: dd.ellipse([600, 340, 680, 420], fill=255)], TEAL, 18, 0.9)
    save(img, "the_inheritance")


def inheritance_stranger():
    img = Image.new("RGB", (W, H), (30, 22, 18))
    planks(img, (38, 28, 22), vertical=True, n=10, seed=17)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 590, W, H], fill=(44, 32, 24))
    # the hearth: a stone arch, the fire inside
    d.rectangle([700, 250, 1180, 600], fill=(96, 90, 84), outline=INK, width=6)
    for row in range(5):
        for col in range(6):
            ox = 40 if row % 2 else 0
            bx0, bx1 = max(700, 700 + col * 80 + ox - 40), min(1180, 700 + col * 80 + ox + 40)
            d.rectangle([bx0, 250 + row * 70, bx1, 250 + row * 70 + 70], outline=(70, 66, 62), width=2)
    d.rectangle([700, 250, 1180, 600], outline=INK, width=6)
    d.rectangle([800, 400, 1080, 600], fill=(20, 12, 10), outline=INK, width=5)
    fire(img, 860, 450, 1020, 580)
    d = ImageDraw.Draw(img)
    d.rectangle([680, 226, 1200, 254], fill=(70, 46, 30), outline=INK, width=4)   # the mantel
    # the stranger, from behind: a high-backed chair, very tall, a long teal-blue coat, a hood; no face
    d.rectangle([330, 300, 560, 620], fill=(56, 36, 24), outline=INK, width=5)   # the chair's back
    d.polygon([(372, 200), (520, 200), (560, 640), (330, 640)], fill=COAT, outline=INK)   # the coat over it
    d.line([(446, 230), (446, 630)], fill=(34, 70, 86), width=3)
    d.ellipse([392, 100, 500, 220], fill=(36, 74, 92), outline=INK, width=5)   # the hood, seen from behind
    d.polygon([(330, 620), (300, 720), (590, 720), (560, 620)], fill=(40, 26, 18), outline=INK)
    glow(img, [lambda dd: dd.line([(520, 210), (560, 640)], fill=255, width=10)], AMBER, 8, 0.8)   # firelight on his right edge
    save(img, "the_inheritance_stranger")


def kings_request():
    img = Image.new("RGB", (W, H), (40, 26, 18))
    planks(img, (44, 29, 19), vertical=False, n=6, seed=23)
    glow(img, [lambda d: d.ellipse([140, 60, 1140, 700], fill=255)], AMBER, 120, 0.35)
    paper = Image.new("RGBA", (700, 460), PAPER + (255,))
    pd = ImageDraw.Draw(paper)
    pd.rectangle([0, 0, 699, 459], outline=INK, width=5)
    rnd = random.Random(29)
    for row in range(6):   # ink, not words
        y = 70 + row * 42
        x = 60
        while x < 640:
            seg = rnd.randint(40, 110)
            pts = [(x + k * 6, y + math.sin((x + k * 6) * 0.3) * 2) for k in range(seg // 6)]
            if len(pts) > 1:
                pd.line(pts, fill=(52, 38, 28, 255), width=3)
            x += seg + rnd.randint(10, 22)
    paper = paper.rotate(4, expand=True, resample=Image.BICUBIC)
    img.paste(paper, (280, 110), paper)
    d = ImageDraw.Draw(img)
    cx, cy = 640, 560   # the royal seal: red wax, a crown pressed in
    d.ellipse([cx - 66, cy - 66, cx + 66, cy + 66], fill=(160, 26, 22), outline=INK, width=5)
    d.polygon([(cx - 34, cy + 18), (cx - 34, cy - 20), (cx - 17, cy), (cx, cy - 30), (cx + 17, cy), (cx + 34, cy - 20),
               (cx + 34, cy + 18)], fill=(104, 12, 10))
    save(img, "the_kings_request")


def first_death():
    img = Image.new("RGB", (W, H), (10, 8, 8))
    glow(img, [lambda d: d.ellipse([440, 120, 840, 560], fill=255)], AMBER, 110, 0.5)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 560, W, H], fill=(20, 14, 12))
    d.rectangle([606, 330, 674, 566], fill=(224, 214, 186), outline=INK, width=4)   # the candle
    d.polygon([(606, 340), (620, 372), (630, 346)], fill=(240, 232, 210), outline=INK)   # a drip
    d.ellipse([570, 552, 710, 584], fill=(70, 52, 36), outline=INK, width=4)   # its dish
    glow(img, [lambda dd: dd.ellipse([600, 230, 680, 330], fill=255)], AMBER, 28, 1.5)
    d = ImageDraw.Draw(img)
    d.polygon([(640, 244), (657, 290), (640, 318), (623, 290)], fill=(255, 224, 140), outline=INK)
    d.line([(640, 318), (640, 332)], fill=INK, width=3)
    save(img, "the_first_death")


if __name__ == "__main__":
    for f in (inheritance_tavern, inheritance_pillar, inheritance_stranger, kings_request, first_death):
        f()
