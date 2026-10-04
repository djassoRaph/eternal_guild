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


def make_sheet(concept, height, views, head_crops, head_win=130.0, head_skin_uv=(0.75, 0.25), side_flip=False):
    """views: {"front"|"side"|"back": (centre px x (front/back: the head's midline; side: the ankle line), crown row,
    sole row)}; head_crops: {view: (window left px, window top px, quadrant u0, quadrant v0)} with square windows of
    head_win px (quadrants of the head texture; the fourth is skin at head_skin_uv). side_flip: the side view shows
    his RIGHT side (his front image-right; 25.31 S1, the player's sheet), not his left."""
    assert set(views) == {"front", "side", "back"} and set(head_crops) <= set(views)
    out = {"concept": concept, "height": float(height), "views": {k: tuple(v) for k, v in views.items()},
           "head_crops": {k: tuple(v) for k, v in head_crops.items()}, "head_win": float(head_win),
           "head_skin_uv": tuple(head_skin_uv)}
    if side_flip:
        out["side_flip"] = True
    return out


def save_sheet(sheet, path):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(sheet, f, indent=1)


def load_sheet(path):
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    return make_sheet(d["concept"], d["height"], d["views"], d["head_crops"], d.get("head_win", 130.0),
                      d.get("head_skin_uv", (0.75, 0.25)), d.get("side_flip", False))


BARTENDER = make_sheet(
    "F:/GAME I AM MAKING/eternal_guild_art/realistic_test/ref_bartender_concept.png", 1.86,
    {"front": (262.3, 32.0, 746.0), "side": (713.0, 36.0, 743.0), "back": (1092.3, 34.0, 735.0)},
    {"front": (262.3 - 65.0, 27.0, 0.0, 0.5), "side": (618.0, 31.0, 0.5, 0.5), "back": (1092.3 - 65.0, 29.0, 0.0, 0.0)})

# The player's pick (25.31 S1, catalogue G1): eternal_guild_art/picked/C_G1_player.png (1344 x 768). Crown (the hair's
# top) and sole rows read off the figure masks; the front and back centres are the face's / the head's midline; the side
# view shows his RIGHT side, its centre placed so his nose tip (px 714, row 103) and the back of his hair (px ~619) land on
# the head mesh (real_player: the Bartender's head narrowed and lowered under the hair). The side view draws his eyes 5 px
# higher than the front view does: its crown row (22.3, not the hair's 31) registers its eye line on the front's (z 1.710),
# or the two projections meet in a step across the cheek.
PLAYER = make_sheet(
    "F:/GAME I AM MAKING/eternal_guild_art/picked/C_G1_player.png", 1.86,
    {"front": (258.0, 27.0, 745.0), "side": (633.0, 22.3, 746.0), "back": (1062.0, 30.0, 744.0)},
    {"front": (258.0 - 65.0, 22.0, 0.0, 0.5), "side": (600.0, 26.0, 0.5, 0.5), "back": (1062.0 - 65.0, 25.0, 0.0, 0.0)},
    side_flip=True)
PLAYER["crown_rows"] = {"front": 27.0, "side": 31.0, "back": 30.0}   # the drawn hair's top per view: the crown samples
                                                                     # 3 px under it (above is the bleed, streaked)
PLAYER["top_from_back"] = {"nz": 0.55, "z_min": 1.80, "y": (-0.20, 0.06), "rows": (38.0, 78.0)}   # the crown (above the
                                                                     # hairline, never the face or the ears): the back view's hair laid flat

# The Quest Dealer's pick (25.31 S1, AC 6b, catalogue G13): eternal_guild_art/picked/C_G13_quest_dealer.png, REAL-2
# (1.70 m: the hair's top to the soles). Her long hair falls to mid-back, so the crop windows are 290 px (rows 22-312)
# instead of 130: the projection reaches the hair's tips. The side view shows her RIGHT side; its centre puts her nose
# tip (px 698) and the back of her hair (px ~605) on REAL-2's head.
DEALER = make_sheet(
    "F:/GAME I AM MAKING/eternal_guild_art/picked/C_G13_quest_dealer.png", 1.70,
    {"front": (249.0, 30.0, 745.0), "side": (620.0, 31.0, 745.0), "back": (1065.0, 30.0, 743.0)},
    {"front": (249.0 - 145.0, 22.0, 0.0, 0.5), "side": (470.0, 22.0, 0.5, 0.5), "back": (1065.0 - 145.0, 22.0, 0.0, 0.0)},
    head_win=290.0, side_flip=True)
DEALER["crown_rows"] = {"front": 30.0, "side": 31.0, "back": 30.0}
DEALER["top_from_back"] = {"nz": 0.55, "z_min": 1.66, "y": (-0.17, 0.05), "rows": (40.0, 85.0)}
DEALER["face_y"] = 0.06            # the front view keeps more of her cheeks (the side view's shading muddied them)



