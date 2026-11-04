"""Story 25.35: the town rebuild. Rewrites ExteriorWorld.tscn's village and forest, writes the street ribbons glTF.

Godot frame (x east, y up, z south). Reads tools/exterior/exterior_terrain.py (Story 25.29's terrain: the same h(x, z)
as a6_exterior_terrain.gltf and the test fixture) and the kit assets' glTF bounds.
- drops the KayKit buildings (Market, Blacksmith, HomeA/B, Residence, Well, Windmill, Watermill), the street props a new
  street or building would stand on, and the whole KayKit forest;
- places the kit town: the fountain on the square, the watermill on the stream (its wheel in the water), the smithy on
  the east street, the pottery on the south street, then houses along every street, facing it (seeded; each lot is
  checked against the stream, the plaza, the streets, the tavern road, the bridge, the tavern, the farm plots, the
  cemetery clearing, the villagers' posts and paths, the cat's stroll, the kept props and the other buildings);
  every building is in group village_kit with a box collider (Body), its roof colour (roof_tint) and its door glow;
- re-routes the farmer along the east street; writes the streets as one ribbon mesh "terrain_paths" (the look gives it
  cobble) under Terrain/Streets; regrows the forest with the nature kit (each piece in group nature_kit with a body).
Usage: python -I tools/exterior/gen_town.py [--dry]      (run from anywhere; re-runnable: it starts from git HEAD's
scene when --from-head is given, else from the scene on disk if it has no Village/Fountain yet)
"""
import hashlib
import importlib.util
import json
import math
import os
import random
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..")).replace("\\", "/") + "/"
SCENE = ROOT + "scenes/world/ExteriorWorld.tscn"
spec = importlib.util.spec_from_file_location("et", os.path.join(HERE, "exterior_terrain.py"))
et = importlib.util.module_from_spec(spec)
spec.loader.exec_module(et)
DRY = "--dry" in sys.argv
VK = "res://assets/environment/village_kit/"
NK = "res://assets/environment/nature_kit/"
STREETS_RES = "res://assets/environment/custom/a6_town_streets.gltf"
WATER_WHEEL = "res://scripts/world/water_wheel.gd"
rng = random.Random(2535)

# ---------------------------------------------------------------- the plan (Godot frame)
PLAZA = et.SQUARE                                  # (17.5, 8.0, 7.0)
STREET_HALF = 1.4
STREETS = {   # a grid like the reference town maps: blocks deep enough for two rows of houses back to back
    "east": [(24.3, 8.2), (31.0, 8.3), (43.6, 8.1)],
    "north": [(17.5, 1.0), (17.5, -13.8), (17.6, -24.5)],
    "south": [(18.0, 15.0), (18.0, 28.0), (18.1, 44.5)],
    "north_lane": [(17.5, -13.8), (31.0, -13.6), (43.6, -14.0)],
    "south_lane": [(18.0, 28.0), (31.0, 28.2), (43.6, 27.9)],
}
CAT = [(24.2, 16.0), (25.5, 17.3), (26.0, 16.2)]
CEMETERY = (-30.0, -18.0, 8.0)
FARMER_PATH = [(25.6, 8.5), (33.0, 8.9), (43.0, 8.3)]
# kit buildings: name -> (file, wall boxes in LOCAL Godot coords [(cx, cy, cz, sx, sy, sz)], glow local point)
HOUSES = {  # name: (w, d, floors) from the Blender bake (village_kit/*.gltf), front = +Z local
    "H01": (4, 4, 2), "H02": (4, 6, 2), "H03": (6, 6, 1), "H04": (6, 8, 2), "H05": (8, 10, 3), "H06": (4, 6, 1),
    "H07": (6, 6, 2), "H08": (4, 8, 2), "H09": (8, 8, 2), "H10": (6, 10, 2), "H11": (4, 4, 1), "H12": (6, 8, 3),
}
SPECIAL = {
    # Blender (x, y) -> Godot (x, -y); boxes: (cx, cy, cz, sx, sy, sz)
    "S_smithy": [(-2.0, 1.5, 0.0, 6.2, 3.0, 6.2), (3.1, 0.5, -0.15, 2.0, 1.0, 1.4)],
    "S_pottery": [(-2.0, 1.5, 0.0, 4.2, 3.0, 6.2), (3.4, 2.35, -1.4, 3.5, 4.7, 3.5), (0.75, 0.85, 0.0, 0.5, 1.7, 2.3)],
    "S_watermill": [(0.0, 3.0, 0.0, 6.2, 6.0, 6.2)],
    "S_fountain": [(0.0, 0.5, 0.0, 3.5, 1.0, 3.5)],
}
ROOFS = [(0.62, 0.40, 0.46), (0.40, 0.50, 0.72), (0.70, 0.32, 0.28), (0.80, 0.62, 0.30), (0.42, 0.56, 0.40),
         (0.52, 0.42, 0.66), (0.36, 0.58, 0.58), (0.44, 0.44, 0.48)]
