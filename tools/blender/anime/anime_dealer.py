# anime_dealer.py - route AN (Story 25.30, catalogue G13): the silver-elf Quest Dealer on the anime base.
#   open_base_as_dealer()  anime_base.blend saved as g13_quest_dealer_anime.blend (its own call: the context is stale
#                          right after a file load), Base_Body deleted by name
#   build()                her parts (the approved test's design, cleaned up), the palette atlas, one Dealer_Body
#                          (the atlas + the face: 2 surfaces), the Dealer_Quill prop on handslot.r, the merge report
# Her look (Raphael's silver-haired elf): long platinum hair with a centre-parted fringe showing the circlet's red gem,
# face-framing locks and back hair to the waist; long elf ears; big teal eyes (the face texture); a high-collared plum
# coat with gold trim, mantles, cuffs and belt; dark leggings; boots. Colours are demo-grade ("plum is okay").
# Fixes over the test: the skirt's back is fuller and a little higher and hips-dominant (seated, its hem hangs behind
# the stool instead of swinging through it); the thigh tops start inside the pelvis; the mantles blend chest to upper
# arm; the hands are built round the re-seated slot, reaching into the cuffs; denser skirt rings; leaner segment counts
# for the <= 10,000-triangle budget.
import math

import bmesh
import bpy
from mathutils import Vector

import anime_atlas as A
import anime_common as C
import anime_hair as HAIR
import anime_kit as K
import anime_merge as MG
import anime_retarget as RT

DEALER_BLEND = C.BLEND + "g13_quest_dealer_anime.blend"
FACE_PNG = C.ART + "textures/anime/g13_quest_dealer_face.png"
PALETTE_PNG = C.ART + "textures/anime/g13_quest_dealer_palette.png"
PALETTE = {"skin": "F7DECF", "hair": "D9DBE6", "coat": "6E3159", "dark": "3A1D33", "gold": "D6A94E", "gem": "C92A3E",
           "boots": "4D3427", "feather": "F2EEE2", "shaft": "A8A092", "nib": "2B1D1F"}
LOD = 0.75
QUILL_DIR = Vector((0.70, -0.30, 0.64))      # rest frame: up and back out of her writing fist (25.13's, measured in Write)


def open_base_as_dealer():
    bpy.ops.wm.open_mainfile(filepath=C.BASE_BLEND)
    arm = bpy.data.objects["Rig"]
    assert "anime_rig" in arm and any("anime_leg_ratio" in a for a in bpy.data.actions), "not a finished base"
    bpy.ops.wm.save_as_mainfile(filepath=DEALER_BLEND)
    return bpy.data.filepath


def _drop_base_body():
    K.remove(["Base_Body"])
    m = bpy.data.materials.get("AN_BaseSkin")
    if m and m.users == 0:
        bpy.data.materials.remove(m)


# ------------------------------------------------------------------ her own pieces (heights through K.Z)

def build_ears(name, mat):
    hc = K.HC()
    bm = bmesh.new()
    for sx in (1, -1):
        base = hc + Vector((0.212 * sx, 0.025, -0.025))
        d = Vector((0.86 * sx, 0.24, 0.45)).normalized()
        n = 9
        pts = [base + d * (0.26 * i / (n - 1)) for i in range(n)]
        radii = [0.058 * (1 - i / (n - 1)) ** 0.85 + 0.002 for i in range(n)]
        K.strand(bm, pts, radii, sides=8, flat=0.28, up_of=lambda p: Vector((0, 0.25, 1)), pole_tip=True)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.head_w)
    return ob


def build_circlet(name, gem_name, mat):
    Z = K.Z
    bm = bmesh.new()
    pts = []
    for i in range(36):
        th = 2 * math.pi * i / 36
        z = Z(1.884) + 0.075 * (1 - math.cos(th)) / 2
        x, y = K.head_radius_at(th, z, grow=0.010)
        pts.append(Vector((x, y, z)))
    K.loop_tube(bm, pts, 0.0065, sides=4)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.head_w)
    bm = bmesh.new()
    gy = K.head_radius_at(0.0, Z(1.874), grow=0.0)[1]
    K.ellipsoid(bm, Vector((0, gy - 0.014, Z(1.874))), 0.020, 0.012, 0.026, 10, 6)
    gem = K.new_obj(gem_name, bm, mat)
    K.skin(gem, K.head_w)
    return ob, gem


def build_collar(name, trim_name, mat):
    Z = K.Z
    bm = bmesh.new()
    K.lathe(bm, [(0.060, Z(1.425)), (0.068, Z(1.47)), (0.077, Z(1.52)), (0.084, Z(1.556))], segs=20, sy=0.9)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.neck_w)
    bm = bmesh.new()
    K.loop_tube(bm, [Vector((0.085 * math.sin(a), -0.085 * 0.9 * math.cos(a), Z(1.556))) for a in [2 * math.pi * i / 20 for i in range(20)]], 0.008, sides=4)
    ob2 = K.new_obj(trim_name, bm, mat)
    K.skin(ob2, K.neck_w)
    return ob, ob2


