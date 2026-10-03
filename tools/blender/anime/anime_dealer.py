# anime_dealer.py - route AN (Story 25.30, catalogue G13): the silver-elf Quest Dealer on the anime base. Since 25.31
# one config (`config()`: her files, palette, body, props, clips, clearance-check keys and desk geometry) drives the
# generic kit; DEALER is the shipped files, SCRATCH the regression rebuild's (25.31 V3: it never writes a shipped file).
#   open_base_as_dealer(cfg)  anime_base.blend saved as cfg's .blend (C.open_base_as: the stamp checks; its own call:
#                             the context is stale right after a file load). Base_Body stays in the file until build()
#   build(cfg)                Base_Body deleted by name; her parts (anime_kit body parts + anime_garments, her values),
#                             the palette atlas, one Dealer_Body (the atlas + the face: 2 surfaces), the Dealer_Quill prop
#                             on handslot.r, the merge report
#   build_clips(cfg)          her own clips (Walk_Bar, Write, Brief) through anime_anims
# Her look (Raphael's silver-haired elf): long platinum hair with a centre-parted fringe showing the circlet's red gem,
# face-framing locks and back hair to the waist; long elf ears; big teal eyes (the face texture); a high-collared plum
# coat with gold trim, mantles, cuffs and belt; dark leggings; boots. Colours are demo-grade ("plum is okay").
# Fixes over the test: the skirt's back is fuller and a little higher and hips-dominant (seated, its hem hangs behind
# the stool instead of swinging through it); the thigh tops start inside the pelvis; the mantles blend chest to upper
# arm; the hands are built round the re-seated slot, reaching into the cuffs; denser skirt rings; leaner segment counts
# for the <= 10,000-triangle budget.
#
# Her seat (Story 25.30, T5): hip_back 0.397 = KayKit's own seated hips offset, so her hips sit over the stool's centre
# (the WorkPoint) and her root 0.397 m in front of it. The desk slab's back edge is then 0.093 m BEHIND her root (the
# WorkPoint is 0.304 m behind it), its top 0.85 up; the open ledger's near edge (desk-local z -0.14, pages at x -0.33 /
# -0.11: to her right) is 0.64 - hip_back ahead of the root, its top 0.88.
import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import anime_anims as AN
import anime_atlas as A
import anime_common as C
import anime_garments as G
import anime_hair as HAIR
import anime_kit as K
import anime_merge as MG
import anime_retarget as RT

PALETTE_MAT = "dealer_palette"               # the atlas material and image (anime_clearcheck finds her flat parts by it)
PALETTE = {"skin": "F7DECF", "hair": "D9DBE6", "coat": "6E3159", "dark": "3A1D33", "gold": "D6A94E", "gem": "C92A3E",
           "boots": "4D3427", "feather": "F2EEE2", "shaft": "A8A092", "nib": "2B1D1F"}
LOD = 0.75
QUILL_DIR = Vector((0.70, -0.30, 0.64))      # rest frame: up and back out of her writing fist (25.13's, measured in Write)
QUILL_SHAFT_FACES = 7                        # the shaft strand's 5 sides + 2 caps: build() splits the UVs at this index
QUILL_VANE_FACES = 8                         # 2 sides x 4 vane quads
HIP_BACK = 0.397

# the guild desk and her stool (Godot tavern coordinates; the 25.30 geometry table): anime_clearcheck's desk_report
DESK_GEOMETRY = {"desk": np.array([11.600, 0.100, -4.300]), "work_point": np.array([11.600, 0.540, -5.080]), "slab_back": -4.776,
                 "stool_box": (np.array([11.397, 0.094, -5.302]), np.array([11.803, 0.540, -4.905])),
                 "stool_centre": np.array([11.600, 0.540, -5.1035]), "approach": np.array([11.0, 0.100, -5.50])}


