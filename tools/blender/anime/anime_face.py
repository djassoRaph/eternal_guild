# anime_face.py - route AN (Stories 25.30, 25.31): a painted anime face texture (1024 px, RGB, no alpha), front-
# projected onto the head by anime_kit.build_head: u = 0.5 + x / 0.5 (x in metres, -0.25..0.25), v = (z - chin) /
# (crown - chin). Runs in system Python with Pillow (not inside Blender):
#   python anime_face.py <out.png> [preset] [--overwrite]      (presets: PRESETS; the default "dealer" is hers)
#   run(out, preset="dealer", overwrite=False, **overrides)       (overrides: any key, e.g. iris colours, skin)
# A face preset is a dict of paint parameters: the eye shape (eye_half, iris_half, lash weight, the outer flick), the
# brows (weight, arc, tilt, colour), the lines of age, the blush and the colours.
#
# What must read in the world is the eye mass (a dark-rimmed iris with the lash line on its top): at zoom 8 one screen
# pixel covers ~30 face texels (mip ~5), at zoom 12 ~45-64 (mip 5.5-6). Brows and highlights are for the portraits
# (A-2): kept in the approved test's light style. The script builds Godot's mip chain (2x2 averages) and prints, per
# eye, the darkest mip-5 texel as a fraction of the skin's luminance darker; the gate is >= 40 %.
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

N = 1024
CHIN_Z, CROWN_Z = -0.29, 0.29       # head-relative (the head's half height HR.z = 0.29)
DEALER = {
    "skin": (247, 222, 207), "lash": (43, 29, 31),
    "iris_top": (24, 92, 94), "iris_bottom": (68, 192, 170), "iris_rim": (16, 66, 66), "glow": (84, 204, 188), "pupil": (12, 44, 46),
    "brow": (176, 150, 122), "mouth": (236, 150, 150), "lip_line": (170, 86, 90), "nose": (214, 160, 148), "blush": (240, 140, 140),
    "eye_x": 0.092, "eye_z": -0.048, "eye_half": (100, 108), "iris_half": (70, 94), "brow_z": 0.058,
}
# Shapes over the dealer's paint (young/adult/aged x female/male); colours (iris, brow, skin) are the character's
# overrides. Male eyes: narrower and shorter, a lighter lash with no outer flick, heavier straighter brows; aged: the
# lines (under-eye, crow's feet, smile lines) and a heavier lid.
_F = {"lash_w": (9, 26), "flick": True, "brow_w": (4, 10), "brow_arc": 42, "brow_tilt": 0.0, "lines": 0, "blush_a": 95,
      "mouth_w": 30}
_M = {"eye_half": (94, 86), "iris_half": (62, 76), "lash_w": (8, 18), "flick": False, "brow_w": (10, 18), "brow_arc": 24,
      "brow_tilt": 6.0, "brow_z": 0.050, "blush_a": 40, "mouth_w": 24, "brow": (96, 74, 58)}
PRESETS = {
    "dealer": {},
    "young_f": dict(_F, eye_half=(104, 112), iris_half=(74, 98), brow=(120, 86, 60), iris_top=(70, 44, 26), iris_bottom=(170, 112, 62),
                    iris_rim=(52, 30, 18), glow=(196, 138, 80), pupil=(36, 20, 12)),
    "adult_f": dict(_F, eye_half=(98, 100), iris_half=(68, 88), brow=(110, 78, 56), iris_top=(70, 44, 26), iris_bottom=(170, 112, 62),
                    iris_rim=(52, 30, 18), glow=(196, 138, 80), pupil=(36, 20, 12), blush_a=70),
    "aged_f": dict(_F, eye_half=(92, 84), iris_half=(62, 72), lash_w=(8, 18), flick=False, brow=(160, 156, 150), brow_w=(4, 9),
                   lines=2, blush_a=50, iris_top=(60, 70, 84), iris_bottom=(120, 140, 160), iris_rim=(40, 48, 60), glow=(150, 168, 186),
                   pupil=(26, 30, 38)),
    "young_m": dict(_M, eye_half=(98, 94), iris_half=(66, 82), iris_top=(40, 56, 82), iris_bottom=(96, 132, 176), iris_rim=(26, 36, 56),
                    glow=(120, 160, 200), pupil=(18, 24, 36)),
    "adult_m": dict(_M, iris_top=(60, 44, 30), iris_bottom=(140, 104, 66), iris_rim=(40, 28, 18), glow=(170, 128, 84), pupil=(30, 20, 14)),
    "aged_m": dict(_M, eye_half=(90, 74), iris_half=(60, 66), brow=(170, 166, 160), brow_w=(12, 20), lines=2, blush_a=25,
                   iris_top=(60, 70, 84), iris_bottom=(120, 140, 160), iris_rim=(40, 48, 60), glow=(150, 168, 186), pupil=(26, 30, 38)),
}


