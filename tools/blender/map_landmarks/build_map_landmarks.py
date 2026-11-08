"""The world map's monuments and mission landmarks (Raphael 2026-11-08: "work on 3D models of world map monuments and
towns", then the mission landmarks), built from primitives in Blender 4.5, run headless; name the sets to build:

    "F:/Blender Foundation/Blender 4.5/blender.exe" --background --python tools/blender/map_landmarks/build_map_landmarks.py -- monuments missions

Writes (08_ASSET_PROMPT_PACK §5 D size spec and §6 rules: metres, origin bottom-centre on 0,0,0, +Y up on export, the
KayKit atlas by swatch, glowing parts their own emissive material at roughness 0, glTF Separate):
  monuments:
  assets/environment/custom/d20_prior_pillar.gltf     an old Prior pillar, its hourglass glowing teal (~1.3 m)
  assets/environment/custom/d21_standing_stones.gltf  a ring of seven stones round an altar with one teal rune
  assets/environment/custom/d8_hermit_tower.gltf      Den Fa's Hermit Tower (D8): stone, a blue roof, a teal lantern
  missions (08 §5 cards D2-D7; D2 after its picked concept, D3-D7 after the cards' words, no concepts yet):
  assets/environment/custom/d2_demon_crypt.gltf       a ruined black crypt, its open door and stairs glowing magenta
  assets/environment/custom/d3_dragon_lair.gltf       a rocky crag round a dark cave, a horned skull, a glint of gold
  assets/environment/custom/d4_bandit_hideout.gltf    a palisade, two tents, a campfire, a lookout, a torn red flag
  assets/environment/custom/d5_goblin_warren.gltf     a burrowed mound, stick-and-hide huts, a painted totem
  assets/environment/custom/d6_slime_bog.gltf         murky pools, reeds, dead trees, three glowing slimes (own objects)
  assets/environment/custom/d7_herb_glade.gltf        flowers, a mossy standing stone, a stream across a corner
plus preview renders on a KayKit hex in <art>/shots/map_landmarks/ and the working files <art>/blender/<set>.blend.
Front faces Blender -Y (Godot +Z, toward the map cameras).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

PROJECT = "F:/GAME I AM MAKING/shiningsun"
ART = "F:/GAME I AM MAKING/eternal_guild_art"
ATLAS = PROJECT + "/assets/environment/hexagons/base/hexagons_medieval.png"
HEX_REF = PROJECT + "/assets/environment/hexagons/base/hex_grass.gltf"
OUT = PROJECT + "/assets/environment/custom"
SHOTS = ART + "/shots/map_landmarks"
BLEND = ART + "/blender/map_landmarks.blend"

# 08 §6.3's swatch table (row, col of hexagons_medieval.png, 8 x 4 swatches), plus KayKit's team blue
SWATCH = {
    "charcoal": (0, 0), "bone_white": (0, 1), "stone_light": (0, 2), "stone_dark": (0, 3), "iron": (0, 4),
    "wood_light": (0, 5), "wood_dark": (0, 6), "ember": (0, 7), "water_light": (1, 0), "water_deep": (1, 1),
    "gold_straw": (1, 3), "grass": (1, 4), "sand_plaster": (1, 5), "stone_warm": (1, 6), "stone_brown": (1, 7),
    "moss": (2, 0), "prior_teal": (2, 1), "parchment": (2, 5), "roof_red": (3, 1), "candle_amber": (3, 2),
    "stone_beige": (3, 5), "stone_taupe": (3, 6), "wood_old": (3, 7), "kaykit_blue": (3, 0),
    "cloth_red": (3, 1), "demon_red": (2, 6),
}
EMISSIVE = {   # 08 §6.3's emissive colours
    "emissive_prior_teal": (0x3F / 255.0, 0xE0 / 255.0, 0xC8 / 255.0),
    "emissive_window": (1.0, 0xC2 / 255.0, 0x66 / 255.0),
    "emissive_demon": (0xE0 / 255.0, 0x30 / 255.0, 0x6A / 255.0),
    "emissive_embers": (1.0, 0x8A / 255.0, 0x2B / 255.0),
    "emissive_gold": (1.0, 0xD6 / 255.0, 0x5C / 255.0),
    "emissive_slime": (0x9B / 255.0, 0xE8 / 255.0, 0x4A / 255.0),
}
BEVEL = 0.012


# ── Scene ─────────────────────────────────────────────────────────────────────

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.unit_settings.system = "METRIC"
    s.unit_settings.scale_length = 1.0


def collection(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


# ── Parts: one primitive, one swatch ──────────────────────────────────────────

def _object(name, bm, swatch, coll, parent, bevel):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    ob["swatch"] = swatch
    coll.objects.link(ob)
    ob.parent = parent
    if bevel and not swatch.startswith("emissive_"):
        m = ob.modifiers.new("bevel", "BEVEL")
        m.width = BEVEL
        m.segments = 1
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(35)
    return ob


def cyl(name, swatch, coll, parent, r1, r2, z0, z1, sides=8, x=0.0, y=0.0, rot=0.0, bevel=True, jitter=0.0, seed=0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=sides, radius1=r1, radius2=max(r2, 0.0001),
                          depth=z1 - z0)
    if r2 <= 0.0:
        # a point: merge the top ring
        top = [v for v in bm.verts if v.co.z > 0.0]
        bmesh.ops.pointmerge(bm, verts=top, merge_co=Vector((0.0, 0.0, (z1 - z0) * 0.5)))
    if jitter > 0.0:
        rnd = random.Random(seed)
        for v in bm.verts:
            v.co.x += rnd.uniform(-jitter, jitter)
            v.co.y += rnd.uniform(-jitter, jitter)
    bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(rot, 3, "Z"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((x, y, (z0 + z1) * 0.5)))
    return _object(name, bm, swatch, coll, parent, bevel)


def box(name, swatch, coll, parent, sx, sy, sz, x=0.0, y=0.0, z0=0.0, rot=0.0, taper=1.0, tilt=(0.0, 0.0), bevel=True):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z = (v.co.z + 0.5) * sz
        if v.co.z > sz * 0.5 and taper != 1.0:
            v.co.x *= taper
            v.co.y *= taper
    m = Euler((tilt[0], tilt[1], rot), "XYZ").to_matrix()
    bmesh.ops.rotate(bm, verts=bm.verts, matrix=m)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((x, y, z0)))
    return _object(name, bm, swatch, coll, parent, bevel)


def prism(name, swatch, coll, parent, w, d, h, x=0.0, y=0.0, z0=0.0, rot=0.0, ridge_x=False, bevel=True):
    """A gable: a w (x) by d (y) base at z0, its ridge h above along y (along x with ridge_x)."""
    bm = bmesh.new()
    if ridge_x:
        pts = [(-w / 2, -d / 2, 0), (-w / 2, d / 2, 0), (-w / 2, 0, h), (w / 2, -d / 2, 0), (w / 2, d / 2, 0), (w / 2, 0, h)]
    else:
        pts = [(-w / 2, -d / 2, 0), (w / 2, -d / 2, 0), (0, -d / 2, h), (-w / 2, d / 2, 0), (w / 2, d / 2, 0), (0, d / 2, h)]
    v = [bm.verts.new(Vector(p)) for p in pts]
    for f in ((0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (0, 2, 5, 3)):
        bm.faces.new([v[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(rot, 3, "Z"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((x, y, z0)))
    return _object(name, bm, swatch, coll, parent, bevel)


def sphere(name, swatch, coll, parent, rad, x=0.0, y=0.0, z0=0.0, squash=1.0, segs=(8, 5)):
    """A low sphere sitting on z0, squashed in z."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs[0], v_segments=segs[1], radius=rad)
    for vt in bm.verts:
        vt.co.z *= squash
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((x, y, z0 + rad * squash)))
    return _object(name, bm, swatch, coll, parent, False)