DROP_BUILDINGS = ["Market", "Blacksmith", "HomeA", "HomeB", "Residence", "Well", "Windmill", "Watermill"]
DROP_PROPS = ["MillSacks", "MillWheelbarrow", "MillCrateLong", "HomeLadder", "SmithLumber", "SmithStone", "SmithRack",
              "TrainingTarget"]   # the old smithy's and the windmill's props; the rest are dropped only if in the way


# ---------------------------------------------------------------- geometry
def glb_bounds(res):
    g = json.load(open(ROOT + res[len("res://"):], encoding="utf-8"))
    lo, hi = [1e9] * 3, [-1e9] * 3

    def qm(q):
        x, y, z, w = q
        return [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]

    def walk(i, chain):
        nd = g["nodes"][i]
        chain = chain + [(qm(nd.get("rotation", [0, 0, 0, 1])), nd.get("translation", [0, 0, 0]), nd.get("scale", [1, 1, 1]))]
        if "mesh" in nd:
            for pr in g["meshes"][nd["mesh"]]["primitives"]:
                a = g["accessors"][pr["attributes"]["POSITION"]]
                for cx in (a["min"][0], a["max"][0]):
                    for cy in (a["min"][1], a["max"][1]):
                        for cz in (a["min"][2], a["max"][2]):
                            p = [cx, cy, cz]
                            for m, t, s in reversed(chain):
                                p = [sum(m[r][c] * p[c] * s[c] for c in range(3)) + t[r] for r in range(3)]
                            for k in range(3):
                                lo[k] = min(lo[k], p[k]); hi[k] = max(hi[k], p[k])
        for c in nd.get("children", []):
            walk(c, chain)
    for r in g["scenes"][g.get("scene", 0)]["nodes"]:
        walk(r, [])
    return lo, hi


class Rect:
    """An oriented rectangle on the ground: local x0..x1, z0..z1 about (x, z), turned by yaw (Godot: local->world
    wx = c*lx + s*lz, wz = -s*lx + c*lz)."""
    def __init__(self, x, z, yaw, x0, x1, z0, z1):
        self.x, self.z, self.yaw = x, z, yaw
        self.x0, self.x1, self.z0, self.z1 = x0, x1, z0, z1

    def to_world(self, lx, lz):
        c, s = math.cos(self.yaw), math.sin(self.yaw)
        return self.x + c * lx + s * lz, self.z - s * lx + c * lz

    def corners(self):
        return [self.to_world(a, b) for a, b in ((self.x0, self.z0), (self.x1, self.z0), (self.x1, self.z1), (self.x0, self.z1))]

    def contains(self, px, pz, m=0.0):
        c, s = math.cos(self.yaw), math.sin(self.yaw)
        dx, dz = px - self.x, pz - self.z
        lx, lz = c * dx - s * dz, s * dx + c * dz
        return self.x0 - m <= lx <= self.x1 + m and self.z0 - m <= lz <= self.z1 + m

    def edge_points(self, step=0.5):
        pts = []
        for (ax, az), (bx, bz) in zip(self.corners(), self.corners()[1:] + self.corners()[:1]):
            n = max(1, int(math.hypot(bx - ax, bz - az) / step))
            pts += [(ax + (bx - ax) * t / n, az + (bz - az) * t / n) for t in range(n)]
        return pts + [(self.x, self.z)]


def overlap(a, b, gap):
    axes = []
    for r in (a, b):
        c, s = math.cos(r.yaw), math.sin(r.yaw)
        axes += [(c, -s), (s, c)]
    for ax, az in axes:
        pa = [x * ax + z * az for x, z in a.corners()]
        pb = [x * ax + z * az for x, z in b.corners()]
        if max(pa) + gap < min(pb) or max(pb) + gap < min(pa):
            return False
    return True


def dist_poly(x, z, poly):
    return et.dist_to_path(x, z, poly)


# ---------------------------------------------------------------- scene blocks
src = open(SCENE, encoding="utf-8", newline="").read()
assert "\r\n" not in src, "CRLF scene"
assert 'name="Fountain" parent="Village"' not in src, "already generated: check out the scene from git first"
parts = [x for x in re.split(r"(?m)^(?=\[)", src) if x]
assert parts[0].startswith("[gd_scene")
head, blocks = parts[0], parts[1:]


def block_key(b):
    m = re.match(r'\[node name="([^"]+)"(?:[^\]]*?parent="([^"]*)")?', b)
    if not m:
        return None
    name, parent = m.group(1), m.group(2)
    if parent is None:
        return "."
    return name if parent == "." else parent + "/" + name


def xf_of(b):
    m = re.search(r"transform = Transform3D\(([^)]*)\)", b)
    return [float(v) for v in m.group(1).split(",")] if m else None