def preset(name, **overrides):
    """DEALER's paint with the preset's and the caller's overrides (an unknown key refuses)."""
    if name not in PRESETS:
        raise ValueError("unknown face preset %r (known: %s)" % (name, sorted(PRESETS)))
    p = dict(DEALER)
    p.update(PRESETS[name])
    bad = sorted(k for k in overrides if k not in p and k not in _F and k not in _M)
    if bad:
        raise ValueError("unknown face parameters %s" % bad)
    p.update(overrides)
    return p


def px(x, z):
    """Head-relative metres (x right = her left, z up from the head's centre) to pixels."""
    return (0.5 + x / 0.5) * N, (1.0 - (z - CHIN_Z) / (CROWN_Z - CHIN_Z)) * N


def arc_pts(cx, cy, w, h, a0, a1, n=40):
    return [(cx + w * math.cos(math.radians(a)), cy + h * math.sin(math.radians(a))) for a in [a0 + (a1 - a0) * i / n for i in range(n + 1)]]


def paint(p=DEALER):
    img = Image.new("RGBA", (N, N), p["skin"] + (255,))
    d = ImageDraw.Draw(img)

    def thick_line(pts, w0, w1, fill):
        for i in range(len(pts) - 1):
            t = i / max(1, len(pts) - 2)
            w = w0 + (w1 - w0) * t
            d.line([pts[i], pts[i + 1]], fill=fill, width=max(1, int(round(w))))
            d.ellipse((pts[i][0] - w / 2, pts[i][1] - w / 2, pts[i][0] + w / 2, pts[i][1] + w / 2), fill=fill)

    ew, eh = p["eye_half"]
    iw, ih = p["iris_half"]
    lw0, lw1 = p.get("lash_w", (9, 26))
    bw0, bw1 = p.get("brow_w", (4, 10))
    for sx in (-1, 1):
        cx, cy = px(sx * p["eye_x"], p["eye_z"])
        d.ellipse((cx - ew, cy - eh, cx + ew, cy + eh), fill=(252, 250, 247))
        icx, icy = cx + sx * 4, cy + 8
        for k in range(ih * 2):
            t = k / (ih * 2)
            y = icy - ih + k
            half = iw * math.sqrt(max(0.0, 1 - ((y - icy) / ih) ** 2))
            col = tuple(int(a + (b - a) * t) for a, b in zip(p["iris_top"], p["iris_bottom"]))
            d.line([(icx - half, y), (icx + half, y)], fill=col)
        d.ellipse((icx - iw, icy - ih, icx + iw, icy + ih), outline=p["iris_rim"], width=7)
        d.ellipse((icx - 44, icy + 28, icx + 32, icy + 72), fill=p["glow"])
        d.ellipse((icx - 26, icy - 42, icx + 26, icy + 40), fill=p["pupil"])
        d.ellipse((icx - 62, icy - 66, icx - 16, icy - 14), fill=(255, 255, 255))
        d.ellipse((icx + 18, icy + 34, icx + 40, icy + 56), fill=(255, 255, 255))
        upper = arc_pts(cx, cy + 8, ew + 8, eh * 0.96, 180, 360)
        lower = arc_pts(cx, cy - 12, ew + 8, eh * 0.92, 0, 180)
        d.polygon(upper + [(cx + ew + 40, cy - eh - 80), (cx - ew - 40, cy - eh - 80)], fill=p["skin"])
        d.polygon(lower + [(cx - ew - 40, cy + eh + 60), (cx + ew + 40, cy + eh + 60)], fill=p["skin"])
        lid = upper if sx > 0 else upper[::-1]
        thick_line(lid, lw0, lw1, p["lash"])
        ox, oy = lid[-1]
        if p.get("flick", True):
            thick_line([(ox - sx * 6, oy - 10), (ox + sx * 22, oy - 12), (ox + sx * 40, oy - 20)], 22, 6, p["lash"])
        low = lower if sx < 0 else lower[::-1]
        thick_line(low[:18], 6, 3, (122, 82, 76))
        bx, by = px(sx * 0.098, p["brow_z"])
        arc = p.get("brow_arc", 42)
        brow = arc_pts(bx, by + arc, 94, arc, 200, 340, 20)
        tilt = p.get("brow_tilt", 0.0)
        if tilt:                                          # the inner end lower (a frown line): rotate about the brow's centre
            a = math.radians(tilt) * -sx
            brow = [(bx + (x - bx) * math.cos(a) - (y - by) * math.sin(a), by + (x - bx) * math.sin(a) + (y - by) * math.cos(a)) for x, y in brow]
        thick_line(brow if sx > 0 else brow[::-1], bw0, bw1, p["brow"])
        if p.get("lines", 0):                             # age: an under-eye line and two crow's feet
            line = tuple(int(c * 0.80) for c in p["skin"])
            thick_line(arc_pts(cx, cy + eh * 0.55, ew * 0.85, eh * 0.55, 30, 150, 16), 4, 4, line)
            for k in range(p["lines"]):
                y0 = cy - 20 + 34 * k
                thick_line([(cx + sx * (ew + 30), y0), (cx + sx * (ew + 70), y0 + 10 * (k - 0.5))], 4, 3, line)
    nx, ny = px(0.004, -0.152)
    thick_line([(nx - 6, ny - 14), (nx + 4, ny + 6), (nx - 8, ny + 12)], 5, 4, p["nose"])
    mx, my = px(0.0, -0.203)
    mw = p.get("mouth_w", 30)
    d.chord((mx - mw, my - 10, mx + mw, my + 18), 20, 160, fill=p["mouth"])
    thick_line(arc_pts(mx, my - 24, 48 * mw / 30, 26, 35, 145, 24), 6, 6, p["lip_line"])
    if p.get("lines", 0):                                 # age: the smile lines
        line = tuple(int(c * 0.82) for c in p["skin"])
        for sx in (-1, 1):
            nx2, ny2 = px(sx * 0.058, -0.150)
            thick_line([(nx2, ny2), (nx2 + sx * 14, ny2 + 40), (nx2 + sx * 10, ny2 + 78)], 4, 3, line)
    blush = Image.new("RGBA", (N, N), p["blush"] + (0,))
    bd = ImageDraw.Draw(blush)
    for sx in (-1, 1):
        cx, cy = px(sx * 0.108, -0.128)
        bd.ellipse((cx - 72, cy - 24, cx + 72, cy + 24), fill=p["blush"] + (p.get("blush_a", 95),))
    img = Image.alpha_composite(img, blush.filter(ImageFilter.GaussianBlur(14)))
    return img.convert("RGB")


