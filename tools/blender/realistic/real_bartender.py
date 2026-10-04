# real_bartender.py - the Bartender on route RL (catalogue G12): the realistic spike's build (2026-10-04, commit 5ae8dc0)
# promoted in Story 25.31 S1 to the shipped g12_bartender_real.glb (staff.json barkeep.model_path; CFG below).
# Raphael's chosen concept (realistic_test/ref_bartender_concept.png): a heavy-set, bald, weathered barkeep, ~1.86 m;
# a full grey beard; a wine-red shirt with rolled sleeves and a laced collar; a long dark leather apron (bib, neck
# strap, chest pocket, mid-shin, frayed hem) tied at the back; a belt with an off-white cloth at his left hip (the
# sheet's front and side views both put it there); dark trousers; worn boots with turned-down cuffs.
# One call per step (README's runner, plus tools/blender/realistic on sys.path):
#   open_base_as_bartender()   realistic_base.blend saved as g12_bartender_real.blend (a file load: own call)
#   build()                    his parts (real_body) on the REAL-1 rig, joined into Bartender_Body (2 surfaces: the head
#                              projection + the body atlas), the cloth props on hips / handslot.r, the merge report
#   paint_head()               the painted head pass (real_bake; overwrite_ok=True to re-bake the shipped PNG)
#   build_clips()              Idle and Walking_A with his arms re-posed (the KayKit chibi arms stand 45 degrees out),
#                              his five bar clips Walk_Bar, Wipe, Serve, Pour, Restock (the 25.13 method, his reach);
#                              speeds() (anime_clearcheck), real_bar.report for the bar clearances
#   export()                   Rig + body + props to assets/characters/custom/g12_bartender_real.glb (refuses the
#                              existing GLB unless overwrite_ok=True)
#   turnaround(out_dir)        front / side / back renders (EEVEE, a toon ramp and an ink hull: the game's look); the
#                              file is reverted after (the render setup is never saved)
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

import anime_anims as AN
import anime_common as C
import anime_kit as K
import anime_merge as MG
import anime_retarget as RT
import real_body as RB
import real_chain as RC
import real_layout as L

ART = C.ART
# The production Bartender (25.31 S1): REAL-1's finished base saved as his own file, his GLB under a new name (N5).
# The spike's files (realistic_bartender_test.blend, custom/tests/g12_bartender_realtest.glb, commit 5ae8dc0) stay.
CFG = {
    "role": "bartender",
    "blend": C.BLEND + "g12_bartender_real.blend",
    "head_png": ART + "textures/realistic/g12_bartender_real_head.png",          # the projection's source crops
    "head_paint_png": ART + "textures/realistic/g12_bartender_real_headpaint.png",   # the painted pass (shipped)
    "body_png": ART + "textures/realistic/g12_bartender_real_body.png",
    "glb": "F:/GAME I AM MAKING/shiningsun/assets/characters/custom/g12_bartender_real.glb",
    "body": "Bartender_Body",
    "props": ["Bartender_ClothHand", "Bartender_ClothBelt"],
}
PICK = ART + "picked/C_G12_bartender.png"      # Raphael's pick (= the spike's ref_bartender_concept.png, re-encoded)
SHEET = L.make_sheet(PICK, L.BARTENDER["height"], L.BARTENDER["views"], L.BARTENDER["head_crops"])
TRI_BUDGET = 10000
HAND_SCALE = 1.06           # build_hand_real is a man's full-size hand; his are big working hands (the concept)
# the apron's folds (real_body.apron_folds): two ripples and three deep troughs, front-left, centre-right and the side
APRON_FOLDS = {"ripples": [(0.011, 5.0, 0.6), (0.007, 11.0, 1.9)], "power": 0.75,
               "troughs": [(-38.0, 0.008, 7.0), (14.0, 0.007, 6.0), (72.0, 0.006, 8.0)], "ease": 0.025}
# how the hem follows the thighs (real_body.skirt_w): the spike's 0.85 / 0.55 kicked it forward like a board (0.18 m up
# in Walk_Bar); less and his thighs show through it mid-stride (scratch apron_poke: legs in front of the apron)
APRON_LEGS, APRON_FOLLOW = 0.75, 0.35


def open_base_as_bartender(overwrite_ok=False):
    return RC.open_base_as(CFG["blend"], overwrite_ok=overwrite_ok)


def _materials():
    head = K.mat("RT_Bartender_Head", "C4A084", CFG["head_png"])
    body = K.mat("RT_Bartender_Body", "6A4A3A", CFG["body_png"])
    for m, name in ((head, "bartender_head"), (body, "bartender_body")):
        im = next(n for n in m.node_tree.nodes if n.type == "TEX_IMAGE").image
        im.name = name
        im.reload()                                           # a repainted PNG (the datablock keeps the old pixels)
    return head, body