drop_prefixes = ["Village/" + n for n in DROP_BUILDINGS] + ["Village/Street/" + n for n in DROP_PROPS] + ["Forest"]
kept, dropped = [], []
street_props = {}          # key -> (x, z, block index in kept)
villager_blocks = {}
for b in blocks:
    k = block_key(b) if b.startswith("[node") else None
    if k and any(k == p or k.startswith(p + "/") for p in drop_prefixes):
        dropped.append(k)
        continue
    kept.append(b)
    if k and k.startswith("Village/Street/") and k.count("/") == 2:
        v = xf_of(b)
        street_props[k] = (v[9], v[11], len(kept) - 1)
    if k and k.startswith("Villagers/") and k.count("/") == 1:
        villager_blocks[k] = len(kept) - 1
missing = [p for p in drop_prefixes if not any(d == p or d.startswith(p + "/") for d in dropped)]
assert not missing, "expected to drop: %s" % missing

# villager posts and paths (the farmer is re-routed below), as points
villager_pts = []
for k, i in villager_blocks.items():
    b = kept[i]
    v = xf_of(b)
    villager_pts.append((v[9], v[11]))
    if k == "Villagers/Farmer":
        continue
    m = re.search(r"waypoints = PackedVector3Array\(([^)]*)\)", b)
    if m:
        f = [float(x) for x in m.group(1).split(",")]
        wps = [(f[j], f[j + 2]) for j in range(0, len(f), 3)]
        for (ax, az), (bx, bz) in zip(wps, wps[1:] + wps[:1]):
            n = max(1, int(math.hypot(bx - ax, bz - az) / 0.5))
            villager_pts += [(ax + (bx - ax) * t / n, az + (bz - az) * t / n) for t in range(n)]
for (ax, az), (bx, bz) in zip(FARMER_PATH, FARMER_PATH[1:]):
    n = max(1, int(math.hypot(bx - ax, bz - az) / 0.5))
    villager_pts += [(ax + (bx - ax) * t / n, az + (bz - az) * t / n) for t in range(n + 1)]

# ---------------------------------------------------------------- lots
def on_plain(x, z):
    return x > et.edge_x(z) + et.SLOPE_W + 0.8


def stream_clear(x, z, m):
    return abs(x - et.stream_x(z)) > et.CH_HALF + et.BANK + m


placed = []        # (name, res, x, z, yaw, Rect bounds, roof)


def lot_problem(r, kind, special=False):
    pts = r.edge_points()
    px0, px1, pz0, pz1 = et.PLAY
    for x, z in pts:
        if not (px0 + 2 < x < px1 - 2 and pz0 + 2 < z < pz1 - 2):
            return "play"
        if not on_plain(x, z):
            return "slope"
        if not special and not stream_clear(x, z, 0.6):
            return "stream"
        if kind != "S_fountain" and math.hypot(x - PLAZA[0], z - PLAZA[1]) < PLAZA[2] + 0.4:
            return "plaza"
        if kind != "S_fountain" and et.dist_to_path(x, z) < et.PATH_HALF + 0.8:   # the road ends on the square
            return "road"
        if et.in_rect(x, z, (et.BRIDGE["x0"] - 1, et.BRIDGE["x1"] + 1, et.BRIDGE["z"] - 2.5, et.BRIDGE["z"] + 2.5)):
            return "bridge"
        if et.in_rect(x, z, et.TAVERN_RECT, 2) or any(et.in_rect(x, z, fr, 1.5) for fr in et.FARM_RECTS):
            return "tavern/farm"
        if math.hypot(x - CEMETERY[0], z - CEMETERY[1]) < CEMETERY[2] + 1:
            return "cemetery"
        for nm, poly in STREETS.items():
            if kind != "S_fountain" and dist_poly(x, z, poly) < STREET_HALF + 0.5:
                return "street " + nm
    for vx, vz in villager_pts:
        if kind == "S_fountain":   # round: its bounding box's corners would overstate it
            if math.hypot(vx - r.x, vz - r.z) < (r.x1 - r.x0) / 2.0 + 0.4:
                return "villager"
        elif r.contains(vx, vz, 1.0):
            return "villager"
    for cx, cz in CAT:
        if r.contains(cx, cz, 2.0):
            return "cat"
    for p in placed:
        if overlap(r, p[5], 0.5):
            return "building " + p[0]
    return ""


def bounds_rect(res, x, z, yaw):
    lo, hi = glb_bounds(res)
    return Rect(x, z, yaw, lo[0], hi[0], lo[2], hi[2])


REASONS = {}


def place(name, res, x, z, yaw, roof=None, special=False):
    r = bounds_rect(res, x, z, yaw)
    why = lot_problem(r, os.path.basename(res)[:-5], special)
    if why:
        REASONS[why.split(" ")[0]] = REASONS.get(why.split(" ")[0], 0) + 1
        return why
    placed.append((name, res, x, z, yaw, r, roof))
    return ""


def must(name, res, x, z, yaw, special=False):
    why = place(name, res, x, z, yaw, None, special)
    assert not why, "%s does not fit at (%.1f, %.1f): %s" % (name, x, z, why)


