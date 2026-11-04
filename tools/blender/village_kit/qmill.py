"""Watermill and plaza fountain (exec'd after qkit, qhouse, qprops, qrough).
Watermill: a 6x6 two-storey mill house; its water wheel is a SEPARATE object "Wheel" (origin on the axle, axis = x)
so the game can turn it. The wheel sits WHEEL_X metres out from the house centre on +x (Blender) = +X (Godot).
"""
import math
import random
import bpy
from mathutils import Vector

WHEEL_X = 4.6        # wheel centre, from the house centre (+x)
WHEEL_Z = 1.6        # axle height above the house's ground
WHEEL_R = 2.2
WHEEL_W = 1.0


def mill_house(into):
    house(place, 0.0, 0.0, 6, 6, 2, seed=51, into=into, balcony=False, styles=["stone", "timber"])
    c = coll(into)
    wood = mat("", kit="MI_WoodTrim")
    # axle housing on the wall + a trough (flume) feeding the wheel from upstream (-y)
    box("P_AxleBlock", (0.8, 0.8, 0.8), (3.35, 0.0, WHEEL_Z - 0.4), wood, c)
    box("P_Flume", (0.9, 4.0, 0.35), (WHEEL_X, -3.6, WHEEL_Z + WHEEL_R + 0.15), wood, c)
    for y in (-5.2, -3.0):
        box("P_FlumePost", (0.18, 0.18, WHEEL_Z + WHEEL_R + 0.2), (WHEEL_X - 0.4, y, -0.9), wood, c)
        box("P_FlumePost", (0.18, 0.18, WHEEL_Z + WHEEL_R + 0.2), (WHEEL_X + 0.4, y, -0.9), wood, c)
    # outer wheel bearing post standing in the water
    box("P_WheelPost", (0.35, 0.35, WHEEL_Z + 0.9), (WHEEL_X + WHEEL_W / 2 + 0.35, 0.0, -0.9), wood, c)
    for i, (x, y) in enumerate([(-2.5, -3.9), (-1.6, -4.0)]):
        place("Prop_Crate", x, y, 0.0, 10 * i, into=into)


def wheel_object(name="Wheel"):
    """The wheel at the origin, axis along x; returns one joined object."""
    clear("WHEEL_TMP")
    c = coll("WHEEL_TMP")
    wood = mat("", kit="MI_WoodTrim")
    iron = mat("P_Iron", (0.09, 0.09, 0.10))
    parts = []
    for sx in (-WHEEL_W / 2, WHEEL_W / 2):
        rim = lathe("P_Rim", [(WHEEL_R - 0.22, -0.07), (WHEEL_R, -0.07), (WHEEL_R, 0.07), (WHEEL_R - 0.22, 0.07), (WHEEL_R - 0.22, -0.07)],
                    (0, 0, 0), wood, c, seg=24, cap_top=False, cap_bottom=False)
        rim.rotation_euler = (0, math.radians(90), 0)
        rim.location = (sx, 0, 0)
        parts.append(rim)
        for k in range(8):
            a = k * math.pi / 4
            sp = box("P_Spoke", (0.12, 0.12, WHEEL_R - 0.1), (sx, 0, 0), wood, c)
            sp.rotation_euler = (a, 0, 0)
            parts.append(sp)
    for k in range(16):
        a = k * 2 * math.pi / 16
        pd = box("P_Paddle", (WHEEL_W + 0.1, 0.06, 0.55), (0, 0, 0), wood, c)
        pd.rotation_euler = (a, 0, 0)
        pd.location = (0, -math.sin(a) * (WHEEL_R - 0.5), math.cos(a) * (WHEEL_R - 0.5))
        parts.append(pd)
    ax = lathe("P_Axle", [(0.0, -1.0), (0.14, -1.0), (0.14, 1.0), (0.0, 1.0)], (0, 0, 0), iron, c, seg=10)
    ax.rotation_euler = (0, math.radians(90), 0)
    parts.append(ax)
    bpy.context.view_layer.update()
    ob = join_collection("WHEEL_TMP", name)
    renormal(ob)
    return ob


def fountain(into):
    """Plaza fountain: a stone basin, a pillar with a small bowl and a water surface."""
    c = coll(into)
    rock = mat("", kit="MI_RockTrim")
    stone = mat("", kit="MI_UnevenBrick")
    water = mat("P_FountainWater", (0.18, 0.36, 0.42))
    lathe("P_FountainBase", [(2.4, 0.0), (2.45, 0.15), (2.3, 0.2)], (0, 0, 0), rock, c, seg=28, cap_top=True)
    lathe("P_FountainWall", [(2.3, 0.2), (2.3, 0.75), (2.1, 0.8), (2.0, 0.8), (2.0, 0.3)], (0, 0, 0), stone, c, seg=28, cap_top=False, cap_bottom=False)
    lathe("P_FountainWater", [(2.02, 0.6), (0.0, 0.6)], (0, 0, 0), water, c, seg=28, cap_top=False, cap_bottom=False)
    lathe("P_FountainPillar", [(0.55, 0.3), (0.45, 0.6), (0.32, 1.6), (0.45, 1.75)], (0, 0, 0), rock, c, seg=14)
    lathe("P_FountainBowl", [(0.25, 1.75), (0.95, 1.95), (1.0, 2.1), (0.85, 2.12), (0.25, 1.95)], (0, 0, 0), rock, c, seg=20, cap_top=False)
    lathe("P_FountainBowlWater", [(0.86, 2.06), (0.0, 2.06)], (0, 0, 0), water, c, seg=20, cap_top=False, cap_bottom=False)
    lathe("P_FountainTop", [(0.16, 2.0), (0.14, 2.7), (0.26, 2.85), (0.0, 3.05)], (0, 0, 0), rock, c, seg=10)
