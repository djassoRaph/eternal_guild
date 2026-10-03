# anime_anims.py - route AN (Story 25.30): a role's own clips on the anime rig, the 25.13 method (staff_anims.py):
# each clip starts from a retargeted KayKit clip's pose at the matching time and changes only what the work needs
# (a torso lean, hands placed on real targets by two-bone arm IK). Targets are in the character's REST frame
# (Blender: front -Y, up Z, her left +X, root at the origin). The Quest Dealer's three: Walk_Bar, Write, Brief.
#
# Her seat (Story 25.30, T5): hip_back 0.397 = KayKit's own seated hips offset, so her hips sit over the stool's centre
# (the WorkPoint) and her root 0.397 m in front of it. The desk slab's back edge is then 0.093 m BEHIND her root (the
# WorkPoint is 0.304 m behind it), its top 0.85 up; the open ledger's near edge (desk-local z -0.14, pages at x -0.33 /
# -0.11: to her right) is 0.64 - hip_back ahead of the root, its top 0.88.
import math

import bpy
from mathutils import Matrix, Vector

import anime_common as C
import anime_retarget as RT

FPS = 24
HIP_BACK = 0.397
ARM = {"l": ("upperarm.l", "lowerarm.l", "handslot.l"), "r": ("upperarm.r", "lowerarm.r", "handslot.r")}
LEG_BONES = ["upperleg.l", "lowerleg.l", "foot.l", "toes.l", "upperleg.r", "lowerleg.r", "foot.r", "toes.r"]
BAR_STRIDE = 0.45          # Walk_Bar's legs: 45% of Walking_A's swing (the shuffle near the desk)


def ledger(hip_back=HIP_BACK):
    return Vector((-0.12, -(0.64 - hip_back + 0.04), 0.92))


def _act(name):
    return bpy.data.actions[name]


def base_pose(action, t_seconds):
    act = _act(action)
    f0, f1 = act.frame_range
    RT.pose_from(act, f0 + math.fmod(t_seconds * FPS, max(f1 - f0, 1e-6)))


def arm_to(side, target, pole):
    u, l, h = ARM[side]
    RT.two_bone(u, l, h, target, pole)


def lean(deg, bone="spine"):
    RT.rotate_about(bone, Matrix.Rotation(math.radians(deg), 3, "X"))


def turn_head(pitch=0.0, yaw=0.0):
    if pitch:
        RT.rotate_about("head", Matrix.Rotation(math.radians(pitch), 3, "X"))
    if yaw:
        RT.rotate_about("head", Matrix.Rotation(math.radians(yaw), 3, "Z"))


def in_frame_of(bone, rest_point):
    arm = C.rig()
    L = arm.data.bones[bone].matrix_local
    return RT.pm(bone) @ (L.inverted() @ Vector(rest_point))


def record():
    return {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy()) for pb in C.rig().pose.bones}


def make_clip(name, length_s, pose_at, loop=True, step=1):
    """Key a new action from pose_at(t) every `step` frames (a loop's last key repeats its first), stash it on a muted
    NLA track with a fake user (the exporter writes every stashed action)."""
    arm = C.rig()
    frames = int(round(length_s * FPS))
    keys = list(range(0, frames + 1, step))
    if keys[-1] != frames:
        keys.append(frames)
    poses = {}
    first = None
    for f in keys:
        if loop and f == frames and first is not None:
            poses[f] = first
            continue
        pose_at(f / FPS)
        poses[f] = record()
        if f == 0:
            first = poses[f]
    old = bpy.data.actions.get(name)
    if old:
        for tr in list(arm.animation_data.nla_tracks):
            if tr.name == name:
                arm.animation_data.nla_tracks.remove(tr)
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    for f, pose in poses.items():
        for pb in arm.pose.bones:
            loc, q, sc = pose[pb.name]
            pb.location, pb.rotation_quaternion, pb.scale = loc, q, sc
            pb.keyframe_insert("location", frame=f, group=pb.name)
            pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
            pb.keyframe_insert("scale", frame=f, group=pb.name)
    act.use_fake_user = True
    arm.animation_data.action = None
    tr = arm.animation_data.nla_tracks.new()
    tr.name = name
    tr.strips.new(name, 0, act)
    tr.mute = True
    return act


WALKING_A_S = 25.6 / FPS
SIT_IDLE_S = 86.4 / FPS