def face(x, z, tx, tz):
    return math.atan2(tx - x, tz - z)


def front(res):
    """How far the piece reaches in front of its origin (local +Z, the door side), eaves and props included."""
    return glb_bounds(res)[1][2]


SET_BACK = STREET_HALF + 0.6        # street centre -> the nearest point of a building (its eaves, its props)

# the fixed pieces
must("Fountain", VK + "S_fountain.gltf", PLAZA[0], PLAZA[1], 0.0)
mz = -14.0
# the wheel (4.6 m out on local +X, turned to face the stream) in the channel's edge; the walls (+-3.1) clear of the bank
must("Watermill", VK + "S_watermill.gltf", et.stream_x(mz) + et.CH_HALF - 0.25 + 4.6, mz, math.pi, special=True)
must("Smithy", VK + "S_smithy.gltf", 36.5, -13.5 + SET_BACK + front(VK + "S_smithy.gltf"), math.pi)   # north lane, facing north
must("Pottery", VK + "S_pottery.gltf", 36.5, 27.8 - SET_BACK - front(VK + "S_pottery.gltf"), 0.0)     # south lane, facing south


# houses along every street, both sides, facing it
def street_lots(poly, side):
    out = []
    for (ax, az), (bx, bz) in zip(poly, poly[1:]):
        L = math.hypot(bx - ax, bz - az)
        tx, tz = (bx - ax) / L, (bz - az) / L
        nx, nz = -tz * side, tx * side
        s = 2.0
        while s < L - 1.0:
            out.append((ax + tx * s, az + tz * s, nx, nz))
            s += 1.0
    return out


names = list(HOUSES)
count = 0
for sname, poly in STREETS.items():
    for side in (1, -1):
        skip_until = -1
        for i, (sx, sz, nx, nz) in enumerate(street_lots(poly, side)):
            if i < skip_until:
                continue
            for hn in rng.sample(names, len(names)):     # every house type, in a random order
                off = SET_BACK + front(VK + hn + ".gltf") + rng.uniform(0.05, 0.6)
                x, z = sx + nx * off, sz + nz * off
                yaw = face(x, z, sx, sz)
                count += 1
                roof = rng.choice(ROOFS)
                if not place("House%02d" % (len([p for p in placed if p[0].startswith("House")]) + 1), VK + hn + ".gltf", x, z, yaw, roof):
                    lo, hi = glb_bounds(VK + hn + ".gltf")
                    skip_until = i + int((hi[0] - lo[0]) * 0.5 + 2.0 + rng.uniform(0, 2.0))
                    break

houses = [p for p in placed if p[0].startswith("House")]
print("houses %d (tried %d), specials %d; refusals %s" % (len(houses), count, len(placed) - len(houses), REASONS))

# drop street props that a building now stands on
for k, (x, z, i) in list(street_props.items()):
    if any(p[5].contains(x, z, 0.8) for p in placed) or any(dist_poly(x, z, poly) < STREET_HALF + 0.3 for poly in STREETS.values()):
        kept[i] = None
        dropped.append(k)
        for j, b in enumerate(kept):
            if b is not None and b.startswith("[node") and (block_key(b) or "").startswith(k + "/"):
                kept[j] = None
kept = [b for b in kept if b is not None]

# ---------------------------------------------------------------- resources
ext_by_path = {}
for b in kept:
    if b.startswith("[ext_resource"):
        m = re.search(r'path="([^"]+)" id="([^"]+)"', b)
        ext_by_path[m.group(1)] = m.group(2)
new_ext, new_subs, nodes = [], [], []


def uid_of(res):
    try:
        imp = open(ROOT + res[len("res://"):] + ".import", encoding="utf-8").read()
        m = re.search(r'uid="(uid://[^"]+)"', imp)
        return m.group(1) if m else None
    except FileNotFoundError:
        return None


def ext_id(res, kind="PackedScene"):
    if res in ext_by_path:
        return ext_by_path[res]
    rid = "s2535_%d" % (len(new_ext) + 1)
    uid = uid_of(res) if kind == "PackedScene" else None
    if kind == "Script":
        try:
            uid = open(ROOT + res[len("res://"):] + ".uid", encoding="utf-8").read().strip()
        except FileNotFoundError:
            uid = None
    new_ext.append('[ext_resource type="%s"%s path="%s" id="%s"]\n' % (kind, ' uid="%s"' % uid if uid else "", res, rid))
    ext_by_path[res] = rid
    return rid


def sub(kind, name, body):
    sid = "%s_s2535_%s" % (kind, name)
    if not any(s.startswith('[sub_resource type="%s" id="%s"]' % (kind, sid)) for s in new_subs):
        new_subs.append('[sub_resource type="%s" id="%s"]\n%s\n' % (kind, sid, body))
    return sid


def fmt(v):
    return "%.5g" % v if abs(v) > 1e-9 else "0"


