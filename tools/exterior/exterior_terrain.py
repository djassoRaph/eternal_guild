# exterior_terrain.py - Story 25.29 shared terrain + layout definition (pure Python, no bpy).
# World metres in the GODOT frame (x east, y up, z south). Used by the Blender terrain builder,
# the ExteriorWorld layout generator and the heightfield fixture, so all three agree.
import math

H_DROP = 3.0          # plateau (tavern hill) at y 0; valley at -H_DROP (2.2 over 7 m didn't read as a hill)
SLOPE_W = 5.0
CH_HALF, BANK, BED_DEPTH = 1.6, 1.0, 0.9
WATER_Y = -H_DROP - 0.25
PLAY = (-48.0, 46.0, -26.0, 46.0)                 # playable rect x0, x1, z0, z1 (boundary walls)
EXTENT = (-86.0, 84.0, -62.0, 82.0)               # terrain mesh extent
PATH = [(-20.9, 10.0), (-12.0, 10.4), (-3.0, 9.6), (3.4, 10.0), (9.4, 10.0), (12.5, 9.0), (17.5, 8.0)]
PATH_HALF = 1.3
BRIDGE = {"x0": 3.4, "x1": 9.4, "z": 10.0, "width": 2.6}
SQUARE = (17.5, 8.0, 7.0)                         # centre x, z, radius
TAVERN_RECT = (-30.8, -19.4, 5.6, 20.4)           # A1 (Story 25.36's kit tavern) incl. eaves, porch, chimney + margin
FARM_RECTS = [(-28.5, -23.5, 23.3, 28.3), (-27.6, -23.4, 31.2, 35.3)]


def clamp01(t):
    return 0.0 if t < 0.0 else 1.0 if t > 1.0 else t


def smooth(t):
    t = clamp01(t)
    return t * t * (3.0 - 2.0 * t)


def edge_x(z):
    return -9.0 + 2.5 * math.sin(z / 11.0 + 0.7) + 1.5 * math.sin(z / 5.3 + 2.0)


def stream_x(z):
    return 5.0 + 2.0 * math.sin(z / 13.0)


def base_h(x, z):
    # A straight ramp, not a smoothstep: the creases at the crest and the foot give the ink shader
    # an outline, which is what makes the hill read in the orthographic view.
    return -H_DROP * clamp01((x - edge_x(z)) / SLOPE_W)


def stream_depth(x, z):
    d = abs(x - stream_x(z))
    if d <= CH_HALF:
        return BED_DEPTH
    if d <= CH_HALF + BANK:
        return BED_DEPTH * (1.0 - smooth((d - CH_HALF) / BANK))
    return 0.0


def h(x, z):
    return base_h(x, z) - stream_depth(x, z)


def dist_to_path(x, z, path=PATH):
    best = 1e9
    for (ax, az), (bx, bz) in zip(path, path[1:]):
        dx, dz = bx - ax, bz - az
        L2 = dx * dx + dz * dz
        t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / L2))
        px, pz = ax + t * dx, az + t * dz
        best = min(best, math.hypot(x - px, z - pz))
    return best


def in_rect(x, z, r, margin=0.0):
    return r[0] - margin <= x <= r[1] + margin and r[2] - margin <= z <= r[3] + margin


# ---------------------------------------------------------------- village (KayKit x3, front = +z)
KK = "res://assets/environment/hexagons/"
def face_square(x, z):
    """Yaw (radians) that turns a KayKit building's +z front toward the village square."""
    return math.atan2(SQUARE[0] - x, SQUARE[1] - z)

VILLAGE = [
    # name, path, x, z, yaw (None = face the square), scale
    ("Market", KK + "blue/building_market_blue.gltf", 17.5, -3.8, None, 3.0),
    ("Blacksmith", KK + "blue/building_blacksmith_blue.gltf", 10.2, 0.2, None, 3.0),
    ("HomeA", KK + "blue/building_home_A_blue.gltf", 26.8, 1.2, None, 3.0),
    ("HomeB", KK + "blue/building_home_B_blue.gltf", 28.2, 13.8, None, 3.0),
    ("Residence", KK + "blue/building_home_A_blue.gltf", 12.6, 20.4, None, 3.0),
    ("Well", KK + "blue/building_well_blue.gltf", 17.5, 8.0, 0.0, 3.0),
    ("Windmill", KK + "blue/building_windmill_blue.gltf", 35.5, -12.0, math.radians(200), 3.0),
    ("Watermill", KK + "blue/building_watermill_blue.gltf", 9.0, -14.0, math.radians(-90), 3.0),
]
# street life (E12) and the tavern yard (A3 subset): name, path, x, z, yaw_deg, scale
PROPS = [
    ("StallTent1", KK + "props/tent.gltf", 12.0, 13.2, 30, 3.0),
    ("StallTent2", KK + "props/tent.gltf", 23.4, 13.6, -40, 3.0),
    ("MarketCrates", KK + "props/crate_A_big.gltf", 13.9, -1.6, 15, 3.0),
    ("MarketCrateSmall", KK + "props/crate_B_small.gltf", 14.9, -0.4, 40, 3.0),
    ("MarketBarrel", KK + "props/barrel.gltf", 21.3, -1.2, 0, 3.0),
    ("MarketSacks", KK + "props/sack.gltf", 20.4, -0.2, 70, 3.0),
    ("MarketPallet", KK + "props/pallet.gltf", 22.4, 0.4, 10, 3.0),
    ("WellBucket", KK + "props/bucket_water.gltf", 19.6, 9.6, 0, 3.0),
    ("SmithLumber", KK + "props/resource_lumber.gltf", 7.9, -3.6, 80, 3.0),
    ("SmithStone", KK + "props/resource_stone.gltf", 11.8, -3.4, 20, 3.0),
    ("SmithRack", KK + "props/weaponrack.gltf", 13.2, 3.6, 45, 3.0),
    ("TrainingTarget", KK + "props/target.gltf", 9.6, 4.8, 110, 3.0),
    ("HomeLadder", KK + "props/ladder.gltf", 29.6, 3.4, -30, 3.0),
    ("MillSacks", KK + "props/sack.gltf", 32.2, -8.6, 0, 3.0),
    ("MillWheelbarrow", KK + "props/wheelbarrow.gltf", 33.6, -7.4, 60, 3.0),
    ("MillCrateLong", KK + "props/crate_long_A.gltf", 38.4, -9.0, 90, 3.0),
    ("StreetBarrel", KK + "props/barrel.gltf", 24.6, 18.4, 0, 3.0),
    ("StreetCrateOpen", KK + "props/crate_open.gltf", 10.4, 16.2, 25, 3.0),
    ("YardWheelbarrow", KK + "props/wheelbarrow.gltf", -21.9, 26.8, -20, 3.0),
    ("YardSacks", KK + "props/sack.gltf", -22.4, 29.8, 0, 3.0),
    ("YardBucket", KK + "props/bucket_empty.gltf", -29.4, 30.2, 0, 3.0),
    ("YardFirewood", KK + "props/resource_lumber.gltf", -32.6, 14.4, 0, 3.0),
]