def _prop(name, bm, mat, bone):
    ob = K.new_obj(name, bm, mat)
    arm = C.rig()
    mw = ob.matrix_world.copy()
    ob.parent = arm
    ob.parent_type = "BONE"
    ob.parent_bone = bone
    ob.matrix_world = mw
    return ob


def build_cloth_belt(mat):
    """The off-white cloth tucked under the belt at his left hip, folded over it, hanging to mid-thigh."""
    bm = bmesh.new()
    cols, rows = 6, 6
    grid = []
    for j in range(rows + 1):
        z = 1.060 - (1.060 - 0.810) * j / rows
        t = j / rows
        row = []
        for i in range(cols + 1):
            th = math.radians(52 + 34 * i / cols)                    # round the hip, front-left
            w, yf, yb = RB.apron_ring(min(z, 1.03))
            # pleats (25.31 S1): alternate columns stand out, deeper toward the hem; the cloth gathers under the belt
            pleat = (0.004 + 0.012 * t) * (1.0 if i % 2 else -0.6)
            g = 0.030 + pleat
            x = (w + g) * RB.se(math.sin(th), 2.2)
            y = (yf + yb) / 2 - ((yb - yf) / 2 + g) * RB.se(math.cos(th), 2.2)
            sway = 0.010 * math.sin(i * 1.3 + j * 0.8) + 0.004 * j
            hem = (0.014 if i in (1, 4) else 0.004 * (i % 2)) if j == rows else 0.0
            row.append(Vector((x + sway * 0.5, y - sway, z - hem)))
        grid.append(row)
    params = RB.grid_slab(bm, grid, 0.006, lambda p: Vector((-p.x, -p.y, 0)).normalized())
    # the fold over the belt: a short lip at the top, in front of the belt
    lip = []
    for j in range(3):
        z = 1.060 - 0.022 * j
        row = []
        for i in range(cols + 1):
            th = math.radians(52 + 34 * i / cols)
            w, yf, yb = RB.apron_ring(1.03)
            g = 0.046 + 0.004 * j
            row.append(Vector(((w + g) * RB.se(math.sin(th), 2.2), (yf + yb) / 2 - ((yb - yf) / 2 + g) * RB.se(math.cos(th), 2.2), z)))
        lip.append(row)
    p2 = RB.grid_slab(bm, lip, 0.005, lambda p: Vector((-p.x, -p.y, 0)).normalized())
    params.update({v: (u, 0.9 + 0.1 * v_) for v, (u, v_) in p2.items()})
    RB.param_uvs(bm, params, "cloth")
    return _prop("Bartender_ClothBelt", bm, mat, "hips")


def build_cloth_hand(mat):
    """A wad of cloth under his right palm (shown while he wipes)."""
    arm = C.rig()
    slot = arm.matrix_world @ arm.data.bones["handslot.r"].head_local
    bm = bmesh.new()
    params = {}
    c = slot + Vector((0.0, 0.0, -0.016))
    for v in K.ellipsoid(bm, Vector((0, 0, 0)), 1.0, 1.0, 1.0, 10, 6):
        q = v.co.copy()
        lump = 1.0 + 0.18 * math.sin(q.x * 7 + q.y * 5) + 0.10 * math.cos(q.y * 9)
        v.co = c + Vector((q.x * 0.062 * lump, q.y * 0.052 * lump, q.z * 0.016 * lump))
        params[v] = (0.5 + 0.45 * q.x, 0.5 + 0.45 * q.y)
    tail = [c + Vector((-0.040, -0.020, -0.004)), c + Vector((-0.070, -0.035, -0.010)), c + Vector((-0.090, -0.040, -0.016))]
    pp, _ = RB.tube(bm, tail, [(0.006, 0.020), (0.005, 0.018), (0.004, 0.014)], 4, up=lambda p, d: Vector((0, 0, 1)))
    params.update(pp)
    RB.param_uvs(bm, params, "cloth")
    return _prop("Bartender_ClothHand", bm, mat, "handslot.r")