def build_trims(name, mat):
    Z, tr = K.Z, K.torso_r
    bm = bmesh.new()
    zs = [1.43 - 0.03 * i for i in range(14)]
    front = [Vector((0, -K.TORSO_SY * tr(z) - 0.006 - (0.02 if 1.22 < z < 1.29 else 0.0), Z(z))) for z in zs]
    K.strand(bm, front, [0.010] * len(front), sides=4, flat=0.5, up_of=lambda p: Vector((0, -1, 0)))
    for zb in (1.33, 1.18):
        K.ellipsoid(bm, Vector((0, -K.TORSO_SY * tr(zb) - 0.018, Z(zb))), 0.02, 0.012, 0.016, 8, 5)
    belt = [Vector((0.126 * math.sin(a), -0.126 * K.TORSO_SY * math.cos(a), Z(1.06))) for a in [2 * math.pi * i / 24 for i in range(24)]]
    K.loop_tube(bm, belt, 0.013, sides=4)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.torso_w)
    return ob


SKIRT = [(0.123, 1.07), (0.138, 1.00), (0.185, 0.88), (0.232, 0.76), (0.262, 0.66)]


def _skirt_shape(v, top_z, hem_z):
    """The back half fuller (depth x1.35 at the hem) and higher (+0.08 at the hem: a coat cut longer in front), so the
    seated back hem stays within 0.048 m of the stool's seat top (the hips-rigid back sinks with the hips)."""
    h = K.clamp01((top_z - v.z) / (top_z - hem_z))
    if v.y < 0:
        v.y *= 1.0 + 0.13 * h                           # a little ease in front for the thighs' stride (T5)
    if v.y > 0:
        k = min(1.0, v.y / 0.12)
        v.y *= 1.0 + 0.35 * h * k
        v.z += 0.08 * h * k


def skirt_w_fn(top_z, hem_z):
    def fn(co):
        h = K.clamp01((top_z - co.z) / (top_z - hem_z))
        s = K.clamp01(0.5 + co.x / 0.26)
        front = K.clamp01(0.5 - co.y / 0.2)               # the back stays with the hips (seated: behind the stool)
        wl = 0.9 * h ** 0.35 * (0.1 + 0.9 * front)          # h^0.35: the front follows the thighs higher up (T5)
        return {"hips": 1 - wl, "upperleg.l": wl * s, "upperleg.r": wl * (1 - s)}
    return fn


def build_skirt(name, trim_name, mat):
    Z = K.Z
    prof = []
    for (r0, z0), (r1, z1) in zip(SKIRT[:-1], SKIRT[1:]):
        for t in (0.0, 1 / 3, 2 / 3):                    # denser rings: the hem deforms over the thighs
            prof.append((r0 + (r1 - r0) * t, Z(z0 + (z1 - z0) * t)))
    prof.append((SKIRT[-1][0], Z(SKIRT[-1][1])))
    top_z, hem_z = prof[0][1], prof[-1][1]
    bm = bmesh.new()
    K.lathe(bm, prof, segs=24, sy=0.84)
    for v in bm.verts:
        _skirt_shape(v.co, top_z, hem_z)
    ob = K.new_obj(name, bm, mat)
    wfn = skirt_w_fn(top_z, hem_z)
    K.skin(ob, wfn)
    bm = bmesh.new()
    hem = []
    for a in [2 * math.pi * i / 28 for i in range(28)]:
        p = Vector((0.266 * math.sin(a), -0.266 * 0.84 * math.cos(a), hem_z + 0.002))
        _skirt_shape(p, top_z, hem_z)
        hem.append(p)
    K.loop_tube(bm, hem, 0.012, sides=4)
    ob2 = K.new_obj(trim_name, bm, mat)
    K.skin(ob2, wfn)
    return ob, ob2


def build_mantle(name, trim_name, mat, s):
    sx = 1 if s == "l" else -1
    Z = K.Z
    bm = bmesh.new()
    K.lathe(bm, [(0.0, 0.085), (0.05, 0.08), (0.085, 0.058), (0.102, 0.025), (0.108, 0.0)], segs=16)
    R = Vector((0, 0, 1)).rotation_difference(Vector((0.62 * sx, 0, 0.78)).normalized()).to_matrix()
    c = Vector((0.205 * sx, 0.0, Z(1.345)))
    for v in bm.verts:
        v.co = R @ v.co + c
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.shoulder_w(s))
    bm = bmesh.new()
    rim = [R @ Vector((0.108 * math.cos(2 * math.pi * k / 16), 0.108 * math.sin(2 * math.pi * k / 16), 0.0)) + c for k in range(16)]
    K.loop_tube(bm, rim, 0.008, sides=4)
    ob2 = K.new_obj(trim_name, bm, mat)
    K.skin(ob2, K.shoulder_w(s))
    return ob, ob2


