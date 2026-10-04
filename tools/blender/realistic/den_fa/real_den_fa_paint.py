# real_den_fa_paint.py - Story 25.32 (AC 4): Den Fa's body atlas, system Python (numpy + Pillow), through
# real_paint.body_texture over real_layout.REG's boxes (no new layout: the regions hold his garments, as the player's
# and the dealer's atlases do). The coat keeps its canon base #26587e (R-3); grime, wear and fray are painted on top;
# the hem darkens toward the floor. Nothing is painted on the mask (it has no texture: DC-5).
#   python real_den_fa_paint.py <out.png> [--overwrite]      (default out: <art>/textures/realistic/g9_den_fa_real_body.png)
# Regions (real_den_fa.py builds the UVs):
#   shirt (wraps; u 0.5 = his front, 0.75 his left)  the coat's body: the side placket on his left, two collar buttons
#   apron        the coat's skirt halves (u 0 / 1: the front opening and the back vent; v 0 the hem)
#   bib          the high stand collar (wraps)        sleeve   the coat sleeves (wrap; v 0 the shoulder)
#   roll         the dark turned-back cuffs (wrap)    hand     the dark grey gloves
#   trousers     dark trousers (wrap)                 boots    knee-high brown leather (wrap; v 0 the sole)
#   forearm      his dark grey skin (the neck, the skull)       seat     the bat ears (u 0.75 the inner bowl: darker)
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import real_layout as L  # noqa: E402
import real_paint as RP  # noqa: E402

OUT = "F:/GAME I AM MAKING/eternal_guild_art/textures/realistic/g9_den_fa_real_body.png"

PALETTE = {
    # Stage D 1 (2026-10-04): an olive-brown grime on the canon blue read GREEN under the hall's amber light (the
    # 25.10 lesson again); the grime and wear are slate now, the mud only at the very hem
    "coat": (38, 88, 126), "coat_dark": (22, 50, 78), "coat_light": (60, 102, 142), "coat_edge": (16, 32, 50),
    "dirt": (30, 40, 56), "mud": (48, 44, 42),
    "cuff": (46, 46, 50), "cuff_dark": (28, 28, 32),
    "glove": (60, 60, 64), "glove_dark": (36, 36, 40),
    "trousers": (40, 39, 44), "boots": (80, 62, 48), "boots_dark": (48, 37, 30), "sole": (30, 24, 20),
    "skin": (64, 64, 70), "skin_dark": (42, 42, 48), "hair": (40, 40, 44),
    "ear": (126, 96, 108), "ear_dark": (80, 56, 70),
    "apron_dark": (22, 52, 76), "apron": (38, 88, 126), "apron_edge": (18, 36, 52),
    "button": (24, 26, 30), "ink": (20, 20, 26),
}
col = RP.col
mix = RP.mix
fbm = RP.fbm
tint = RP.tint
lines_layer = RP.lines_layer
fold_strokes = RP.fold_strokes


def _wool(w, h, seed, wrap, folds=14, vertical=True, curl=0.4, fold_len=0.25):
    n = fbm(w, h, 5, 4, (wrap, False), seed)
    img = tint(col("coat"), n, 0.10)
    img = mix(img, np.clip((fbm(w, h, 8, 3, (wrap, False), seed + 1) - 0.58) * 3, 0, 1), col("coat_dark"), 0.45)
    img = mix(img, np.clip((fbm(w, h, 11, 3, (wrap, False), seed + 2) - 0.66) * 4, 0, 1), col("coat_light"), 0.30)   # worn, faded
    st = fold_strokes(w, h, folds, (h if vertical else w) * fold_len, vertical, curl, seed + 3, (0.05, 0.95))
    img = mix(img, lines_layer(w, h, st, 1.8, wrap, 0.7), col("ink"), 0.35)
    # Stage D 2 (LookDev): the toon look lifts the clean canon blue to a cyan beside the muted cast: an old coat's
    # all-over slate grime (the base stays #26587e under it)
    img = mix(img, 0.6 + 0.4 * fbm(w, h, 7, 3, (wrap, False), seed + 9), col("dirt"), 0.40)
    return img


