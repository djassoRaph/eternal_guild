# real_paint.py - route RL's textures (the spike 2026-10-04; reusable since 25.31 S1.0), system Python (numpy +
# Pillow), lossless PNG. As functions: head_texture(out, sheet) (any concept sheet: real_layout.make_sheet / load_sheet,
# its PNG and crop boxes) and body_texture(out, painters, palette) (any region -> painter map over real_layout.REG;
# the default is the Bartender's). From the command line:
#   python real_paint.py head <out.png> [--sheet <sheet.json>] [--overwrite]
#                                                       the head material: three crops of the picked concept turnaround
#                                                       (front, his left side, back; the sheet's head_crops; default the
#                                                       spike's Bartender sheet, real_layout.BARTENDER), the
#                                                       background flood-filled away and bled over with the nearest
#                                                       drawing (so a mesh edge a pixel past the drawn silhouette samples
#                                                       skin or beard, never the sheet's grey), upscaled, a skin quadrant
#   python real_paint.py body <out.png> [--overwrite]   the body atlas (real_layout.REG): painted shirt, sleeves, rolled
#                                                       cuffs, hairy forearms, hands, the leather apron (grime, scratches,
#                                                       worn edges, a frayed hem), straps and pocket, trousers (worn knees,
#                                                       a frayed hem), boots (scuffs, sole), belt, cloth; ink fold lines
# A region whose ring wraps (real_layout.PAD) is painted periodic in u (and v for the roll).
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import real_layout as L  # noqa: E402

RNG = np.random.default_rng(20261004)


# ------------------------------------------------------------------ noise (periodic value noise, octaves)

def vnoise(w, h, cells, periodic=(True, True), seed=0):
    """Smooth value noise in [0, 1] of size (h, w) with `cells` lattice cells across; periodic per axis."""
    rng = np.random.default_rng(seed)
    cx, cy = max(1, int(cells)), max(1, int(round(cells * h / w)))
    g = rng.random((cy + 1, cx + 1))
    if periodic[0]:
        g[:, -1] = g[:, 0]
    if periodic[1]:
        g[-1, :] = g[0, :]
    xs = np.linspace(0, cx, w, endpoint=not periodic[0])
    ys = np.linspace(0, cy, h, endpoint=not periodic[1])
    x0 = np.clip(np.floor(xs).astype(int), 0, cx - 1)
    y0 = np.clip(np.floor(ys).astype(int), 0, cy - 1)
    tx = xs - x0
    ty = ys - y0
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    top = a + (b - a) * tx[None, :]
    bot = c + (d - c) * tx[None, :]
    return top + (bot - top) * ty[:, None]


def fbm(w, h, cells, octaves=4, periodic=(True, True), seed=0):
    out = np.zeros((h, w))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += amp * vnoise(w, h, cells * 2 ** o, periodic, seed + o * 17)
        tot += amp
        amp *= 0.5
    return out / tot


PAL = dict(L.PALETTE)        # the palette the painters read (body_texture(palette=...) swaps it for one atlas)


def col(name):
    return np.array(PAL[name], dtype=float)


def tint(base, n, amount):
    """base colour x (1 + amount * (n - 0.5) * 2) per pixel (n: noise in 0..1)."""
    return base[None, None, :] * (1.0 + amount * (n[..., None] - 0.5) * 2.0)


# ------------------------------------------------------------------ a region canvas (logical period + wrap)

class Canvas:
    def __init__(self, img, region, wrap_u=False, wrap_v=False):
        u0, v0, u1, v1 = L.REG[region]
        N = img.shape[0]
        self.img = img
        self.x0, self.x1 = int(round(u0 * N)), int(round(u1 * N))
        self.y0, self.y1 = int(round((1 - v1) * N)), int(round((1 - v0) * N))     # image rows: v up -> row down
        self.w, self.h = self.x1 - self.x0, self.y1 - self.y0
        self.wrap_u, self.wrap_v = wrap_u, wrap_v
        self.pw = int(round(self.w / (1 + L.PAD))) if wrap_u else self.w
        self.ph = int(round(self.h / (1 + L.PAD))) if wrap_v else self.h

    def put(self, tile):
        """tile: (ph, pw, 3) floats; tiled over the region (periodic axes repeat)."""
        reps = (math.ceil(self.h / tile.shape[0]) + 1, math.ceil(self.w / tile.shape[1]) + 1, 1)
        full = np.tile(tile, reps)
        # u 0 is the region's left edge; v 0 its BOTTOM (tile row 0 is the period's top): bottom-align the rows
        full = full[full.shape[0] - self.h:, : self.w]
        self.img[self.y0:self.y1, self.x0:self.x1] = np.clip(full, 0, 255)


