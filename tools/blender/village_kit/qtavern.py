"""The Guild Tavern (A1) from the kit (Story 25.36; exec'd after qkit, qhouse, qprops, qrough).

Build frame = the houses' frame: the front (door, porch, sign) on -y. tavern_bake() turns the baked mesh +90 deg about
Z so the front faces +x (Blender) = +x (Godot), the side A1 has always had, then adds A1's contract:
  interact_point (at the door), spawn_point (in front of it), chimney_smoke_anchor(_02) (the chimney tops),
  col_main / col_wing / col_chimney -convcolonly boxes (Godot imports them as convex colliders, no mesh),
  the window glass as "emissive_window_mat" (exterior_look lights it by phase, never fully off).
Origin = the main hall's centre on the ground. Godot local = (-by, z, -bx) of a build-frame point (bx, by, z).
"""
import bpy
import bmesh
import math
import random
from mathutils import Matrix, Vector

DOOR_X = 1.0                 # the door's wall slot on the main hall's front (build x)
FRONT_Y = -4.0               # the main hall's front wall (build y)
WING = (-6.0, 1.0, 4, 6)     # brewhouse wing: centre x, y, w, d (one storey, stone)
CHIMNEY = (-8.5, 1.0)        # the brewhouse chimney stack, outside the wing's end wall


def _wood():
    # flat dark wood: the kit's WoodTrim is a trim sheet, box-projected onto plain posts it comes out pale
    return mat("P_DarkWood", (0.22, 0.13, 0.08))


def porch(c, into):
    z = 2.45
    place("Roof_Wooden_2x1_L", DOOR_X - 1.0, FRONT_Y, z, 0, into=into)
    place("Roof_Wooden_2x1_R", DOOR_X + 1.0, FRONT_Y, z, 0, into=into)
    for px in (DOOR_X - 1.95, DOOR_X + 1.95):
        box("P_PorchPost", (0.18, 0.18, z - 0.1), (px, FRONT_Y - 1.38, 0.0), _wood(), c)
    box("P_PorchBeam", (4.1, 0.16, 0.16), (DOOR_X, FRONT_Y - 1.38, z - 0.26), _wood(), c)


def sign(c):
    """The guild's sign: an iron arm off the front wall left of the porch, a board with a golden sun on both faces."""
    iron = mat("P_Iron", (0.08, 0.08, 0.09))
    gold = mat("P_SignGold", (0.85, 0.62, 0.18), emit=(1.0, 0.75, 0.3), strength=0.6)
    board = mat("P_SignBoard", (0.30, 0.18, 0.11))
    x = DOOR_X - 2.6
    box("P_SignArm", (0.05, 1.05, 0.05), (x, FRONT_Y - 0.55, 3.05), iron, c)
    for dy in (-0.25, 0.25):
        box("P_SignChain", (0.02, 0.02, 0.27), (x, FRONT_Y - 0.62 + dy, 2.78), iron, c)
    box("P_SignBoard", (0.07, 1.0, 0.75), (x, FRONT_Y - 0.62, 2.15), board, c)
    cz = 2.525
    for dx in (-0.045, 0.045):
        disc = lathe("P_SignSun", [(0.0, -0.012), (0.2, -0.012), (0.2, 0.012), (0.0, 0.012)], (0, 0, 0), gold, c, seg=16)
        disc.rotation_euler = (0.0, math.radians(90), 0.0)
        disc.location = (x + dx, FRONT_Y - 0.62, cz)
        for i in range(8):
            a = i * math.pi / 4
            ray = box("P_SignRay", (0.02, 0.06, 0.12), (x + dx, FRONT_Y - 0.62 + 0.22 * math.cos(a), cz + 0.22 * math.sin(a)),
                      gold, c)
            ray.rotation_euler = (a - math.pi / 2, 0.0, 0.0)


def yard(c, into):
    """Barrels and a bench by the door, a cart and crates by the brewhouse, hop vines on the walls."""
    rng = random.Random(36)
    barrel(c, (DOOR_X + 2.55, FRONT_Y - 0.75, 0.0), name="P_Barrel")
    barrel(c, (DOOR_X + 3.25, FRONT_Y - 0.55, 0.0), name="P_Barrel")
    box("P_Bench", (1.3, 0.36, 0.08), (DOOR_X - 1.6 + 0.0, FRONT_Y - 0.45, 0.45), _wood(), c)
    for bx in (DOOR_X - 2.1, DOOR_X - 1.1):
        box("P_BenchLeg", (0.08, 0.3, 0.45), (bx, FRONT_Y - 0.45, 0.0), _wood(), c)
    place("Prop_Crate", WING[0] - 1.0, WING[1] - WING[3] / 2 - 0.9, 0.0, 12, into=into)
    place("Prop_Crate", WING[0] + 0.1, WING[1] - WING[3] / 2 - 0.8, 0.0, -8, into=into)
    barrel(c, (WING[0] + 1.3, WING[1] - WING[3] / 2 - 0.7, 0.0), name="P_Barrel")
    for name, x, y, z, r in [("Prop_Vine1", -3.0, FRONT_Y, 2.9, 0), ("Prop_Vine2", 3.0, FRONT_Y, 2.9, 0),
                             ("Prop_Vine1", WING[0] - 1.0, WING[1] - WING[3] / 2, 2.9, 0),
                             ("Prop_Vine2", -4.0, 3.0, 2.9, -90)]:
        place(name, x, y, z, r, into=into)


ANCHORS = {}   # build frame (x, y, z): the chimney tops, filled by tavern()


