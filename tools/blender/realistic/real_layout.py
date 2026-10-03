# real_layout.py - the realistic spike's shared numbers (pure Python: imported in Blender by real_body and in system
# Python by real_paint). The concept sheet's measurement frame and the body atlas's regions.
#
# The concept (eternal_guild_art/realistic_test/ref_bartender_concept.png, 1344 x 768, Raphael's chosen turnaround)
# measured by silhouette rows: each view's crown and sole rows give its own scale (m/px), so a 3D point projects to a
# pixel of any of the three views (front, his left side, back). The head, beard, ears and neck are textured by that
# projection (real_paint.head_texture); the body is built from the same rows.
CONCEPT = "F:/GAME I AM MAKING/eternal_guild_art/realistic_test/ref_bartender_concept.png"
HEIGHT = 1.86
VIEWS = {
    # name: (centre px x (front/back: the head's midline; side: the ankle line), crown row, sole row)
    "front": (262.3, 32.0, 746.0),
    "side": (713.0, 36.0, 743.0),
    "back": (1092.3, 34.0, 735.0),
}


def scale(view):
    cx, top, sole = VIEWS[view]
    return HEIGHT / (sole - top)


def to_px(view, x, y, z):
    """A Blender rest point (front -Y, his left +X, up Z) to a concept pixel (px, py) in `view`."""
    cx, top, sole = VIEWS[view]
    s = scale(view)
    py = top + (HEIGHT - z) / s
    if view == "front":
        return cx + x / s, py
    if view == "side":                     # his left side: his front is image-left
        return cx + y / s, py
    return cx - x / s, py                  # back: his left is image-left


# The head texture: three square crops of the concept (px windows), one quadrant each; quadrant 4 is a skin fill.
HEAD_WIN = 130.0
HEAD_CROPS = {   # view: (window left px, window top px, quadrant u0, quadrant v0)
    "front": (262.3 - 65.0, 27.0, 0.0, 0.5),
    "side": (618.0, 31.0, 0.5, 0.5),
    "back": (1092.3 - 65.0, 29.0, 0.0, 0.0),
}
HEAD_SKIN_UV = (0.75, 0.25)


def head_uv(view, x, y, z):
    px, py = to_px(view, x, y, z)
    wx, wy, u0, v0 = HEAD_CROPS[view]
    return u0 + 0.5 * (px - wx) / HEAD_WIN, v0 + 0.5 * (1.0 - (py - wy) / HEAD_WIN)


# The body atlas (1024 px): regions in UV space (u0, v0, u1, v1), v up. A wrapping axis (a closed ring) spans
# 1 + PAD of the region, and the painter makes that region periodic with a period of 1 / (1 + PAD) of its size.
BODY_PX = 1024
PAD = 0.125
REG = {
    "shirt": (0.000, 0.500, 0.500, 1.000),
    "apron": (0.500, 0.625, 1.000, 1.000),
    "bib": (0.500, 0.500, 0.750, 0.625),
    "straps": (0.750, 0.500, 1.000, 0.625),
    "sleeve": (0.000, 0.250, 0.250, 0.500),
    "forearm": (0.250, 0.250, 0.375, 0.500),
    "hand": (0.375, 0.250, 0.500, 0.500),
    "trousers": (0.500, 0.250, 0.750, 0.500),
    "boots": (0.750, 0.250, 1.000, 0.500),
    "belt": (0.000, 0.1875, 0.250, 0.250),
    "cloth": (0.000, 0.000, 0.250, 0.1875),
    "misc": (0.250, 0.000, 0.500, 0.250),
    "seat": (0.500, 0.000, 0.750, 0.250),
    "roll": (0.750, 0.000, 1.000, 0.250),
}
# flat cells inside "misc" (4 x 4 grid of 16 px cells... centres in UV)
MISC_CELLS = ["buckle", "laces", "sole", "stitch", "strap_dark", "knot", "metal_dark", "skin"]

# The palette: the concept's lit tones (sampled medians, nudged up ~10 % for the tavern's dim key light).
PALETTE = {
    "shirt": (102, 56, 52), "shirt_dark": (64, 34, 34),
    "apron": (86, 69, 56), "apron_dark": (52, 41, 33), "apron_edge": (40, 31, 26),
    "trousers": (56, 47, 41), "boots": (78, 62, 48), "boots_dark": (44, 34, 27), "sole": (30, 24, 20),
    "skin": (196, 160, 132), "skin_dark": (150, 112, 92), "hair": (70, 52, 42),
    "belt": (46, 35, 29), "buckle": (128, 120, 104), "cloth": (182, 172, 152), "cloth_dark": (128, 118, 102),
    "laces": (30, 22, 18), "ink": (34, 24, 22),
}


def misc_uv(name):
    i = MISC_CELLS.index(name)
    u0, v0, u1, v1 = REG["misc"]
    return u0 + (u1 - u0) * ((i % 4) + 0.5) / 4.0, v0 + (v1 - v0) * ((i // 4) + 0.5) / 4.0