def lum(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def mip_check(img, out_base, p=DEALER):
    """Godot's mip chain (2x2 box averages); save mip 5 and 6; per eye, the darkest mip-5 texel vs the skin."""
    mips = [img]
    for _ in range(6):
        mips.append(mips[-1].reduce(2))
    mips[5].resize((256, 256), Image.NEAREST).save(out_base + "_mip5.png")
    mips[6].resize((256, 256), Image.NEAREST).save(out_base + "_mip6.png")
    skin = lum(p["skin"])
    res = {}
    for level in (5, 6):
        m = mips[level]
        sc = m.size[0] / N
        for sx in (-1, 1):
            cx, cy = px(sx * p["eye_x"], p["eye_z"])
            x0, x1 = int((cx - 110) * sc), int((cx + 110) * sc) + 1
            y0, y1 = int((cy - 120) * sc), int((cy + 120) * sc) + 1
            dark = min(lum(m.getpixel((x, y))) for x in range(max(0, x0), min(m.size[0], x1)) for y in range(max(0, y0), min(m.size[1], y1)))
            res["mip%d_%s" % (level, "left" if sx > 0 else "right")] = round(1 - dark / skin, 3)
    return res


def run(out, preset_name="dealer", overwrite=False, **overrides):
    """Paint the preset's face to `out` (refuses an existing file unless overwrite: N5) and check its eyes at mip 5."""
    if os.path.exists(out) and not overwrite:
        raise FileExistsError("%s exists: pass overwrite=True (or --overwrite) to repaint it" % out)
    folder = os.path.dirname(out)
    if folder:                                       # a bare file name writes to the working folder
        os.makedirs(folder, exist_ok=True)
    p = preset(preset_name, **overrides)
    img = paint(p)
    img.save(out)
    res = mip_check(img, os.path.splitext(out)[0], p)
    ok = all(v >= 0.40 for k, v in res.items() if k.startswith("mip5"))
    print("face (%s) -> %s (RGB %s); eye area darker than skin: %s; mip-5 gate (>= 40%%): %s" % (preset_name, out, img.mode, res, "OK" if ok else "OVER"))
    return ok


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit("usage: python anime_face.py <out.png> [preset] [--overwrite]   (presets: %s)" % ", ".join(sorted(PRESETS)))
    run(args[0], args[1] if len(args) > 1 else "dealer", overwrite="--overwrite" in sys.argv)