def pose_walk_bar(t):
    """Walking_A's torso with its legs' swing cut to BAR_STRIDE (blended toward Idle), both hands held in front of the
    belly, elbows tucked, riding the chest's bob: her arms stay off the desk top."""
    base_pose("Idle", t)
    arm = C.rig()
    idle = {b: arm.pose.bones[b].rotation_quaternion.copy() for b in LEG_BONES}
    idle_h = arm.pose.bones["hips"].location.copy()
    base_pose("Walking_A", t)
    for b in LEG_BONES:
        pb = arm.pose.bones[b]
        pb.rotation_quaternion = idle[b].slerp(pb.rotation_quaternion, BAR_STRIDE)
    hb = arm.pose.bones["hips"]
    hb.location = idle_h.lerp(hb.location, BAR_STRIDE)       # the bob shrinks with the stride (the feet stay down)
    RT._upd()
    sw = 0.02 * math.sin(2 * math.pi * t / WALKING_A_S)
    for s, sx in (("l", 1), ("r", -1)):
        tgt = in_frame_of("chest", (0.12 * sx, -0.26, 1.00 + sw * sx))
        pole = in_frame_of("chest", (0.55 * sx, 0.05, 1.10))      # elbows out to the sides: clear of the back hair
        arm_to(s, tgt, pole)


def pose_write(t, length=SIT_IDLE_S, hip_back=HIP_BACK):
    """Seated: the quill hand makes small strokes on the ledger's near page, lifting to pause once a loop; the left
    hand rests on the desk; head down."""
    base_pose("Sit_Chair_Idle", t)
    lean(26.0, bone="chest")
    k = t / length
    pause = max(0.0, 1 - abs(k - 0.8) / 0.1)
    turn_head(pitch=14.0 - 12.0 * pause)
    stroke = Vector((0.03 * math.sin(2 * math.pi * 6 * k), 0.012 * math.sin(2 * math.pi * 12 * k), 0.0)) * (1 - pause)
    quill = ledger(hip_back) + stroke + Vector((0.0, 0.03, 0.09)) * pause
    arm_to("r", quill, Vector((-0.6, 0.3, 0.5)))
    arm_to("l", Vector((0.12, -(0.64 - hip_back), 0.93)), Vector((0.7, 0.3, 0.6)))      # resting, clear of the slab edge


def pose_brief(t, length=SIT_IDLE_S, hip_back=HIP_BACK):
    """Seated, head up toward the customer side; both hands gesture above the desk top; one 'counting on fingers'
    beat ('I'll need three days')."""
    base_pose("Sit_Chair_Idle", t)
    k = t / length
    turn_head(pitch=-4.0, yaw=6.0 * math.sin(2 * math.pi * k))
    dy = hip_back - 0.32                                     # 25.13's targets, moved back with her deeper seat
    open_r = Vector((-0.20, -0.20 + dy, 1.08 + 0.05 * math.sin(2 * math.pi * 2 * k)))
    open_l = Vector((0.20, -0.18 + dy, 1.06 + 0.04 * math.sin(2 * math.pi * 2 * k + 1.3)))
    count = max(0.0, 1 - abs(k - 0.5) / 0.18)
    arm_to("r", open_r.lerp(Vector((-0.06, -0.24 + dy, 1.16)), count), Vector((-0.6, 0.3, 1.0)))
    arm_to("l", open_l.lerp(Vector((0.06, -0.22 + dy, 1.12)), count), Vector((0.6, 0.3, 1.0)))


CLIPS = [("Walk_Bar", WALKING_A_S, pose_walk_bar, True), ("Write", SIT_IDLE_S, pose_write, True), ("Brief", SIT_IDLE_S, pose_brief, True)]


def build_clips(names=None):
    out = []
    for name, length, fn, loop in CLIPS:
        if names and name not in names:
            continue
        act = make_clip(name, length, fn, loop=loop, step=2 if length > 2.5 else 1)
        out.append((name, tuple(round(v, 1) for v in act.frame_range)))
    RT.rest_pose()
    C.drop_cached_clouds()          # anime_clearcheck's clouds of the old clips
    return out


def write_reach(hip_back=HIP_BACK):
    """The quill hand's (handslot.r) worst distance to the ledger target over Write, and the quill's nib height."""
    arm = C.rig()
    act = _act("Write")
    worst = 0.0
    for f in C.frames(act):
        m = C.fk(arm, C.Curves(act), f, ["handslot.r"])
        k = f / (SIT_IDLE_S * FPS)
        pause = max(0.0, 1 - abs(k - 0.8) / 0.1)
        if pause == 0.0:
            worst = max(worst, (m["handslot.r"].translation - ledger(hip_back)).length)
    return worst