def xform(x, y, z, yaw=0.0, s=1.0):
    c, sn = math.cos(yaw), math.sin(yaw)
    rows = [c * s, 0, sn * s, 0, s, 0, -sn * s, 0, c * s]
    return "Transform3D(" + ", ".join(fmt(v) for v in rows + [x, y, z]) + ")"


def seat_y(r, sink=0.02):
    return round(min(et.h(x, z) for x, z in r.corners() + [(r.x, r.z)]) - sink, 4)


# ---------------------------------------------------------------- the kit town
for name, res, x, z, yaw, r, roof in placed:
    kind = os.path.basename(res)[:-5]
    # every lot is on the flat valley floor (lot_problem: on the plain, clear of the stream's bank), so the ground at
    # the origin is the ground under the walls; the watermill's walls are clear of the bank too (only its wheel is not)
    y = round(et.h(x, z) - 0.02, 4)
    assert all(abs(et.h(cx, cz) - et.h(x, z)) < 0.05 for cx, cz in [r.to_world(a, b) for a in (-2.9, 2.9) for b in (-2.9, 2.9)]), name
    lines = ['[node name="%s" parent="Village" groups=["village_kit"] instance=ExtResource("%s")]' % (name, ext_id(res)),
             "transform = " + xform(round(x, 3), y, round(z, 3), yaw)]
    if kind == "S_watermill":
        lines.append('script = ExtResource("%s")' % ext_id(WATER_WHEEL, "Script"))
    if roof:
        lines.append("metadata/roof_tint = Color(%s, %s, %s, 1)" % roof)
    if kind.startswith("H"):
        w, d, fl = HOUSES[kind]
        lines.append("metadata/glow = Vector3(0, 1.3, %s)" % fmt(d / 2.0 + 1.2))
    elif kind in ("S_smithy", "S_pottery"):
        lines.append("metadata/glow = Vector3(-2, 1.3, 4.2)")
    nodes.append("\n".join(lines) + "\n\n")
    nodes.append('[node name="Body" type="StaticBody3D" parent="Village/%s"]\n\n' % name)
    boxes = SPECIAL.get(kind)
    if boxes is None:
        w, d, fl = HOUSES[kind]
        boxes = [(0.0, 1.5 * fl, 0.0, w + 0.2, 3.0 * fl, d + 0.2)]
    for bi, (cx, cy, cz, sx, sy, sz) in enumerate(boxes):
        sid = sub("BoxShape3D", "%s_%d" % (kind, bi), "size = Vector3(%s, %s, %s)\n" % (fmt(sx), fmt(sy), fmt(sz)))
        nodes.append('[node name="CollisionShape3D%s" type="CollisionShape3D" parent="Village/%s/Body"]\n'
                     'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\nshape = SubResource("%s")\n\n'
                     % ("" if bi == 0 else str(bi + 1), name, fmt(cx), fmt(cy), fmt(cz), sid))
    if kind in ("S_smithy", "S_pottery"):
        lp = (3.1, 1.2, -0.15) if kind == "S_smithy" else (3.4, 0.7, 0.9)
        nodes.append('[node name="FireLight" type="OmniLight3D" parent="Village/%s"]\n'
                     'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\nlight_color = Color(1, 0.55, 0.25, 1)\n'
                     'light_energy = 2.0\nomni_range = 6.0\n\n' % (name, *map(fmt, lp)))

