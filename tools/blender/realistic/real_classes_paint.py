# real_classes_paint.py - the class bodies' textures (Story 25.31 S3, AC 8), system Python (numpy + Pillow): per class
# the head texture (real_paint.head_texture on its sheet, real_layout.CLASS_SHEETS) and the body atlas
# (real_paint.body_texture with the class's painters and palette over real_layout.REG). Colours: the picks' muted tones
# (R-7) within data/config/class_colors.json's hues; V6: green only on the Ranger and the Rogue's small scarf; cream
# only on the Healer. Region use (real_classes):
#   fighter    shirt the tabard, sleeve / bib the mail (sleeves; collar and skirt), cloth / roll the plate (pauldrons,
#              poleyns; vambraces), apron the shield's face
#   rogue      shirt the tunic, apron the cowl, straps the green scarf, roll the bracers, forearm her bare arms
#   mage       shirt the robe's body, apron its skirt halves, bib the cowl, cloth the hat, roll the cuffs
#   healer     shirt the robe's body (the tabard's gold edges and green cross), apron its skirt halves, bib the capelet,
#              sleeve the bell sleeves (gold cuffs)
#   barbarian  shirt the jerkin, bib the fur mantle, roll the bracers, forearm his bare arms (scars)
#   ranger     shirt the jerkin, sleeve the grey sleeves, roll the bracers, bib the cowl, apron the cape, cloth her hair
#   all        trousers, seat, boots, belt, hand; misc's flat cells for straps, satchels and the props
# Usage: python real_classes_paint.py <class>|all [--overwrite] [--body-only]
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import real_layout as L  # noqa: E402
import real_paint as P  # noqa: E402
import real_townsfolk_paint as TP  # noqa: E402
from real_paint import col, fbm, fold_strokes, lines_layer, mix, tint  # noqa: E402

ART = "F:/GAME I AM MAKING/eternal_guild_art/"
G = {"fighter": "g2", "rogue": "g3", "mage": "g4", "healer": "g5", "barbarian": "g6", "ranger": "g7"}
COMMON = dict(TP.COMMON)


def fabric(cv, **kw):
    return TP.fabric(cv, **kw)


def region_img(cv):
    return cv.img[cv.y0:cv.y0 + cv.ph, cv.x0:cv.x0 + cv.pw].astype(float)


def leather_tile(w, h, base, dark, seed, edges=True):
    img = tint(col(base), fbm(w, h, 5, 4, (False, False), seed), 0.15)
    img = mix(img, np.clip((fbm(w, h, 8, 3, (False, False), seed + 1) - 0.58) * 3, 0, 1), col(dark), 0.55)
    img = mix(img, lines_layer(w, h, fold_strokes(w, h, 8, h * 0.2, True, 0.4, seed + 2), 1.4, False, 0.5), col("ink"), 0.3)
    if edges:
        xx = np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]
        img = mix(img, np.clip((0.03 - np.minimum(xx, 1 - xx)) / 0.03, 0, 1), col(dark), 0.8)
    return img


def wrap_leather(cv, base, dark, seed, stitch_rows=(0.15, 0.85)):
    w, h = cv.pw, cv.ph
    img = tint(col(base), fbm(w, h, 6, 4, (cv.wrap_u, cv.wrap_v), seed), 0.15)
    img = mix(img, np.clip((fbm(w, h, 9, 3, (cv.wrap_u, cv.wrap_v), seed + 1) - 0.58) * 3, 0, 1), col(dark), 0.55)
    st = np.zeros((h, w))
    for r in stitch_rows:
        st[int(h * r), ::5] = 1
    img = mix(img, st, col(dark), 0.8)
    yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
    img = mix(img, ((yy < 0.06) | (yy > 0.94)).astype(float), col(dark), 0.7)
    cv.put(img)