def root(asset_id, coll):
    e = bpy.data.objects.new(asset_id, None)
    e.empty_display_type = "PLAIN_AXES"
    coll.objects.link(e)
    return e


# ── Materials and the atlas ───────────────────────────────────────────────────

def atlas_material():
    m = bpy.data.materials.get("kaykit_atlas_mat")
    if m:
        return m
    img = bpy.data.images.load(ATLAS, check_existing=True)
    img.name = "hexagons_medieval"
    m = bpy.data.materials.new("kaykit_atlas_mat")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 1.0
    return m


def emissive_material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    c = EMISSIVE[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*c, 1.0)
    bsdf.inputs["Emission Color"].default_value = (*c, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 2.0
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.0   # light, not ink: no outline on it
    return m


def remap(asset_root):
    """UV every part into its swatch (centre column; the middle 60% of the swatch by height over the whole asset,
    higher = lighter) and give it the atlas material, or its emissive one."""
    parts = [o for o in asset_root.children_recursive if o.type == "MESH"]
    zs = [(o.matrix_world @ v.co).z for o in parts for v in o.data.vertices]
    zmin, zmax = min(zs), max(zs)
    for o in parts:
        sw = o["swatch"]
        me = o.data
        if not me.uv_layers:
            me.uv_layers.new(name="UVMap")
        uv = me.uv_layers.active.data
        r, c = SWATCH.get(sw, (0, 2))
        for poly in me.polygons:
            for li in poly.loop_indices:
                z = (o.matrix_world @ me.vertices[me.loops[li].vertex_index].co).z
                t = (z - zmin) / max(zmax - zmin, 1e-4)
                uv[li].uv = ((c + 0.5) / 8.0, 1.0 - (r + 1) / 4.0 + 0.25 * (0.2 + 0.6 * t))
        me.materials.clear()
        me.materials.append(emissive_material(sw) if sw.startswith("emissive_") else atlas_material())


# ── The monuments ─────────────────────────────────────────────────────────────

def prior_pillar(coll):
    a = "d20_prior_pillar"
    r = root(a, coll)
    cyl("plinth_low", "stone_beige", coll, r, 0.34, 0.34, 0.0, 0.10, 8, rot=math.pi / 8)
    cyl("plinth_high", "stone_beige", coll, r, 0.27, 0.26, 0.10, 0.20, 8, rot=math.pi / 8)
    cyl("shaft_low", "stone_beige", coll, r, 0.15, 0.14, 0.20, 0.46, 6)
    cyl("ring_low", "stone_taupe", coll, r, 0.19, 0.19, 0.46, 0.50, 6)
    cyl("glass_low", "emissive_prior_teal", coll, r, 0.16, 0.035, 0.50, 0.66, 6, bevel=False)
    cyl("glass_high", "emissive_prior_teal", coll, r, 0.035, 0.16, 0.66, 0.82, 6, bevel=False)
    for k, ang in enumerate((90.0, 210.0, 330.0)):
        t = math.radians(ang)
        box("cage_%d" % k, "stone_beige", coll, r, 0.04, 0.04, 0.32, x=0.175 * math.cos(t), y=0.175 * math.sin(t),
            z0=0.50, rot=t, bevel=False)
    cyl("ring_high", "stone_taupe", coll, r, 0.19, 0.19, 0.82, 0.86, 6)
    cyl("shaft_high", "stone_beige", coll, r, 0.14, 0.12, 0.86, 1.10, 6)
    cyl("cap", "stone_beige", coll, r, 0.20, 0.16, 1.10, 1.20, 6)
    cyl("tip", "stone_taupe", coll, r, 0.10, 0.0, 1.20, 1.32, 6, bevel=False)
    for k, ang in enumerate((270.0, 30.0, 150.0)):   # runes on three shaft faces, the first facing the front (-Y)
        t = math.radians(ang)
        box("rune_%d" % k, "emissive_prior_teal", coll, r, 0.05, 0.012, 0.16, x=0.135 * math.cos(t),
            y=0.135 * math.sin(t), z0=0.25, rot=t + math.pi / 2, bevel=False)
    for k, (ang, s) in enumerate(((200.0, 0.09), (320.0, 0.07), (60.0, 0.06))):
        t = math.radians(ang)
        cyl("moss_%d" % k, "moss", coll, r, s, s * 0.4, 0.0, s * 0.7, 6, x=0.33 * math.cos(t), y=0.33 * math.sin(t),
            bevel=False)
    return r


def standing_stones(coll):
    a = "d21_standing_stones"
    r = root(a, coll)
    rnd = random.Random(21)
    heights = [0.62, 0.78, 0.55, 0.70, 0.0, 0.82, 0.58]
    swatches = ["stone_taupe", "stone_light", "stone_warm", "stone_taupe", "stone_light", "stone_warm", "stone_taupe"]
    for i in range(7):
        t = math.radians(i * 360.0 / 7.0 + 12.0)
        x, y = 0.62 * math.cos(t), 0.62 * math.sin(t)
        if heights[i] == 0.0:   # one stone has fallen outward
            box("stone_fallen", swatches[i], coll, r, 0.62, 0.17, 0.11, x=0.70 * math.cos(t), y=0.70 * math.sin(t),
                z0=0.0, rot=t, taper=0.85)
            continue
        lean = math.radians(rnd.uniform(3.0, 8.0))
        box("stone_%d" % i, swatches[i], coll, r, 0.17, 0.11, heights[i], x=x, y=y, z0=-0.02, rot=t + math.pi / 2,
            taper=0.72, tilt=(lean * math.cos(t + math.pi / 2), -lean * math.sin(t + math.pi / 2)))
        if i % 2 == 0:
            cyl("moss_%d" % i, "moss", coll, r, 0.07, 0.03, 0.0, 0.05, 6, x=x * 0.88, y=y * 0.88, bevel=False)
    box("altar_leg_a", "stone_dark", coll, r, 0.08, 0.20, 0.10, x=-0.12, y=0.0, z0=0.0)
    box("altar_leg_b", "stone_dark", coll, r, 0.08, 0.20, 0.10, x=0.12, y=0.0, z0=0.0)
    box("altar_top", "stone_warm", coll, r, 0.38, 0.25, 0.09, x=0.0, y=0.0, z0=0.10)
    box("altar_rune", "emissive_prior_teal", coll, r, 0.16, 0.045, 0.008, x=0.0, y=0.0, z0=0.19, bevel=False)
    return r


def hermit_tower(coll):
    a = "d8_hermit_tower"
    r = root(a, coll)
    cyl("rock", "stone_brown", coll, r, 0.50, 0.38, 0.0, 0.16, 7, jitter=0.04, seed=8)
    cyl("body", "stone_light", coll, r, 0.30, 0.26, 0.16, 1.40, 8, rot=math.pi / 8)
    cyl("band_low", "stone_dark", coll, r, 0.315, 0.31, 0.55, 0.60, 8, rot=math.pi / 8)
    cyl("band_high", "stone_dark", coll, r, 0.29, 0.29, 1.02, 1.07, 8, rot=math.pi / 8)
    box("step", "stone_warm", coll, r, 0.24, 0.10, 0.04, x=0.0, y=-0.36, z0=0.16)
    box("door", "wood_dark", coll, r, 0.16, 0.05, 0.30, x=0.0, y=-0.29, z0=0.18)
    box("window_front", "emissive_window", coll, r, 0.07, 0.03, 0.11, x=0.0, y=-0.27, z0=0.74, bevel=False)
    box("window_side", "emissive_window", coll, r, 0.03, 0.07, 0.11, x=0.27, y=0.0, z0=0.92, bevel=False)
    box("window_top", "emissive_window", coll, r, 0.07, 0.03, 0.10, x=0.0, y=-0.255, z0=1.16, bevel=False)
    cyl("gallery", "wood_dark", coll, r, 0.35, 0.35, 1.40, 1.45, 8, rot=math.pi / 8)
    for k in range(4):
        t = math.radians(45.0 + 90.0 * k)
        box("post_%d" % k, "wood_dark", coll, r, 0.04, 0.04, 0.23, x=0.21 * math.cos(t), y=0.21 * math.sin(t),
            z0=1.45, rot=t, bevel=False)
    cyl("lantern", "emissive_prior_teal", coll, r, 0.13, 0.12, 1.47, 1.66, 8, bevel=False)
    cyl("roof", "water_deep", coll, r, 0.34, 0.0, 1.68, 1.95, 8, rot=math.pi / 8, bevel=False)
    cyl("roof_rim", "wood_dark", coll, r, 0.25, 0.25, 1.66, 1.69, 8, rot=math.pi / 8, bevel=False)
    cyl("finial", "iron", coll, r, 0.025, 0.0, 1.95, 2.02, 6, bevel=False)
    return r


# ── The mission landmarks (08 §5, D2-D7) ──────────────────────────────────────

def demon_crypt(coll):
    """D2 (after its picked concept): a squat ruined crypt of black stone, a steep broken roof, buttresses, one jagged
    spire, a pointed doorway whose door hangs open on stairs glowing magenta; banners, candles, gravestones, a fence."""
    r = root("d2_demon_crypt", coll)
    box("plinth", "stone_dark", coll, r, 1.05, 1.0, 0.06, y=0.02)
    box("walls", "stone_dark", coll, r, 0.80, 0.72, 0.62, y=0.10, z0=0.06)
    prism("roof", "charcoal", coll, r, 0.98, 0.86, 0.60, y=0.10, z0=0.68)
    box("roof_break", "demon_red", coll, r, 0.16, 0.30, 0.03, x=-0.20, y=0.18, z0=0.92, tilt=(0.0, 0.7), bevel=False)
    for sx in (-1.0, 1.0):
        for k, yy in enumerate((-0.25, 0.46)):
            box("buttress_%d_%d" % (sx, k), "stone_dark", coll, r, 0.12, 0.14, 0.80, x=sx * 0.44, y=yy, z0=0.06, taper=0.6)
            cyl("spike_%d_%d" % (sx, k), "stone_dark", coll, r, 0.06, 0.0, 0.86, 1.02, 4, x=sx * 0.44, y=yy,
                rot=math.pi / 4, bevel=False)
    box("door_frame", "stone_light", coll, r, 0.40, 0.06, 0.48, y=-0.27, z0=0.06)
    prism("door_arch", "stone_light", coll, r, 0.40, 0.06, 0.16, y=-0.27, z0=0.54)
    box("door_dark", "charcoal", coll, r, 0.27, 0.07, 0.40, y=-0.275, z0=0.06, bevel=False)
    box("door_glow", "emissive_demon", coll, r, 0.21, 0.02, 0.30, y=-0.315, z0=0.07, bevel=False)
    for k in range(3):   # steps up to the door, lit from below
        box("step_%d" % k, "stone_dark", coll, r, 0.36 - 0.03 * k, 0.09, 0.06 * (k + 1), y=-0.50 + 0.07 * k, z0=0.0)
        box("step_glow_%d" % k, "emissive_demon", coll, r, 0.20, 0.06, 0.01, y=-0.50 + 0.07 * k, z0=0.06 * (k + 1),
            bevel=False)
    box("door_leaf", "wood_dark", coll, r, 0.16, 0.03, 0.40, x=0.24, y=-0.40, z0=0.06, rot=math.radians(55))
    box("spire_base", "stone_dark", coll, r, 0.18, 0.18, 0.30, x=-0.28, y=-0.16, z0=0.96)
    cyl("spire", "stone_dark", coll, r, 0.11, 0.0, 1.26, 1.98, 4, x=-0.28, y=-0.16, rot=math.pi / 4, bevel=False)
    for k, yy in enumerate((0.02, 0.32)):
        box("banner_%d" % k, "cloth_red", coll, r, 0.02, 0.13, 0.30, x=-0.415, y=yy, z0=0.30, bevel=False)
    for k, (cx, cy) in enumerate(((0.36, -0.42), (-0.36, -0.44))):
        box("candle_base_%d" % k, "stone_dark", coll, r, 0.14, 0.10, 0.05, x=cx, y=cy)
        for j, (dx, hh) in enumerate(((-0.03, 0.12), (0.03, 0.09))):
            cyl("candle_%d_%d" % (k, j), "bone_white", coll, r, 0.025, 0.025, 0.05, 0.05 + hh, 6, x=cx + dx, y=cy,
                bevel=False)
            cyl("flame_%d_%d" % (k, j), "emissive_embers", coll, r, 0.014, 0.0, 0.05 + hh, 0.09 + hh, 4, x=cx + dx,
                y=cy, bevel=False)
    for k, (gx, gy, rot, tilt) in enumerate(((0.58, 0.40, -0.3, 0.12), (-0.60, -0.10, 0.4, -0.15))):
        box("grave_%d" % k, "stone_light", coll, r, 0.18, 0.06, 0.26, x=gx, y=gy, rot=rot, taper=0.8, tilt=(tilt, 0.0))
    for k in range(6):   # the rusted fence along the back left
        fy = 0.62 - 0.14 * k
        box("fence_post_%d" % k, "iron", coll, r, 0.025, 0.025, 0.26, x=-0.62, y=fy, bevel=False)
        cyl("fence_tip_%d" % k, "iron", coll, r, 0.02, 0.0, 0.26, 0.31, 4, x=-0.62, y=fy, bevel=False)
    for k, z in enumerate((0.08, 0.20)):
        box("fence_rail_%d" % k, "iron", coll, r, 0.02, 0.72, 0.02, x=-0.62, y=0.27, z0=z, bevel=False)
    for k, (tx, ty) in enumerate(((0.62, -0.05), (0.05, -0.62), (-0.35, 0.62))):
        cyl("dead_grass_%d" % k, "stone_taupe", coll, r, 0.05, 0.0, 0.0, 0.09, 4, x=tx, y=ty, bevel=False)
    return r


def dragon_lair(coll):
    """D3: a steep faceted crag round a dark cave mouth, claw scars and scorch, a horned skull half-buried at the lip,
    bones, a glint of gold inside. About a KayKit mountain's size (1.8 x 1.9 m), under 1.8 m."""
    r = root("d3_dragon_lair", coll)
    cyl("crag_base", "stone_brown", coll, r, 0.86, 0.66, 0.0, 0.55, 7, y=0.12, jitter=0.07, seed=31)
    cyl("crag_mid", "stone_warm", coll, r, 0.60, 0.36, 0.55, 1.15, 7, x=0.05, y=0.18, jitter=0.06, seed=32, rot=0.3)
    cyl("crag_top", "stone_warm", coll, r, 0.34, 0.06, 1.15, 1.62, 6, x=0.10, y=0.22, jitter=0.05, seed=33, rot=0.6)
    cyl("boulder", "stone_brown", coll, r, 0.32, 0.18, 0.0, 0.42, 6, x=0.58, y=0.36, jitter=0.04, seed=34)
    box("cave_mouth", "charcoal", coll, r, 0.50, 0.24, 0.44, x=-0.06, y=-0.52, z0=0.0, taper=0.8, bevel=False)
    prism("cave_lip", "stone_brown", coll, r, 0.66, 0.30, 0.16, x=-0.06, y=-0.50, z0=0.44)
    for k in range(3):   # claw scars across the crag's face
        box("scar_%d" % k, "charcoal", coll, r, 0.03, 0.02, 0.34, x=0.30 + 0.07 * k, y=-0.44 + 0.02 * k, z0=0.60,
            tilt=(0.0, 0.35), bevel=False)
    for k, (sx, sz) in enumerate(((-0.40, 0.48), (0.22, 0.50))):
        box("scorch_%d" % k, "charcoal", coll, r, 0.22, 0.02, 0.08, x=sx, y=-0.62, z0=sz, rot=0.2 * (k * 2 - 1),
            bevel=False)
    for k, (gx, gz) in enumerate(((-0.14, 0.04), (-0.02, 0.06), (0.06, 0.03), (-0.08, 0.10))):
        box("gold_%d" % k, "emissive_gold", coll, r, 0.035, 0.035, 0.035, x=gx, y=-0.66, z0=gz, rot=0.6 * k, bevel=False)
    box("skull", "bone_white", coll, r, 0.24, 0.28, 0.14, x=0.34, y=-0.78, z0=0.0, rot=-0.4, taper=0.8)
    box("skull_snout", "bone_white", coll, r, 0.14, 0.14, 0.09, x=0.26, y=-0.92, z0=0.0, rot=-0.4)
    for k, sx in enumerate((-1.0, 1.0)):
        box("eye_%d" % k, "charcoal", coll, r, 0.04, 0.03, 0.03, x=0.34 + 0.07 * sx, y=-0.88 + 0.03 * sx, z0=0.07,
            rot=-0.4, bevel=False)
        cyl("horn_%d" % k, "bone_white", coll, r, 0.04, 0.0, 0.08, 0.34, 5, x=0.36 + 0.09 * sx, y=-0.70, bevel=False)
    for k, (bx, by, rot) in enumerate(((-0.42, -0.74, 0.6), (0.02, -0.86, -0.2), (0.58, -0.40, 1.2))):
        box("bone_%d" % k, "bone_white", coll, r, 0.20, 0.03, 0.03, x=bx, y=by, rot=rot, bevel=False)
    return r


def bandit_hideout(coll):
    """D4: a ring of sharpened logs with a gate gap toward the front, two patched tents, a campfire, a lookout on
    stilts, stolen crates and a barrel, a torn red flag."""
    r = root("d4_bandit_hideout", coll)
    rnd = random.Random(44)
    k = 0
    for deg in range(0, 360, 15):
        if abs(deg - 270) <= 22:   # the gate, facing the front
            continue
        t = math.radians(deg)
        h = rnd.uniform(0.30, 0.40)
        x, y = 0.80 * math.cos(t), 0.80 * math.sin(t)
        cyl("log_%d" % k, "wood_old", coll, r, 0.045, 0.045, 0.0, h, 6, x=x, y=y, bevel=False)
        cyl("log_tip_%d" % k, "wood_old", coll, r, 0.045, 0.0, h, h + 0.08, 6, x=x, y=y, bevel=False)
        k += 1
    prism("tent_a", "sand_plaster", coll, r, 0.40, 0.50, 0.34, x=-0.30, y=0.26, rot=math.radians(20))
    prism("tent_b", "parchment", coll, r, 0.36, 0.46, 0.30, x=0.34, y=0.30, rot=math.radians(-15))
    box("patch", "cloth_red", coll, r, 0.10, 0.02, 0.08, x=-0.36, y=0.03, z0=0.10, rot=math.radians(20), bevel=False)
    for j in range(6):
        t = math.radians(j * 60)
        cyl("fire_stone_%d" % j, "stone_light", coll, r, 0.035, 0.03, 0.0, 0.04, 5, x=0.12 * math.cos(t),
            y=-0.18 + 0.12 * math.sin(t), bevel=False)
    box("fire_log_a", "wood_dark", coll, r, 0.18, 0.04, 0.04, y=-0.18, rot=0.6, bevel=False)
    box("fire_log_b", "wood_dark", coll, r, 0.18, 0.04, 0.04, y=-0.18, rot=-0.6, bevel=False)
    cyl("flames", "emissive_embers", coll, r, 0.07, 0.0, 0.03, 0.20, 5, y=-0.18, bevel=False)
    for j, (px, py) in enumerate(((-0.56, -0.08), (-0.36, -0.08), (-0.56, -0.28), (-0.36, -0.28))):
        box("stilt_%d" % j, "wood_dark", coll, r, 0.035, 0.035, 0.72, x=px, y=py, bevel=False)
    box("platform", "wood_light", coll, r, 0.30, 0.30, 0.04, x=-0.46, y=-0.18, z0=0.72)
    prism("lookout_roof", "wood_old", coll, r, 0.32, 0.32, 0.14, x=-0.46, y=-0.18, z0=0.98)
    for j in range(2):
        box("roof_post_%d" % j, "wood_dark", coll, r, 0.03, 0.03, 0.22, x=-0.58 + 0.24 * j, y=-0.18, z0=0.76,
            bevel=False)
    box("crate_a", "wood_light", coll, r, 0.14, 0.14, 0.14, x=0.52, y=-0.12, rot=0.3)
    box("crate_b", "wood_light", coll, r, 0.11, 0.11, 0.11, x=0.56, y=-0.12, z0=0.14, rot=0.8)
    cyl("barrel", "wood_dark", coll, r, 0.07, 0.07, 0.0, 0.15, 8, x=0.40, y=-0.30)
    box("flag_pole", "wood_dark", coll, r, 0.025, 0.025, 0.72, x=0.10, y=0.55, bevel=False)
    box("flag", "cloth_red", coll, r, 0.22, 0.01, 0.13, x=0.21, y=0.55, z0=0.56, bevel=False)
    return r


def goblin_warren(coll):
    """D5: a grassy mound burrowed full of dark holes, two crude huts of sticks and hide on top, a painted grinning
    totem, junk piles. Mischievous, not horror."""
    r = root("d5_goblin_warren", coll)
    cyl("mound", "stone_brown", coll, r, 0.84, 0.50, 0.0, 0.30, 8, jitter=0.05, seed=51)   # dug earth
    cyl("mound_grass", "grass", coll, r, 0.50, 0.40, 0.30, 0.40, 8, jitter=0.03, seed=53)
    cyl("mound_top", "grass", coll, r, 0.40, 0.26, 0.40, 0.48, 8, jitter=0.03, seed=52)
    for k in range(5):   # holes on the slope, facing out
        t = math.radians(-60 + k * 52)
        box("hole_%d" % k, "charcoal", coll, r, 0.22, 0.07, 0.15, x=0.68 * math.cos(t), y=0.68 * math.sin(t), z0=0.03,
            rot=t + math.pi / 2, tilt=(math.radians(-35) * math.sin(t + math.pi / 2), math.radians(35) * math.cos(t + math.pi / 2)),
            bevel=False)
    for k, (hx, hy, hz, rr) in enumerate(((-0.14, 0.10, 0.47, 0.19), (0.20, -0.06, 0.46, 0.16))):
        cyl("hut_%d" % k, "wood_old", coll, r, rr, 0.0, hz, hz + rr * 1.9, 6, x=hx, y=hy, rot=0.3 * k, bevel=False)
        box("hide_%d" % k, "sand_plaster", coll, r, rr * 0.8, 0.02, rr * 0.7, x=hx + 0.02, y=hy - rr * 0.55, z0=hz + 0.05,
            bevel=False)
        box("hut_door_%d" % k, "charcoal", coll, r, rr * 0.45, 0.02, rr * 0.6, x=hx, y=hy - rr * 0.62, z0=hz,
            bevel=False)
    cyl("totem", "wood_dark", coll, r, 0.055, 0.05, 0.12, 0.78, 6, x=0.46, y=-0.40, bevel=False)
    box("totem_face", "cloth_red", coll, r, 0.10, 0.03, 0.12, x=0.46, y=-0.455, z0=0.56, bevel=False)
    box("totem_grin", "gold_straw", coll, r, 0.08, 0.035, 0.03, x=0.46, y=-0.46, z0=0.58, bevel=False)
    for k, sx in enumerate((-1.0, 1.0)):
        cyl("totem_horn_%d" % k, "bone_white", coll, r, 0.025, 0.0, 0.74, 0.86, 4, x=0.46 + 0.05 * sx, y=-0.40,
            bevel=False)
    for k, (jx, jy) in enumerate(((-0.58, -0.40), (0.62, 0.30), (-0.30, -0.66))):
        box("junk_a_%d" % k, "iron", coll, r, 0.09, 0.07, 0.05, x=jx, y=jy, rot=0.5 * k, bevel=False)
        box("junk_b_%d" % k, "wood_light", coll, r, 0.07, 0.05, 0.06, x=jx + 0.06, y=jy + 0.03, z0=0.03, rot=-0.4,
            bevel=False)
    return r


def slime_bog(coll):
    """D6: murky water pools in mud, clumps of reeds, two dead trees, three glossy slimes (separate objects slime_01..03
    so Godot can bounce them), a few bubbles."""
    r = root("d6_slime_bog", coll)
    pools = ((-0.22, 0.12, 0.40), (0.36, -0.26, 0.28), (0.24, 0.46, 0.22))
    for k, (px, py, pr) in enumerate(pools):
        cyl("mud_%d" % k, "stone_brown", coll, r, pr + 0.07, pr + 0.05, 0.0, 0.015, 8, x=px, y=py, jitter=0.03,
            seed=60 + k, bevel=False)
        cyl("pool_%d" % k, "moss", coll, r, pr, pr, 0.015, 0.03, 8, x=px, y=py, jitter=0.03, seed=70 + k, bevel=False)
    rnd = random.Random(66)
    k = 0
    for (cx, cy) in ((-0.62, 0.0), (0.05, -0.30), (0.60, 0.18), (-0.30, 0.60), (0.0, 0.30)):
        for j in range(4):
            cyl("reed_%d" % k, "grass", coll, r, 0.016, 0.0, 0.0, rnd.uniform(0.16, 0.28), 4,
                x=cx + rnd.uniform(-0.06, 0.06), y=cy + rnd.uniform(-0.06, 0.06), bevel=False)
            k += 1
    for t, (tx, ty) in enumerate(((-0.52, -0.42), (0.58, 0.52))):
        cyl("dead_trunk_%d" % t, "wood_old", coll, r, 0.05, 0.03, 0.0, 0.62, 6, x=tx, y=ty, bevel=False)
        for b, (ang, zz) in enumerate(((0.6, 0.40), (-0.7, 0.50), (2.2, 0.32))):
            box("dead_branch_%d_%d" % (t, b), "wood_old", coll, r, 0.20, 0.025, 0.025, x=tx + 0.08 * math.cos(ang),
                y=ty + 0.08 * math.sin(ang), z0=zz, rot=ang, tilt=(0.0, -0.5), bevel=False)
    for k, (sx, sy, rad) in enumerate(((-0.24, 0.10, 0.12), (0.36, -0.24, 0.09), (0.22, 0.46, 0.07))):
        sphere("slime_%02d" % (k + 1), "emissive_slime", coll, r, rad, x=sx, y=sy, z0=0.025, squash=0.72)
    for k, (bx, by) in enumerate(((-0.06, 0.24), (0.46, -0.16), (-0.36, -0.04))):
        sphere("bubble_%d" % k, "water_light", coll, r, 0.025, x=bx, y=by, z0=0.025, segs=(6, 4))
    return r


def herb_glade(coll):
    """D7: a peaceful meadow: clusters of pale blue and white flowers, one mossy standing stone, a small stream crossing
    a corner. Gentle and safe; cheap (≤ 1,200 tris)."""
    r = root("d7_herb_glade", coll)
    for k, (sx, sy, rot) in enumerate(((0.52, -0.62, 0.55), (0.70, -0.30, 1.05), (0.80, 0.05, 1.45))):
        box("stream_%d" % k, "water_light", coll, r, 0.40, 0.14, 0.02, x=sx, y=sy, rot=rot, bevel=False)
    box("stone", "stone_light", coll, r, 0.18, 0.12, 0.50, x=-0.20, y=0.26, taper=0.75, tilt=(0.06, -0.08))
    box("stone_moss", "moss", coll, r, 0.15, 0.10, 0.04, x=-0.22, y=0.26, z0=0.48, bevel=False)
    rnd = random.Random(77)
    k = 0
    for (cx, cy) in ((-0.50, -0.30), (0.05, -0.40), (0.20, 0.10), (-0.55, 0.30), (0.10, 0.55), (-0.15, -0.05)):
        for j in range(4):
            fx, fy = cx + rnd.uniform(-0.08, 0.08), cy + rnd.uniform(-0.08, 0.08)
            hh = rnd.uniform(0.06, 0.11)
            cyl("leaf_%d" % k, "grass", coll, r, 0.03, 0.0, 0.0, hh, 4, x=fx, y=fy, bevel=False)
            box("flower_%d" % k, "water_light" if j % 2 == 0 else "bone_white", coll, r, 0.035, 0.035, 0.03, x=fx, y=fy,
                z0=hh, rot=0.785, bevel=False)
            k += 1
    return r


# ── Export and preview ────────────────────────────────────────────────────────

def export(asset_root):
    bpy.ops.object.select_all(action="DESELECT")
    asset_root.select_set(True)
    for o in asset_root.children_recursive:
        o.select_set(True)
    bpy.context.view_layer.objects.active = asset_root
    path = "%s/%s.gltf" % (OUT, asset_root.name)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", use_selection=True, export_yup=True,
                              export_apply=True, export_materials="EXPORT", export_cameras=False,
                              export_lights=False, export_animations=False, export_image_format="AUTO")
    return path


