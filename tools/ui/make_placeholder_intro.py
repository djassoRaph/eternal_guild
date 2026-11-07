# make_placeholder_intro.py - the New Game intro's PLACEHOLDER slide art (Raphael 2026-11-07: "put the place holders of
# the art work power points after the new game first").
#
# Writes assets/ui/panels/placeholder_intro_<id>.png, one per slide in data/narrative/intro.json: 1280x720, simple
# inked shapes in the slide's planned composition (dark ground, ink outlines, the Priors' teal and the hearth's amber),
# no text but a small "PLACEHOLDER" mark in a corner, the Story 10.1 rule (illustrated panels: the words are Labels
# beside the art, never baked into it). The real art (the n8n inked pipeline, 08_ASSET_PROMPT_PACK.md) replaces a file
# at the same path, or intro.json points a slide elsewhere; nothing in code changes.
# Canon kept: no faces, no named places, the Priors only as stone and teal runes, the threat only as a dark horizon.
# Pure Python with Pillow:  python tools/ui/make_placeholder_intro.py
# Then import headless (Godot --headless --import) before a game run sees them.
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "ui", "panels")
W, H = 1280, 720
INK = (22, 15, 11)
TEAL = (90, 235, 215)
AMBER = (255, 184, 92)
STONE = (178, 172, 156)
PAPER = (222, 206, 166)


# ── helpers ───────────────────────────────────────────────────────────────────

def gradient(top, bottom, horizon=H):
    img = Image.new("RGB", (W, H), bottom)
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = min(y / max(horizon, 1), 1.0)
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img


def glow(img, shapes, color, radius, strength=1.0):
    """shapes: callables drawing on an ImageDraw in white; the blurred result is added in `color`."""
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    for s in shapes:
        s(d)
    mask = mask.filter(ImageFilter.GaussianBlur(radius))
    if strength != 1.0:
        mask = mask.point(lambda v: min(255, int(v * strength)))
    layer = Image.new("RGB", (W, H), color)
    img.paste(layer, (0, 0), mask)


def vignette(img, amount=0.55):
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    for k in range(40):
        t = k / 40.0
        d.ellipse([-W * 0.25 + t * W * 0.25, -H * 0.3 + t * H * 0.3, W * 1.25 - t * W * 0.25, H * 1.3 - t * H * 0.3],
                  fill=int(255 * t))
    mask = mask.filter(ImageFilter.GaussianBlur(60))
    dark = Image.new("RGB", (W, H), (8, 5, 4))
    inv = mask.point(lambda v: int((255 - v) * amount))
    img.paste(dark, (0, 0), inv)


def mark(img):
    """Top-left, well inside the edge: the intro's slow push-in crops the borders, and the corner below holds its dots."""
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.load_default(size=18)
    except TypeError:
        font = ImageFont.load_default()
    d.text((56, 40), "PLACEHOLDER", fill=(200, 190, 170), font=font)


def planks(img, base, vertical=True, n=9, seed=1):
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img)
    size = W if vertical else H
    step = size / n
    for k in range(n):
        shade = rnd.randint(-12, 12)
        col = tuple(max(0, min(255, c + shade)) for c in base)
        if vertical:
            box = [k * step, 0, (k + 1) * step, H]
        else:
            box = [0, k * step, W, (k + 1) * step]
        d.rectangle(box, fill=col, outline=INK, width=3)
        for _ in range(6):   # grain
            if vertical:
                x = k * step + rnd.uniform(8, step - 8)
                d.line([(x, rnd.uniform(0, H)), (x + rnd.uniform(-6, 6), rnd.uniform(0, H))],
                       fill=tuple(max(0, c - 18) for c in col), width=2)
            else:
                y = k * step + rnd.uniform(8, step - 8)
                d.line([(rnd.uniform(0, W), y), (rnd.uniform(0, W), y + rnd.uniform(-6, 6))],
                       fill=tuple(max(0, c - 18) for c in col), width=2)


def save(img, sid):
    vignette(img)
    mark(img)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "placeholder_intro_%s.png" % sid)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT))


# ── the slides ────────────────────────────────────────────────────────────────