def build_cuff(name, mat, s):
    sh, el, wr = K.arm_pts(s)
    d = (wr - el).normalized()
    u, w = K.ring_frame(d, Vector((0, 0, 1)))
    bm = bmesh.new()
    K.loop_tube(bm, [wr + d * 0.012 + (u * math.cos(2 * math.pi * k / 12) + w * math.sin(2 * math.pi * k / 12)) * 0.043 for k in range(12)], 0.009, sides=4)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.chain(["upperarm." + s, "lowerarm." + s, "wrist." + s, "hand." + s]))
    return ob


def build_quill(name, mat):
    """A feather quill on her right hand slot (bone-parented: glTF puts it under the joint, Godot makes it a
    BoneAttachment3D), rising up and back out of her fist while she writes."""
    bm = bmesh.new()
    K.strand(bm, [Vector((0, 0, -0.06)), Vector((0, 0, 0.26))], [0.011, 0.011], sides=5)
    vane = [(0.05, 0.0), (0.10, 0.020), (0.18, 0.026), (0.24, 0.016), (0.28, 0.0)]   # slim: a wider vane read as a blob at zoom 8
    for sx in (1, -1):
        prev = None
        for z, w in vane:
            a = bm.verts.new((0.0, 0.004 * sx, z))
            b = bm.verts.new((w * sx, 0.004 * sx, z + 0.02))
            if prev:
                bm.faces.new((prev[0], a, b, prev[1]) if sx > 0 else (prev[0], prev[1], b, a))
            prev = (a, b)
    arm = C.rig()
    grip = arm.matrix_world @ arm.data.bones["handslot.r"].head_local
    R = Vector((0, 0, 1)).rotation_difference(QUILL_DIR.normalized()).to_matrix()
    for v in bm.verts:
        v.co = R @ v.co + grip
    ob = K.new_obj(name, bm, mat)
    mw = ob.matrix_world.copy()
    ob.parent = arm
    ob.parent_type = "BONE"
    ob.parent_bone = "handslot.r"
    ob.matrix_world = mw
    return ob


def build():
    assert bpy.data.filepath.endswith("g13_quest_dealer_anime.blend"), "open_base_as_dealer() first"
    RT.rest_pose()             # build in the REST pose: a bone-parented prop placed on a posed bone keeps the pose's offset
    _drop_base_body()
    K.setup()
    old = [o.name for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(("AN_", "Dealer_"))]
    K.remove(old)
    face = K.mat("AN_Dealer_Face", PALETTE["skin"], FACE_PNG)
    next(n for n in face.node_tree.nodes if n.type == "TEX_IMAGE").image.name = "dealer_face"   # -> <glb>_dealer_face.png in Godot
    pal, cells = A.build("dealer_palette", PALETTE_PNG, PALETTE)
    q = lambda n: max(4, int(round(n * LOD)))
    parts = {}

    def add(ob, key):
        parts[ob.name] = key
        return ob

    head = add(K.build_head("AN_Head", face, face_uv=True, useg=32, vseg=22), None)
    add(build_ears("AN_Ears", pal), "skin")
    add(K.build_neck("AN_Neck", pal), "skin")
    col, colt = build_collar("AN_Collar", "AN_CollarTrim", pal)
    add(col, "coat")
    add(colt, "gold")
    add(K.build_torso("AN_Torso", pal, bust=0.022), "coat")
    add(build_trims("AN_Trim", pal), "gold")
    add(K.build_pelvis("AN_Pelvis", pal), "dark")
    sk, skt = build_skirt("AN_Skirt", "AN_SkirtTrim", pal)
    add(sk, "coat")
    add(skt, "gold")
    for s in ("l", "r"):
        add(K.build_arm("AN_Sleeve_" + s, pal, s, sides=10, rings=10), "coat")
        add(build_cuff("AN_Cuff_" + s, pal, s), "gold")
        add(K.build_hand("AN_Hand_" + s, pal, s, lod=0.8), "skin")
        mt, mtt = build_mantle("AN_Mantle_" + s, "AN_MantleTrim_" + s, pal, s)
        add(mt, "coat")
        add(mtt, "gold")
        add(K.build_leg("AN_Leg_" + s, pal, s, sides=10, rings=12), "dark")
        add(K.build_foot("AN_Boot_" + s, pal, s, boot_top=0.08, sides=10), "boots")
    circ, gem = build_circlet("AN_Circlet", "AN_Gem", pal)
    add(circ, "gold")
    add(gem, "gem")
    for ob in HAIR.build_all("AN_", pal, lod=LOD):
        add(ob, "hair")
    for n, key in parts.items():
        if key:
            A.paint_part(bpy.data.objects[n], pal, cells[key])
    quill = build_quill("Dealer_Quill", pal)
    # the quill: its shaft and nib in the shaft cell, its vane (the flat faces) in the feather cell
    lay = quill.data.uv_layers[0]
    for poly in quill.data.polygons:
        key = "feather" if poly.index >= 7 else "shaft"     # the strand's 5 sides and 2 caps first, then the vane
        for li in poly.loop_indices:
            lay.data[li].uv = cells[key]
    body = MG.join("Dealer_Body", [bpy.data.objects[n] for n in parts])
    ok, stats = MG.check(body, props=[quill])
    return ok, stats