def build():
    assert C.is_open(CFG["blend"]), "open_base_as_bartender() first (%r)" % bpy.data.filepath
    # a turnaround() re-wires the materials for its render and is reverted, never saved: refuse a polluted file
    assert "RT_ink" not in bpy.data.materials and "RT_sun" not in bpy.data.objects, "turnaround state in the file: revert it"
    RT.rest_pose()
    K.remove(["Base_Body"])
    m = bpy.data.materials.get("AN_BaseSkin")
    if m and m.users == 0:
        bpy.data.materials.remove(m)
    K.setup()
    old = [o.name for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(("RB_", "RT_", "Bartender_"))]
    K.remove(old)
    head, body = _materials()
    parts = [RB.build_head("RT_Head", head, sheet=SHEET), RB.build_beard("RT_Beard", head, sheet=SHEET),
             RB.build_ears("RT_Ears", head, sheet=SHEET), RB.build_neck("RT_Neck", head, sheet=SHEET),
             RB.build_torso("RT_Shirt", body), RB.build_collar("RT_Collar", body),
             RB.build_pelvis("RT_Seat", body), RB.build_apron_skirt("RT_Apron", body, cols=24, folds=APRON_FOLDS,
                                                                       legs=APRON_LEGS, front_follow=APRON_FOLLOW),
             RB.build_bib("RT_Bib", body), RB.build_pocket("RT_Pocket", body), RB.build_straps("RT_Strap", body),
             RB.build_ties("RT_Ties", body), RB.build_belt("RT_Belt", body)]
    for s in ("l", "r"):
        parts += [RB.build_sleeve("RT_Sleeve_" + s, body, s), RB.build_roll("RT_Roll_" + s, body, s),
                  RB.build_forearm("RT_Forearm_" + s, body, s), RB.build_hand_real("RT_Hand_" + s, body, s, scale=HAND_SCALE),
                  RB.build_trouser_leg("RT_Leg_" + s, body, s), RB.build_boot("RT_Boot_" + s, body, s)]
    counts = {p.name: sum(len(f.vertices) - 2 for f in p.data.polygons) for p in parts}
    props = [build_cloth_hand(body), build_cloth_belt(body)]
    out = MG.join(CFG["body"], parts)
    C.drop_cached_clouds()
    ok, stats = MG.check(out, props=props, tri_budget=TRI_BUDGET)
    print("parts (tris):", sorted(counts.items(), key=lambda kv: -kv[1]))
    return ok, stats


def paint_head(overwrite_ok=False):
    """After build() (own call): the painted head pass (real_bake): the three views blended by the normal into the
    head's own unwrap, so no seam where the front view hands over to the side (the first portrait showed a jagged beard
    edge and a second brow line there)."""
    import real_bake as BK
    out = BK.bake_head(CFG["body"], "RT_Bartender_Head", SHEET, CFG["head_paint_png"], overwrite_ok=overwrite_ok)
    ok, stats = MG.check(bpy.data.objects[CFG["body"]], props=[bpy.data.objects[n] for n in CFG["props"]], tri_budget=TRI_BUDGET)
    return ok, stats, out


# ------------------------------------------------------------------ his clips (the 25.13 method on his reach)

IDLE_HAND = (0.390, -0.030, 0.875)      # the concept's hands: ~0.43 out from his midline at his hips, arms ~20 deg out
IDLE_POLE = (0.75, 0.45, 1.20)          # elbows back and out
STAND = 0.65                             # how much of KayKit Idle's crouch is taken out of his knees (0: all of it kept)
STANCE_DEG = 4.0                         # the concept's A-stance: each leg out this much (feet ~0.16 m off the midline)


# The retargeted Idle and Walking_A are kept as SRC_* copies (not on an NLA track: not exported) the first time
# build_clips runs, and every pose here reads them: the step is repeatable (a rebuild never compounds the stride).
SRC = {"Idle": "SRC_Idle", "Walking_A": "SRC_Walking_A"}


def ensure_sources():
    for name, src in SRC.items():
        if src not in bpy.data.actions:
            a = bpy.data.actions[name]
            assert "anime_leg_ratio" in a, "%s is not the retargeted clip any more: rebuild the file from the base" % name
            c = a.copy()
            c.name = src
            c.use_fake_user = True


def stand_tall():
    """KayKit's chibi Idle stands with bent knees: straighten his legs toward the rest pose (STAND), open the stance
    (STANCE_DEG), then put the soles back on the floor (the hips move down/up, never the feet)."""
    arm = C.rig()
    for b in AN.LEG_BONES:
        pb = arm.pose.bones[b]
        pb.rotation_quaternion = pb.rotation_quaternion.slerp(Quaternion((1.0, 0.0, 0.0, 0.0)), STAND)
    RT._upd()
    for s, sg in (("l", -1.0), ("r", 1.0)):
        RT.rotate_about("upperleg." + s, Matrix.Rotation(math.radians(STANCE_DEG * sg), 3, "Y"))
        RT.rotate_about("foot." + s, Matrix.Rotation(math.radians(-STANCE_DEG * sg), 3, "Y"))     # soles flat again
    _ground()


def _ground():
    pts = _soles()
    low = min((RT.pm(b) @ p).z for s in ("l", "r") for b, p in pts[s])
    RT.set_pm("hips", Matrix.Translation(Vector((0.0, 0.0, SOLE_Z - low))) @ RT.pm("hips"))