def config(blend=C.BLEND + "g13_quest_dealer_anime.blend", face_png=C.TEXTURES + "g13_quest_dealer_face.png",
           palette_png=C.TEXTURES + "g13_quest_dealer_palette.png"):
    """The dealer's config. Only the paths vary (the shipped files, or a scratch rebuild's)."""
    return {"role": "dealer", "blend": blend, "face_png": face_png, "palette_png": palette_png,
            "palette_mat": PALETTE_MAT, "palette": PALETTE, "body": "Dealer_Body", "props": ["Dealer_Quill"],
            # anime_clearcheck: which palette keys are which, its Z bands (test heights) and clip lists
            "check": {"keys": {"hair": "hair", "legs": "dark", "skirt": "coat", "skin": "skin", "cuff": "gold"},
                      "skirt_below": 0.70, "thigh_band": (0.66, 0.95), "thigh_pad": 0.02,
                      "hair_clips": ("Idle", "Walking_A", "Walk_Bar", "Interact", "Write", "Brief"),
                      "thigh_clips": ("Idle", "Walking_A", "Walk_Bar", "Sit_Chair_Down", "Sit_Chair_Idle"),
                      "cuff_clips": ("Idle", "Walking_A", "Walk_Bar", "Interact", "Write", "Brief", "Sit_Chair_Down",
                                     "Sit_Chair_Idle", "Sit_Chair_StandUp"),
                      "cuff": {"r": 0.043, "tube": 0.009, "offset": 0.012},     # anime_garments.build_cuff's
                      "seat_keys": ("skin", "dark"),                            # refit_sit's seat: never the coat's hem
                      "walk_clip": "Walk_Bar", "hall_clip": "Walking_A", "seated_clips": ("Sit_Chair_Idle", "Write", "Brief"),
                      "geometry": DESK_GEOMETRY, "hip_back": HIP_BACK}}


DEALER = config()
SCRATCH = config(blend=C.BLEND + "scratch_2531_dealer.blend", face_png=C.SCRATCH_TEXTURES + "g13_quest_dealer_face.png",
                 palette_png=C.SCRATCH_TEXTURES + "g13_quest_dealer_palette.png")


def open_base_as_dealer(cfg=DEALER, overwrite_ok=False):
    return C.open_base_as(cfg["blend"], overwrite_ok=overwrite_ok)


def _drop_base_body():
    K.remove(["Base_Body"])
    m = bpy.data.materials.get("AN_BaseSkin")
    if m and m.users == 0:
        bpy.data.materials.remove(m)


def build_quill(name, mat):
    """A feather quill on her right hand slot (bone-parented: glTF puts it under the joint, Godot makes it a
    BoneAttachment3D), rising up and back out of her fist while she writes."""
    bm = bmesh.new()
    K.strand(bm, [Vector((0, 0, -0.06)), Vector((0, 0, 0.26))], [0.011, 0.011], sides=5)
    n_shaft = len(bm.faces)
    assert n_shaft == QUILL_SHAFT_FACES, "the shaft has %d faces, not %d: anime_kit.strand changed (fix build()'s UV split)" % (n_shaft, QUILL_SHAFT_FACES)
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


def build(cfg=DEALER):
    assert C.is_open(cfg["blend"]), "open_base_as_dealer(cfg) first (this file is %r, the config's %r)" % (bpy.data.filepath, cfg["blend"])
    RT.rest_pose()             # build in the REST pose: a bone-parented prop placed on a posed bone keeps the pose's offset
    _drop_base_body()
    K.setup()
    old = [o.name for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(("AN_", "Dealer_"))]
    K.remove(old)
    face = K.mat("AN_Dealer_Face", PALETTE["skin"], cfg["face_png"])
    # the datablock's name only: Godot names an extracted image after its PNG file, <glb>_<png> =
    # g13_quest_dealer_anime_g13_quest_dealer_face.png (and ..._palette.png)
    next(n for n in face.node_tree.nodes if n.type == "TEX_IMAGE").image.name = "dealer_face"
    pal, cells = A.build(cfg["palette_mat"], cfg["palette_png"], cfg["palette"])
    parts = {}

    def add(ob, key):
        parts[ob.name] = key
        return ob

    add(K.build_head("AN_Head", face, face_uv=True, useg=32, vseg=22), None)
    add(G.build_ears("AN_Ears", pal), "skin")
    add(K.build_neck("AN_Neck", pal), "skin")
    col, colt = G.build_collar("AN_Collar", "AN_CollarTrim", pal)
    add(col, "coat")
    add(colt, "gold")
    add(K.build_torso("AN_Torso", pal, bust=0.022), "coat")
    add(G.build_trims("AN_Trim", pal), "gold")
    add(K.build_pelvis("AN_Pelvis", pal), "dark")
    sk, skt = G.build_skirt("AN_Skirt", "AN_SkirtTrim", pal)
    add(sk, "coat")
    add(skt, "gold")
    for s in ("l", "r"):
        add(K.build_arm("AN_Sleeve_" + s, pal, s, sides=10, rings=10), "coat")
        add(G.build_cuff("AN_Cuff_" + s, pal, s), "gold")
        add(K.build_hand("AN_Hand_" + s, pal, s, lod=0.8), "skin")
        mt, mtt = G.build_mantle("AN_Mantle_" + s, "AN_MantleTrim_" + s, pal, s)
        add(mt, "coat")
        add(mtt, "gold")
        add(K.build_leg("AN_Leg_" + s, pal, s, sides=10, rings=12), "dark")
        add(K.build_foot("AN_Boot_" + s, pal, s, boot_top=0.08, sides=10), "boots")
    circ, gem = G.build_circlet("AN_Circlet", "AN_Gem", pal)
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
    n_quill = QUILL_SHAFT_FACES + QUILL_VANE_FACES
    assert len(quill.data.polygons) == n_quill, "the quill has %d faces, not %d: fix the UV split below" % (len(quill.data.polygons), n_quill)
    for poly in quill.data.polygons:
        key = "feather" if poly.index >= QUILL_SHAFT_FACES else "shaft"     # the strand's 5 sides and 2 caps first, then the vane
        for li in poly.loop_indices:
            lay.data[li].uv = cells[key]
    body = MG.join(cfg["body"], [bpy.data.objects[n] for n in parts])
    C.drop_cached_clouds()
    ok, stats = MG.check(body, props=[quill])
    return ok, stats


