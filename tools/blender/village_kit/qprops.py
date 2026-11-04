"""Hand-built props for the smithy and the pottery (exec'd in Blender after qkit.py).
Every prop is a mesh object with box-projected UVs so kit textures (wood, brick, stone) tile on it.
Blender coords (Z up). Each function returns the objects it made.
"""
import bpy
import bmesh
import math
import random
from mathutils import Vector, Matrix, noise

UV_SCALE = 0.5


def mat(name, color=None, emit=None, strength=0.0, kit=None):
    """kit='MI_WoodTrim' reuses the imported kit material (its textures); else a flat colour material."""
    if kit:
        carrier = {"MI_RedBrick": "Floor_RedBrick", "MI_Brick": "Floor_Brick", "MI_UnevenBrick": "Floor_UnevenBrick",
                   "MI_RockTrim": "Stairs_Exterior_Straight_Center", "MI_WoodTrim": "Floor_WoodDark", "MI_Plaster": "Wall_Plaster_Straight"}
        for attempt in range(2):
            for m in bpy.data.materials:
                if m.name == kit or (m.name.startswith(kit + ".") and m.name[len(kit) + 1:].isdigit()):
                    return m
            load(carrier[kit])   # importing a piece that uses it brings the material (and its textures) in
        raise RuntimeError("kit material not found: " + kit)
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    if color:
        b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = 1.0
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m


def _uv_box(bm, scale=UV_SCALE):
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            c = l.vert.co
            if ax == 0:
                l[uv].uv = (c.y * scale, c.z * scale)
            elif ax == 1:
                l[uv].uv = (c.x * scale, c.z * scale)
            else:
                l[uv].uv = (c.x * scale, c.y * scale)


def _obj(name, bm, material, coll, loc=(0, 0, 0), rot=0.0, uv=True):
    bm.normal_update()
    if uv:
        _uv_box(bm)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.rotation_euler = (0, 0, math.radians(rot))
    coll.objects.link(ob)
    return ob