def coat_body(cv):
    """The coat's body: worn wool, the side placket on his left of the front (u ~0.54) with its ink edge, two dark
    buttons near the collar, grime toward the waist, a seam over each shoulder."""
    w, h = cv.pw, cv.ph
    img = _wool(w, h, 401, True, folds=16)
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
    img = mix(img, np.clip((0.25 - yy) / 0.25, 0, 1) * fbm(w, h, 10, 3, (True, False), 405), col("dirt"), 0.35)
    xp = 0.545 * w
    pl = lines_layer(w, h, [([(xp + 1.5 * math.sin(y * 0.05), y) for y in np.linspace(0, h, 30)], 1.0)], 2.6, True, 0.5)
    img = mix(img, pl, col("coat_edge"), 0.85)
    shade = np.zeros((h, w))
    shade[:, int(xp):int(xp + 0.02 * w)] = 1
    img = mix(img, shade, col("coat_dark"), 0.5)
    yy_i, xx_i = np.mgrid[0:h, 0:w]
    for k in range(2):
        cy = int(h * (0.04 + 0.055 * k))
        cx = int(xp - 0.018 * w)
        m = ((xx_i - cx) ** 2 + (yy_i - cy) ** 2) < 30
        img[m] = col("button")
    for u in (0.75, 0.25):                                      # the shoulder seams down the arm's line
        seam = lines_layer(w, h, [([(u * w + 2 * math.sin(y * 0.1), y) for y in np.linspace(0, h * 0.12, 8)], 1.0)], 1.5, True, 0.4)
        img = mix(img, seam, col("ink"), 0.4)
    cv.put(img)


def coat_skirt(cv):
    """The skirt halves: worn wool, the edges (front opening, back vent) bound darker, the hem frayed, torn and dark
    with dirt toward the floor (the pick)."""
    w, h = cv.pw, cv.ph
    img = _wool(w, h, 411, False, folds=22, fold_len=0.35)
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
    xx = np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]
    dirt = np.clip((0.40 - yy) / 0.40, 0, 1) ** 1.6 * (0.6 + 0.4 * fbm(w, h, 9, 3, (False, False), 412))
    img = mix(img, dirt, col("dirt"), 0.75)
    img = mix(img, np.clip((0.10 - yy) / 0.10, 0, 1) * fbm(w, h, 14, 3, (False, False), 415), col("mud"), 0.5)
    fib = (fbm(w, h, 60, 2, (False, False), 413) > 0.5) * np.clip((0.05 - yy) / 0.05, 0, 1)
    img = mix(img, fib, col("coat_edge"), 0.9)
    rng = np.random.default_rng(414)
    tears = []
    for _ in range(9):
        x = rng.random() * w
        tears.append(([(x, h), (x + rng.normal() * 3, h - h * (0.03 + 0.05 * rng.random()))], 1.0 + rng.random()))
    img = mix(img, lines_layer(w, h, tears, 2.0, False, 0.3), col("ink"), 0.9)
    img = mix(img, np.clip((0.012 - yy) / 0.012, 0, 1), col("ink"), 1.0)
    edge = np.clip((0.05 - np.minimum(xx, 1 - xx)) / 0.05, 0, 1)
    img = mix(img, edge, col("coat_edge"), 0.85)
    img = mix(img, (np.minimum(xx, 1 - xx) < 0.012).astype(float), col("ink"), 1.0)   # the black front edge (the pick)
    cv.put(img)


def collar(cv):
    w, h = cv.pw, cv.ph
    img = _wool(w, h, 421, True, folds=6, fold_len=0.5) * 0.9
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
    img = mix(img, ((yy > 0.70) & (yy < 0.76)).astype(float), col("ink"), 0.7)        # the top edge's fold (outer wall top)
    img = mix(img, (yy > 0.76).astype(float), col("coat_dark"), 0.6)                    # the lip inside, in shadow
    xp = 0.545 * w
    pl = lines_layer(w, h, [([(xp, h * 0.25), (xp, h)], 1.0)], 3.0, True, 0.4)
    img = mix(img, pl, col("ink"), 0.9)
    yy_i, xx_i = np.mgrid[0:h, 0:w]
    for v in (0.42, 0.62):                                       # the two buttons on the collar's placket (the pick)
        m = ((xx_i - (xp - 0.02 * w)) ** 2 + (yy_i - (1 - v) * h) ** 2) < 26
        img[m] = col("button")
    cv.put(img)


def sleeve(cv):
    w, h = cv.pw, cv.ph
    img = _wool(w, h, 431, True, folds=6)
    creases = fold_strokes(w, h, 16, w * 0.35, False, 0.5, 432, (0.35, 0.65))          # bunching at the elbow
    img = mix(img, lines_layer(w, h, creases, 2.0, True, 0.6), col("ink"), 0.45)
    yy = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    img = mix(img, np.clip(0.10 - yy, 0, 1) * 8, col("coat_dark"), 0.4)
    img = mix(img, np.clip((yy - 0.80) / 0.20, 0, 1) * fbm(w, h, 9, 3, (True, False), 433), col("dirt"), 0.35)   # grubby by the cuff
    cv.put(img)