def lines_layer(w, h, segs, width, periodic=True, blur=0.0):
    """A mask (h, w) in 0..1 of polyline strokes [(points in logical px, width scale)], wrapped in u."""
    im = Image.new("L", (w * 3 if periodic else w, h), 0)
    d = ImageDraw.Draw(im)
    off = w if periodic else 0
    for pts, ws in segs:
        for k in ((-1, 0, 1) if periodic else (0,)):
            q = [(x + off + k * w, y) for x, y in pts]
            d.line(q, fill=255, width=max(1, int(round(width * ws))), joint="curve")
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(im, dtype=float) / 255.0
    return a[:, off:off + w] if periodic else a


def fold_strokes(w, h, n, length, vertical=True, curl=0.25, seed=1, y_range=(0.0, 1.0)):
    rng = np.random.default_rng(seed)
    out = []
    for _ in range(n):
        x, y = rng.random() * w, h * (y_range[0] + (y_range[1] - y_range[0]) * rng.random())
        ang = (math.pi / 2 if vertical else 0.0) + rng.normal() * curl
        ln = length * (0.5 + rng.random())
        pts = []
        for i in range(6):
            t = i / 5.0
            pts.append((x + math.cos(ang) * ln * t + math.sin(t * 3 + x) * 2, y + math.sin(ang) * ln * t))
        out.append((pts, 0.6 + 0.8 * rng.random()))
    return out


def mix(img, mask, colour, alpha=1.0):
    m = np.clip(mask * alpha, 0, 1)[..., None]
    return img * (1 - m) + np.asarray(colour, dtype=float)[None, None, :] * m


# ------------------------------------------------------------------ the regions

def shirt(cv):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 6, 4, (True, False), 11)
    img = tint(col("shirt"), n, 0.10)
    # grime: darker toward the hem, the armpits and the back's lower half
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))          # v (1 at the top)
    uu = np.ones((h, 1)) * np.linspace(0, 1, w, endpoint=False)[None, :]
    grime = np.clip(0.35 - yy, 0, 1) * 1.6 * fbm(w, h, 10, 3, (True, False), 12)
    arm = np.exp(-((np.minimum(np.abs(uu - 0.25), np.abs(uu - 0.75))) / 0.05) ** 2) * np.exp(-((yy - 0.83) / 0.06) ** 2)
    img = mix(img, grime + 0.5 * arm, col("shirt_dark"), 0.55)
    # folds (ink): verticals on the body, a few diagonal pulls under the bib and over the belly
    folds = lines_layer(w, h, fold_strokes(w, h, 18, h * 0.14, True, 0.45, 13, (0.15, 0.9)), 2.0, True, 0.7)
    img = mix(img, folds, col("ink"), 0.40)
    # the laced V-neck at the front (u 0.5), z 1.44-1.56 -> v 0.80-0.98
    v_of = lambda z: (z - 0.905) / (1.598 - 0.905)
    cx = 0.5 * w
    top, bot = (1 - v_of(1.575)) * h, (1 - v_of(1.455)) * h
    tri = Image.new("L", (w, h), 0)
    ImageDraw.Draw(tri).polygon([(cx - 0.035 * w, top), (cx + 0.035 * w, top), (cx, bot)], fill=255)
    tri = np.asarray(tri.filter(ImageFilter.GaussianBlur(0.8)), dtype=float) / 255
    img = mix(img, tri, col("skin_dark"), 1.0)
    lace = Image.new("L", (w, h), 0)
    dl = ImageDraw.Draw(lace)
    for i in range(4):
        y = top + (bot - top) * (0.12 + 0.24 * i)
        hw = 0.032 * w * (1 - (y - top) / (bot - top)) + 3
        dl.line([(cx - hw - 3, y), (cx + hw + 3, y + 7)], fill=255, width=3)
        dl.line([(cx + hw + 3, y), (cx - hw - 3, y + 7)], fill=255, width=3)
    dl.polygon([(cx - 0.035 * w, top), (cx, bot), (cx + 0.035 * w, top)], outline=255, width=2)
    img = mix(img, np.asarray(lace, dtype=float) / 255, col("laces"), 1.0)
    # the shoulder seams (ink) and the frayed back hem
    seam = lines_layer(w, h, [([(x, (1 - v_of(1.515)) * h + 6 * math.sin(x / w * 12.56)) for x in np.linspace(0, w, 40)], 1.0)], 1.6, True)
    img = mix(img, seam, col("ink"), 0.35)
    hem = np.clip((0.06 - yy) / 0.06, 0, 1) * (fbm(w, h, 40, 2, (True, False), 14) > 0.45)
    img = mix(img, hem, col("shirt_dark"), 0.7)
    cv.put(img)