def sheet_by_eyes(concept, height, eye_z, nose_y, views, win=130.0, side_flip=True):
    """(25.31 S2, the townsfolk) A sheet registered on the EYE LINE, for picks whose crown is under a hat: views
    {"front": (face midline px, eye row, sole row), "side": (nose tip px, eye row, sole row), "back": (head midline px,
    eye row or None (the front's eyes-to-sole), sole row)}. Each view's scale is eye_z / (sole - eye) and its virtual
    crown row sole - height / scale; the side view's centre column puts the nose tip at nose_y (the head mesh's, rest
    y). Head crop windows (win px square) frame the head from about 0.48 win above the eyes."""
    out_v, crops = {}, {}
    f_eye, f_sole = views["front"][1], views["front"][2]
    for view in ("front", "side", "back"):
        px, eye, sole = views[view]
        if eye is None:
            eye = sole - (f_sole - f_eye)
        s = eye_z / (sole - eye)
        crown = sole - height / s
        if view == "side":
            cx = px + nose_y / s if side_flip else px - nose_y / s
            left = px - 0.88 * win if side_flip else px - 0.12 * win
        else:
            cx = px
            left = px - 0.5 * win
        out_v[view] = (round(cx, 1), round(crown, 1), float(sole))
        crops[view] = (round(left, 1), round(eye - 0.48 * win, 1)) + {"front": (0.0, 0.5), "side": (0.5, 0.5), "back": (0.0, 0.0)}[view]
    sh = make_sheet(concept, height, out_v, crops, head_win=win, side_flip=side_flip)
    sh["eye_rows"] = {v: views[v][1] for v in views}
    return sh


# The townsfolk's picks (25.31 S2, AC 11; eternal_guild_art/picked/C_G19_<id>.png, 1344 x 768), registered on the eye
# line (their crowns are under hats): the men on REAL-1 with the player's head (eyes z 1.710, nose tip y -0.213), the
# old woman on REAL-2 (eyes z 1.5855, nose tip y -0.190). Rows read off 3x crops with a pixel ruler (2026-10-04). The
# farmer's side view faces image-left (his left side); the others show the right side.
_PICK = "F:/GAME I AM MAKING/eternal_guild_art/picked/C_G19_%s.png"
FARMER = sheet_by_eyes(_PICK % "farmer", 1.86, 1.710, -0.213,
                       {"front": (195.0, 81.7, 752.0), "side": (613.0, 82.0, 757.0), "back": (1130.0, None, 752.0)},
                       win=140.0, side_flip=False)
LOCAL = sheet_by_eyes(_PICK % "local", 1.86, 1.710, -0.213,
                      {"front": (246.7, 81.7, 748.0), "side": (710.0, 80.0, 753.0), "back": (1086.7, None, 748.0)})
TRAVELLER = sheet_by_eyes(_PICK % "traveller", 1.86, 1.710, -0.213,
                          {"front": (256.7, 81.7, 746.0), "side": (715.7, 81.7, 745.0), "back": (1083.0, None, 744.0)})
TRAVELLER["crown_rows"] = {"front": 35.0, "side": 36.0, "back": 35.0}
TRAVELLER["top_from_back"] = {"nz": 0.55, "z_min": 1.78, "y": (-0.20, 0.06), "rows": (40.0, 80.0)}
GUARD = sheet_by_eyes(_PICK % "guard", 1.86, 1.710, -0.213,
                      {"front": (245.0, 96.7, 739.0), "side": (718.3, 95.0, 748.0), "back": (1090.0, None, 739.0)})
MERCHANT = sheet_by_eyes(_PICK % "merchant", 1.86, 1.710, -0.213,
                         {"front": (241.7, 83.3, 748.0), "side": (726.7, 81.7, 750.0), "back": (1100.0, None, 744.0)})
OLD_WOMAN = sheet_by_eyes(_PICK % "old_woman", 1.70, 1.5855, -0.190,
                          {"front": (250.0, 81.7, 745.0), "side": (741.7, 80.0, 746.0), "back": (1088.0, None, 745.0)},
                          win=150.0)
OLD_WOMAN["face_y"] = 0.06
OLD_WOMAN["crown_rows"] = {"front": 23.0, "side": 27.0, "back": 26.0}
OLD_WOMAN["top_from_back"] = {"nz": 0.55, "z_min": 1.62, "y": (-0.15, 0.06), "rows": (32.0, 70.0)}   # her scarf's crown
TOWNSFOLK_SHEETS = {"farmer": FARMER, "local": LOCAL, "traveller": TRAVELLER, "guard": GUARD, "merchant": MERCHANT,
                    "old_woman": OLD_WOMAN}

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
    if view == "side":                     # his left side: his front is image-left (side_flip: his right, front image-right)
        return (cx - y / s if sheet.get("side_flip") else cx + y / s), py
    return cx - x / s, py                  # back: his left is image-left


def head_uv(view, x, y, z, sheet=None):
    """The head texture's UV of a rest point seen in `view` (its quadrant: the view's crop window)."""
    sheet = sheet or BARTENDER
    px, py = to_px(view, x, y, z, sheet)
    wx, wy, u0, v0 = sheet["head_crops"][view]
    win = sheet["head_win"]
    if "crown_rows" in sheet:                  # (25.31 S1, the player) never sample above the drawn crown (the bleed)
        py = max(py, sheet["crown_rows"][view] + 3.0)
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