def palm_to(side, want):
    """Twist the forearm about its own axis (the elbow and the wrist stay where the IK put them) so the palm faces
    `want` as closely as it can: the two-bone IK only places the slot, and left KayKit's wrist roll (palms up on the
    counter, 2026-10-04's first in-game shot)."""
    arm = C.rig()
    hb = arm.data.bones["hand." + side]
    n_local = hb.matrix_local.to_3x3().inverted() @ Vector((0.0, 0.0, -1.0))      # rest (T-pose): palms down
    el = RT.pm("lowerarm." + side).translation
    wr = RT.pm("wrist." + side).translation
    ax = (wr - el).normalized()
    cur = RT.pm("hand." + side).to_3x3() @ n_local
    want = Vector(want).normalized()
    a = cur - ax * cur.dot(ax)
    b = want - ax * want.dot(ax)
    if a.length < 1e-4 or b.length < 1e-4:
        return 0.0
    a.normalize()
    b.normalize()
    ang = math.atan2(ax.dot(a.cross(b)), a.dot(b))
    RT.rotate_about("lowerarm." + side, Matrix.Rotation(ang, 3, ax), pivot=el)
    return math.degrees(ang)


def hand_level(side):
    """Pitch the hand at the wrist so its length lies flat (the hand otherwise continues the forearm's slope, and on
    the counter his fingertips went 2 cm into it)."""
    arm = C.rig()
    hb = arm.data.bones["hand." + side]
    m = RT.pm("hand." + side)
    h = m.to_3x3() @ Vector((0.0, 1.0, 0.0))                  # a bone's length runs along its local Y
    flat = Vector((h.x, h.y, 0.0))
    if flat.length < 1e-4:
        return
    RT.rotate_about("wrist." + side, h.rotation_difference(flat.normalized()).to_matrix(), pivot=RT.pm("wrist." + side).translation)


def reach(side, target, pole, palm, level=False):
    """Two-bone IK to the slot target, the palm turned to `palm` (and the hand levelled); the twist and the wrist move
    the slot (it sits off the forearm's axis), so IK and the hand alternate a few rounds."""
    for _ in range(4):
        AN.arm_to(side, target, pole)
        palm_to(side, palm)
        if level:
            hand_level(side)


def pose_idle(t):
    AN.base_pose(SRC["Idle"], t)
    stand_tall()
    for s, sx in (("l", 1), ("r", -1)):
        reach(s, AN.in_frame_of("chest", (IDLE_HAND[0] * sx, IDLE_HAND[1], IDLE_HAND[2])),
              AN.in_frame_of("chest", (IDLE_POLE[0] * sx, IDLE_POLE[1], IDLE_POLE[2])), (-sx, 0.15, 0.0))   # palms to his thighs


WALK_STRIDE = 0.55          # Walking_A's leg swing kept (toward Idle): KayKit's knee lift is a chibi's (the spike's 0.74
                            # lifted his thigh near level, through the apron); 1.03 m/s on his legs, a heavy man's amble
BAR_STRIDE = 0.45           # Walk_Bar's (25.13's shuffle)


def short_walk(t, stride):
    """The retargeted Walking_A at time t with its legs' swing and the hips' bob blended toward Idle by `stride`."""
    AN.base_pose(SRC["Idle"], t)
    arm = C.rig()
    idle = {b: arm.pose.bones[b].rotation_quaternion.copy() for b in AN.LEG_BONES}
    idle_h = arm.pose.bones["hips"].location.copy()
    AN.base_pose(SRC["Walking_A"], t)
    for b in AN.LEG_BONES:
        pb = arm.pose.bones[b]
        pb.rotation_quaternion = idle[b].slerp(pb.rotation_quaternion, stride)
    hb = arm.pose.bones["hips"]
    hb.location = idle_h.lerp(hb.location, stride)
    RT._upd()
    # the blend moves the soles off the floor (the planted foot sank 3-5 cm): put the lowest sole point back on it
    _ground()


SOLE_Z = 0.004              # the boots' rest sole height (real_body.build_boot clamps the sole there)
_SOLES = {}


def _soles():
    if "pts" not in _SOLES:
        _SOLES["pts"] = C.sole_points(C.rig(), [bpy.data.objects[CFG["body"]]])
    return _SOLES["pts"]


def pose_walk_bar(t, hand=(0.17, -0.315, 1.00), pole=(0.45, 0.30, 1.15), swing=0.02):
    """Walk_Bar (25.13): the shuffle, both hands held in front of his belly, elbows back, riding the chest's bob."""
    short_walk(t, BAR_STRIDE)
    sw = swing * math.sin(2 * math.pi * t / AN.WALKING_A_S)
    for s, sx in (("l", 1), ("r", -1)):
        reach(s, AN.in_frame_of("chest", (hand[0] * sx, hand[1], hand[2] + sw * sx)),
              AN.in_frame_of("chest", (pole[0] * sx, pole[1], pole[2])), (-0.6 * sx, 0.8, -0.2))      # resting on his belly