# ---------------------------------------------------------------- streets: one ribbon mesh, a glTF beside the terrain
def write_streets():
    pos, nrm, uv, idx = [], [], [], []
    for poly in STREETS.values():
        pts = []
        for (ax, az), (bx, bz) in zip(poly, poly[1:]):
            n = max(1, int(math.hypot(bx - ax, bz - az) / 0.8))
            pts += [(ax + (bx - ax) * t / n, az + (bz - az) * t / n) for t in range(n)]
        pts.append(poly[-1])
        acc = 0.0
        for i, (x, z) in enumerate(pts):
            a = pts[max(i - 1, 0)]
            b = pts[min(i + 1, len(pts) - 1)]
            tx, tz = b[0] - a[0], b[1] - a[1]
            L = math.hypot(tx, tz) or 1.0
            nx, nz = -tz / L, tx / L
            if i:
                acc += math.hypot(x - pts[i - 1][0], z - pts[i - 1][1])
            base = len(pos)
            for side in (-1, 1):
                px, pz = x + nx * STREET_HALF * side, z + nz * STREET_HALF * side
                pos.append((px, et.h(px, pz) + 0.04, pz))
                nrm.append((0.0, 1.0, 0.0))
                uv.append((acc / 2.8, (side + 1) / 2.0))
            if i:
                a0, a1, b0, b1 = base - 2, base - 1, base, base + 1
                idx += [a0, a1, b0, a1, b1, b0]   # counter-clockwise seen from above: the face points up (y+)
    blob = b"".join(struct.pack("<3f", *p) for p in pos) + b"".join(struct.pack("<3f", *n) for n in nrm) \
        + b"".join(struct.pack("<2f", *t) for t in uv)
    ioff = len(blob)
    blob += b"".join(struct.pack("<I", i) for i in idx)
    lo = [min(p[k] for p in pos) for k in range(3)]
    hi = [max(p[k] for p in pos) for k in range(3)]
    n = len(pos)
    # Godot re-imports a .gltf only when ITS text changes, not its .bin: carry the geometry's hash in the text
    g = {"asset": {"version": "2.0", "generator": "tools/exterior/gen_town.py (Story 25.35)",
                   "extras": {"bin_md5": hashlib.md5(blob).hexdigest()}},
         "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"name": "terrain_paths", "mesh": 0}],
         "materials": [{"name": "town_street", "pbrMetallicRoughness": {"baseColorFactor": [0.42, 0.38, 0.34, 1.0], "metallicFactor": 0.0, "roughnessFactor": 1.0}}],
         "meshes": [{"name": "terrain_paths", "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
         "buffers": [{"uri": "a6_town_streets.bin", "byteLength": len(blob)}],
         "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": n * 12, "target": 34962},
                         {"buffer": 0, "byteOffset": n * 12, "byteLength": n * 12, "target": 34962},
                         {"buffer": 0, "byteOffset": n * 24, "byteLength": n * 8, "target": 34962},
                         {"buffer": 0, "byteOffset": ioff, "byteLength": len(idx) * 4, "target": 34963}],
         "accessors": [{"bufferView": 0, "componentType": 5126, "count": n, "type": "VEC3", "min": lo, "max": hi},
                       {"bufferView": 1, "componentType": 5126, "count": n, "type": "VEC3"},
                       {"bufferView": 2, "componentType": 5126, "count": n, "type": "VEC2"},
                       {"bufferView": 3, "componentType": 5125, "count": len(idx), "type": "SCALAR"}]}
    base = ROOT + STREETS_RES[len("res://"):-5]
    if not DRY:
        open(base + ".bin", "wb").write(blob)
        with open(base + ".gltf", "w", encoding="utf-8", newline="\n") as f:
            json.dump(g, f, indent=1)
    return n, len(idx) // 3


sv, st = write_streets()
nodes.append('[node name="Streets" parent="Terrain" instance=ExtResource("%s")]\n\n' % ext_id(STREETS_RES))

# ---------------------------------------------------------------- the forest (nature kit)
TREES = ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5", "Pine_1", "Pine_3", "CommonTree_1", "CommonTree_2",
         "CommonTree_3", "CommonTree_4", "CommonTree_5"]
ODD = ["DeadTree_1", "DeadTree_2", "DeadTree_3", "TwistedTree_1", "TwistedTree_2"]
ROCKS = ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
UNDER = ["Bush_Common", "Fern_1", "Plant_1_Big", "Grass_Wispy_Tall"]
trees = []


def tree_blocked(x, z, r):
    ex0, ex1, ez0, ez1 = et.EXTENT
    if not (ex0 + 3 < x < ex1 - 3 and ez0 + 3 < z < ez1 - 3):
        return True
    if et.dist_to_path(x, z) < et.PATH_HALF + 1.2 + r:
        return True
    if not stream_clear(x, z, 0.6 + r):
        return True
    if et.in_rect(x, z, (et.BRIDGE["x0"] - 1, et.BRIDGE["x1"] + 1, et.BRIDGE["z"] - 2.5, et.BRIDGE["z"] + 2.5), r):
        return True
    if et.in_rect(x, z, et.TAVERN_RECT, 3 + r) or et.in_rect(x, z, (-23.5, -17.0, 6.5, 13.5), r):
        return True
    if any(et.in_rect(x, z, fr, 2 + r) for fr in et.FARM_RECTS):
        return True
    if math.hypot(x - PLAZA[0], z - PLAZA[1]) < PLAZA[2] + 2.5 + r:
        return True
    if math.hypot(x - CEMETERY[0], z - CEMETERY[1]) < CEMETERY[2] + r:
        return True
    if any(dist_poly(x, z, poly) < STREET_HALF + 1.0 + r for poly in STREETS.values()):
        return True
    if any(p[5].contains(x, z, 1.5 + r) for p in placed):
        return True
    if any(math.hypot(x - vx, z - vz) < 1.2 + r for vx, vz in villager_pts):
        return True
    if any(math.hypot(x - cx, z - cz) < 2.0 + r for cx, cz in CAT):
        return True
    for k, (px, pz, i) in street_props.items():
        if k not in dropped and math.hypot(x - px, z - pz) < 1.5 + r:
            return True
    for px, pz, rr in trees:
        if math.hypot(x - px, z - pz) < 0.8 * (r + rr):
            return True
    return False


def on_slope(x, z):
    t = (x - et.edge_x(z)) / et.SLOPE_W
    return -0.1 < t < 1.1


