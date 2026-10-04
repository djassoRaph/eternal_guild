# real_layout.py - route RL's shared numbers (pure Python: imported in Blender by real_body and in system Python by
# real_paint): a concept SHEET's measurement frame (which pixels a 3D point projects to, per view) and the body
# atlas's regions.
#
# A sheet (make_sheet) is one picked concept turnaround: its PNG, the character's height, and per view the centre
# pixel column and the crown and sole rows (each view's own scale, m/px), plus the head crop boxes that
# real_paint.head_texture cuts out of it (one quadrant of the head texture per view) and the head texture's skin
# quadrant. real_body.projection_uvs projects a head's faces onto it; real_paint.head_texture(out, sheet) paints the
# matching texture. A new character's sheet is measured off its own pick and saved as JSON (save_sheet / load_sheet:
# `python real_paint.py head <out.png> --sheet <sheet.json>`).
# BARTENDER is the spike's sheet (eternal_guild_art/realistic_test/ref_bartender_concept.png, 1344 x 768, Raphael's
# chosen turnaround), measured by silhouette rows; the module-level CONCEPT ... HEAD_SKIN_UV are its values.
import json


def make_sheet(concept, height, views, head_crops, head_win=130.0, head_skin_uv=(0.75, 0.25)):
    """views: {"front"|"side"|"back": (centre px x (front/back: the head's midline; side: the ankle line), crown row,
    sole row)}; head_crops: {view: (window left px, window top px, quadrant u0, quadrant v0)} with square windows of
    head_win px (quadrants of the head texture; the fourth is skin at head_skin_uv)."""
    assert set(views) == {"front", "side", "back"} and set(head_crops) <= set(views)
    return {"concept": concept, "height": float(height), "views": {k: tuple(v) for k, v in views.items()},
            "head_crops": {k: tuple(v) for k, v in head_crops.items()}, "head_win": float(head_win),
            "head_skin_uv": tuple(head_skin_uv)}


def save_sheet(sheet, path):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(sheet, f, indent=1)


def load_sheet(path):
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    return make_sheet(d["concept"], d["height"], d["views"], d["head_crops"], d.get("head_win", 130.0),
                      d.get("head_skin_uv", (0.75, 0.25)))


BARTENDER = make_sheet(
    "F:/GAME I AM MAKING/eternal_guild_art/realistic_test/ref_bartender_concept.png", 1.86,
    {"front": (262.3, 32.0, 746.0), "side": (713.0, 36.0, 743.0), "back": (1092.3, 34.0, 735.0)},
    {"front": (262.3 - 65.0, 27.0, 0.0, 0.5), "side": (618.0, 31.0, 0.5, 0.5), "back": (1092.3 - 65.0, 29.0, 0.0, 0.0)})

CONCEPT = BARTENDER["concept"]
HEIGHT = BARTENDER["height"]
VIEWS = BARTENDER["views"]
HEAD_WIN = BARTENDER["head_win"]
HEAD_CROPS = BARTENDER["head_crops"]
HEAD_SKIN_UV = BARTENDER["head_skin_uv"]


def scale(view, sheet=None):
    sheet = sheet or BARTENDER
    cx, top, sole = sheet["views"][view]
    return sheet["height"] / (sole - top)


def to_px(view, x, y, z, sheet=None):
    """A Blender rest point (front -Y, his left +X, up Z) to a concept pixel (px, py) in `view`."""
    sheet = sheet or BARTENDER
    cx, top, sole = sheet["views"][view]
    s = scale(view, sheet)
    py = top + (sheet["height"] - z) / s
    if view == "front":
        return cx + x / s, py
    if view == "side":                     # his left side: his front is image-left
        return cx + y / s, py
    return cx - x / s, py                  # back: his left is image-left


def head_uv(view, x, y, z, sheet=None):
    """The head texture's UV of a rest point seen in `view` (its quadrant: the view's crop window)."""
    sheet = sheet or BARTENDER
    px, py = to_px(view, x, y, z, sheet)
    wx, wy, u0, v0 = sheet["head_crops"][view]
    win = sheet["head_win"]
    return u0 + 0.5 * (px - wx) / win, v0 + 0.5 * (1.0 - (py - wy) / win)


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