def pose_walk(t):
    """Walking_A with a heavier man's shorter stride (its legs' swing and the hips' bob blended toward Idle, as
    walk_bar does); his arms swing from the shoulders opposite the legs, close to his sides."""
    short_walk(t, WALK_STRIDE)
    fl, fr = RT.pm("foot.l").translation, RT.pm("foot.r").translation
    lead = fl.y - fr.y                                    # < 0: the left foot ahead
    for s, sx, sw in (("l", 1, -lead), ("r", -1, lead)):          # each arm back while its own foot is ahead
        hand = (0.375 * sx, -0.03 + 0.42 * sw, 0.94 + 0.10 * abs(sw))
        reach(s, AN.in_frame_of("chest", hand), AN.in_frame_of("chest", (0.70 * sx, 0.55, 1.20)), (-sx, 0.15, 0.0))


# ---- the work clips at the bar (25.31 S1). The serve stand moved toward the counter: the spike wiped from 25.13's
# r 1.76 (the counter's inner face 0.59 m ahead), leaning 18 degrees to reach a top a real barman stands at. SERVE_R is
# his body block's serve_r (staff.json, measured by real_bar.report): his belly ~0.29 m ahead in Idle, the counter
# face (r 2.35, top 1.12) EDGE ahead. Every target below is in his rest frame (front -Y, his left +X, up Z).
COUNTER_FACE, COUNTER_TOP = 2.35, 1.12
SERVE_R = 1.92
EDGE = COUNTER_FACE - SERVE_R            # 0.43: the counter's inner face ahead of his root at a serve stand
RESTOCK_R = 1.98                          # the restock station (25.13's; his Walk_Bar front 0.43 keeps him off the kegs)
TAP = (-0.255, -(RESTOCK_R - 1.47), 0.30)  # the right tap ahead of him at the restock station (taps r 1.47, y 0.30)
TANKARD_SCALE = 1.1                       # his body block's tankard_scale: the H1 tankard drawn x 1.1 (true size 0.19 m)
TANKARD_BELOW, TANKARD_ABOVE, TANKARD_R = 0.085, 0.105, 0.056     # the H1 tankard about its grip (true size)

WIPE_LEAN = 10.0
WIPE_R, WIPE_Z = 0.035, 1.19           # the palm and the cloth on the top (1.168: 1.7 cm into it)
WIPE_C = (-0.12, -(EDGE + 0.12))           # the cloth's circle on the counter top, 0.09-0.16 m past its edge


def pose_wipe(t, period=2 * AN.IDLE_S):
    """At a serve stand, facing the counter (its face EDGE ahead, top 1.12 up): he leans in a little, the right hand
    circles the cloth on the top, the left hand rests on its edge; a look down."""
    AN.base_pose(SRC["Idle"], t)
    stand_tall()
    AN.lean(WIPE_LEAN)
    AN.turn_head(pitch=14.0)
    a = 2 * math.pi * t / period
    right = Vector((WIPE_C[0] + WIPE_R * math.cos(a), WIPE_C[1] + WIPE_R * math.sin(a), WIPE_Z))
    reach("r", right, Vector((-0.75, 0.10, 1.30)), (0.0, 0.0, -1.0), level=True)          # flat on the counter, on the cloth
    reach("l", Vector((0.25, -(EDGE + 0.04), WIPE_Z)), Vector((0.75, 0.10, 1.30)), (0.0, 0.0, -1.0), level=True)


def _sm(x):
    return 0.5 * (1 - math.cos(math.pi * min(1.0, max(0.0, x))))


def squat_planted(drop):
    """anime_anims.squat with the feet locked: the leg IK places each foot's joint but turns the foot with the shin
    (the toes went 0.15 m into the floor at Pour's depth), so each foot gets its pre-squat world rotation back."""
    keep = {s: RT.pm("foot." + s).copy() for s in ("l", "r")}
    AN.squat(drop)
    for s in ("l", "r"):
        now = RT.pm("foot." + s)
        RT.set_pm("foot." + s, Matrix.Translation(now.translation) @ keep[s].to_3x3().to_4x4())


SERVE_S = 1.2
SERVE_GRIP_DOWN = COUNTER_TOP + TANKARD_BELOW * TANKARD_SCALE + 0.004     # the tankard's base on the counter top