def _top(ob):
    bpy.context.view_layer.update()
    ws = [ob.matrix_world @ Vector(v) for v in ob.bound_box]
    return (sum(w.x for w in ws) / 8.0, sum(w.y for w in ws) / 8.0, max(w.z for w in ws))


def tavern(into):
    c = coll(into)
    house(place, 0.0, 0.0, 8, 8, 2, seed=36, into=into, balcony=False, styles=["stone", "timber"], chimney=True,
          door_x=int(DOOR_X), door="Wall_UnevenBrick_Door_Round", windows=0.8)
    hall_chimney = [o for o in c.objects if o.name.startswith("Prop_Chimney") and o.location.z > 6.0]
    house(place, WING[0], WING[1], WING[2], WING[3], 1, seed=37, into=into, balcony=False, styles=["stone"],
          chimney=False, door_x=1, windows=0.45)
    for z in (0.0, 3.0):
        place("Prop_Chimney2", CHIMNEY[0], CHIMNEY[1], z, 90, into=into)
    cap = place("Prop_Chimney", CHIMNEY[0], CHIMNEY[1], 6.0, 0, into=into)
    ANCHORS["chimney_smoke_anchor"] = _top(cap)
    if hall_chimney:
        ANCHORS["chimney_smoke_anchor_02"] = _top(hall_chimney[0])
    # guest rooms in the roof: two dormers on the slope the exterior camera sees (-x here, +z in Godot); the kit
    # dormer's window is at its local +x end (1.9 m from the origin): turned 180, the window faces -x at origin - 1.9,
    # its sill on the slope (8x8 roof: z +1.75 at x -2.9)
    for y in (-2.2, 0.6):
        place("Roof_Dormer_RoundTile", -1.0, y, 6.0 + 1.75 - 0.05, 180, into=into)
    porch(c, into)
    sign(c)
    yard(c, into)


# ---------------------------------------------------------------- bake, turn, contract, export

A1_PATH = "F:/GAME I AM MAKING/shiningsun/assets/environment/custom/a1_guild_tavern.gltf"
LOOK = dict(sag=0.8, kick=0.6, bow=0.10, lean=0.12, tilt=0.015, wob=0.08)
# convex colliders, build frame: (name, x0, x1, y0, y1, z1)
COLS = [("col_main", -4.1, 4.1, -4.1, 4.1, 7.0), ("col_wing", -8.1, -4.0, -2.1, 4.1, 3.6),
        ("col_chimney", -9.05, -7.95, 0.45, 1.55, 8.0)]


def _turn(x, y):
    """Build frame -> Blender after the +90 deg turn: (x, y) -> (-y, x)."""
    return (-y, x)


def _window_mat():
    m = bpy.data.materials.get("emissive_window_mat")
    if m is None:
        m = bpy.data.materials.new("emissive_window_mat")
        m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (0.10, 0.09, 0.11, 1)
    b.inputs["Roughness"].default_value = 1.0
    b.inputs["Emission Color"].default_value = (1.0, 0.62, 0.30, 1)
    b.inputs["Emission Strength"].default_value = 2.2
    return m


def _empty(name, loc, parent, into):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.3
    e.location = loc
    coll(into).objects.link(e)
    e.parent = parent
    return e


def _col_box(name, x0, x1, y0, y1, z1, parent, into):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector(((v.co.x + 0.5) * (x1 - x0) + x0, (v.co.y + 0.5) * (y1 - y0) + y0, (v.co.z + 0.5) * z1))
    me = bpy.data.meshes.new(name + "-convcolonly")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name + "-convcolonly", me)
    coll(into).objects.link(ob)
    ob.parent = parent
    return ob


def tavern_bake(look=None):
    """Bake the tavern into ROUGH as 'A1_tavern', turned to face +x, with A1's markers and colliders as children."""
    for n in ["A1_tavern"]:
        old = bpy.data.objects.get(n)
        if old is not None:
            for ch in list(old.children):
                bpy.data.objects.remove(ch, do_unlink=True)
            bpy.data.objects.remove(old, do_unlink=True)
    ANCHORS.clear()
    ob, t0, t1 = bake_with(tavern, clear, coll, "A1_tavern", 8, 8, 2, 36, **(look or LOOK))
    ob.data.transform(Matrix.Rotation(math.radians(90), 4, "Z"))
    ob.data.update()
    renormal(ob)
    win = _window_mat()
    swapped = 0
    for i, m in enumerate(ob.data.materials):
        if m is not None and (m.name == "MI_WindowGlass" or m.name.startswith("MI_WindowGlass.")):
            ob.data.materials[i] = win
            swapped += 1
    out = "ROUGH"
    door = _turn(DOOR_X, FRONT_Y - 0.45)
    _empty("interact_point", (door[0], door[1], 0.0), ob, out)
    sp = _turn(DOOR_X, FRONT_Y - 1.6)
    _empty("spawn_point", (sp[0], sp[1], 0.0), ob, out)
    for name, (x, y, z) in ANCHORS.items():
        t = _turn(x, y)
        _empty(name, (t[0], t[1], z), ob, out)
    for name, x0, x1, y0, y1, z1 in COLS:
        a = _turn(x0, y0)
        b = _turn(x1, y1)
        _col_box(name, min(a[0], b[0]), max(a[0], b[0]), min(a[1], b[1]), max(a[1], b[1]), z1, ob, out)
    return ob, t0, t1, swapped


def tavern_export(ob):
    keep = ob.location.copy()
    ob.location = (0, 0, 0)
    bpy.context.view_layer.update()
    _export([ob] + list(ob.children), A1_PATH)
    ob.location = keep
    return A1_PATH