def cuff(cv):
    w, h = cv.pw, cv.ph
    img = tint(col("cuff"), fbm(w, h, 8, 3, (True, True), 441), 0.12)
    bands = lines_layer(w, h, [([(x, h * k / 3 + 3 * math.sin(x * 0.05 + k)) for x in np.linspace(0, w, 30)], 1.0) for k in range(3)], 2.4, True, 0.6)
    img = mix(img, bands, col("cuff_dark"), 0.7)
    img = mix(img, np.clip((fbm(w, h, 14, 2, (True, True), 442) - 0.62) * 4, 0, 1), col("cuff") * 1.35, 0.4)        # worn
    cv.put(img)


def gloves(cv):
    w, h = cv.pw, cv.ph
    img = tint(col("glove"), fbm(w, h, 6, 3, (False, False), 451), 0.12)
    img = mix(img, np.clip((fbm(w, h, 9, 3, (False, False), 452) - 0.55) * 3, 0, 1), col("glove_dark"), 0.5)
    kn = lines_layer(w, h, [([(w * (0.15 + 0.2 * i), h * 0.42), (w * (0.18 + 0.2 * i), h * 0.46)], 1.0) for i in range(4)], 2, False, 0.5)
    img = mix(img, kn, col("ink"), 0.5)
    cv.put(img)


def trousers(cv):
    w, h = cv.pw, cv.ph
    img = tint(col("trousers"), fbm(w, h, 6, 4, (True, False), 461), 0.12)
    img = mix(img, lines_layer(w, h, fold_strokes(w, h, 14, w * 0.3, False, 0.45, 462, (0.4, 0.95)), 2, True, 0.6), col("ink"), 0.4)
    cv.put(img)


def skin(cv):
    w, h = cv.pw, cv.ph
    img = tint(col("skin"), fbm(w, h, 6, 4, (True, False), 471), 0.08)
    img = mix(img, np.clip((fbm(w, h, 10, 3, (True, False), 472) - 0.55) * 3, 0, 1), col("skin_dark"), 0.4)
    cv.put(img)


def ears(cv):
    """Muted mauve outside, the inner bowl (the ring's front, u 0.75) darker, a darker rim line round it."""
    w, h = cv.pw, cv.ph
    img = tint(col("ear"), fbm(w, h, 6, 3, (True, False), 481), 0.10)
    uu = np.ones((h, 1)) * np.linspace(0, 1, w, endpoint=False)[None, :]
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))                   # v up: the base at v 0
    inner = np.clip((0.20 - np.abs(uu - 0.75)) / 0.05, 0, 1) * np.clip((yy - 0.10) / 0.10, 0, 1) * np.clip((0.97 - yy) / 0.05, 0, 1)
    img = mix(img, inner, col("ear_dark"), 0.85)
    rim = np.clip(1.0 - np.abs(np.abs(uu - 0.75) - 0.20) / 0.012, 0, 1) * (yy > 0.10)
    img = mix(img, rim, col("ink"), 0.45)
    veins = fold_strokes(w, h, 6, h * 0.5, True, 0.15, 482, (0.1, 0.6))
    img = mix(img, lines_layer(w, h, veins, 1.2, True, 0.5) * inner, col("ink"), 0.35)
    cv.put(img)


PAINTERS = [
    ("shirt", True, False, coat_body),
    ("apron", False, False, coat_skirt),
    ("bib", True, False, collar),
    ("sleeve", True, False, sleeve),
    ("roll", True, True, cuff),
    ("hand", False, False, gloves),
    ("trousers", True, False, trousers),
    ("boots", True, False, RP.boots),
    ("forearm", True, False, skin),
    ("seat", True, False, ears),
]


def misc(img):
    u0, v0, u1, v1 = L.REG["misc"]
    N = img.shape[0]
    cw = (u1 - u0) * N / 4
    for i, key in enumerate(L.MISC_CELLS):
        cx = u0 * N + cw * (i % 4)
        cy = (1 - v0) * N - cw * (i // 4 + 1)
        img[int(cy):int(cy + cw), int(cx):int(cx + cw)] = col({"skin": "skin", "sole": "sole"}.get(key, "coat_dark"))


def paint(out=OUT):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    RP.body_texture(out, painters=PAINTERS, palette=PALETTE, ground="coat_dark", misc_fn=misc)
    return out


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out = args[0] if args else OUT
    if os.path.exists(out) and "--overwrite" not in sys.argv:
        sys.exit("%s exists (--overwrite to repaint)" % out)
    paint(out)