def serve_target(k):
    """The right slot's path through Serve (k 0..1): from his belly up (the tankard's base clears the top), over the
    counter, down onto it (the release at k 0.6), back. Also the test of where the tankard is (counter_report)."""
    start = Vector((-0.17, -0.30, 1.00))
    up = Vector((-0.15, -0.36, COUNTER_TOP + 0.20))
    over = Vector((-0.10, -(EDGE + 0.18), COUNTER_TOP + 0.20))
    down = Vector((-0.10, -(EDGE + 0.18), SERVE_GRIP_DOWN))
    if k < 0.25:
        return start.lerp(up, _sm(k / 0.25))
    if k < 0.5:
        return up.lerp(over, _sm((k - 0.25) / 0.25))
    if k < 0.6:
        return over.lerp(down, _sm((k - 0.5) / 0.1))
    if k < 0.75:
        return down.lerp(over, _sm((k - 0.6) / 0.15))
    if k < 0.88:                                               # back over the edge before dropping (no diagonal through it)
        return over.lerp(up, _sm((k - 0.75) / 0.13))
    return up.lerp(start, _sm((k - 0.88) / 0.12))


def pose_serve(t, length=SERVE_S):
    """At a serve stand: the tankard lifted from his belly, over the counter and set down on its top ~0.18 m past the
    edge (released at k 0.6, SERVE_RELEASE_AT), then the hand back; the left hand on the counter's edge."""
    AN.base_pose(SRC["Idle"], t)
    stand_tall()
    k = t / length
    put = _sm(k / 0.5) * (1 - _sm((k - 0.7) / 0.3))
    AN.lean(6.0 * put)
    AN.turn_head(pitch=8.0 * put)
    reach("r", serve_target(k), Vector((-0.75, 0.15, 1.10)), (0.85, 0.0, -0.5))     # the grip: palm in, round the handle
    reach("l", Vector((0.25, -(EDGE + 0.04), WIPE_Z)), Vector((0.75, 0.10, 1.30)), (0.0, 0.0, -1.0), level=True)


POUR_S = 2.0
POUR_DROP, POUR_LEAN = 0.46, 24.0     # the taps are 0.30 up: a deep squat (0.34 / 16 left the hand 0.12 short)
POUR_GRIP = Vector((TAP[0] + 0.03, TAP[1] + 0.10, 0.40))     # the tankard in front of the tap, its base ~0.30 up
POUR_HANDLE = Vector((0.10, -(RESTOCK_R - 1.49) + 0.03, 0.57))  # the left hand steadying on the keg's top (y 0.49)


def pose_pour(t, length=POUR_S):
    """At the restock station, facing the island (the taps 0.51 m ahead, 0.30 up): a deep squat with a lean, the
    tankard held in front of the right tap, the left hand steadying on the keg's top; hold; rise."""
    AN.base_pose(SRC["Idle"], t)
    stand_tall()
    k = t / length
    s = _sm(k / 0.3) * (1 - _sm((k - 0.7) / 0.3))
    squat_planted(POUR_DROP * s)
    AN.lean(POUR_LEAN * s)
    AN.turn_head(pitch=18.0 * s)
    stand_r = Vector((-0.17, -0.34, 1.00))
    stand_l = Vector((0.17, -0.34, 1.00))
    reach("r", stand_r.lerp(POUR_GRIP, s), Vector((-0.70, 0.10, 0.80 - 0.3 * s)), (0.85, 0.0, -0.5))
    reach("l", stand_l.lerp(POUR_HANDLE, s), Vector((0.70, 0.10, 0.80 - 0.3 * s)), (0.0, 0.3, -1.0))


RESTOCK_S = 3.2
RESTOCK_SQUAT, RESTOCK_LEAN = 0.26, 44.0   # the shelf is 0.77 m off past the kegs: 0.16 / 34 fell 0.11 short
SHELF = Vector((0.0, -(RESTOCK_R - 1.165 - 0.11), 0.70))     # the middle tier (r <= 1.165, y 0.6-0.9): the slot 11 cm
                                                               # short, so the fingers (and the bottle) meet its face
KEG = Vector((0.0, -(RESTOCK_R - 1.49 - 0.02), 0.62))         # over the kegs' tops (r <= 1.49, y <= 0.49)


def pose_restock(t, length=RESTOCK_S):
    """At the restock station: down to the keg tops for a bottle, then up and over them to set it on the shelf's middle
    tier, a small nod, and back (a loop). The reach to the shelf takes a lean and a slight squat (the kegs keep him
    0.49 m off)."""
    AN.base_pose(SRC["Idle"], t)
    stand_tall()
    k = t / length
    phase = 0.5 * (1 - math.cos(2 * math.pi * k))            # 0 at the shelf, 1 down at the keg tops
    squat_planted(RESTOCK_SQUAT + 0.06 * phase)
    AN.lean(RESTOCK_LEAN - 6.0 * phase)
    AN.turn_head(pitch=4.0 + 14.0 * phase)
    for s, sx in (("l", 1), ("r", -1)):
        tgt = (SHELF + Vector((0.09 * sx, 0, 0))).lerp(KEG + Vector((0.13 * sx, 0, 0)), phase)
        reach(s, tgt, Vector((0.65 * sx, 0.10, 0.55)), (0.0, 0.2, -1.0))


