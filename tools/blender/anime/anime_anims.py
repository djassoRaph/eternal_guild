# anime_anims.py - route AN (Stories 25.30, 25.31): a role's own clips on the anime rig, the 25.13 method
# (pipeline_ref/25_13/staff_anims.py): each clip starts from a retargeted KayKit clip's pose at the matching time and
# changes only what the work needs (a torso lean, a squat with the feet kept, hands placed on real targets by two-bone
# arm IK). Targets are in the character's REST frame (Blender: front -Y, up Z, the character's left +X, root at the
# origin). Generic: the role's clip list is its own config (anime_dealer.CLIPS: Walk_Bar, Write, Brief), built with
# build_clips(clips). N9: actions are file-global, so one role per .blend.
import math

import bpy
from mathutils import Matrix, Vector

import anime_common as C
import anime_retarget as RT

FPS = 24
ARM = {"l": ("upperarm.l", "lowerarm.l", "handslot.l"), "r": ("upperarm.r", "lowerarm.r", "handslot.r")}
LEG = {"l": ("upperleg.l", "lowerleg.l", "foot.l"), "r": ("upperleg.r", "lowerleg.r", "foot.r")}
LEG_BONES = ["upperleg.l", "lowerleg.l", "foot.l", "toes.l", "upperleg.r", "lowerleg.r", "foot.r", "toes.r"]
BAR_STRIDE = 0.45          # Walk_Bar's legs: 45% of Walking_A's swing (the shuffle near the desk / along the bar)
WALKING_A_S = 25.6 / FPS
IDLE_S = 25.6 / FPS
SIT_IDLE_S = 86.4 / FPS


def _act(name):
    return bpy.data.actions[name]


def base_pose(action, t_seconds):
    act = _act(action)
    f0, f1 = act.frame_range
    RT.pose_from(act, f0 + math.fmod(t_seconds * FPS, max(f1 - f0, 1e-6)))


def arm_to(side, target, pole):
    u, l, h = ARM[side]
    RT.two_bone(u, l, h, target, pole)


def leg_to(side, foot_target, pole):
    u, l, f = LEG[side]
    RT.two_bone(u, l, f, foot_target, pole)


def lean(deg, bone="spine"):
    RT.rotate_about(bone, Matrix.Rotation(math.radians(deg), 3, "X"))


def turn_head(pitch=0.0, yaw=0.0):
    if pitch:
        RT.rotate_about("head", Matrix.Rotation(math.radians(pitch), 3, "X"))
    if yaw:
        RT.rotate_about("head", Matrix.Rotation(math.radians(yaw), 3, "Z"))


def squat(drop, feet=None):
    """Lower the hips by drop, keeping the feet where they are (two-bone leg IK, knees forward)."""
    feet = feet or {s: RT.pm(LEG[s][2]).translation.copy() for s in ("l", "r")}
    RT.set_pm("hips", Matrix.Translation(Vector((0, 0, -drop))) @ RT.pm("hips"))
    for s in ("l", "r"):
        leg_to(s, feet[s], RT.pm(LEG[s][1]).translation + Vector((0, -0.6, 0.1)))


def in_frame_of(bone, rest_point):
    """A rest-frame point carried along with a bone's current pose (so hands ride the torso's bob)."""
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


def walk_bar(hand=(0.12, -0.26, 1.00), pole=(0.55, 0.05, 1.10), stride=BAR_STRIDE, swing=0.02):
    """A pose function for Walk_Bar: Walking_A's torso with its legs' swing cut to `stride` (blended toward Idle, the
    hips' bob with it: the feet stay down), both hands held in front of the belly at `hand` (chest-carried rest point,
    x mirrored), elbows toward `pole`, riding the chest's bob. The dealer's defaults: elbows OUT to the sides (clear
    of her back hair); the Bartender's (25.13): hand (0.15, -0.36, 0.70), pole (0.30, 0.35, 0.80), elbows TUCKED."""
    def pose(t):
        base_pose("Idle", t)
        arm = C.rig()
        idle = {b: arm.pose.bones[b].rotation_quaternion.copy() for b in LEG_BONES}
        idle_h = arm.pose.bones["hips"].location.copy()
        base_pose("Walking_A", t)
        for b in LEG_BONES:
            pb = arm.pose.bones[b]
            pb.rotation_quaternion = idle[b].slerp(pb.rotation_quaternion, stride)
        hb = arm.pose.bones["hips"]
        hb.location = idle_h.lerp(hb.location, stride)
        RT._upd()
        sw = swing * math.sin(2 * math.pi * t / WALKING_A_S)
        for s, sx in (("l", 1), ("r", -1)):
            tgt = in_frame_of("chest", (hand[0] * sx, hand[1], hand[2] + sw * sx))
            pl = in_frame_of("chest", (pole[0] * sx, pole[1], pole[2]))
            arm_to(s, tgt, pl)
    return pose


def build_clips(clips, names=None):
    """clips: the role's [(name, length_s, pose_at(t), loop)], in build order; names: a subset to (re)build."""
    out = []
    for name, length, fn, loop in clips:
        if names and name not in names:
            continue
        act = make_clip(name, length, fn, loop=loop, step=2 if length > 2.5 else 1)
        out.append((name, tuple(round(v, 1) for v in act.frame_range)))
    RT.rest_pose()
    C.drop_cached_clouds()          # anime_clearcheck's clouds of the old clips
    return out