def box(name, size, loc, material, coll, rot=0.0, taper=1.0):
    """size (x, y, z), origin at the bottom centre; taper scales the top face."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], (v.co.z + 0.5) * size[2]))
        if v.co.z > size[2] * 0.5 and taper != 1.0:
            v.co.x *= taper
            v.co.y *= taper
    return _obj(name, bm, material, coll, loc, rot)


def lathe(name, profile, loc, material, coll, seg=16, rot=0.0, cap_top=True, cap_bottom=True, wobble=0.0, seed=0):
    """profile: [(radius, z), ...] bottom to top."""
    bm = bmesh.new()
    rings = []
    rng = random.Random(seed)
    for r, z in profile:
        ring = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            rr = r * (1.0 + wobble * (rng.random() - 0.5))
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        a, b = rings[k], rings[k + 1]
        for i in range(seg):
            bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
    if cap_bottom and profile[0][0] > 0.001:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and profile[-1][0] > 0.001:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, material, coll, loc, rot)


def blob(name, radius, squash, loc, material, coll, seed=0, rough=0.25):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=radius)
    off = Vector((seed * 3.1, seed * 1.7, 0.4))
    for v in bm.verts:
        n = noise.noise(v.co * 1.6 + off)
        v.co *= 1.0 + rough * n
        v.co.z = v.co.z * squash
        if v.co.z < 0:
            v.co.z *= 0.2
    return _obj(name, bm, material, coll, loc)


# ---------------------------------------------------------------- props

def anvil(coll, loc, rot=0.0):
    iron = mat("P_Iron", (0.09, 0.09, 0.10))
    wood = mat("", kit="MI_WoodTrim")
    out = [lathe("P_Stump", [(0.36, 0.0), (0.33, 0.55), (0.30, 0.6)], loc, wood, coll, seg=10, rot=rot, wobble=0.15, seed=3)]
    # body: foot, waist, face (three boxes); the horn is a tapered lathe off +x
    parts =[((0.56, 0.34, 0.08), 0.0), ((0.32, 0.20, 0.14), 0.08), ((0.62, 0.28, 0.14), 0.22)]
    for i, (s, z) in enumerate(parts):
        out.append(box("P_Anvil%d" % i, s, (loc[0], loc[1], loc[2] + 0.6 + z), iron, coll, rot))
    horn = lathe("P_AnvilHorn", [(0.11, 0.0), (0.07, 0.16), (0.01, 0.30)], (0, 0, 0), iron, coll, seg=8)
    horn.rotation_euler = (0, math.radians(90), math.radians(rot))
    d = Vector((math.cos(math.radians(rot)), math.sin(math.radians(rot)), 0))
    horn.location = Vector(loc) + d * 0.30 + Vector((0, 0, 0.6 + 0.29))
    out.append(horn)
    return out


def barrel(coll, loc, name="P_Barrel", water=False):
    wood = mat("", kit="MI_WoodTrim")
    iron = mat("P_Iron", (0.09, 0.09, 0.10))
    prof = [(0.30, 0.0), (0.36, 0.25), (0.38, 0.45), (0.36, 0.65), (0.30, 0.9)]
    out = [lathe(name, prof, loc, wood, coll, seg=14, cap_top=not water)]
    for z in (0.12, 0.78):
        r = 0.34 if z < 0.5 else 0.335
        out.append(lathe(name + "_band", [(r + 0.012, z - 0.03), (r + 0.02, z), (r + 0.012, z + 0.03)], loc, iron, coll, seg=14, cap_top=False, cap_bottom=False))
    if water:
        wat = mat("P_Water", (0.06, 0.14, 0.16))
        out.append(lathe(name + "_water", [(0.33, 0.78), (0.0, 0.78)], loc, wat, coll, seg=14, cap_top=False, cap_bottom=False))
    return out


def forge(coll, loc, roof_top=6.4):
    """Stone hearth with a coal bed, a hood and a brick flue to above roof_top. loc = hearth centre on the ground."""
    stone = mat("", kit="MI_UnevenBrick")
    rock = mat("", kit="MI_RockTrim")
    brick = mat("", kit="MI_Brick")
    ember = mat("P_Ember", (1.0, 0.42, 0.1), emit=(1.0, 0.45, 0.12), strength=6.0)
    coal = mat("P_Coal", (0.05, 0.045, 0.045))
    x, y, z = loc
    out = [box("P_Hearth", (1.9, 1.3, 0.85), (x, y, z), stone, coll)]
    out.append(box("P_HearthRim", (2.0, 1.4, 0.10), (x, y, z + 0.85), rock, coll))
    out.append(box("P_CoalBed", (1.1, 0.75, 0.06), (x, y - 0.05, z + 0.93), coal, coll))
    for i, (dx, dy) in enumerate([(-0.25, -0.1), (0.1, 0.05), (0.3, -0.15), (-0.05, -0.25)]):
        out.append(blob("P_Ember%d" % i, 0.16, 0.45, (x + dx, y + dy, z + 0.97), ember, coll, seed=i, rough=0.35))
    out.append(box("P_Hood", (1.8, 1.25, 1.0), (x, y + 0.05, z + 1.75), brick, coll, taper=0.45))
    out.append(box("P_Flue", (0.8, 0.7, roof_top - 2.7), (x, y + 0.05, z + 2.7), brick, coll, taper=0.92))
    out.append(box("P_FlueCap", (0.95, 0.85, 0.18), (x, y + 0.05, z + roof_top), rock, coll))
    # bellows beside the hearth
    leather = mat("P_Leather", (0.30, 0.17, 0.09))
    out.append(box("P_Bellows", (0.5, 0.9, 0.22), (x + 1.25, y + 0.1, z + 0.55), leather, coll, taper=0.6))
    return out


def weapon_rack(coll, loc, rot=0.0):
    wood = mat("", kit="MI_WoodTrim")
    iron = mat("P_Steel", (0.42, 0.44, 0.47))
    x, y, z = loc
    d = Vector((math.cos(math.radians(rot)), math.sin(math.radians(rot)), 0))
    out = []
    for s in (-0.7, 0.7):
        p = Vector(loc) + d * s
        out.append(box("P_RackPost", (0.1, 0.1, 1.3), tuple(p), wood, coll, rot))
    out.append(box("P_RackBar", (1.6, 0.08, 0.08), (x, y, z + 1.1), wood, coll, rot))
    out.append(box("P_RackFoot", (1.6, 0.3, 0.06), (x, y, z + 0.1), wood, coll, rot))
    for i, s in enumerate((-0.45, -0.15, 0.15, 0.45)):
        p = Vector(loc) + d * s
        out.append(box("P_Blade%d" % i, (0.06, 0.03, 1.0), (p.x, p.y, z + 0.12), iron, coll, rot, taper=0.4))
        out.append(box("P_Guard%d" % i, (0.24, 0.05, 0.04), (p.x, p.y, z + 1.05), wood, coll, rot))
    return out


def grindstone(coll, loc, rot=0.0):
    wood = mat("", kit="MI_WoodTrim")
    rock = mat("", kit="MI_RockTrim")
    x, y, z = loc
    out = [box("P_GrindFrame", (1.0, 0.12, 0.6), (x, y - 0.25, z), wood, coll, rot),
           box("P_GrindFrame2", (1.0, 0.12, 0.6), (x, y + 0.25, z), wood, coll, rot)]
    w = lathe("P_GrindWheel", [(0.0, -0.08), (0.42, -0.08), (0.42, 0.08), (0.0, 0.08)], (0, 0, 0), rock, coll, seg=16)
    w.rotation_euler = (math.radians(90), 0, math.radians(rot))
    w.location = (x, y, z + 0.7)
    out.append(w)
    return out


def pot(coll, loc, kind=0, scale=1.0, color=None, seed=0):
    tc = mat("P_Terracotta", (0.55, 0.27, 0.15))
    if color == "teal":
        tc = mat("P_GlazeTeal", (0.16, 0.36, 0.36))
    elif color == "cream":
        tc = mat("P_GlazeCream", (0.78, 0.72, 0.58))
    elif color == "raw":
        tc = mat("P_Clay", (0.48, 0.36, 0.27))
    profs = [
        [(0.10, 0.0), (0.17, 0.08), (0.20, 0.20), (0.15, 0.32), (0.08, 0.38), (0.10, 0.42)],      # jug
        [(0.08, 0.0), (0.20, 0.06), (0.24, 0.14), (0.20, 0.18)],                                  # bowl
        [(0.12, 0.0), (0.28, 0.25), (0.30, 0.55), (0.18, 0.85), (0.10, 0.95), (0.13, 1.0)],      # amphora / big jar
        [(0.10, 0.0), (0.14, 0.12), (0.14, 0.26), (0.11, 0.30)],                                  # cup / small pot
    ]
    p = [(r * scale, z * scale) for r, z in profs[kind]]
    return [lathe("P_Pot%d" % kind, p, loc, tc, coll, seg=12, cap_top=kind in (3,), wobble=0.06, seed=seed)]


def shelf(coll, loc, rot=0.0, length=2.0, rng=None):
    wood = mat("", kit="MI_WoodTrim")
    x, y, z = loc
    d = Vector((math.cos(math.radians(rot)), math.sin(math.radians(rot)), 0))
    out = []
    for s in (-length / 2, length / 2):
        p = Vector(loc) + d * s
        out.append(box("P_ShelfSide", (0.06, 0.45, 1.7), tuple(p), wood, coll, rot))
    rng = rng or random.Random(5)
    for lv in (0.15, 0.75, 1.35):
        out.append(box("P_Plank", (length + 0.1, 0.45, 0.05), (x, y, z + lv), wood, coll, rot))
        t = -length / 2 + 0.25
        while t < length / 2 - 0.2:
            p = Vector(loc) + d * t
            k = rng.choice([0, 1, 3, 3, 0])
            out += pot(coll, (p.x, p.y, z + lv + 0.05), kind=k, scale=rng.uniform(0.8, 1.1), color=rng.choice([None, None, "teal", "cream", "raw"]), seed=rng.randint(0, 99))
            t += rng.uniform(0.32, 0.45)
    return out


def wheel(coll, loc):
    wood = mat("", kit="MI_WoodTrim")
    clay = mat("P_Clay", (0.48, 0.36, 0.27))
    x, y, z = loc
    out = [lathe("P_WheelBase", [(0.32, 0.0), (0.30, 0.12), (0.06, 0.14), (0.06, 0.62)], loc, wood, coll, seg=14),
           lathe("P_WheelHead", [(0.30, 0.62), (0.32, 0.68), (0.0, 0.70)], loc, wood, coll, seg=16, cap_bottom=True, cap_top=False),
           lathe("P_WheelPot", [(0.10, 0.70), (0.14, 0.80), (0.12, 0.92), (0.10, 0.95)], loc, clay, coll, seg=12),
           box("P_Stool", (0.35, 0.35, 0.45), (x, y - 0.65, z), wood, coll)]
    return out


def kiln(coll, loc, rot=0.0):
    """A bottle kiln: brick lathe, a glowing firing mouth facing local -y."""
    brick = mat("", kit="MI_RedBrick")
    rock = mat("", kit="MI_RockTrim")
    ember = mat("P_Ember", (1.0, 0.42, 0.1), emit=(1.0, 0.45, 0.12), strength=6.0)
    soot = mat("P_Coal", (0.05, 0.045, 0.045))
    prof = [(1.55, 0.0), (1.65, 0.6), (1.70, 1.4), (1.55, 2.3), (1.15, 3.1), (0.70, 3.8), (0.55, 4.6), (0.62, 4.75)]
    out = [lathe("P_Kiln", prof, loc, brick, coll, seg=20, rot=rot, cap_top=False, wobble=0.03, seed=7)]
    out.append(lathe("P_KilnBand", [(1.72, 1.15), (1.76, 1.25), (1.72, 1.35)], loc, rock, coll, seg=20, cap_top=False, cap_bottom=False))
    out.append(lathe("P_KilnSoot", [(0.52, 4.6), (0.0, 4.55)], loc, soot, coll, seg=12, cap_top=False, cap_bottom=False))
    d = Vector((math.sin(math.radians(rot)), -math.cos(math.radians(rot)), 0))
    m = Vector(loc) + d * 1.55
    out.append(box("P_KilnArch", (1.3, 0.5, 1.4), (m.x, m.y, loc[2]), rock, coll, rot))
    g = Vector(loc) + d * 1.81
    out.append(box("P_KilnFire", (0.8, 0.05, 0.85), (g.x, g.y, loc[2] + 0.1), ember, coll, rot))
    return out