def hair_strands(cv, base="hair", dark="hair_dark", light="hair_light", seed=1201):
    """Hair as strands along v (the hair shell's rows run up the head, the braid's along its length)."""
    w, h = cv.pw, cv.ph
    st = np.asarray(Image.fromarray((fbm(w, 6, 60, 3, (cv.wrap_u, False), seed) * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR),
                    dtype=float) / 255
    img = tint(col(base), st, 0.30)
    img = mix(img, np.clip((st - 0.62) * 4, 0, 1), col(light), 0.6)
    img = mix(img, np.clip((0.40 - st) * 4, 0, 1), col(dark), 0.6)
    cv.put(img)


def flat_cells(names):
    return TP.flat_cells(names)


# ------------------------------------------------------------------ the classes

def _fighter():
    pal = dict(COMMON, shirt=(94, 36, 34), shirt_dark=(60, 22, 22), undershirt=(70, 72, 78), trousers=(70, 54, 42),
               patch=(96, 76, 58), boots=(78, 58, 42), boots_dark=(48, 36, 28), belt=(62, 44, 32),
               mail=(86, 88, 94), mail_dark=(46, 48, 54), steel=(104, 108, 116), steel_dark=(62, 66, 74),
               wood=(112, 84, 58), wood_dark=(70, 52, 36), star=(132, 44, 38), apron_dark=(70, 26, 26),
               apron_edge=(50, 20, 20), hair=(54, 40, 30), grip=(60, 44, 34))

    def tabard(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, seed=1311, folds=16, hem=True, fray=True, grime=0.45)
        img = TP.laced_v(img, w, h, top_v=1.0, depth=0.10, half=0.030, under="mail_dark", laces=3)
        cv.put(img)

    def plate(cv, seed=1321):
        TP.steel(cv, seed=seed)

    def shield(cv):
        w, h = cv.pw, cv.ph
        img = tint(col("wood"), fbm(w, h, 5, 4, (False, False), 1331), 0.14)
        xx, yy = np.meshgrid(np.linspace(-1, 1, w), np.linspace(1, -1, h))
        for k in range(-3, 4):                                         # the planks
            img = mix(img, (np.abs(xx - k * 0.27) < 0.012).astype(float), col("wood_dark"), 0.9)
        r = np.hypot(xx, yy)
        a = np.arctan2(yy, xx)
        star_r = 0.30 + 0.48 * np.abs(np.cos(4 * a)) ** 6             # an eight-point star
        img = mix(img, ((r < star_r) & (r > 0.16)).astype(float), col("star"), 0.85)
        img = mix(img, (r > 0.90).astype(float), col("steel"), 1.0)  # the rim
        img = mix(img, ((r > 0.88) & (r < 0.91)).astype(float), col("steel_dark"), 1.0)
        rv = np.zeros((h, w))
        for k in range(12):
            t = 2 * math.pi * k / 12
            rv += np.exp(-(((xx - 0.80 * math.cos(t)) ** 2 + (yy - 0.80 * math.sin(t)) ** 2) / 0.0006))
        img = mix(img, np.clip(rv, 0, 1), col("steel_dark"), 0.9)
        img = mix(img, np.clip((fbm(w, h, 10, 3, (False, False), 1332) - 0.62) * 3, 0, 1), col("wood_dark"), 0.5)
        cv.put(img)
    return pal, [("shirt", True, False, tabard), ("sleeve", True, False, lambda cv: TP.mail(cv, seed=1341)),
                 ("bib", False, False, lambda cv: TP.mail(cv, seed=1342)), ("cloth", False, False, plate),
                 ("roll", True, True, lambda cv: plate(cv, 1343)), ("apron", False, False, shield),
                 ("hand", False, False, P.hands), ("trousers", True, False, _patched("patch", 1351)),
                 ("seat", True, False, lambda cv: P.trousers(cv, seat=True)), ("boots", True, False, P.boots),
                 ("belt", True, True, P.belt)], \
        flat_cells({"knot": "belt", "strap_dark": "belt", "metal_dark": "steel", "buckle": "steel_dark", "laces": "grip",
                    "stitch": "apron_edge"})


def _patched(colour, seed, spots=((0.02, 0.62, 0.07, 0.055), (0.48, 0.40, 0.06, 0.05))):
    def fn(cv):
        P.trousers(cv)
        w, h = cv.pw, cv.ph
        sub = region_img(cv)
        cv.put(TP.patches(sub, w, h, [(u, v, int(w * a), int(h * b)) for u, v, a, b in spots], colour, seed))
    return fn


def _rogue():
    pal = dict(COMMON, skin=(196, 156, 128), skin_dark=(150, 112, 92), shirt=(104, 76, 56), shirt_dark=(64, 46, 34),
               cowl=(66, 50, 40), cowl_dark=(40, 30, 24), scarf=(60, 104, 66), scarf_dark=(36, 66, 42),
               leather=(92, 66, 46), leather_dark=(56, 40, 28), trousers=(68, 64, 60), patch=(90, 80, 68),
               boots=(98, 74, 54), boots_dark=(58, 44, 32), belt=(62, 46, 34), apron_dark=(40, 30, 24),
               apron_edge=(30, 22, 18), hair=(150, 70, 40), sheath=(54, 40, 30), grip=(70, 50, 36), steel=(120, 124, 130))

    def tunic(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, seed=1411, folds=18, hem=True, fray=True, grime=0.5)
        cv.put(TP.patches(img, w, h, [(0.30, 0.25, 10, 12)], "shirt_dark", 1412))

    def cowl(cv):
        cv.put(fabric(cv, base="cowl", dark="cowl_dark", seed=1421, folds=14, hem=True, grime=0.4))

    def scarf(cv):
        cv.put(fabric(cv, base="scarf", dark="scarf_dark", seed=1431, folds=8, grime=0.25))
    return pal, [("shirt", True, False, tunic), ("apron", False, False, cowl), ("straps", False, False, scarf),
                 ("roll", True, True, lambda cv: wrap_leather(cv, "leather", "leather_dark", 1441, (0.3, 0.55, 0.8))),
                 ("forearm", True, False, lambda cv: P.skin(cv, hairy=False, seed=1451)),
                 ("hand", False, False, P.hands), ("trousers", True, False, _patched("patch", 1461, ((0.05, 0.70, 0.07, 0.05), (0.55, 0.45, 0.06, 0.05), (0.35, 0.20, 0.05, 0.04)))),
                 ("seat", True, False, lambda cv: P.trousers(cv, seat=True)), ("boots", True, False, P.boots),
                 ("belt", True, True, P.belt)], \
        flat_cells({"knot": "sheath", "strap_dark": "belt", "metal_dark": "steel", "laces": "grip", "stitch": "apron_edge"})


def _mage():
    pal = dict(COMMON, shirt=(84, 92, 106), shirt_dark=(52, 58, 70), navy=(42, 48, 76), navy_dark=(26, 30, 50),
               felt=(88, 80, 74), felt_dark=(58, 52, 48), trousers=(80, 64, 50), patch=(70, 76, 90),
               boots=(84, 64, 48), boots_dark=(52, 40, 30), belt=(70, 52, 38), satchel=(108, 80, 56),
               wood=(74, 54, 40), apron_dark=(52, 58, 70), apron_edge=(36, 40, 50), hair=(40, 32, 28))

    def robe_body(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, seed=1511, folds=14, grime=0.5)
        img = TP.patches(img, w, h, [(0.18, 0.55, 12, 12), (0.80, 0.35, 10, 11)], "shirt_dark", 1512)
        xx = np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]
        img = mix(img, (np.abs(xx - 0.5) < 0.020).astype(float), col("navy"), 1.0)          # the placket down the front
        img = mix(img, (np.abs(np.abs(xx - 0.5) - 0.020) < 0.003).astype(float), col("ink"), 0.8)
        cv.put(img)

    def robe_skirt(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, seed=1521, folds=22, hem=False, grime=0.6)
        img = TP.patches(img, w, h, [(0.25, 0.45, 13, 15), (0.70, 0.62, 11, 12), (0.45, 0.20, 10, 10)], "shirt_dark", 1522)
        yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
        xx = np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]
        img = mix(img, (yy < 0.05).astype(float), col("navy"), 1.0)                         # the navy hem band
        img = mix(img, (xx < 0.035).astype(float), col("navy"), 1.0)                         # the front edge (the opening)
        img = mix(img, ((yy < 0.006) | (xx < 0.004)).astype(float), col("ink"), 0.9)
        cv.put(img)
    return pal, [("shirt", True, False, robe_body), ("apron", False, False, robe_skirt),
                 ("bib", False, False, lambda cv: cv.put(fabric(cv, base="navy", dark="navy_dark", seed=1531, folds=12, grime=0.3))),
                 ("sleeve", True, False, lambda cv: cv.put(TP.patches(fabric(cv, seed=1541, folds=14, vfold=False), cv.pw, cv.ph,
                                                                      [(0.6, 0.55, 10, 12)], "shirt_dark", 1542))),
                 ("roll", True, True, lambda cv: cv.put(fabric(cv, base="navy", dark="navy_dark", seed=1551, folds=4))),
                 ("cloth", False, False, lambda cv: cv.put(fabric(cv, base="felt", dark="felt_dark", seed=1561, folds=10, grime=0.55))),
                 ("hand", False, False, P.hands), ("trousers", True, False, P.trousers),
                 ("seat", True, False, lambda cv: P.trousers(cv, seat=True)), ("boots", True, False, P.boots),
                 ("belt", True, True, P.belt)], \
        flat_cells({"knot": "satchel", "strap_dark": "belt", "metal_dark": "wood", "stitch": "apron_edge"})