def sleeve(cv, roll=False):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 5, 4, (True, cv.wrap_v), 21 + roll)
    img = tint(col("shirt") * (1.04 if not roll else 0.92), n, 0.10)
    if roll:
        bands = lines_layer(w, h, [([(x, h * k / 6 + 4 * math.sin(x * 0.07 + k)) for x in np.linspace(0, w, 30)], 1.0) for k in range(6)], 2.4, True, 0.7)
        img = mix(img, bands, col("ink"), 0.55)
        img = mix(img, fbm(w, h, 12, 2, (True, True), 23), col("shirt_dark"), 0.35)
    else:
        creases = fold_strokes(w, h, 16, w * 0.35, False, 0.5, 22, (0.35, 1.0))       # bunching toward the elbow
        img = mix(img, lines_layer(w, h, creases, 2.0, True, 0.6), col("ink"), 0.5)
        yy = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
        img = mix(img, np.clip(yy - 0.6, 0, 1) * 1.5, col("shirt_dark"), 0.35)
    cv.put(img)


def skin(cv, hairy=True, seed=31):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 6, 4, (cv.wrap_u, False), seed)
    img = tint(col("skin"), n, 0.07)
    if hairy:
        rng = np.random.default_rng(seed + 1)
        hair = Image.new("L", (w * 3, h), 0)
        d = ImageDraw.Draw(hair)
        # strokes thicker on the outer forearm (u around 0.0-0.5: the ring's top half in rest = the back of the arm)
        for _ in range(int(w * h / 75)):
            x, y = rng.random() * w, rng.random() * h
            u = x / w
            dens = 0.25 + 0.75 * (0.5 + 0.5 * math.cos(2 * math.pi * u))
            if rng.random() > dens:
                continue
            ln = 9 + 9 * rng.random()
            a = math.radians(78 + 24 * rng.random())          # combed along the arm, toward the wrist
            bend = 2.5 * (rng.random() - 0.5)
            for k in (0, 1, 2):
                xx = x + k * w - w
                d.line([(xx + w, y), (xx + w + math.cos(a) * ln * 0.35 + bend, y + math.sin(a) * ln * 0.5),
                        (xx + w + math.cos(a) * ln * 0.6 + bend * 2, y + math.sin(a) * ln)], fill=150, width=1)
        hm = np.asarray(hair.filter(ImageFilter.GaussianBlur(0.35)), dtype=float)[:, w:2 * w] / 255
        img = mix(img, hm, col("hair"), 0.9)
    yy = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    img = mix(img, np.clip(0.15 - yy, 0, 1) * 4, col("skin_dark"), 0.4)        # shade into the roll
    cv.put(img)


def hands(cv):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 5, 3, (False, False), 41)
    img = tint(col("skin"), n, 0.07)
    # knuckle creases (the palm's far end, u ~0.85-1) and the finger columns (u 0.8 / 0.15 used by fingers/thumb)
    kn = lines_layer(w, h, [([(w * 0.86, h * (0.2 + 0.15 * i)), (w * 0.9, h * (0.25 + 0.15 * i))], 1.0) for i in range(4)], 2, False, 0.5)
    img = mix(img, kn, col("skin_dark"), 0.6)
    sh = fbm(w, h, 4, 3, (False, False), 42)
    img = mix(img, np.clip((sh - 0.5) * 2, 0, 1), col("skin_dark"), 0.25)                    # weathered, uneven
    cv.put(img)


