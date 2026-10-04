# real_den_fa_anims.py - Story 25.32 (from Story 25.10's den_anims.py, <art>/pipeline_ref/25_10/): Den Fa's six clips on
# his own d_ rig, without the wings (R-8: the wing tuck in Sit is gone, nothing else changed). Versioned here (DC-14).
# A pose is {bone: {'r': [(axis, deg), ...], 'l': (x, y, z), 's': (x, y, z)}}. Rotations are about ARMATURE axes as at
# rest (X: + tips a DOWN-pointing bone BACK (+Y) and an UP-pointing bone FORWARD (-Y); Z: + turns a forward-facing head
# toward his LEFT, +X), 'lx'/'lz' bend about the bone's own axes. 'l' is an armature-space offset in metres. Front is
# -Y; his left is +X (the fire side when seated).
#
# record_shipped(path) dumps the shipped 25.10 file's rest pose and actions to JSON (run with g9_den_fa.blend OPEN,
# never saved); compare(path) proves the rebuilt clips keyframe-identical on the 30 kept bones (AC 3).
import json
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

FPS = 24
HIP_BACK = 0.55        # his root stands this far in front of the seat marker (den_fa.gd DEN_FA_HIP_BACK)
HIP_IN_CLIP = 0.47     # hips this far behind the root in Sit: 0.08 m in front of the marker (wall clearance)
SEAT_SIDE = 0.48       # his root also stands this far to his RIGHT of the marker line, so standing up he clears the chimney
SEAT_UP = 0.45         # seat top above his feet
HIP_REST_Z = 1.20      # thigh heads, rest pose
CLIPS = ["Sit", "Idle", "Walk", "Point", "StandUp", "SitDown"]
LOOPS = ["Idle", "Sit", "Walk"]
ONE_SHOTS = ["Point", "StandUp", "SitDown"]


def sin01(t):
    return math.sin(2 * math.pi * t)


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def merge(p, q, w):
    """Blend two poses (w=0 -> p, w=1 -> q) by interpolating each bone's rotation list and offsets."""
    out = {}
    for b in set(p) | set(q):
        a, c = p.get(b, {}), q.get(b, {})
        la, lc = Vector(a.get('l', (0, 0, 0))), Vector(c.get('l', (0, 0, 0)))
        sa, sc = Vector(a.get('s', (1, 1, 1))), Vector(c.get('s', (1, 1, 1)))
        out[b] = {'r': [(ax, d * (1 - w)) for ax, d in a.get('r', [])] + [(ax, d * w) for ax, d in c.get('r', [])],
                  'l': tuple(la.lerp(lc, w)), 's': tuple(sa.lerp(sc, w))}
    return out


def idle_pose(t):
    breath = 0.006 * sin01(t)
    sway = 0.012 * sin01(t)
    p = {
        'd_hips': {'l': (sway, 0, 0)},
        'd_chest': {'r': [('X', 1.5 * sin01(t))], 'l': (0, 0, breath)},
        'd_head': {'r': [('Y', -5 + 2 * sin01(t + 0.2)), ('X', 4)]},     # a slight, listening tilt
        'd_thigh.L': {'r': [('X', 2)]}, 'd_shin.L': {'r': [('X', 3)]},    # a little contrapposto
        'd_thigh.R': {'r': [('X', -1)]},
    }
    for s, sx in (('L', 1), ('R', -1)):  # hands loosely clasped in front, at the waist
        p['d_upperarm.%s' % s] = {'r': [('X', -18), ('Y', sx * -8)]}
        p['d_forearm.%s' % s] = {'r': [('X', -62), ('Z', sx * -38)]}   # inward, toward the other hand
        p['d_hand.%s' % s] = {'r': [('X', -10)]}
    return p


# Solved against the tavern (real_den_fa_check.py): no vertex in the bench, behind the wall face or past the chimney
# face. The hips turn 32 deg toward the room and shift 0.13 m to his right; with the head's 30 deg the mask faces about
# 60 deg off the seat, near the game camera. The legs cross toward the fire so no wood-store log's line of sight to the
# camera is blocked (real_den_fa_check.log_hits).
SIT = {'hip_yaw': -32.0, 'hip_shift': 0.13, 'leg_yaw': -10.0, 'hip_lift': 0.17, 'head_yaw': -30.0, 'larm': (-20.0, -50.0, -70.0),
       'leg_yaw_L': 12.0, 'leg_yaw_R': 32.0}