CLIPS = [("Idle", AN.IDLE_S, pose_idle, True), ("Walking_A", AN.WALKING_A_S, pose_walk, True),
         ("Walk_Bar", AN.WALKING_A_S, pose_walk_bar, True),
         ("Wipe", 2 * AN.IDLE_S, pose_wipe, True), ("Serve", SERVE_S, pose_serve, False),
         ("Pour", POUR_S, pose_pour, False), ("Restock", RESTOCK_S, pose_restock, True)]


def build_clips(names=None):
    assert C.is_open(CFG["blend"])
    ensure_sources()
    order = ["Walk_Bar", "Wipe", "Serve", "Pour", "Restock", "Idle", "Walking_A"]
    clips = sorted([c for c in CLIPS if not names or c[0] in names], key=lambda c: order.index(c[0]))
    out = AN.build_clips(clips)
    for a in bpy.data.actions:
        if a.name in [c[0] for c in clips]:
            a.use_fake_user = True
    print("clips", out)
    return out


def speeds():
    import anime_clearcheck as CC
    cfg = {"body": CFG["body"], "props": CFG["props"]}
    out = {c: round(CC.ground_speed(c, cfg), 3) for c in ("Walking_A", "Walk_Bar")}
    CC._rest()
    print("ground speeds (m/s):", out)
    return out


def grounded(clips=("Idle", "Walking_A", "Walk_Bar", "Wipe")):
    """Per clip: the lowest sole point per frame (min, max over the clip: ~0 means a foot is always planted, no float
    or sink) - the foot report's measure on his own body."""
    arm = C.rig()
    body = bpy.data.objects[CFG["body"]]
    pts = C.sole_points(arm, [body])
    fb = sorted({b for s in ("l", "r") for b, _ in pts[s]})
    out = {}
    for c in clips:
        act = bpy.data.actions[c]
        low = [C.lowest_foot(C.fk(arm, C.Curves(act), f, fb), pts) for f in C.frames(act)]
        out[c] = (round(min(low), 4), round(max(low), 4))
    print("lowest sole per frame (min, max):", out)
    return out


def counter_report(clip="Wipe"):
    """How deep anything of his (props included) goes below the counter top (1.12) beyond its inner edge (EDGE ahead
    of a serve stand: 0.43; the spike stood at r 1.76 with the edge 0.55 ahead),
    over the clip: the hands and the cloth must ride ON the top."""
    import anime_clearcheck as CC
    import numpy as np
    cfg = {"body": CFG["body"], "props": CFG["props"]}
    worst = 0.0
    for f in CC.frames_of(clip, 2):
        p = CC.cloud(clip, f, with_props=True, cfg=cfg)
        q = p[(p[:, 2] > EDGE) & (p[:, 1] < COUNTER_TOP)]
        if len(q):
            worst = max(worst, COUNTER_TOP - float(np.min(q[:, 1])))
    CC._rest()
    print("%s: deepest point under the counter top beyond its edge: %.3f m" % (clip, worst))
    return worst


def wipe_reach():
    """The right slot's distance to its circle target, worst over Wipe (two-bone IK stops short when out of reach)."""
    arm = C.rig()
    act = bpy.data.actions["Wipe"]
    worst = 0.0
    for f in C.frames(act):
        m = C.fk(arm, C.Curves(act), f, ["handslot.r", "handslot.l"])
        a = 2 * math.pi * (f / AN.FPS) / (2 * AN.IDLE_S)
        tgt = Vector((WIPE_C[0] + WIPE_R * math.cos(a), WIPE_C[1] + WIPE_R * math.sin(a), WIPE_Z))
        worst = max(worst, (m["handslot.r"].translation - tgt).length)
    print("Wipe: right slot worst miss %.3f m" % worst)
    return worst


# ------------------------------------------------------------------ export

def export(overwrite_ok=False):
    """Rig + body + props to CFG["glb"] (real_chain.export_glb: refuses the existing shipped GLB unless overwrite_ok).
    The SRC_* copies are the clip builder's sources, not his clips: the exporter writes every action on the armature,
    so they are dropped for the export only and the file is reverted in a finally (it is saved with them)."""
    assert C.is_open(CFG["blend"])
    assert "RT_ink" not in bpy.data.materials and "RT_sun" not in bpy.data.objects, "turnaround state in the file: revert it"
    RT.rest_pose()
    objs = [C.rig(), bpy.data.objects[CFG["body"]]] + [bpy.data.objects[n] for n in CFG["props"]]
    return RC.export_glb(CFG["glb"], objs, drop_actions=list(SRC.values()), overwrite_ok=overwrite_ok)