def leather(cv, base="apron", seed=51, hem=False, edges=True, stitch=True):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 4, 5, (False, False), seed)
    img = tint(col(base), n, 0.16)
    blot = fbm(w, h, 7, 3, (False, False), seed + 1)
    img = mix(img, np.clip((blot - 0.55) * 3, 0, 1), col("apron_dark"), 0.55)          # grime blotches
    worn = fbm(w, h, 9, 3, (False, False), seed + 2)
    img = mix(img, np.clip((worn - 0.62) * 4, 0, 1), col(base) * 1.25, 0.45)           # worn, lighter scuffs
    rng = np.random.default_rng(seed + 3)
    scr = []
    for _ in range(int(w * h / 1800)):
        x, y = rng.random() * w, rng.random() * h
        a = rng.random() * math.pi
        ln = 6 + 18 * rng.random()
        scr.append(([(x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln)], 0.5 + rng.random()))
    img = mix(img, lines_layer(w, h, scr, 1.3, False, 0.3), col("apron_edge"), 0.6)
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
    xx = np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]
    if hem:
        # darker, frayed toward the hem (v 0): grime band + ragged fibres
        img = mix(img, np.clip((0.22 - yy) / 0.22, 0, 1) ** 1.5, col("apron_dark"), 0.75)
        fib = (fbm(w, h, 60, 2, (False, False), seed + 4) > 0.5) * np.clip((0.035 - yy) / 0.035, 0, 1)
        img = mix(img, fib, col("apron_edge"), 0.9)
        img = mix(img, np.clip((0.012 - yy) / 0.012, 0, 1), col("ink"), 1.0)
    if edges:
        e = np.clip((0.025 - np.minimum(xx, 1 - xx)) / 0.025, 0, 1)
        img = mix(img, e, col("apron_edge"), 0.8)
    if stitch:
        st = np.zeros((h, w))
        for x in (int(w * 0.03), int(w * 0.97)):
            st[::6, max(0, x - 1):x + 1] = 1
            st[1::6, max(0, x - 1):x + 1] = 1
        img = mix(img, st, col("apron_edge"), 0.8)
    cv.put(img)


def bib(cv):
    leather(cv, seed=61, hem=False)
    w, h = cv.pw, cv.ph
    sub = cv.img[cv.y0:cv.y1, cv.x0:cv.x1].astype(float)
    # the top hem (v 1): a folded, stitched band; a horizontal crease where it bends over the belly
    band = np.zeros((h, w))
    band[: int(h * 0.07)] = 1
    sub = mix(sub, band, col("apron_dark"), 0.6)
    cr = lines_layer(w, h, [([(w * 0.1, h * 0.72), (w * 0.5, h * 0.76), (w * 0.9, h * 0.71)], 1.0)], 2, False, 0.8)
    sub = mix(sub, cr, col("apron_edge"), 0.6)
    cv.img[cv.y0:cv.y1, cv.x0:cv.x1] = np.clip(sub, 0, 255)


def straps(cv):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 8, 3, (False, False), 71)
    img = tint(col("apron_dark") * 1.1, n, 0.12)
    # the pocket (u 0.55-0.95): leather with a stitched outline
    pk = np.zeros((h, w))
    x0, x1, y0, y1 = int(w * 0.55), int(w * 0.95), int(h * 0.1), int(h * 0.9)
    img[y0:y1, x0:x1] = tint(col("apron") * 1.05, n[y0:y1, x0:x1], 0.15)
    pk[y0 + 3:y1 - 3:5, x0 + 3:x0 + 5] = 1
    pk[y0 + 3:y1 - 3:5, x1 - 5:x1 - 3] = 1
    pk[y0 + 3:y0 + 5, x0 + 3:x1 - 3:5] = 1
    img = mix(img, pk, col("ink"), 0.7)
    img[y0:y0 + 3, x0:x1] = col("ink")
    cv.put(img)


def trousers(cv, seat=False):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 6, 4, (True, False), 81 + seat)
    img = tint(col("trousers"), n, 0.12)
    yy = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    uu = np.ones((h, 1)) * np.linspace(0, 1, w, endpoint=False)[None, :]
    if not seat:
        knee = np.exp(-((yy - 0.62) / 0.06) ** 2) * np.exp(-((uu - 0.0) / 0.12) ** 2 * 0) * (0.5 + 0.5 * np.cos(2 * np.pi * uu))
        img = mix(img, knee * fbm(w, h, 14, 2, (True, False), 83), col("trousers") * 1.45, 0.55)      # worn knees (front: u 0)
        creases = fold_strokes(w, h, 18, w * 0.3, False, 0.45, 84, (0.55, 0.98))
        img = mix(img, lines_layer(w, h, creases, 2, True, 0.6), col("ink"), 0.45)
        fr = np.clip((yy - 0.93) / 0.07, 0, 1) * (fbm(w, h, 50, 2, (True, False), 85) > 0.48)
        img = mix(img, fr, col("trousers") * 1.6, 0.8)                                               # frayed, pale threads
    else:
        img = mix(img, lines_layer(w, h, fold_strokes(w, h, 10, h * 0.25, True, 0.5, 86), 2, True, 0.6), col("ink"), 0.35)
    cv.put(img)