def sit_pose(t=0.0):
    """Seated on the 0.45 m hearth bench, hips 0.08 m in front of the marker, thighs level. The hips turn toward the
    room (his right, -X) so his knees stay clear of the chimney on his left and the mask comes round to the camera;
    the head turns further toward the room. (25.10 also tucked the last wing strut here; R-8 drops it.)"""
    k = SIT
    p = {
        'd_hips': {'r': [('Z', k['hip_yaw'])], 'l': (SEAT_SIDE - k['hip_shift'], HIP_IN_CLIP, SEAT_UP + k['hip_lift'] - HIP_REST_Z)},
        'd_spine': {'r': [('X', 4)]},
        'd_chest': {'r': [('X', 3 + 1.0 * sin01(t))], 'l': (0, 0, 0.005 * sin01(t))},
        'd_neck': {'r': [('Z', k['head_yaw'] * 0.35)]},
        'd_head': {'r': [('Z', k['head_yaw'] * 0.65), ('X', 5), ('Y', -4 + 3 * sin01(t + 0.3))]},
    }
    for s, sx in (('L', 1), ('R', -1)):
        p['d_thigh.%s' % s] = {'r': [('X', -90), ('Z', k.get('leg_yaw_' + s, k['leg_yaw']))]}
        p['d_shin.%s' % s] = {'r': [('X', 90)]}
        if s == 'L':                      # his left (fire-side) hand rests across his lap, clear of the chimney
            ua, fx, fz = k['larm']
            p['d_upperarm.L'] = {'r': [('X', ua), ('Y', -6)]}
            p['d_forearm.L'] = {'r': [('X', fx), ('Z', fz)]}
        else:
            p['d_upperarm.R'] = {'r': [('X', -30), ('Y', 6)]}
            p['d_forearm.R'] = {'r': [('X', -55), ('Z', -14)]}
        p['d_hand.%s' % s] = {'r': [('X', 20)]}
    return p


def walk_pose(t):
    p = {}
    for side, ph in (('L', 0.0), ('R', 0.5)):
        a = sin01(t + ph)
        swing = max(0.0, math.cos(2 * math.pi * (t + ph)))
        p['d_thigh.%s' % side] = {'r': [('X', -18 * a)]}
        p['d_shin.%s' % side] = {'r': [('X', 34 * swing * (a < 0.3 and 1 or 0.4))]}
        p['d_foot.%s' % side] = {'r': [('X', -8 * a)]}
        arm = sin01(t + ph + 0.5)
        p['d_upperarm.%s' % side] = {'r': [('X', -11 * arm)]}
        p['d_forearm.%s' % side] = {'r': [('X', -14 - 6 * arm)]}
    p['d_hips'] = {'l': (0, 0, 0.012 * math.cos(4 * math.pi * t))}
    p['d_spine'] = {'r': [('Y', 3 * sin01(t))]}
    p['d_head'] = {'r': [('Y', -2 * sin01(t)), ('X', 3)]}
    return p


def point_pose(t):
    """3 s one-shot: a slow, deliberate point, forward and ~5 deg up, held; ends in Idle."""
    p = idle_pose(0.0)
    up = smooth((t - 0.10) / 0.30) * (1.0 - smooth((t - 0.78) / 0.20))
    p['d_upperarm.R'] = {'r': [('X', -18 * (1 - up) - 95 * up), ('Y', 8 * (1 - up))]}
    p['d_forearm.R'] = {'r': [('X', -62 * (1 - up)), ('Z', 38 * (1 - up))]}
    p['d_hand.R'] = {'r': [('X', -10 * (1 - up))]}
    p['d_head'] = {'r': [('X', 4 - 6 * up), ('Y', -5 * (1 - up))]}
    p['d_chest'] = {'r': [('X', -2 * up)]}
    return p


def stand_up_pose(t):
    return merge(sit_pose(0.0), idle_pose(0.0), smooth(t))


def sit_down_pose(t):
    return merge(idle_pose(0.0), sit_pose(0.0), smooth(t))


POSE_FNS = {"Sit": sit_pose, "Idle": idle_pose, "Walk": walk_pose, "Point": point_pose, "StandUp": stand_up_pose,
            "SitDown": sit_down_pose}
# (frames, key step, loop) per clip: the 25.10 numbers
SPEC = {"Sit": (96, 4, True), "Idle": (96, 4, True), "Walk": (30, 2, True), "Point": (72, 2, False),
        "StandUp": (24, 2, False), "SitDown": (24, 2, False)}


def local_quat(rig, bone, rots):
    M = rig.data.bones[bone].matrix_local.to_3x3()
    q = Quaternion()
    local = Quaternion()
    for axis, deg in rots:
        if axis in ('lx', 'lz'):
            local = Quaternion(Vector((1, 0, 0)) if axis == 'lx' else Vector((0, 0, 1)), math.radians(deg)) @ local
        else:
            R = Matrix.Rotation(math.radians(deg), 3, axis)
            q = (M.inverted() @ R @ M).to_quaternion() @ q
    return q @ local


def apply_pose(rig, pose):
    for pb in rig.pose.bones:
        spec = pose.get(pb.name, {})
        pb.rotation_quaternion = local_quat(rig, pb.name, spec.get('r', []))
        pb.location = rig.data.bones[pb.name].matrix_local.to_3x3().inverted() @ Vector(spec.get('l', (0, 0, 0)))
        pb.scale = Vector(spec.get('s', (1, 1, 1)))


