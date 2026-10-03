# real_bartender.py - the realistic spike's Bartender (2026-10-04, catalogue G12; a TEST: nothing shipped points at it).
# Raphael's chosen concept (realistic_test/ref_bartender_concept.png): a heavy-set, bald, weathered barkeep, ~1.86 m;
# a full grey beard; a wine-red shirt with rolled sleeves and a laced collar; a long dark leather apron (bib, neck
# strap, chest pocket, mid-shin, frayed hem) tied at the back; a belt with an off-white cloth at his left hip (the
# sheet's front and side views both put it there); dark trousers; worn boots with turned-down cuffs.
# One call per step (README's runner, plus tools/blender/realistic on sys.path):
#   open_base_as_bartender()   realistic_base.blend saved as realistic_bartender_test.blend (a file load: own call)
#   build()                    his parts (real_body) on the REAL-1 rig, joined into Bartender_Body (2 surfaces: the head
#                              projection + the body atlas), the cloth props on hips / handslot.r, the merge report
#   build_clips()              Idle and Walking_A with his arms re-posed (the KayKit chibi arms stand 45 degrees out),
#                              Walk_Bar and Wipe (the 25.13 method, his reach), then the speeds (anime_clearcheck)
#   export()                   Rig + body + props to assets/characters/custom/tests/g12_bartender_realtest.glb
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
CFG = {
    "role": "bartender_realtest",
    "blend": C.BLEND + "realistic_bartender_test.blend",
    "head_png": ART + "textures/realistic/g12_bartender_realtest_head.png",
    "body_png": ART + "textures/realistic/g12_bartender_realtest_body.png",
    "glb": "F:/GAME I AM MAKING/shiningsun/assets/characters/custom/tests/g12_bartender_realtest.glb",
    "body": "Bartender_Body",
    "props": ["Bartender_ClothHand", "Bartender_ClothBelt"],
}
TRI_BUDGET = 10000
HAND_SCALE = 1.12           # the sheet's hands are big working hands (the first pass read small next to the concept)


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
    cols, rows = 4, 6
    grid = []
    for j in range(rows + 1):
        z = 1.060 - (1.060 - 0.810) * j / rows
        row = []
        for i in range(cols + 1):
            th = math.radians(52 + 34 * i / cols)                    # round the hip, front-left
            w, yf, yb = RB.apron_ring(min(z, 1.03))
            x = (w + 0.030) * RB.se(math.sin(th), 2.2)
            y = (yf + yb) / 2 - ((yb - yf) / 2 + 0.030) * RB.se(math.cos(th), 2.2)
            sway = 0.010 * math.sin(i * 1.9 + j * 0.8) + 0.004 * j
            row.append(Vector((x + sway * 0.5, y - sway, z - (0.012 if i in (1, 3) and j == rows else 0.0))))
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
    parts = [RB.build_head("RT_Head", head), RB.build_beard("RT_Beard", head), RB.build_ears("RT_Ears", head),
             RB.build_neck("RT_Neck", head), RB.build_torso("RT_Shirt", body), RB.build_collar("RT_Collar", body),
             RB.build_pelvis("RT_Seat", body), RB.build_apron_skirt("RT_Apron", body), RB.build_bib("RT_Bib", body),
             RB.build_pocket("RT_Pocket", body), RB.build_straps("RT_Strap", body), RB.build_ties("RT_Ties", body),
             RB.build_belt("RT_Belt", body)]
    for s in ("l", "r"):
        parts += [RB.build_sleeve("RT_Sleeve_" + s, body, s), RB.build_roll("RT_Roll_" + s, body, s),
                  RB.build_forearm("RT_Forearm_" + s, body, s), RB.build_hand("RT_Hand_" + s, body, s, scale=HAND_SCALE),
                  RB.build_trouser_leg("RT_Leg_" + s, body, s), RB.build_boot("RT_Boot_" + s, body, s)]
    counts = {p.name: sum(len(f.vertices) - 2 for f in p.data.polygons) for p in parts}
    props = [build_cloth_hand(body), build_cloth_belt(body)]
    out = MG.join(CFG["body"], parts)
    C.drop_cached_clouds()
    ok, stats = MG.check(out, props=props, tri_budget=TRI_BUDGET)
    print("parts (tris):", sorted(counts.items(), key=lambda kv: -kv[1]))
    return ok, stats


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


