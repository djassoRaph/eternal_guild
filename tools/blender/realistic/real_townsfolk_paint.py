# real_townsfolk_paint.py - the townsfolk's textures (Story 25.31 S2, AC 11), system Python (numpy + Pillow): per
# variant the head texture (real_paint.head_texture on its sheet, real_layout.TOWNSFOLK_SHEETS) and the body atlas
# (real_paint.body_texture with the variant's painters and palette over real_layout.REG). Region use (real_townsfolk):
#   shirt (wraps)   the tunic / shirt / dress (the farmer's linen, the local's blue-grey, the traveller's grey, the
#                   guard's crimson tabard top, the merchant's olive tunic, the old woman's brown dress)
#   apron           the traveller's cloak, the guard's tabard skirt, the merchant's coat skirt halves
#   bib             the farmer's straw brim, the local's cap peak, the traveller's scarf, the guard's mail mantle,
#                   the merchant's coat body, the old woman's shawl
#   cloth           the hat crowns (straw, cloth cap, beret, steel helmet), the traveller's bedroll
#   straps          the merchant's lapels and collar, the traveller's pack
#   sleeve / roll   sleeves / cuffs and bracers; trousers, seat, boots, belt, hand as the player's
# Usage: python real_townsfolk_paint.py <variant>|all [--overwrite]
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import real_layout as L  # noqa: E402
import real_paint as P  # noqa: E402
from real_paint import col, fbm, fold_strokes, lines_layer, mix, tint  # noqa: E402

ART = "F:/GAME I AM MAKING/eternal_guild_art/"


def fabric(cv, base="shirt", dark="shirt_dark", seed=401, folds=14, hem=False, fray=False, grime=0.5, vfold=True):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 6, 4, (cv.wrap_u, cv.wrap_v), seed)
    img = tint(col(base), n, 0.11)
    img = mix(img, np.clip((fbm(w, h, 9, 3, (cv.wrap_u, cv.wrap_v), seed + 1) - 0.58) * 3, 0, 1), col(dark), grime)
    img = mix(img, lines_layer(w, h, fold_strokes(w, h, folds, h * 0.22, vfold, 0.40, seed + 2, (0.08, 0.95)), 1.8,
                               cv.wrap_u, 0.7), col("ink"), 0.38)
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
    if hem:
        img = mix(img, np.clip((0.16 - yy) / 0.16, 0, 1) ** 1.5, col(dark), 0.6)
    if fray:
        fib = (fbm(w, h, 60, 2, (cv.wrap_u, False), seed + 4) > 0.5) * np.clip((0.035 - yy) / 0.035, 0, 1)
        img = mix(img, fib, col(dark), 0.9)
        img = mix(img, np.clip((0.010 - yy) / 0.010, 0, 1), col("ink"), 0.9)
    return img


def patches(img, w, h, spots, colour, seed):
    """Stitched patches: spots [(u, v, half-w px, half-h px)] (u, v in 0..1, v up)."""
    pm = np.zeros((h, w))
    st = np.zeros((h, w))
    for u, v, hw, hh in spots:
        x, y = int(u * w), int((1 - v) * h)
        y0, y1, x0, x1 = max(0, y - hh), min(h, y + hh), max(0, x - hw), min(w, x + hw)
        pm[y0:y1, x0:x1] = 1
        st[y0:y1:4, x0] = 1
        st[y0:y1:4, min(w - 1, x1 - 1)] = 1
        st[y0, x0:x1:4] = 1
        st[min(h - 1, y1 - 1), x0:x1:4] = 1
    pm = np.asarray(Image.fromarray((pm * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0)), dtype=float) / 255
    tile = tint(col(colour), fbm(w, h, 10, 3, (False, False), seed), 0.10)
    img = img * (1 - pm[..., None]) + tile * pm[..., None]
    return mix(img, st, col("ink"), 0.8)