# ------------------------------------------------------------------ her clips (the 25.13 method, anime_anims)

def ledger(hip_back=HIP_BACK):
    return Vector((-0.12, -(0.64 - hip_back + 0.04), 0.92))


def pose_write(t, length=AN.SIT_IDLE_S, hip_back=HIP_BACK):
    """Seated: the quill hand makes small strokes on the ledger's near page, lifting to pause once a loop; the left
    hand rests on the desk; head down."""
    AN.base_pose("Sit_Chair_Idle", t)
    AN.lean(26.0, bone="chest")
    k = t / length
    pause = max(0.0, 1 - abs(k - 0.8) / 0.1)
    AN.turn_head(pitch=14.0 - 12.0 * pause)
    stroke = Vector((0.03 * math.sin(2 * math.pi * 6 * k), 0.012 * math.sin(2 * math.pi * 12 * k), 0.0)) * (1 - pause)
    quill = ledger(hip_back) + stroke + Vector((0.0, 0.03, 0.09)) * pause
    AN.arm_to("r", quill, Vector((-0.6, 0.3, 0.5)))
    AN.arm_to("l", Vector((0.12, -(0.64 - hip_back), 0.93)), Vector((0.7, 0.3, 0.6)))      # resting, clear of the slab edge


def pose_brief(t, length=AN.SIT_IDLE_S, hip_back=HIP_BACK):
    """Seated, head up toward the customer side; both hands gesture above the desk top; one 'counting on fingers'
    beat ('I'll need three days')."""
    AN.base_pose("Sit_Chair_Idle", t)
    k = t / length
    AN.turn_head(pitch=-4.0, yaw=6.0 * math.sin(2 * math.pi * k))
    dy = hip_back - 0.32                                     # 25.13's targets, moved back with her deeper seat
    open_r = Vector((-0.20, -0.20 + dy, 1.08 + 0.05 * math.sin(2 * math.pi * 2 * k)))
    open_l = Vector((0.20, -0.18 + dy, 1.06 + 0.04 * math.sin(2 * math.pi * 2 * k + 1.3)))
    count = max(0.0, 1 - abs(k - 0.5) / 0.18)
    AN.arm_to("r", open_r.lerp(Vector((-0.06, -0.24 + dy, 1.16)), count), Vector((-0.6, 0.3, 1.0)))
    AN.arm_to("l", open_l.lerp(Vector((0.06, -0.22 + dy, 1.12)), count), Vector((0.6, 0.3, 1.0)))


# Walk_Bar: elbows OUT to the sides (25.30 T5: pointing back, they went into her back hair)
CLIPS = [("Walk_Bar", AN.WALKING_A_S, AN.walk_bar(hand=(0.12, -0.26, 1.00), pole=(0.55, 0.05, 1.10)), True),
         ("Write", AN.SIT_IDLE_S, pose_write, True), ("Brief", AN.SIT_IDLE_S, pose_brief, True)]


def build_clips(cfg=DEALER, names=None):
    assert C.is_open(cfg["blend"]), "build_clips: open the dealer's file (%r) first" % cfg["blend"]
    return AN.build_clips(CLIPS, names)


def write_reach(hip_back=HIP_BACK):
    """The quill hand's (handslot.r) worst distance to the ledger target over Write."""
    arm = C.rig()
    act = bpy.data.actions["Write"]
    worst = 0.0
    for f in C.frames(act):
        m = C.fk(arm, C.Curves(act), f, ["handslot.r"])
        k = f / (AN.SIT_IDLE_S * AN.FPS)
        pause = max(0.0, 1 - abs(k - 0.8) / 0.1)
        if pause == 0.0:
            worst = max(worst, (m["handslot.r"].translation - ledger(hip_back)).length)
    return worst