def boots(cv):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 6, 4, (True, False), 91)
    img = tint(col("boots"), n, 0.12)
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))                       # v up
    scuff = fbm(w, h, 16, 3, (True, False), 92)
    img = mix(img, np.clip((scuff - 0.6) * 4, 0, 1), col("boots") * 1.35, 0.5)
    img = mix(img, np.clip((0.40 - yy) / 0.40, 0, 1) * 0.6, col("boots_dark"), 0.6)          # the foot darker (dirt)
    img = mix(img, (yy < 0.05).astype(float), col("sole"), 1.0)                              # the sole
    img = mix(img, ((yy > 0.05) & (yy < 0.065)).astype(float), col("ink"), 0.9)
    creases = fold_strokes(w, h, 14, w * 0.25, False, 0.4, 93, (0.0, 0.55))                  # shaft wrinkles
    img = mix(img, lines_layer(w, h, creases, 2, True, 0.5), col("boots_dark"), 0.8)
    img = mix(img, ((yy > 0.88) & (yy < 0.96)).astype(float) * 0.5, col("boots_dark"), 0.8)  # the cuff's fold
    cv.put(img)


def belt(cv):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 10, 3, (True, True), 101)
    img = tint(col("belt"), n, 0.15)
    st = np.zeros((h, w))
    st[int(h * 0.3), ::5] = 1
    st[int(h * 0.62), ::5] = 1
    img = mix(img, st, col("buckle") * 0.7, 0.6)
    cv.put(img)


def cloth(cv):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 5, 4, (False, False), 111)
    img = tint(col("cloth"), n, 0.06)
    img = mix(img, np.clip((fbm(w, h, 8, 3, (False, False), 112) - 0.55) * 3, 0, 1), col("cloth_dark"), 0.5)   # stains
    folds = fold_strokes(w, h, 12, h * 0.4, True, 0.2, 113)
    img = mix(img, lines_layer(w, h, folds, 2, False, 0.6), col("cloth_dark") * 0.7, 0.7)
    cv.put(img)