def priors():
    img = gradient((26, 20, 44), (204, 126, 72), horizon=470)
    glow(img, [lambda d: d.ellipse([820, 380, 1040, 560], fill=255)], (255, 170, 90), 60, 0.8)
    d = ImageDraw.Draw(img)
    d.polygon([(0, 560), (180, 470), (420, 420), (700, 440), (980, 500), (1280, 470), (1280, 720), (0, 720)],
              fill=(30, 26, 32), outline=INK)
    # the ruins: standing stones, a broken arch, fallen blocks
    stones = [(330, 250, 380, 440), (430, 300, 470, 432), (520, 210, 572, 430), (690, 280, 735, 440),
              (780, 330, 815, 452)]
    for s in stones:
        d.rectangle(s, fill=STONE, outline=INK, width=4)
    d.rectangle([505, 190, 760, 222], fill=STONE, outline=INK, width=4)   # the lintel, broken off past 690
    d.polygon([(560, 455), (640, 448), (650, 478), (566, 486)], fill=(150, 145, 130), outline=INK)
    d.polygon([(860, 470), (930, 462), (936, 490), (858, 498)], fill=(150, 145, 130), outline=INK)
    runes = []
    for (x0, y0, x1, y1) in stones:
        for k in range(3):
            cx = (x0 + x1) / 2
            cy = y0 + 40 + k * 45
            runes.append(lambda d, cx=cx, cy=cy: d.line([(cx - 8, cy - 10), (cx, cy + 10), (cx + 8, cy - 10)],
                                                       fill=255, width=4))
    glow(img, runes, TEAL, 6, 1.6)
    d = ImageDraw.Draw(img)
    for (x0, y0, x1, y1) in stones:
        for k in range(3):
            cx = (x0 + x1) / 2
            cy = y0 + 40 + k * 45
            d.line([(cx - 8, cy - 10), (cx, cy + 10), (cx + 8, cy - 10)], fill=TEAL, width=3)
    save(img, "priors")


def forgetting():
    img = gradient((12, 14, 30), (44, 38, 62), horizon=430)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 470, W, H], fill=(30, 25, 22))
    houses = [(60, 330, 230), (250, 360, 380), (400, 320, 520), (760, 330, 880), (900, 350, 1040), (1060, 320, 1230)]
    lit = []
    for (x0, top, x1) in houses:
        d.rectangle([x0, top, x1, 480], fill=(48, 36, 28), outline=INK, width=4)
        d.polygon([(x0 - 14, top), ((x0 + x1) / 2, top - 70), (x1 + 14, top)], fill=(36, 26, 22), outline=INK)
        for wx in range(x0 + 22, x1 - 30, 52):
            box = [wx, top + 40, wx + 24, top + 70]
            d.rectangle(box, fill=AMBER, outline=INK, width=2)
            lit.append(lambda dd, b=box: dd.rectangle(b, fill=255))
    glow(img, lit, AMBER, 14, 0.7)
    glow(img, [lambda dd: dd.ellipse([520, 120, 760, 520], fill=255)], TEAL, 70, 0.55)
    d = ImageDraw.Draw(img)
    d.rectangle([600, 170, 680, 482], fill=STONE, outline=INK, width=5)   # the pillar the village grew round
    for k in range(4):
        y = 215 + k * 62
        d.line([(628, y), (640, y + 22), (652, y)], fill=TEAL, width=4)
    for (x, s) in [(450, 1.0), (520, 0.9), (770, 1.05), (840, 0.95)]:   # people passing, not looking
        d.ellipse([x - 9 * s, 452 - 70 * s, x + 9 * s, 452 - 52 * s], fill=INK)
        d.rectangle([x - 11 * s, 452 - 52 * s, x + 11 * s, 482], fill=INK)
    save(img, "forgetting")


def you():
    img = Image.new("RGB", (W, H), (60, 40, 26))
    planks(img, (64, 43, 28), vertical=True, n=10, seed=3)
    glow(img, [lambda d: d.ellipse([-300, -200, 700, 800], fill=255)], AMBER, 120, 0.45)
    d = ImageDraw.Draw(img)
    for (x, y) in [(380, 300), (870, 300)]:   # pegs
        d.rectangle([x - 10, y - 10, x + 10, y + 26], fill=(40, 26, 18), outline=INK, width=3)
    # the sword, across the pegs: blade, guard, grip, pommel
    d.polygon([(300, 312), (1000, 290), (1060, 300), (1000, 312), (300, 334)], fill=(176, 180, 188), outline=INK)
    d.line([(320, 322), (990, 301)], fill=(210, 214, 220), width=2)
    d.rectangle([272, 270, 296, 376], fill=(150, 116, 60), outline=INK, width=4)
    d.rectangle([196, 310, 272, 336], fill=(90, 56, 34), outline=INK, width=4)
    d.ellipse([168, 304, 202, 342], fill=(150, 116, 60), outline=INK, width=4)
    # worn boots on the floor
    d.rectangle([0, 600, W, H], fill=(36, 24, 16))
    for bx in (840, 960):
        d.polygon([(bx, 470), (bx + 70, 470), (bx + 74, 610), (bx + 120, 620), (bx + 122, 650), (bx - 6, 650)],
                  fill=(46, 30, 20), outline=INK)
    save(img, "you")