def pose_at(rig, clip, t):
    """The clip's pose at t in [0, 1] (its own function, not the keys)."""
    apply_pose(rig, POSE_FNS[clip](t))


def make_action(rig, name, frames, step, pose_fn, loop=True):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = act
    keys = list(range(0, frames + 1, step))
    if keys[-1] != frames:
        keys.append(frames)
    for f in keys:
        t = f / frames
        apply_pose(rig, pose_fn(0.0 if (loop and f == frames) else t))
        for pb in rig.pose.bones:
            pb.keyframe_insert('rotation_quaternion', frame=f, group=pb.name)
            pb.keyframe_insert('location', frame=f, group=pb.name)
            pb.keyframe_insert('scale', frame=f, group=pb.name)
    act.use_fake_user = True
    return act


def build_actions(rig):
    """The six clips, stashed on muted NLA tracks (use_fake_user), the action slot left empty and the rig in rest."""
    bpy.context.scene.render.fps = FPS
    acts = [make_action(rig, n, SPEC[n][0], SPEC[n][1], POSE_FNS[n], loop=SPEC[n][2]) for n in CLIPS]
    ad = rig.animation_data
    for tr in list(ad.nla_tracks):
        ad.nla_tracks.remove(tr)
    for a in acts:
        tr = ad.nla_tracks.new()
        tr.name = a.name
        tr.strips.new(a.name, 0, a)
        tr.mute = True
    ad.action = None
    for pb in rig.pose.bones:
        pb.matrix_basis.identity()
    return [a.name for a in acts]


# ------------------------------------------------------------------ the 25.10 record and the proof

def record_shipped(path, rig_name="DenFa_Rig"):
    """Run with the shipped g9_den_fa.blend OPEN (read only: never saved): its rest (head, tail, roll per bone,
    armature space) and every action's F-curves (data_path, index, keyframe co and interpolation) -> JSON."""
    rig = bpy.data.objects[rig_name]
    out = {"file": bpy.data.filepath, "rest": {}, "actions": {}}
    for b in rig.data.bones:
        out["rest"][b.name] = {"head": list(b.head_local), "tail": list(b.tail_local),
                               "matrix": [list(r) for r in b.matrix_local]}
    for a in bpy.data.actions:
        fcs = []
        for fc in a.fcurves:
            fcs.append({"path": fc.data_path, "index": fc.array_index,
                        "keys": [[k.co[0], k.co[1], k.interpolation] for k in fc.keyframe_points]})
        out["actions"][a.name] = fcs
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f)
    return {"bones": len(out["rest"]), "actions": {k: len(v) for k, v in out["actions"].items()}}


def _bone_of(path):
    return path.split('"')[1] if path.startswith('pose.bones["') else None


def compare(path, rig, tol=1e-5):
    """AC 2 / AC 3: the open rig's rest vs the record (head, tail and the bone matrix on every kept bone; no wing
    bone), and every action's F-curves on the kept bones vs the record's (same keys, values within tol). Returns
    (rest worst difference, {clip: worst key difference or a reason}, the record's bones the rig lacks)."""
    rec = json.load(open(path, encoding="utf-8"))
    names = [b.name for b in rig.data.bones]
    rest_worst = 0.0
    for b in rig.data.bones:
        r = rec["rest"][b.name]
        rest_worst = max(rest_worst, (b.head_local - Vector(r["head"])).length, (b.tail_local - Vector(r["tail"])).length,
                         max(abs(b.matrix_local[i][j] - r["matrix"][i][j]) for i in range(4) for j in range(4)))
    dropped = sorted(set(rec["rest"]) - set(names))
    clips = {}
    for clip in CLIPS:
        a = bpy.data.actions.get(clip)
        if a is None:
            clips[clip] = "missing"
            continue
        mine = {(fc.data_path, fc.array_index): fc for fc in a.fcurves}
        theirs = {(f["path"], f["index"]): f for f in rec["actions"][clip] if _bone_of(f["path"]) in names}
        if set(mine) != set(theirs):
            clips[clip] = "channels differ: +%s -%s" % (sorted(set(mine) - set(theirs))[:3], sorted(set(theirs) - set(mine))[:3])
            continue
        worst = 0.0
        for key, f in theirs.items():
            kps = mine[key].keyframe_points
            if len(kps) != len(f["keys"]):
                worst = float("inf")
                break
            for kp, (fr, val, interp) in zip(kps, f["keys"]):
                if abs(kp.co[0] - fr) > 1e-6 or kp.interpolation != interp:
                    worst = float("inf")
                worst = max(worst, abs(kp.co[1] - val))
        clips[clip] = worst
    return rest_worst, clips, dropped