def laced_v(img, w, h, top_v=1.0, depth=0.10, half=0.05, under="undershirt", laces=3):
    """A laced V at the front (u 0.5) from the top (v top_v) down depth."""
    cx = 0.5 * w
    top, bot = (1 - top_v) * h, (1 - top_v + depth) * h
    tri = Image.new("L", (w, h), 0)
    ImageDraw.Draw(tri).polygon([(cx - half * w, top), (cx + half * w, top), (cx, bot)], fill=255)
    img = mix(img, np.asarray(tri.filter(ImageFilter.GaussianBlur(0.8)), dtype=float) / 255, col(under), 1.0)
    lace = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(lace)
    for i in range(laces):
        y = top + (bot - top) * (0.22 + 0.25 * i)
        hw = half * w * (1 - (y - top) / max(bot - top, 1)) + 3
        d.line([(cx - hw, y), (cx + hw, y + 5)], fill=255, width=2)
        d.line([(cx + hw, y), (cx - hw, y + 5)], fill=255, width=2)
    d.polygon([(cx - half * w, top), (cx, bot), (cx + half * w, top)], outline=255, width=2)
    return mix(img, np.asarray(lace, dtype=float) / 255, col("laces"), 1.0)


def straw(cv, seed=501):
    w, h = cv.pw, cv.ph
    n = fbm(w, h, 8, 4, (cv.wrap_u, cv.wrap_v), seed)
    img = tint(col("straw"), n, 0.14)
    xx, yy = np.meshgrid(np.arange(w), np.arange(h))
    weave = ((xx + yy) // 3 % 2) * ((xx - yy) // 3 % 2)
    img = mix(img, weave.astype(float), col("straw_dark"), 0.35)
    streak = lines_layer(w, h, fold_strokes(w, h, 40, w * 0.3, False, 0.2, seed + 1), 1.2, cv.wrap_u, 0.3)
    img = mix(img, streak, col("straw_dark"), 0.5)
    img = mix(img, np.clip((fbm(w, h, 6, 3, (cv.wrap_u, cv.wrap_v), seed + 2) - 0.6) * 3, 0, 1), col("straw_dark") * 0.8, 0.5)
    cv.put(img)


def straw_brim(cv, seed=511):
    """The brim: straw, a frayed outer edge (v 0 the crown's edge... the grid's v: 1 at the inner row)."""
    straw(cv, seed)
    w, h = cv.pw, cv.ph
    sub = cv.img[cv.y0:cv.y0 + h, cv.x0:cv.x0 + w].astype(float)
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
    fib = (fbm(w, h, 50, 2, (False, False), seed + 5) > 0.45) * np.clip((0.12 - yy) / 0.12, 0, 1)
    sub = mix(sub, fib, col("straw_dark") * 0.7, 0.8)
    cv.put(sub)


def rope(cv, seed=521):
    w, h = cv.pw, cv.ph
    img = tint(col("rope"), fbm(w, h, 8, 3, (True, True), seed), 0.12)
    xx, yy = np.meshgrid(np.arange(w), np.arange(h))
    tw = (np.sin((xx * 0.6 + yy * 2.2) * 0.9) > 0.3).astype(float)
    img = mix(img, tw, col("rope_dark"), 0.55)
    cv.put(img)


def mail(cv, base="mail", seed=531, edge_gold=False):
    w, h = cv.pw, cv.ph
    img = tint(col(base), fbm(w, h, 6, 3, (cv.wrap_u, cv.wrap_v), seed), 0.10)
    xx, yy = np.meshgrid(np.arange(w), np.arange(h))
    off = (yy // 5) % 2 * 3
    ring = (((xx + off) % 6) - 3) ** 2 + ((yy % 5) - 2.5) ** 2
    img = mix(img, (ring < 3.0).astype(float), col("mail_dark"), 0.7)
    img = mix(img, ((ring > 3.0) & (ring < 5.5)).astype(float), col("mail") * 1.3, 0.35)
    if edge_gold:
        yv = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
        img = mix(img, (yv > 0.90).astype(float), col("gold"), 1.0)
        img = mix(img, ((yv > 0.88) & (yv <= 0.90)).astype(float), col("gold_dark"), 1.0)
    cv.put(img)


def steel(cv, seed=541):
    w, h = cv.pw, cv.ph
    img = tint(col("steel"), fbm(w, h, 4, 3, (cv.wrap_u, cv.wrap_v), seed), 0.06)
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
    img = mix(img, np.clip(np.sin(yy * 9.0) * 0.5 + 0.2, 0, 1), col("steel") * 1.22, 0.35)     # polish bands
    img = mix(img, np.clip((fbm(w, h, 12, 3, (cv.wrap_u, cv.wrap_v), seed + 1) - 0.62) * 3, 0, 1), col("steel_dark"), 0.5)
    xx = np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]
    riv = np.zeros((h, w))
    for k in range(10):                                    # a row of rivets round the band
        x = int(w * (k + 0.5) / 10)
        y = int(h * 0.88)
        riv[max(0, y - 2):y + 2, max(0, x - 2):x + 2] = 1
    img = mix(img, riv, col("steel_dark"), 0.9)
    cv.put(img)


def gold_edges(img, w, h, left=0, right=0, bottom=0, top=0):
    for a, b in ((0, left), (w - right, w)):
        if b > a:
            img[:, a:b] = col("gold")
            img[:, a:a + 1] = col("gold_dark")
            img[:, b - 1:b] = col("gold_dark")
    if bottom:
        img[h - bottom:, :] = col("gold")
        img[h - bottom:h - bottom + 1, :] = col("gold_dark")
    if top:
        img[:top, :] = col("gold")
        img[top - 1:top, :] = col("gold_dark")
    return img


def brocade(img, w, h, seed=551):
    xx, yy = np.meshgrid(np.arange(w), np.arange(h))
    pat = (np.sin(xx * 0.35) * np.sin(yy * 0.35) > 0.55).astype(float)
    return mix(img, pat, col("gold") * 0.85, 0.55)


def fringe(img, w, h):
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
    xx = np.ones((h, 1)) * np.arange(w)[None, :]
    f = ((xx % 4) < 2) * (yy < 0.08)
    img = mix(img, f.astype(float), col("shirt_dark"), 0.8)
    return mix(img, ((yy >= 0.08) & (yy < 0.095)).astype(float), col("ink"), 0.6)


def flat_cells(names):
    def fn(img):
        u0, v0, u1, v1 = L.REG["misc"]
        N = img.shape[0]
        cw = (u1 - u0) * N / 4
        for i, key in enumerate(L.MISC_CELLS):
            cx = u0 * N + cw * (i % 4)
            cy = (1 - v0) * N - cw * (i // 4 + 1)
            img[int(cy):int(cy + cw), int(cx):int(cx + cw)] = col(names.get(key, key if key in P.PAL else "ink"))
    return fn


def _put(cv, fn):
    """Paint with fn(w, h) -> image and put it."""
    cv.put(fn(cv.pw, cv.ph))


# ------------------------------------------------------------------ the variants

COMMON = {"skin": (190, 148, 124), "skin_dark": (140, 104, 88), "laces": (40, 30, 24), "ink": (34, 24, 22),
          "sole": (30, 24, 20), "buckle": (128, 120, 104), "gold": (156, 124, 72), "gold_dark": (100, 78, 46)}

VARIANTS = {}


def _farmer():
    pal = dict(COMMON, shirt=(168, 158, 138), shirt_dark=(118, 108, 92), undershirt=(150, 120, 100),
               trousers=(84, 66, 50), patch=(112, 90, 66), boots=(124, 96, 64), boots_dark=(80, 62, 44),
               straw=(176, 144, 86), straw_dark=(118, 92, 52), rope=(150, 126, 88), rope_dark=(98, 80, 54),
               belt=(150, 126, 88), apron_dark=(70, 56, 42), apron_edge=(50, 40, 30), hair=(70, 50, 38))

    def shirt(cv):
        img = fabric(cv, seed=411, folds=20, hem=True, fray=True, grime=0.55)
        img = laced_v(img, cv.pw, cv.ph, top_v=1.0, depth=0.16, half=0.045, under="skin_dark", laces=3)
        cv.put(img)

    def sleeve(cv):
        cv.put(fabric(cv, seed=421, folds=18, vfold=False, grime=0.45))

    def trousers(cv):
        P.trousers(cv)
        w, h = cv.pw, cv.ph
        sub = cv.img[cv.y0:cv.y0 + h, cv.x0:cv.x0 + w].astype(float)
        sub = patches(sub, w, h, [(0.02, 0.62, int(w * 0.08), int(h * 0.06)), (0.55, 0.40, int(w * 0.07), int(h * 0.05)),
                                  (0.30, 0.75, int(w * 0.06), int(h * 0.05))], "patch", 431)
        cv.put(sub)
    return pal, [("shirt", True, False, shirt), ("sleeve", True, False, sleeve), ("forearm", True, False, lambda cv: P.skin(cv, hairy=True)),
                 ("hand", False, False, P.hands), ("trousers", True, False, trousers),
                 ("seat", True, False, lambda cv: P.trousers(cv, seat=True)), ("boots", True, False, P.boots),
                 ("belt", True, True, rope), ("cloth", True, False, straw), ("bib", False, False, straw_brim),
                 ("roll", True, True, sleeve)], flat_cells({"knot": "rope", "strap_dark": "rope_dark", "metal_dark": "boots_dark",
                                                            "stitch": "apron_edge", "skin": "skin"})


def _local():
    pal = dict(COMMON, shirt=(80, 86, 98), shirt_dark=(48, 52, 62), undershirt=(70, 56, 46), trousers=(78, 62, 48),
               patch=(98, 80, 62), boots=(76, 58, 44), boots_dark=(48, 38, 30), belt=(62, 46, 36), cap=(70, 70, 78),
               cap_dark=(44, 44, 52), apron_dark=(52, 44, 38), apron_edge=(38, 32, 28), hair=(46, 36, 30))

    def tunic(cv):
        img = fabric(cv, seed=611, folds=16, hem=True, fray=True, grime=0.6)
        w, h = cv.pw, cv.ph
        img = mix(img, np.clip((fbm(w, h, 7, 3, (True, False), 615) - 0.6) * 3, 0, 1), col("undershirt"), 0.35)   # brown grime
        img = laced_v(img, w, h, top_v=1.0, depth=0.11, half=0.035, under="skin_dark", laces=2)
        img[: max(2, int(h * 0.02))] = col("apron_dark")                                         # the collar's brown trim
        cv.put(img)

    def trousers(cv):
        P.trousers(cv)
        w, h = cv.pw, cv.ph
        sub = cv.img[cv.y0:cv.y0 + h, cv.x0:cv.x0 + w].astype(float)
        cv.put(patches(sub, w, h, [(0.62, 0.42, int(w * 0.06), int(h * 0.05))], "patch", 631))

    def cap(cv):
        cv.put(fabric(cv, base="cap", dark="cap_dark", seed=641, folds=10, grime=0.4))
    return pal, [("shirt", True, False, tunic), ("sleeve", True, False, lambda cv: cv.put(fabric(cv, seed=621, folds=16, vfold=False))),
                 ("hand", False, False, P.hands), ("trousers", True, False, trousers),
                 ("seat", True, False, lambda cv: P.trousers(cv, seat=True)), ("boots", True, False, P.boots),
                 ("belt", True, True, P.belt), ("cloth", True, False, cap),
                 ("bib", False, False, lambda cv: cv.put(fabric(cv, base="cap_dark", dark="cap_dark", seed=651, folds=4)))], \
        flat_cells({"knot": "belt", "strap_dark": "belt", "metal_dark": "boots_dark", "stitch": "apron_edge"})


def _traveller():
    pal = dict(COMMON, shirt=(84, 80, 74), shirt_dark=(54, 51, 47), undershirt=(80, 70, 60), trousers=(100, 78, 56),
               patch=(122, 96, 70), boots=(88, 68, 50), boots_dark=(54, 42, 32), belt=(70, 52, 38),
               cloak=(100, 86, 68), cloak_dark=(64, 54, 42), scarf=(126, 124, 120), scarf_dark=(84, 82, 80),
               leather=(116, 82, 54), leather_dark=(74, 52, 36), roll=(120, 120, 118), roll_dark=(80, 80, 80),
               apron_dark=(64, 54, 42), apron_edge=(44, 36, 28), hair=(46, 38, 32))

    def cloak(cv):
        img = fabric(cv, base="cloak", dark="cloak_dark", seed=711, folds=22, hem=True, fray=True, grime=0.6)
        img = patches(img, cv.pw, cv.ph, [(0.22, 0.55, 14, 16), (0.78, 0.25, 12, 12)], "cloak_dark", 712)
        cv.put(img)

    def pack(cv):
        w, h = cv.pw, cv.ph
        img = tint(col("leather"), fbm(w, h, 5, 4, (False, False), 721), 0.15)
        img = mix(img, np.clip((fbm(w, h, 9, 3, (False, False), 722) - 0.6) * 3, 0, 1), col("leather_dark"), 0.6)
        img = mix(img, lines_layer(w, h, fold_strokes(w, h, 8, h * 0.2, True, 0.3, 723), 1.5, False, 0.5), col("ink"), 0.4)
        cv.put(img)

    def bedroll(cv):
        w, h = cv.pw, cv.ph
        img = tint(col("roll"), fbm(w, h, 6, 3, (True, False), 731), 0.08)
        xx = np.ones((h, 1)) * np.arange(w)[None, :]
        img = mix(img, ((xx % max(4, w // 6)) < 2).astype(float), col("roll_dark"), 0.7)     # the roll's spiral lines
        cv.put(img)

    def trousers(cv):
        P.trousers(cv)
        w, h = cv.pw, cv.ph
        sub = cv.img[cv.y0:cv.y0 + h, cv.x0:cv.x0 + w].astype(float)
        cv.put(patches(sub, w, h, [(0.02, 0.62, int(w * 0.07), int(h * 0.055)), (0.48, 0.62, int(w * 0.07), int(h * 0.055))],
                       "patch", 741))
    return pal, [("shirt", True, False, lambda cv: cv.put(fabric(cv, seed=751, folds=16, hem=True, grime=0.5))),
                 ("apron", False, False, cloak), ("bib", False, False, lambda cv: cv.put(fabric(cv, base="scarf", dark="scarf_dark", seed=761, folds=12, vfold=False))),
                 ("sleeve", True, False, lambda cv: cv.put(fabric(cv, seed=771, folds=14, vfold=False))),
                 ("roll", True, True, lambda cv: cv.put(fabric(cv, base="leather", dark="leather_dark", seed=781, folds=4))),
                 ("hand", False, False, P.hands), ("trousers", True, False, trousers),
                 ("seat", True, False, lambda cv: P.trousers(cv, seat=True)), ("boots", True, False, P.boots),
                 ("belt", True, True, P.belt), ("straps", False, False, pack), ("cloth", True, False, bedroll)], \
        flat_cells({"knot": "leather", "strap_dark": "leather_dark", "metal_dark": "boots_dark", "stitch": "apron_edge"})


def _guard():
    pal = dict(COMMON, shirt=(108, 40, 46), shirt_dark=(66, 24, 30), trousers=(54, 52, 52), boots=(86, 64, 46),
               boots_dark=(52, 40, 30), belt=(66, 48, 36), mail=(86, 88, 94), mail_dark=(46, 48, 54),
               steel=(116, 120, 128), steel_dark=(66, 70, 78), apron_dark=(66, 24, 30), apron_edge=(48, 18, 22),
               hair=(50, 40, 34))

    def tabard_top(cv):
        cv.put(fabric(cv, seed=811, folds=10, grime=0.4))

    def tabard(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, seed=821, folds=16, hem=True, grime=0.45)
        img = gold_edges(img, w, h, bottom=max(5, int(h * 0.05)))
        cv.put(img)
    return pal, [("shirt", True, False, tabard_top), ("apron", False, False, tabard),
                 ("bib", False, False, lambda cv: mail(cv, seed=831, edge_gold=True)),
                 ("sleeve", True, False, lambda cv: mail(cv, seed=841)), ("roll", True, True, lambda cv: mail(cv, seed=842)),
                 ("hand", False, False, P.hands), ("trousers", True, False, P.trousers),
                 ("seat", True, False, lambda cv: P.trousers(cv, seat=True)), ("boots", True, False, P.boots),
                 ("belt", True, True, P.belt), ("cloth", True, False, steel)], \
        flat_cells({"knot": "belt", "strap_dark": "belt", "metal_dark": "steel_dark", "stitch": "apron_edge"})


def _merchant():
    pal = dict(COMMON, shirt=(70, 68, 50), shirt_dark=(44, 42, 32), undershirt=(60, 58, 44), apron=(72, 62, 80),
               apron_dark=(46, 40, 52), apron_edge=(36, 30, 42), trousers=(52, 50, 50), boots=(78, 60, 46),
               boots_dark=(48, 38, 30), belt=(62, 46, 36), beret=(54, 52, 58), beret_dark=(34, 32, 38),
               feather=(60, 60, 64), purse=(112, 78, 50), hair=(52, 40, 32))

    def wool(cv, seed, folds=14, hem=False):
        return fabric(cv, base="apron", dark="apron_dark", seed=seed, folds=folds, hem=hem, grime=0.45)

    def coat_body(cv):
        w, h = cv.pw, cv.ph
        img = wool(cv, 911)
        bw = max(4, int(w * 0.03))
        img = gold_edges(img, w, h, left=bw, right=bw)
        yy, xx = np.mgrid[0:h, 0:w]
        for x in (bw + 6, w - bw - 7):                       # the gold buttons down both front edges
            for k in range(5):
                y = int(h * (0.12 + 0.17 * k))
                img[((xx - x) ** 2 + (yy - y) ** 2) < 12] = col("gold_dark")
        cv.put(img)

    def coat_skirt(cv):
        w, h = cv.pw, cv.ph
        img = wool(cv, 921, folds=18, hem=True)
        img = gold_edges(img, w, h, left=max(4, int(w * 0.03)), bottom=max(4, int(h * 0.035)))
        cv.put(img)

    def lapels(cv):
        w, h = cv.pw, cv.ph
        img = brocade(wool(cv, 931, folds=4), w, h)
        img = gold_edges(img, w, h, left=3, right=3, top=4)
        cv.put(img)

    def cuffs(cv):
        w, h = cv.pw, cv.ph
        img = brocade(tint(col("apron_dark"), fbm(w, h, 8, 3, (True, True), 941), 0.10), w, h)
        img[: max(2, int(h * 0.10))] = col("gold")
        cv.put(img)

    def tunic(cv):
        img = fabric(cv, seed=951, folds=10, grime=0.4)
        cv.put(laced_v(img, cv.pw, cv.ph, top_v=1.0, depth=0.22, half=0.05, under="shirt_dark", laces=3))
    return pal, [("shirt", True, False, tunic), ("bib", False, False, coat_body), ("apron", False, False, coat_skirt),
                 ("straps", False, False, lapels), ("sleeve", True, False, lambda cv: cv.put(wool(cv, 961, folds=12))),
                 ("roll", True, True, cuffs), ("hand", False, False, P.hands), ("trousers", True, False, P.trousers),
                 ("seat", True, False, lambda cv: P.trousers(cv, seat=True)), ("boots", True, False, P.boots),
                 ("belt", True, True, P.belt),
                 ("cloth", True, False, lambda cv: cv.put(fabric(cv, base="beret", dark="beret_dark", seed=971, folds=8, grime=0.3)))], \
        flat_cells({"knot": "purse", "strap_dark": "feather", "metal_dark": "boots_dark", "stitch": "apron_edge"})


def _old_woman():
    pal = dict(COMMON, skin=(186, 146, 122), skin_dark=(136, 102, 86), shirt=(86, 72, 60), shirt_dark=(54, 44, 38),
               patch=(70, 58, 48), shawl=(116, 100, 116), shawl_dark=(80, 66, 82), boots=(66, 52, 42),
               boots_dark=(40, 32, 26), belt=(70, 58, 48), cane=(78, 56, 40), apron_dark=(54, 44, 38),
               apron_edge=(40, 32, 28), hair=(150, 150, 150))

    def dress(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, seed=1011, folds=26, hem=True, fray=True, grime=0.55)
        img = patches(img, w, h, [(0.38, 0.30, 13, 15), (0.62, 0.22, 12, 12), (0.10, 0.45, 12, 14)], "patch", 1012)
        cv.put(img)

    def shawl(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, base="shawl", dark="shawl_dark", seed=1021, folds=14, grime=0.5)
        cv.put(fringe(img, w, h))
    return pal, [("shirt", True, False, dress), ("bib", False, False, shawl),
                 ("sleeve", True, False, lambda cv: cv.put(fabric(cv, seed=1031, folds=14, vfold=False))),
                 ("hand", False, False, P.hands), ("boots", True, False, P.boots),
                 ("belt", True, True, lambda cv: cv.put(fabric(cv, base="shirt_dark", dark="shirt_dark", seed=1041, folds=4)))], \
        flat_cells({"knot": "belt", "strap_dark": "boots_dark", "metal_dark": "cane", "stitch": "apron_edge"})


VARIANTS = {"farmer": _farmer, "local": _local, "traveller": _traveller, "guard": _guard, "merchant": _merchant,
            "old_woman": _old_woman}
BG = {"farmer": 156, "local": 165, "traveller": 172, "guard": 164, "merchant": 165, "old_woman": 165}


def paint(v, overwrite=False):
    head = ART + "textures/realistic/g19_%s_real_head.png" % v
    body = ART + "textures/realistic/g19_%s_real_body.png" % v
    for p in (head, body):
        if os.path.exists(p) and not overwrite:
            sys.exit("%s exists (--overwrite)" % p)
    pal, painters, cells = VARIANTS[v]()
    P.head_texture(head, L.TOWNSFOLK_SHEETS[v], skin_rgb=pal["skin"], bg_value=BG[v])
    P.body_texture(body, painters=painters, palette=pal, ground="apron_dark", misc_fn=cells)


if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    for v in (list(VARIANTS) if names == ["all"] else names):
        paint(v, "--overwrite" in sys.argv)