def misc(img):
    u0, v0, u1, v1 = L.REG["misc"]
    N = img.shape[0]
    names = {"buckle": "buckle", "laces": "laces", "sole": "sole", "stitch": "apron_edge", "strap_dark": "apron_dark",
             "knot": "apron_dark", "metal_dark": "belt", "skin": "skin"}
    cw = (u1 - u0) * N / 4
    for i, key in enumerate(L.MISC_CELLS):
        cx = u0 * N + cw * (i % 4)
        cy = (1 - v0) * N - cw * (i // 4 + 1)
        img[int(cy):int(cy + cw), int(cx):int(cx + cw)] = col(names[key])


# the Bartender's atlas: (region, wrap_u, wrap_v, painter(canvas)) in paint order
BARTENDER_PAINTERS = [
    ("shirt", True, False, shirt),
    ("apron", False, False, lambda cv: leather(cv, seed=51, hem=True)),
    ("bib", False, False, bib),
    ("straps", False, False, straps),
    ("sleeve", True, False, sleeve),
    ("roll", True, True, lambda cv: sleeve(cv, roll=True)),
    ("forearm", True, False, skin),
    ("hand", False, False, hands),
    ("trousers", True, False, trousers),
    ("seat", True, False, lambda cv: trousers(cv, seat=True)),
    ("boots", True, False, boots),
    ("belt", True, True, belt),
    ("cloth", False, False, cloth),
]


# ------------------------------------------------------------------ the player (25.31 S1, catalogue G1; his pick
# C_G1_player.png): the regions keep real_layout.REG's boxes with his own garments in them:
#   shirt (wraps)  the dark leather vest over the grey shirt (the laced V at the front)
#   bib            the long coat's body (open at the front)          apron     the coat's skirt (the frayed hem)
#   straps         its collar and lapels                             sleeve    the coat's sleeves (wrap)
#   roll           the coat's turned cuffs (wrap both)                trousers  worn trousers with knee patches (wrap)
#   cloth          the sword's scabbard (a steel chape and throat)    hand / boots / belt / seat as the Bartender's
PLAYER_PALETTE = {
    "shirt": (66, 51, 44), "shirt_dark": (44, 34, 29), "undershirt": (86, 84, 82), "undershirt_dark": (52, 50, 50),
    "apron": (88, 70, 55), "apron_dark": (56, 44, 35), "apron_edge": (40, 31, 26),
    "trousers": (68, 64, 56), "patch": (110, 96, 80), "boots": (86, 72, 59), "boots_dark": (50, 42, 36),
    "skin": (190, 148, 124), "skin_dark": (140, 104, 88), "hair": (50, 42, 36),
    "belt": (58, 46, 36), "buckle": (128, 120, 104), "scabbard": (54, 41, 32), "steel": (122, 120, 114),
}


def vest(cv):
    """The vest: dark leather, worn, a seam down the front; the grey shirt's laced V at the neck (u 0.5 = his front)."""
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 6, 4, (True, False), 211)
    img = tint(col("shirt"), n, 0.12)
    img = mix(img, np.clip((fbm(w, h, 9, 3, (True, False), 212) - 0.6) * 3, 0, 1), col("shirt_dark"), 0.6)
    img = mix(img, lines_layer(w, h, fold_strokes(w, h, 14, h * 0.12, True, 0.5, 213, (0.1, 0.9)), 2.0, True, 0.7), col("ink"), 0.4)
    cx = 0.5 * w
    top, bot = 0.0, h * 0.30
    tri = Image.new("L", (w, h), 0)
    ImageDraw.Draw(tri).polygon([(cx - 0.06 * w, top), (cx + 0.06 * w, top), (cx, bot)], fill=255)
    tri = np.asarray(tri.filter(ImageFilter.GaussianBlur(0.8)), dtype=float) / 255
    img = mix(img, tri, col("undershirt"), 1.0)
    lace = Image.new("L", (w, h), 0)
    dl = ImageDraw.Draw(lace)
    for i in range(3):
        y = top + (bot - top) * (0.25 + 0.22 * i)
        hw = 0.05 * w * (1 - (y - top) / (bot - top)) + 3
        dl.line([(cx - hw, y), (cx + hw, y + 6)], fill=255, width=3)
        dl.line([(cx + hw, y), (cx - hw, y + 6)], fill=255, width=3)
    dl.polygon([(cx - 0.06 * w, top), (cx, bot), (cx + 0.06 * w, top)], outline=255, width=2)
    img = mix(img, np.asarray(lace, dtype=float) / 255, col("laces"), 1.0)
    seam = lines_layer(w, h, [([(cx, bot), (cx + 2, h)], 1.0)], 2, True, 0.4)
    img = mix(img, seam, col("ink"), 0.6)
    cv.put(img)


def coat_sleeve(cv):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 5, 4, (True, False), 221)
    img = tint(col("apron"), n, 0.13)
    img = mix(img, np.clip((fbm(w, h, 9, 3, (True, False), 222) - 0.6) * 3, 0, 1), col("apron_dark"), 0.55)
    creases = fold_strokes(w, h, 18, w * 0.35, False, 0.5, 223, (0.30, 0.75))        # bunching at the elbow
    img = mix(img, lines_layer(w, h, creases, 2.0, True, 0.6), col("ink"), 0.5)
    yy = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    img = mix(img, np.clip(0.12 - yy, 0, 1) * 6, col("apron_dark"), 0.4)               # dark under the shoulder seam
    cv.put(img)


def coat_cuff(cv):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 8, 3, (True, True), 231)
    img = tint(col("apron") * 0.9, n, 0.12)
    bands = lines_layer(w, h, [([(x, h * k / 3 + 3 * math.sin(x * 0.05 + k)) for x in np.linspace(0, w, 30)], 1.0) for k in range(3)], 2.4, True, 0.6)
    img = mix(img, bands, col("ink"), 0.5)
    cv.put(img)