# ------------------------------------------------------------------ turnaround renders (EEVEE toon + ink hull)

def _toonify(mat, steps=(0.42,), shadow=0.52):
    """The body's material re-wired for the render only: diffuse -> Shader to RGB -> a two-tone ramp x the texture."""
    nt = mat.node_tree
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].color = (shadow, shadow * 0.93, shadow * 0.98, 1)
    ramp.color_ramp.elements[1].position = steps[0]
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    mul = nt.nodes.new("ShaderNodeMixRGB")
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    emi = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(dif.outputs[0], s2r.inputs[0])
    nt.links.new(s2r.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], mul.inputs[1])
    nt.links.new(tex.outputs[0], mul.inputs[2])
    nt.links.new(mul.outputs[0], emi.inputs[0])
    nt.links.new(emi.outputs[0], out.inputs[0])


def _render_setup(ink):
    sc = bpy.context.scene
    for m in {s.material for o in [bpy.data.objects[CFG["body"]]] + [bpy.data.objects[n] for n in CFG["props"]] for s in o.material_slots}:
        _toonify(m)
    ink_m = bpy.data.materials.new("RT_ink")
    ink_m.use_nodes = True
    nt = ink_m.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = (0.03, 0.018, 0.016, 1)
    nt.links.new(e.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs[0])
    ink_m.use_backface_culling = True
    for o in [bpy.data.objects[CFG["body"]]] + [bpy.data.objects[n] for n in CFG["props"]]:
        o.data.materials.append(ink_m)
        sol = o.modifiers.new("RT_ink", "SOLIDIFY")
        sol.thickness = ink
        sol.offset = 1.0
        sol.use_flip_normals = True
        sol.material_offset = len(o.data.materials) - 1
        sol.use_rim = False
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False
    w = sc.world or bpy.data.worlds.new("RT_world")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.29, 0.29, 0.29, 1)
    bg.inputs[1].default_value = 0.0
    sun = bpy.data.objects.new("RT_sun", bpy.data.lights.new("RT_sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.data.energy = 3.0
    cam = bpy.data.objects.new("RT_tcam", bpy.data.cameras.new("RT_tcam"))
    sc.collection.objects.link(cam)


def turnaround(out_dir, jobs, res=(640, 1000), ortho=2.05, target_z=0.98, ink=0.011, elev=4.0, transparent=False):
    """jobs: [(clip or None, frame, tag, views)]. Renders through an ortho camera with a sun from the front-left-top
    (the game's key), a toon ramp and an inverted-hull ink (solidify, flipped, ink material). Reverts nothing itself:
    call bpy.ops.wm.revert_mainfile() in the next call (never save after this)."""
    sc = bpy.context.scene
    arm = C.rig()
    if "RT_ink" not in bpy.data.materials:                 # first call since the file was opened: set the look up
        _render_setup(ink)
    cam, sun = bpy.data.objects["RT_tcam"], bpy.data.objects["RT_sun"]
    sc.camera = cam
    for o in [bpy.data.objects[CFG["body"]]] + [bpy.data.objects[n] for n in CFG["props"]]:
        o.modifiers["RT_ink"].thickness = ink
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    yaw = {"front": 0.0, "side": 90.0, "back": 180.0, "q34": 35.0, "game": 45.0}
    outs = []
    for clip, frame, tag, views in jobs:
        if clip:
            arm.animation_data.action = bpy.data.actions[clip]
            sc.frame_set(frame)
        else:
            RT.rest_pose()
        sc.render.film_transparent = transparent
        # the props as bartender.gd shows them: the hand cloth only while he wipes, the belt cloth otherwise
        bpy.data.objects["Bartender_ClothHand"].hide_render = clip != "Wipe"
        bpy.data.objects["Bartender_ClothBelt"].hide_render = clip == "Wipe"
        outs += _views(sc, cam, sun, out_dir, tag, views, yaw, target_z, elev)
    return outs


def _views(sc, cam, sun, out_dir, tag, views, yaw, target_z, elev_deg=4.0):
    outs = []
    for v in views:
        a = math.radians(yaw[v])
        elev = math.radians(30.0 if v == "game" else elev_deg)
        d = Vector((math.sin(a) * math.cos(elev), -math.cos(a) * math.cos(elev), math.sin(elev)))
        t = Vector((0, 0, target_z))
        cam.location = t + d * 8
        cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
        # the key light from the camera's left, above, a little in front
        ld = Matrix.Rotation(math.radians(-40), 3, "Z") @ d
        sun.rotation_euler = (-(ld + Vector((0, 0, 0.9)))).to_track_quat("-Z", "Y").to_euler()
        p = os.path.join(out_dir, "%s_%s.png" % (tag, v))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        outs.append(p)
    return outs