HF = json.load(open(ROOT + "test/fixtures/exterior_heightfield.json", encoding="utf-8"))


def hf_h(x, z):
    """The terrain height as the fixture (and so Test 9) interpolates it: bilinear on its 1 m grid. On the hill's
    crease and the stream's banks it differs from et.h by up to ~0.1 m; seating by it keeps every piece within the
    test's 0.12 m."""
    fx, fz = (x - HF["x0"]) / HF["step"], (z - HF["z0"]) / HF["step"]
    i = min(max(int(math.floor(fx)), 0), HF["nx"] - 2)
    j = min(max(int(math.floor(fz)), 0), HF["nz"] - 2)
    tx, tz = min(max(fx - i, 0.0), 1.0), min(max(fz - j, 0.0), 1.0)
    H = HF["heights"]
    a = H[j][i] + (H[j][i + 1] - H[j][i]) * tx
    b = H[j + 1][i] + (H[j + 1][i + 1] - H[j + 1][i]) * tx
    return a + (b - a) * tz


def plant(x, z, pool, scale=(0.75, 1.1), radius=2.2):
    piece = rng.choice(pool)
    s = rng.uniform(*scale)
    if piece in ROCKS:
        r = 1.5 * s
    elif piece in UNDER:
        r = 0.9 * s
    else:
        r = radius * s
    if tree_blocked(x, z, r):
        return False
    y = round(hf_h(x, z) - 0.05, 4)
    n = len(trees)
    kind = "Rock" if piece in ROCKS else ("Bush" if piece in UNDER else "Tree")
    nm = "%s_%03d" % (kind, n)
    nodes.append('[node name="%s" parent="Forest" groups=["nature_kit"] instance=ExtResource("%s")]\ntransform = %s\n\n'
                 % (nm, ext_id(NK + piece + ".gltf"), xform(round(x, 3), y, round(z, 3), rng.uniform(0, math.tau), round(s, 3))))
    # every piece the player can reach blocks him (Test 9); the body scales with the piece
    if kind == "Tree":
        sid = sub("CylinderShape3D", "trunk", "height = 4.0\nradius = 0.45\n")
        cy = 2.0 / s
    elif kind == "Rock":
        sid = sub("CylinderShape3D", "rock", "height = 2.0\nradius = 1.3\n")
        cy = 0.6
    else:
        sid = sub("CylinderShape3D", "bush", "height = 1.2\nradius = 0.5\n")
        cy = 0.6
    nodes.append('[node name="Body" type="StaticBody3D" parent="Forest/%s"]\n\n' % nm)
    nodes.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Forest/%s/Body"]\n'
                 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, 0)\nshape = SubResource("%s")\n\n' % (nm, fmt(cy), sid))
    trees.append((x, z, r))
    return True


nodes.append('[node name="Forest" type="Node3D" parent="."]\n\n')
px0, px1, pz0, pz1 = et.PLAY
ex0, ex1, ez0, ez1 = et.EXTENT


def outside_play(x, z):
    return max(px0 - x, x - px1, pz0 - z, z - pz1)


# 1) dense band beyond the walls
zz = ez0 + 3
while zz < ez1 - 3:
    xx = ex0 + 3
    while xx < ex1 - 3:
        x, z = xx + rng.uniform(-2.0, 2.0), zz + rng.uniform(-2.0, 2.0)
        d = outside_play(x, z)
        if d > 0 and (d < 22 or rng.random() < 0.45):
            plant(x, z, ROCKS if rng.random() < 0.08 else (ODD if rng.random() < 0.05 else TREES))
        xx += 5.0
    zz += 5.0
# 2) the treeline just inside the walls, with undergrowth in front of it
zz = pz0
while zz <= pz1:
    xx = px0
    while xx <= px1:
        x, z = xx + rng.uniform(-1.4, 1.4), zz + rng.uniform(-1.4, 1.4)
        d = outside_play(x, z)
        if -4.5 < d <= 0:
            plant(x, z, TREES)
        elif -7.5 < d <= -4.5 and rng.random() < 0.5:
            plant(x, z, UNDER, (0.7, 1.0))
        xx += 3.6
    zz += 3.6
# 3) groves inside the play area (away from the town), around the cemetery clearing, on the hill
for gx, gz, gr in [(-40, -12, 8), (-38, 28, 7), (-14, -20, 7), (-6, 36, 6), (-22, -8, 5), (-40, 40, 6), (40, 38, 6),
                   (42, -18, 5), (-44, 6, 5), (8, 40, 4), (2, -20, 5)]:
    for _ in range(int(gr * gr / 2.2)):
        a, rr = rng.uniform(0, math.tau), gr * math.sqrt(rng.random())
        plant(gx + rr * math.cos(a), gz + rr * math.sin(a), TREES if rng.random() < 0.85 else UNDER)
# 4) singles and odd trees in the open, rocks on the hill crest and the stream banks
for _ in range(70):
    plant(rng.uniform(px0 + 4, px1 - 4), rng.uniform(pz0 + 4, pz1 - 4), TREES if rng.random() < 0.8 else ODD, (0.7, 1.0))
