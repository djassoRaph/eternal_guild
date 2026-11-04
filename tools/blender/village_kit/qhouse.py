"""Parametric house from the Quaternius Medieval Village kit (exec'd in Blender after qkit.py).

Rules learned 2026-11-04:
- 2 m grid, 3 m storeys. Floor tiles are 2x2 centred on their origin.
- Wall pieces: 2 m wide centred on origin, wall plane at local y=0, exterior faces local -y (Blender).
  rot 0 = south side (exterior -y), 180 = north, 90 = east (exterior +x), -90 = west.
- Window / shutter / glass pieces share the wall's transform. Door_1_* leaf: wall transform, x - 0.53.
- Roof_RoundTiles_WxD: W across the gables (x), D along the ridge (y); sits at the top of the last storey.
  Gable fill Roof_Front_Brick{W} at y = +-D/2 (rot 0 south, 180 north).
- Corner_Exterior_Wood posts at the footprint corners, every storey.
"""
import random

ROOFS = {(4, 4), (4, 6), (4, 8), (6, 4), (6, 6), (6, 8), (6, 10), (6, 12), (6, 14), (8, 8), (8, 10), (8, 12), (8, 14)}
STYLE = {
    "stone": {"plain": "Wall_UnevenBrick_Straight", "window": ["Wall_UnevenBrick_Window_Wide_Round", "Wall_UnevenBrick_Window_Thin_Round", "Wall_UnevenBrick_Window_Wide_Flat"],
              "door": "Wall_UnevenBrick_Door_Round"},
    "plaster": {"plain": "Wall_Plaster_Straight_Base", "window": ["Wall_Plaster_Window_Wide_Round", "Wall_Plaster_Window_Thin_Round", "Wall_Plaster_Window_Wide_Flat"],
                "door": "Wall_Plaster_Door_Round"},
    "timber": {"plain": "Wall_Plaster_WoodGrid", "window": ["Wall_Plaster_Window_Wide_Flat", "Wall_Plaster_Window_Wide_Round", "Wall_Plaster_Window_Thin_Round"],   # not Wide_Flat2: no kit window fills its opening
               "door": "Wall_Plaster_Door_Flat"},
}
FILL = {  # window wall -> the pieces that fill its hole
    "Window_Wide_Round": ["Window_Wide_Round1", "WindowShutters_Wide_Round_Open"],
    "Window_Thin_Round": ["Window_Thin_Round1", "WindowShutters_Thin_Round_Closed"],
    "Window_Wide_Flat2": ["Window_Wide_Flat1"],
    "Window_Wide_Flat": ["Window_Wide_Flat1"],
}


def load_piece(name):
    # qkit's load() is exec'd into the same namespace as this file
    return load(name)


def house(place, ox, oy, w=4, d=4, floors=2, seed=1, into="BUILD", balcony=True, styles=None, chimney=True):
    """w, d in metres (even, w in 4/6/8). Door on the south (-y) side. Returns the pieces placed."""
    rng = random.Random(seed)
    assert (w, d) in ROOFS, (w, d)
    hx, hy = w / 2.0, d / 2.0
    n = 0

    def P(name, x, y, z=0.0, r=0.0):
        nonlocal n
        place(name, ox + x, oy + y, z, r, into=into)
        n += 1

    def wall(name, x, y, z, r):
        P(name, x, y, z, r)
        for key, fills in FILL.items():
            if key in name:
                for f in fills:
                    if "Shutters" in f and rng.random() < 0.4:
                        continue
                    P(f, x, y, z, r)
                break
        if "Door_Round" in name or "Door_Flat" in name:
            P("Door_1_Round" if "Round" in name else "Door_1_Flat", x - 0.53, y, z, r)

    door_x = rng.choice([x for x in range(int(-hx) + 1, int(hx), 2)])
    for f in range(floors):
        z = 3.0 * f
        st = STYLE["stone" if (f == 0 and rng.random() < 0.7) else ("timber" if f > 0 and rng.random() < 0.5 else "plaster")]
        if styles:
            st = STYLE[styles[min(f, len(styles) - 1)]]
        sides = []
        for x in range(int(-hx) + 1, int(hx), 2):
            sides.append(("S", x, -hy, 0))
            sides.append(("N", x, hy, 180))
        for y in range(int(-hy) + 1, int(hy), 2):
            sides.append(("E", hx, y, 90))
            sides.append(("W", -hx, y, -90))
        for side, a, b, r in sides:
            if f == 0 and side == "S" and a == door_x:
                name = st["door"]
            else:
                name = rng.choice(st["window"]) if rng.random() < 0.55 else st["plain"]
            if side in ("S", "N"):
                wall(name, a, b, z, r)
            else:
                wall(name, a, b, z, r)
        for cx in (-hx, hx):
            for cy in (-hy, hy):
                P("Corner_Exterior_Wood", cx, cy, z)
        for x in range(int(-hx) + 1, int(hx), 2):
            for y in range(int(-hy) + 1, int(hy), 2):
                P("Floor_WoodDark", x, y, z)
    top = 3.0 * floors
    P("Roof_RoundTiles_%dx%d" % (w, d), 0, 0, top)
    P("Roof_Front_Brick%d" % w, 0, -hy, top, 0)
    P("Roof_Front_Brick%d" % w, 0, hy, top, 180)
    # chimney: ONE piece standing on the back half of a roof slope near the ridge (the kit's way),
    # its base sunk below the roof surface on the downhill side so no gap shows.
    roof = load_piece("Roof_RoundTiles_%dx%d" % (w, d))
    xs = [v[0] for v in roof.bound_box]
    zs = [v[2] for v in roof.bound_box]
    xmax, zmin, zmax = max(xs), min(zs), max(zs)
    slope = (zmax - zmin) / xmax

    def roof_z(ax):
        return top + zmax - slope * ax

    side = rng.choice([-1, 1])
    cx = side * min(1.3, xmax * 0.35)
    cy = hy - 1.0 if hy > 2 else 0.6
    base = roof_z(abs(cx) + 0.5) - 0.3
    if chimney:
        P("Prop_Chimney", cx, cy, base, rng.choice([0, 90, 180, 270]))
    if balcony and floors > 1 and rng.random() < 0.6:
        P("Balcony_Simple_Straight", door_x, -hy, 3.0, 0)
    return n