def _healer():
    pal = dict(COMMON, skin=(198, 160, 134), skin_dark=(150, 114, 96), shirt=(184, 174, 150), shirt_dark=(140, 128, 106),
               cross=(66, 112, 70), trousers=(84, 86, 84), boots=(98, 74, 54), boots_dark=(58, 44, 32), belt=(70, 50, 36),
               satchel=(98, 70, 48), wood=(80, 58, 42), patch=(140, 120, 96), apron_dark=(140, 128, 106),
               apron_edge=(104, 92, 74), hair=(36, 28, 24))

    def robe_body(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, seed=1611, folds=12, grime=0.35)
        xx = np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]
        yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
        for x in (0.5 - 0.130, 0.5 + 0.130):                                                # the tabard's gold edges
            img = mix(img, (np.abs(xx - x) < 0.010).astype(float), col("gold"), 1.0)
            img = mix(img, (np.abs(np.abs(xx - x) - 0.010) < 0.002).astype(float), col("gold_dark"), 1.0)
        # the green cross on her chest (her pick: ~0.20 m tall, 0.18 m across, z 1.10-1.30, the bar at 1.22; v = (z - 0.96) / 0.46)
        cross = ((np.abs(xx - 0.5) < 0.026) & (yy > 0.30) & (yy < 0.75)) | ((np.abs(yy - 0.57) < 0.050) & (np.abs(xx - 0.5) < 0.092))
        img = mix(img, cross.astype(float), col("cross"), 1.0)
        img = mix(img, np.clip((fbm(w, h, 10, 3, (True, False), 1612) - 0.66) * 3, 0, 1), col("apron_edge"), 0.35)
        cv.put(img)

    def robe_skirt(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, seed=1621, folds=18, grime=0.55)
        img = TP.patches(img, w, h, [(0.62, 0.40, 12, 13)], "patch", 1622)
        img = TP.gold_edges(img, w, h, left=max(4, int(w * 0.025)), bottom=max(5, int(h * 0.035)))
        cv.put(img)

    def capelet(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, seed=1631, folds=12, grime=0.3)
        cv.put(TP.gold_edges(img, w, h, bottom=max(5, int(h * 0.06))))

    def sleeve(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, seed=1641, folds=12, vfold=False, grime=0.4)
        img = TP.patches(img, w, h, [(0.55, 0.50, 10, 12)], "patch", 1642)
        yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
        img = mix(img, (yy > 0.93).astype(float), col("gold"), 1.0)                        # the gold cuff (the wrist end)
        img = mix(img, ((yy > 0.925) & (yy < 0.935)).astype(float), col("gold_dark"), 1.0)
        cv.put(img)
    return pal, [("shirt", True, False, robe_body), ("apron", False, False, robe_skirt), ("bib", False, False, capelet),
                 ("sleeve", True, False, sleeve), ("hand", False, False, P.hands), ("trousers", True, False, P.trousers),
                 ("seat", True, False, lambda cv: P.trousers(cv, seat=True)), ("boots", True, False, P.boots),
                 ("belt", True, True, P.belt)], \
        flat_cells({"knot": "satchel", "strap_dark": "belt", "metal_dark": "wood", "stitch": "apron_edge"})