def report(asset_root):
    dg = bpy.context.evaluated_depsgraph_get()
    tris = 0
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in asset_root.children_recursive:
        if o.type != "MESH":
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        for v in me.vertices:
            w = o.matrix_world @ v.co
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
        ev.to_mesh_clear()
    size = hi - lo
    print("[map_landmarks] %-22s tris %5d  size %.2f x %.2f x %.2f m  min z %.3f" % (
        asset_root.name, tris, size.x, size.y, size.z, lo.z))
    return tris, size


def preview(asset_roots, ref_coll):
    os.makedirs(SHOTS, exist_ok=True)
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_EEVEE_NEXT"
    scn.render.resolution_x = 720
    scn.render.resolution_y = 720
    scn.render.film_transparent = False
    world = bpy.data.worlds.new("preview") if not scn.world else scn.world
    scn.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.08, 0.07, 0.06, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = Euler((math.radians(50), 0.0, math.radians(30)), "XYZ")
    scn.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.9
    scn.collection.objects.link(cam)
    scn.camera = cam
    # the hall map's view: Godot (20, 50, 23) -> Blender (20, -23, 50), looking at the hex's middle
    d = Vector((20.0, -23.0, 50.0)).normalized()
    for ar in asset_roots:
        for other in asset_roots:
            hide = other is not ar
            other.hide_render = hide
            for o in other.children_recursive:
                o.hide_render = hide
        target = Vector((0.0, 0.0, 0.55))
        cam.location = target + d * 12.0
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = "%s/%s.png" % (SHOTS, ar.name)
        bpy.ops.render.render(write_still=True)
        print("[map_landmarks] preview", scn.render.filepath)


SETS = {
    "monuments": [prior_pillar, standing_stones, hermit_tower],
    "missions": [demon_crypt, dragon_lair, bandit_hideout, goblin_warren, slime_bog, herb_glade],
}


def build(set_name):
    reset()
    ref = collection("REF")
    bpy.ops.import_scene.gltf(filepath=HEX_REF)
    for o in list(bpy.context.selected_objects):
        for c in o.users_collection:
            c.objects.unlink(o)
        ref.objects.link(o)
    coll = collection(set_name.upper())
    roots = [fn(coll) for fn in SETS[set_name]]
    for ar in roots:
        remap(ar)
        report(ar)
    blend = "%s/blender/%s.blend" % (ART, "map_landmarks" if set_name == "monuments" else "mission_landmarks")
    os.makedirs(os.path.dirname(blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    for ar in roots:
        print("[map_landmarks] wrote", export(ar))
    preview(roots, ref)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for set_name in (args or list(SETS)):
        if set_name not in SETS:
            print("[map_landmarks] unknown set %r (sets: %s)" % (set_name, ", ".join(SETS)))
            continue
        build(set_name)


main()