def patched_trousers(cv):
    """trousers() and a stitched patch over each knee (u 0: the ring's front)."""
    trousers(cv)
    w, h = cv.pw, cv.ph
    sub = cv.img[cv.y0:cv.y0 + h, cv.x0:cv.x0 + w].astype(float)
    pm = np.zeros((h, w))
    yc, hh, hw = int(h * 0.30), int(h * 0.075), int(w * 0.11)         # row 0 is the hem (v 1): the knee is ~0.3 down
    for x0 in (0, w):
        pm[yc - hh:yc + hh, max(0, x0 - hw):min(w, x0 + hw)] = 1
    pm = np.asarray(Image.fromarray((pm * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0)), dtype=float) / 255
    tile = tint(col("patch"), fbm(w, h, 10, 3, (True, False), 242), 0.10)
    sub = sub * (1 - pm[..., None]) + tile * pm[..., None]
    st = np.zeros((h, w))
    for x0 in (0, w):
        for y in (yc - hh, yc + hh - 1):
            st[y, max(0, x0 - hw):min(w, x0 + hw):4] = 1
        for x in (x0 - hw, x0 + hw - 1):
            if 0 <= x < w:
                st[yc - hh:yc + hh:4, x] = 1
    sub = mix(sub, st, col("ink"), 0.8)
    cv.put(sub)


def scabbard(cv):
    """The sword's scabbard along v (0 the tip, 1 the throat): dark leather, a steel chape at the tip, a steel throat."""
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 4, 4, (False, False), 251)
    img = tint(col("scabbard"), n, 0.15)
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
    img = mix(img, ((yy < 0.10) | (yy > 0.92)).astype(float), col("steel"), 1.0)
    img = mix(img, (((yy > 0.10) & (yy < 0.115)) | ((yy > 0.905) & (yy < 0.92))).astype(float), col("ink"), 0.9)
    img = mix(img, lines_layer(w, h, fold_strokes(w, h, 8, h * 0.2, True, 0.1, 252), 1.5, False, 0.4), col("apron_edge"), 0.6)
    cv.put(img)