def letter():
    img = Image.new("RGB", (W, H), (48, 32, 21))
    planks(img, (52, 35, 23), vertical=False, n=6, seed=7)
    glow(img, [lambda d: d.ellipse([820, 40, 1240, 460], fill=255)], AMBER, 90, 0.7)
    paper = Image.new("RGBA", (620, 420), PAPER + (255,))
    pd = ImageDraw.Draw(paper)
    pd.rectangle([0, 0, 619, 419], outline=INK, width=5)
    rnd = random.Random(11)
    for row in range(7):   # ink, not words
        y = 60 + row * 40
        x = 50
        while x < 560 - (120 if row == 6 else 0):
            seg = rnd.randint(30, 90)
            pts = [(x + k * 6, y + math.sin((x + k * 6) * 0.25) * 3) for k in range(seg // 6)]
            if len(pts) > 1:
                pd.line(pts, fill=(64, 46, 32, 255), width=3)
            x += seg + rnd.randint(10, 22)
    paper = paper.rotate(-6, expand=True, resample=Image.BICUBIC)
    img.paste(paper, (230, 150), paper)
    d = ImageDraw.Draw(img)
    cx, cy = 690, 520   # the wax seal: an hourglass pressed in red
    d.ellipse([cx - 52, cy - 52, cx + 52, cy + 52], fill=(146, 28, 24), outline=INK, width=4)
    d.polygon([(cx - 22, cy - 28), (cx + 22, cy - 28), (cx, cy), (cx + 22, cy + 28), (cx - 22, cy + 28), (cx, cy)],
              fill=(98, 14, 12))
    d.rectangle([1030, 300, 1076, 520], fill=(222, 212, 182), outline=INK, width=4)   # the candle
    glow(img, [lambda dd: dd.ellipse([1020, 220, 1086, 310], fill=255)], AMBER, 26, 1.4)
    d = ImageDraw.Draw(img)
    d.polygon([(1053, 232), (1068, 272), (1053, 296), (1038, 272)], fill=(255, 222, 140), outline=INK)
    save(img, "letter")


def road():
    img = gradient((36, 26, 56), (160, 94, 68), horizon=380)
    glow(img, [lambda d: d.ellipse([900, 250, 1400, 470], fill=255)], (14, 8, 18), 50, 1.1)   # the dark, far off
    d = ImageDraw.Draw(img)
    d.rectangle([0, 380, W, H], fill=(38, 32, 26))
    d.polygon([(560, 380), (720, 380), (1120, 720), (160, 720)], fill=(116, 96, 66), outline=INK)
    for side in (-1, 1):   # trees, and their long shadows across the road
        for k in range(5):
            x = 640 + side * (200 + k * 110)
            y = 380 + k * 55
            h = 120 + k * 50
            d.polygon([(x + side * h * 1.6, y + 30), (x + side * h * 1.6 + 30, y + 46), (x - 10, y + 22), (x + 10, y + 14)],
                      fill=(20, 15, 14))
            d.polygon([(x, y - h), (x - 34 - k * 6, y + 10), (x + 34 + k * 6, y + 10)], fill=(22, 26, 20), outline=INK)
            d.rectangle([x - 6, y + 10, x + 6, y + 26], fill=(30, 22, 16))
    save(img, "road")


def the_map():
    img = Image.new("RGB", (W, H), (50, 34, 22))
    planks(img, (54, 36, 24), vertical=False, n=6, seed=5)
    glow(img, [lambda d: d.ellipse([-200, -260, 700, 420], fill=255)], AMBER, 110, 0.5)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = 200, 120, 1080, 620
    d.rectangle([x0, y0, x1, y1], fill=PAPER, outline=INK, width=5)
    d.rectangle([x0 + 40, y0 + 30, x1 - 40, y1 - 30], fill=(116, 146, 156), outline=INK, width=3)   # the sea
    rnd = random.Random(21)
    blobs = [(560, 330, 260, 170), (840, 250, 120, 80), (380, 470, 90, 60)]
    for (cx, cy, rx, ry) in blobs:   # land, ink-edged
        pts = []
        for k in range(28):
            a = k / 28 * math.tau
            r = 1.0 + rnd.uniform(-0.22, 0.18)
            pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
        d.polygon(pts, fill=(156, 166, 104), outline=INK)
    for gx in range(x0 + 40, x1 - 40, 34):   # a faint hex grid over it all
        for gy in range(y0 + 30, y1 - 30, 30):
            ox = 17 if ((gy - y0) // 30) % 2 else 0
            d.point((gx + ox, gy), fill=(70, 60, 44))
    for cx in (x0, x1):   # the rolled ends
        d.rectangle([cx - 22, y0 - 16, cx + 22, y1 + 16], fill=(200, 182, 140), outline=INK, width=4)
    d.ellipse([588, 318, 632, 362], outline=(170, 26, 22), width=6)   # one place, marked
    d.line([(560, 300), (660, 380)], fill=(170, 26, 22), width=3)
    save(img, "map")


if __name__ == "__main__":
    for f in (priors, forgetting, you, letter, road, the_map):
        f()