WALK_STRIDE = 0.74          # Walking_A's leg swing kept (toward Idle): KayKit's full stride on his legs is 1.72 m/s
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


WIPE_LEAN = 18.0
WIPE_C, WIPE_R, WIPE_Z = (-0.12, -0.585), 0.035, 1.168     # the cloth's circle on the counter top (edge 0.55 ahead)


def pose_wipe(t, period=2 * AN.IDLE_S):
    """At a serve point, facing the counter (its inner edge 0.55 m ahead, top 1.12 m up): he leans in, the right hand
    circles the cloth on the top 0.56-0.66 m ahead, the left hand rests on the counter's edge; a look down."""
    AN.base_pose(SRC["Idle"], t)
    stand_tall()
    AN.lean(WIPE_LEAN)
    AN.turn_head(pitch=12.0)
    a = 2 * math.pi * t / period
    right = Vector((WIPE_C[0] + WIPE_R * math.cos(a), WIPE_C[1] + WIPE_R * math.sin(a), WIPE_Z))
    reach("r", right, Vector((-0.75, 0.10, 1.35)), (0.0, 0.0, -1.0), level=True)          # flat on the counter, on the cloth
    reach("l", Vector((0.24, -0.565, WIPE_Z)), Vector((0.75, 0.10, 1.35)), (0.0, 0.0, -1.0), level=True)    # resting


CLIPS = [("Idle", AN.IDLE_S, pose_idle, True), ("Walking_A", AN.WALKING_A_S, pose_walk, True),
         ("Walk_Bar", AN.WALKING_A_S, pose_walk_bar, True),
         ("Wipe", 2 * AN.IDLE_S, pose_wipe, True)]


def build_clips(names=None):
    assert C.is_open(CFG["blend"])
    ensure_sources()
    order = ["Walk_Bar", "Wipe", "Idle", "Walking_A"]
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
    """How deep anything of his (props included) goes below the counter top (1.12) beyond its inner edge (0.55 ahead),
    over the clip: the hands and the cloth must ride ON the top."""
    import anime_clearcheck as CC
    import numpy as np
    cfg = {"body": CFG["body"], "props": CFG["props"]}
    worst = 0.0
    for f in CC.frames_of(clip, 2):
        p = CC.cloud(clip, f, with_props=True, cfg=cfg)
        q = p[(p[:, 2] > 0.55) & (p[:, 1] < 1.12)]
        if len(q):
            worst = max(worst, 1.12 - float(np.min(q[:, 1])))
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

def export():
    assert C.is_open(CFG["blend"])
    assert "RT_ink" not in bpy.data.materials and "RT_sun" not in bpy.data.objects, "turnaround state in the file: revert it"
    RT.rest_pose()
    arm = C.rig()
    body = bpy.data.objects[CFG["body"]]
    props = [bpy.data.objects[n] for n in CFG["props"]]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in [arm, body] + props:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(CFG["glb"]), exist_ok=True)
    # the SRC_* copies are the clip builder's sources, not his clips: the exporter writes every action on the armature,
    # so they go for the export and the file is reverted right after (it is saved with them)
    bpy.ops.wm.save_mainfile()
    for src in SRC.values():
        if src in bpy.data.actions:
            bpy.data.actions.remove(bpy.data.actions[src])
    bpy.ops.export_scene.gltf(filepath=CFG["glb"], use_selection=True, export_apply=False, export_skins=True,
                              export_animations=True, export_yup=True)
    print("exported", CFG["glb"], os.path.getsize(CFG["glb"]))
    bpy.ops.wm.revert_mainfile()
    return CFG["glb"]


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