def player_misc(img):
    """The flat cells: buckle, laces (the grip's wrap), sole, stitch, strap_dark, knot, metal_dark (the guard and the
    pommel: steel), skin."""
    u0, v0, u1, v1 = L.REG["misc"]
    N = img.shape[0]
    names = {"buckle": "buckle", "laces": "laces", "sole": "sole", "stitch": "apron_edge", "strap_dark": "apron_dark",
             "knot": "apron_dark", "metal_dark": "steel", "skin": "skin"}
    cw = (u1 - u0) * N / 4
    for i, key in enumerate(L.MISC_CELLS):
        cx = u0 * N + cw * (i % 4)
        cy = (1 - v0) * N - cw * (i // 4 + 1)
        img[int(cy):int(cy + cw), int(cx):int(cx + cw)] = col(names[key])


PLAYER_PAINTERS = [
    ("shirt", True, False, vest),
    ("bib", False, False, lambda cv: leather(cv, seed=261, hem=False, edges=True, stitch=True)),
    ("apron", False, False, lambda cv: leather(cv, seed=262, hem=True, edges=True, stitch=True)),
    ("straps", False, False, lambda cv: leather(cv, base="apron_dark", seed=263, hem=False, edges=True, stitch=False)),
    ("sleeve", True, False, coat_sleeve),
    ("roll", True, True, coat_cuff),
    ("forearm", True, False, lambda cv: skin(cv, hairy=False, seed=271)),
    ("hand", False, False, hands),
    ("trousers", True, False, patched_trousers),
    ("seat", True, False, lambda cv: trousers(cv, seat=True)),
    ("boots", True, False, boots),
    ("belt", True, True, belt),
    ("cloth", False, False, scabbard),
]


def body_texture(out, painters=None, palette=None, ground="apron_dark", flat_cells=True, misc_fn=None):
    """The body atlas: each (region, wrap_u, wrap_v, painter) paints its real_layout.REG region (periodic on a
    wrapping axis); misc's flat cells last (misc_fn: the role's own, default the Bartender's). palette: {name: (r, g,
    b)} over real_layout.PALETTE's keys (a recolour) and any new keys the role's painters read."""
    global PAL
    keep = PAL
    PAL = dict(L.PALETTE, **(palette or {}))
    try:
        N = L.BODY_PX
        img = np.zeros((N, N, 3)) + col(ground)
        for region, wu, wv, fn in (painters or BARTENDER_PAINTERS):
            fn(Canvas(img, region, wu, wv))
        if flat_cells:
            (misc_fn or misc)(img)
        Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").save(out)
    finally:
        PAL = keep
    print("body atlas ->", out)


# ------------------------------------------------------------------ the head: the concept's own drawing

def _background(a, bg_value=147):
    """The sheet's grey reached from the crop's border (low saturation, value near the sheet's)."""
    sat = a.max(axis=2) - a.min(axis=2)
    val = a.mean(axis=2)
    cand = (sat < 12) & (np.abs(val - bg_value) < 16)
    h, w = cand.shape
    bg = np.zeros_like(cand)
    stack = [(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)]
    while stack:
        y, x = stack.pop()
        if bg[y, x] or not cand[y, x]:
            continue
        bg[y, x] = True
        if y > 0:
            stack.append((y - 1, x))
        if y < h - 1:
            stack.append((y + 1, x))
        if x > 0:
            stack.append((y, x - 1))
        if x < w - 1:
            stack.append((y, x + 1))
    return bg


def _bleed(a, bg, steps=24):
    """Fill the background with the nearest drawing (iterated 4-neighbour averages), inside out."""
    a = a.astype(float).copy()
    known = ~bg
    for _ in range(steps):
        acc = np.zeros_like(a)
        cnt = np.zeros(known.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = np.roll(known, (dy, dx), (0, 1))
            acc += np.roll(a, (dy, dx), (0, 1)) * k[..., None]
            cnt += k
        new = (~known) & (cnt > 0)
        a[new] = acc[new] / cnt[new][:, None]
        known = known | new
    a[~known] = a[known].mean(axis=0)
    return a


def head_texture(out, sheet=None, skin_rgb=None, bg_value=147, N=1024):
    """The head texture of a concept sheet (real_layout.make_sheet / load_sheet; default the spike's Bartender): each
    view's crop box (sheet["head_crops"], sheet["head_win"] px square) cut from the sheet's PNG, its grey background
    (value ~bg_value, low saturation, reached from the border) flood-filled away with its silhouette ink, bled over
    with the nearest drawing, upscaled into its quadrant; the rest is skin (skin_rgb, default the palette's)."""
    sheet = sheet or L.BARTENDER
    Q = N // 2
    win = sheet["head_win"]
    con = Image.open(sheet["concept"]).convert("RGB")
    img = Image.new("RGB", (N, N), tuple(int(c) for c in (skin_rgb or col("skin"))))
    for view, (wx, wy, u0, v0) in sheet["head_crops"].items():
        pad = 12                                                 # crop wider so the bleed has context, trimmed after
        box = (int(round(wx)) - pad, int(round(wy)) - pad, int(round(wx + win)) + pad, int(round(wy + win)) + pad)
        a = np.asarray(con.crop(box), dtype=float)
        bg = _background(a.astype(np.int32), bg_value)
        # the drawn silhouette ink (the 3 px next to the sheet) goes too: the game's hull draws the outline, and a
        # mesh edge a hair inside the drawn one would show a second line
        grown = bg.copy()
        for _ in range(3):
            g = grown.copy()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                g |= np.roll(grown, (dy, dx), (0, 1))
            grown = g
        a = _bleed(a, grown, steps=80)
        crop = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
        sc = Q / win
        big = crop.resize((int(round(crop.width * sc)), int(round(crop.height * sc))), Image.LANCZOS)
        big = big.filter(ImageFilter.UnsharpMask(radius=2.0, percent=70, threshold=2))
        # the window's exact origin inside the padded crop (sub-pixel offset of wx/wy kept)
        ox = (wx - box[0]) * sc
        oy = (wy - box[1]) * sc
        tile = big.crop((int(round(ox)), int(round(oy)), int(round(ox)) + Q, int(round(oy)) + Q))
        img.paste(tile, (int(u0 * N), int((1 - v0) * N) - Q))
    img.save(out)
    print("head texture ->", out)


if __name__ == "__main__":
    argv = sys.argv[1:]
    sheet = None
    if "--sheet" in argv:
        i = argv.index("--sheet")
        sheet = L.load_sheet(argv[i + 1])
        del argv[i:i + 2]
    args = [a for a in argv if not a.startswith("--")]
    if len(args) != 2 or args[0] not in ("head", "body"):
        sys.exit("usage: python real_paint.py head|body <out.png> [--sheet <sheet.json>] [--overwrite]")
    if os.path.exists(args[1]) and "--overwrite" not in argv:
        sys.exit("%s exists (--overwrite to repaint)" % args[1])
    os.makedirs(os.path.dirname(os.path.abspath(args[1])), exist_ok=True)
    if args[0] == "head":
        head_texture(args[1], sheet)
    else:
        body_texture(args[1])