for _ in range(50):
    plant(rng.uniform(px0 + 4, px1 - 4), rng.uniform(pz0 + 4, pz1 - 4), UNDER, (0.7, 1.0))
for z in range(int(pz0), int(pz1), 3):
    if rng.random() < 0.6:
        plant(et.edge_x(z) + rng.uniform(-0.5, 3.0), z + rng.uniform(-1, 1), ROCKS, (0.4, 0.8))
for z in range(int(pz0), int(pz1), 6):
    if rng.random() < 0.5:
        side = rng.choice((-1, 1))
        plant(et.stream_x(z) + side * (et.CH_HALF + et.BANK + rng.uniform(1.6, 2.8)), z, ROCKS, (0.35, 0.6))

# ---------------------------------------------------------------- the farmer walks the east street
for i, b in enumerate(kept):
    if not b.startswith("[node") or block_key(b) != "Villagers/Farmer":
        continue
    pts = FARMER_PATH + FARMER_PATH[-2:0:-1]
    wp = ", ".join("%s, %s, %s" % (fmt(x), fmt(round(et.h(x, z) + 0.02, 3)), fmt(z)) for x, z in pts)
    b = re.sub(r"waypoints = PackedVector3Array\([^)]*\)", "waypoints = PackedVector3Array(%s)" % wp, b)
    v = xf_of(b)
    v[9], v[10], v[11] = FARMER_PATH[0][0], round(et.h(*FARMER_PATH[0]) + 0.02, 3), FARMER_PATH[0][1]
    b = re.sub(r"transform = Transform3D\([^)]*\)", "transform = Transform3D(" + ", ".join(fmt(x) for x in v) + ")", b, count=1)
    kept[i] = b

# ---------------------------------------------------------------- drop resources nothing uses any more, write
body = "".join(b for b in kept if not b.startswith("[ext_resource") and not b.startswith("[sub_resource")) + "".join(nodes)
subs_kept = [b for b in kept if b.startswith("[sub_resource")]
RID = re.compile(r' id="([^"]+)"')      # the leading space: never the tail of uid="..."


def rid(b):
    return RID.search(b.split("\n", 1)[0]).group(1)


# sub_resources can reference each other (AnimationLibrary -> Animation): keep the ones the nodes or kept subs use
used = set(re.findall(r'SubResource\("([^"]+)"\)', body))
changed = True
while changed:
    changed = False
    for b in subs_kept:
        if rid(b) in used:
            for s2 in re.findall(r'SubResource\("([^"]+)"\)', b):
                if s2 not in used:
                    used.add(s2); changed = True
subs_kept = [b for b in subs_kept if rid(b) in used]
all_text = body + "".join(subs_kept) + "".join(new_subs)
used_ext = set(re.findall(r'ExtResource\("([^"]+)"\)', all_text))
exts = [b for b in kept if b.startswith("[ext_resource") and rid(b) in used_ext] + new_ext
missing_ext = used_ext - {rid(e) for e in exts}
assert not missing_ext, "ext resources referenced but not declared: %s" % missing_ext
missing_sub = set(re.findall(r'SubResource\("([^"]+)"\)', all_text)) - {rid(b) for b in subs_kept + new_subs}
assert not missing_sub, "sub resources referenced but not declared: %s" % missing_sub
exts = [e.rstrip("\n") + "\n" for e in exts]
node_blocks = [b for b in kept if b.startswith("[node") or b.startswith("[editable") or b.startswith("[connection")]
steps = len(exts) + len(subs_kept) + len(new_subs) + 1
head2 = re.sub(r"load_steps=\d+", "load_steps=%d" % steps, head)
out = head2 + "".join(exts) + "\n" + "".join(subs_kept) + "".join(new_subs) + "".join(node_blocks).rstrip("\n") + "\n\n" + "".join(nodes).rstrip("\n") + "\n"
print("dropped %d nodes (%s...), buildings %d, streets %d verts / %d tris, forest %d pieces, ext %d (+%d), subs %d (+%d)"
      % (len(dropped), dropped[:3], len(placed), sv, st, len(trees), len(exts), len(new_ext), len(subs_kept), len(new_subs)))
plan = {"buildings": [{"name": p[0], "res": p[1], "x": round(p[2], 3), "z": round(p[3], 3), "yaw_deg": round(math.degrees(p[4]), 2),
                       "corners": [[round(a, 2), round(b, 2)] for a, b in p[5].corners()], "roof": p[6]} for p in placed],
        "streets": STREETS, "street_half": STREET_HALF, "dropped": dropped}
with open(os.path.join(HERE, "town_plan.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(plan, f, indent=1)
if not DRY:
    assert out.startswith("[gd_scene")
    with open(SCENE, "w", encoding="utf-8", newline="\n") as f:
        f.write(out)
    print("written", SCENE)