def _barbarian():
    pal = dict(COMMON, skin=(194, 150, 122), skin_dark=(146, 106, 88), shirt=(124, 78, 48), shirt_dark=(78, 48, 30),
               fur=(74, 66, 62), fur_dark=(42, 38, 36), fur_light=(104, 96, 90), trousers=(76, 70, 62), patch=(98, 88, 74),
               boots=(84, 64, 48), boots_dark=(50, 38, 30), belt=(58, 44, 36), leather=(66, 48, 36), leather_dark=(40, 30, 24),
               strapc=(52, 38, 30), steel=(112, 114, 120), apron_dark=(78, 48, 30), apron_edge=(54, 32, 22), hair=(54, 40, 30),
               scar=(150, 96, 84))

    def jerkin(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, seed=1711, folds=16, hem=True, fray=True, grime=0.55)
        cv.put(TP.patches(img, w, h, [(0.30, 0.25, 12, 14), (0.75, 0.40, 10, 11), (0.12, 0.62, 9, 10)], "shirt_dark", 1712))

    def fur(cv):
        w, h = cv.pw, cv.ph
        img = tint(col("fur"), fbm(w, h, 8, 4, (True, False), 1721), 0.18)
        rng = np.random.default_rng(1722)
        tufts = []
        for _ in range(int(w * h / 90)):
            x, y = rng.random() * w, rng.random() * h
            a = math.radians(95 + 25 * (rng.random() - 0.5))
            ln = 8 + 10 * rng.random()
            tufts.append(([(x, y), (x + math.cos(a) * ln * 0.5 + 2, y + math.sin(a) * ln)], 0.6 + 0.6 * rng.random()))
        img = mix(img, lines_layer(w, h, tufts[: len(tufts) // 2], 1.6, True, 0.3), col("fur_dark"), 0.8)
        img = mix(img, lines_layer(w, h, tufts[len(tufts) // 2:], 1.3, True, 0.3), col("fur_light"), 0.6)
        cv.put(img)

    def arms(cv):
        P.skin(cv, hairy=True, seed=1731)
        w, h = cv.pw, cv.ph
        sub = region_img(cv)
        sc = lines_layer(w, h, [([(w * 0.18, h * 0.30), (w * 0.26, h * 0.36)], 1.0), ([(w * 0.62, h * 0.55), (w * 0.70, h * 0.50)], 1.0),
                                ([(w * 0.40, h * 0.18), (w * 0.47, h * 0.22)], 1.0)], 2, True, 0.5)
        cv.put(mix(sub, sc, col("scar"), 0.8))
    return pal, [("shirt", True, False, jerkin), ("bib", True, False, fur),
                 ("roll", True, True, lambda cv: wrap_leather(cv, "leather", "leather_dark", 1741, (0.25, 0.5, 0.75))),
                 ("forearm", True, False, arms), ("hand", False, False, P.hands),
                 ("trousers", True, False, _patched("patch", 1751, ((0.02, 0.62, 0.07, 0.055), (0.55, 0.42, 0.07, 0.05), (0.30, 0.78, 0.05, 0.04)))),
                 ("seat", True, False, lambda cv: P.trousers(cv, seat=True)), ("boots", True, False, P.boots),
                 ("belt", True, True, P.belt)], \
        flat_cells({"knot": "belt", "strap_dark": "strapc", "metal_dark": "steel", "buckle": "steel", "stitch": "apron_edge"})


def _ranger():
    pal = dict(COMMON, skin=(198, 160, 134), skin_dark=(150, 114, 96), shirt=(62, 88, 60), shirt_dark=(38, 56, 38),
               sleeve_g=(84, 86, 84), sleeve_dark=(54, 56, 54), cowl=(80, 60, 44), cowl_dark=(50, 38, 28),
               cape=(86, 68, 52), cape_dark=(56, 44, 34), trousers=(88, 70, 54), patch=(110, 92, 72),
               boots=(102, 80, 58), boots_dark=(60, 46, 34), belt=(64, 48, 36), hair=(132, 100, 66), hair_dark=(84, 62, 40),
               hair_light=(172, 138, 94), quiver=(110, 82, 56), qband=(70, 52, 38), shaft=(130, 104, 74),
               fletch=(150, 40, 36), bow=(84, 60, 42), apron_dark=(56, 44, 34), apron_edge=(38, 30, 24))

    def jerkin(cv):
        w, h = cv.pw, cv.ph
        img = fabric(cv, seed=1811, folds=10, hem=True, grime=0.45)
        xx = np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]
        yy = np.linspace(1, 0, h)[:, None] * np.ones((1, w))
        for x in (0.5 - 0.11, 0.5 + 0.11, 0.0, 1.0):                                        # leather panel seams
            img = mix(img, (np.abs(xx - x) < 0.004).astype(float), col("shirt_dark"), 0.9)
        img = mix(img, (np.abs(xx - 0.5) < 0.006).astype(float) * (yy > 0.45), col("shirt_dark"), 1.0)   # the lacing line
        for k in range(5):
            y = 0.52 + 0.08 * k
            img = mix(img, ((np.abs(xx - 0.5) < 0.012) & (np.abs(yy - y) < 0.008)).astype(float), col("ink"), 0.8)
        cv.put(img)
    return pal, [("shirt", True, False, jerkin),
                 ("sleeve", True, False, lambda cv: cv.put(fabric(cv, base="sleeve_g", dark="sleeve_dark", seed=1821, folds=14, vfold=False))),
                 ("roll", True, True, lambda cv: wrap_leather(cv, "shirt", "shirt_dark", 1831, (0.3, 0.6))),
                 ("bib", False, False, lambda cv: cv.put(fabric(cv, base="cowl", dark="cowl_dark", seed=1841, folds=10, grime=0.4))),
                 ("apron", False, False, lambda cv: cv.put(fabric(cv, base="cape", dark="cape_dark", seed=1851, folds=20, hem=True, fray=True, grime=0.55))),
                 ("cloth", True, False, hair_strands), ("hand", False, False, P.hands),
                 ("trousers", True, False, _patched("patch", 1861)), ("seat", True, False, lambda cv: P.trousers(cv, seat=True)),
                 ("boots", True, False, P.boots), ("belt", True, True, P.belt)], \
        flat_cells({"knot": "quiver", "strap_dark": "qband", "metal_dark": "bow", "laces": "shaft", "stitch": "fletch"})


def _barbarian_head(path):
    """His pick's back view has the axe across his hair (image-left of the midline, above row ~280): the back
    quadrant's left half takes its right half mirrored there (the long hair and the fur are near symmetric)."""
    im = np.asarray(Image.open(path).convert("RGB")).copy()
    N = im.shape[0]
    Q = N // 2
    sh = L.CLASS_SHEETS["barbarian"]
    wx, wy, u0, v0 = sh["head_crops"]["back"]
    win = sh["head_win"]
    mid = int(round((L.CLASS_SHEETS["barbarian"]["views"]["back"][0] - wx) / win * Q))
    rows = int(round((280.0 - wy) / win * Q))
    y0, x0 = N - Q, 0                                         # the back quadrant: u 0-0.5, v 0-0.5 (image bottom-left)
    blk = im[y0:y0 + rows, x0:x0 + Q]
    w = min(mid, Q - mid)
    blk[:, mid - w:mid] = blk[:, mid:mid + w][:, ::-1]
    Image.fromarray(im).save(path)
    print("barbarian head: the axe mirrored out of the back view (%d rows, mid %d)" % (rows, mid))


HEAD_FIX = {"barbarian": _barbarian_head}

VARIANTS = {"fighter": _fighter, "rogue": _rogue, "mage": _mage, "healer": _healer, "barbarian": _barbarian, "ranger": _ranger}
BG = {"fighter": 164, "rogue": 165, "mage": 164, "healer": 168, "barbarian": 164, "ranger": 150}


def paint(v, overwrite=False, body_only=False):
    head = ART + "textures/realistic/%s_%s_real_head.png" % (G[v], v)
    body = ART + "textures/realistic/%s_%s_real_body.png" % (G[v], v)
    for p in ([body] if body_only else [head, body]):
        if os.path.exists(p) and not overwrite:
            sys.exit("%s exists (--overwrite)" % p)
    pal, painters, cells = VARIANTS[v]()
    if not body_only:
        P.head_texture(head, L.CLASS_SHEETS[v], skin_rgb=pal["skin"], bg_value=BG[v])
        if v in HEAD_FIX:
            HEAD_FIX[v](head)
    P.body_texture(body, painters=painters, palette=pal, ground="apron_dark", misc_fn=cells)


if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    for v in (list(VARIANTS) if names == ["all"] else names):
        paint(v, "--overwrite" in sys.argv, "--body-only" in sys.argv)
