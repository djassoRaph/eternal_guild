# anime_face.py - route AN (Story 25.30): a painted anime face texture (1024 px, RGB, no alpha), front-projected onto
# the head by anime_kit.build_head: u = 0.5 + x / 0.5 (x in metres, -0.25..0.25), v = (z - chin) / (crown - chin).
# Runs in system Python with Pillow (not inside Blender):  python anime_face.py [out.png]
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
        thick_line(lid, 9, 26, p["lash"])
        ox, oy = lid[-1]
        thick_line([(ox - sx * 6, oy - 10), (ox + sx * 22, oy - 12), (ox + sx * 40, oy - 20)], 22, 6, p["lash"])
        low = lower if sx < 0 else lower[::-1]
        thick_line(low[:18], 6, 3, (122, 82, 76))
        bx, by = px(sx * 0.098, p["brow_z"])
        brow = arc_pts(bx, by + 42, 94, 42, 200, 340, 20)
        thick_line(brow if sx > 0 else brow[::-1], 4, 10, p["brow"])
    nx, ny = px(0.004, -0.152)
    thick_line([(nx - 6, ny - 14), (nx + 4, ny + 6), (nx - 8, ny + 12)], 5, 4, p["nose"])
    mx, my = px(0.0, -0.203)
    d.chord((mx - 30, my - 10, mx + 30, my + 18), 20, 160, fill=p["mouth"])
    thick_line(arc_pts(mx, my - 24, 48, 26, 35, 145, 24), 6, 6, p["lip_line"])
    blush = Image.new("RGBA", (N, N), p["blush"] + (0,))
    bd = ImageDraw.Draw(blush)
    for sx in (-1, 1):
        cx, cy = px(sx * 0.108, -0.128)
        bd.ellipse((cx - 72, cy - 24, cx + 72, cy + 24), fill=p["blush"] + (95,))
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


def run(out):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img = paint()
    img.save(out)
    res = mip_check(img, out[:-4])
    ok = all(v >= 0.40 for k, v in res.items() if k.startswith("mip5"))
    print("face -> %s (RGB %s); eye area darker than skin: %s; mip-5 gate (>= 40%%): %s" % (out, img.mode, res, "OK" if ok else "OVER"))
    return ok


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else "F:/GAME I AM MAKING/eternal_guild_art/textures/anime/g13_quest_dealer_face.png")
