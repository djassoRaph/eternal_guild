# anime_retarget.py - route AN step 4 (Story 25.30): the 76 KayKit clips on the stretched rig.
#   ratio_step()   the hips and root location keys scaled by the leg ratio (anime thigh + shin over KayKit's, read from
#                  rig["kaykit_thigh"/"kaykit_shin"]); every other deform bone's location curve reported, left as is;
#                  each action stamped act["anime_leg_ratio"]. Refuses a stamped file: it is never run twice.
#   refit_sit()    Sit_Chair_Down / Idle / StandUp rewritten absolutely from anime_base_kaykit_sit.json: KayKit's back
#                  offset kept (0 -> 0.397 m, unscaled: RealisticPatron's SIT_HIP_BACK 0.40 stays true), the height
#                  solved so the body's lowest seat vertex rests on the 0.44 m seat, the feet planted by two-bone leg IK.
#                  Repeatable (never scales), not blocked by the stamp; prints SIT_HIPS_Y (Test 19's AN_SIT_HIPS_Y).
#   foot_report()  every clip, every frame KayKit's own foot is down (contact), the body's lowest foot within 0.03 m of
#                  the floor; over the limit, a hips-height contact correction (smoothed); a before/after table.
#   seated_room()  the upperarm heads in Sit_Chair_Idle (frame 0 and mid), root-local: >= 1.05 (the desk top + 0.20).
# Frames: armature +Z up, -Y front. The hips bone's local Y is armature +Z and its local Z is armature -Y (asserted),
# so hips location[1] is the height and location[2] the front (+) / back (-).
import math

import bpy
from mathutils import Matrix, Vector

import anime_common as C

LOOP_CLIPS = {"Idle", "Walking_A", "Walking_B", "Walking_C", "Walking_Backwards", "Running_A", "Running_B", "Running_Strafe_Left",
              "Running_Strafe_Right", "Sit_Chair_Idle", "Sit_Floor_Idle", "Lie_Idle", "Blocking", "2H_Melee_Idle", "Unarmed_Idle",
              "Spellcasting", "1H_Ranged_Aiming", "2H_Ranged_Aiming", "Jump_Idle", "1H_Ranged_Shooting", "2H_Ranged_Shooting", "2H_Melee_Attack_Spinning"}
SKIP_REPORT = ("root", "hips")
INERT = ("IK", "control-", "handIK", "elbowIK", "kneeIK", "heelIK")
LIMIT = 0.03
CONTACT = 0.01


def _assert_hips_axes(arm):
    m = arm.data.bones["hips"].matrix_local.to_3x3()
    y, z = m.col[1], m.col[2]
    assert (y - Vector((0, 0, 1))).length < 1e-3 and (z - Vector((0, -1, 0))).length < 1e-3, "hips axes: local Y up, local Z front"


def leg_ratio(arm=None):
    arm = arm or C.rig()
    b = arm.data.bones
    return (b["upperleg.l"].length + b["lowerleg.l"].length) / (arm["kaykit_thigh"] + arm["kaykit_shin"])


def ratio_step():
    arm = C.rig()
    _assert_hips_axes(arm)
    stamped = [a.name for a in bpy.data.actions if "anime_leg_ratio" in a]
    assert not stamped, "already retargeted (%d stamped actions): rebuild the chain from the kit" % len(stamped)
    k = leg_ratio(arm)
    report = {}
    for act in bpy.data.actions:
        for f in act.fcurves:
            if f.data_path in ('pose.bones["hips"].location', 'pose.bones["root"].location'):
                for kp in f.keyframe_points:
                    kp.co[1] *= k
                    kp.handle_left[1] *= k
                    kp.handle_right[1] *= k
                f.update()
            elif f.data_path.endswith(".location"):
                bone = f.data_path.split('"')[1]
                if bone not in SKIP_REPORT and not any(t in bone for t in INERT):
                    peak = max(abs(kp.co[1]) for kp in f.keyframe_points) if len(f.keyframe_points) else 0.0
                    if peak > report.get(bone, (0.0, ""))[0]:
                        report[bone] = (peak, act.name)
        act["anime_leg_ratio"] = k
    rows = sorted(report.items(), key=lambda kv: -kv[1][0])
    print("leg ratio %.4f; hips + root location keys scaled in %d actions" % (k, len(bpy.data.actions)))
    print("other deform-bone location offsets (left unscaled): " + ", ".join("%s %.3f (%s)" % (b, p, a) for b, (p, a) in rows[:10]))
    return k, rows


# ------------------------------------------------------------------ live pose helpers (the 25.13 method)

def _upd():
    bpy.context.view_layer.update()


def pm(name):
    return C.rig().pose.bones[name].matrix.copy()


def set_pm(name, M):
    C.rig().pose.bones[name].matrix = M
    _upd()


def rotate_about(name, R3, pivot=None):
    M = pm(name)
    p = M.translation.copy() if pivot is None else Vector(pivot)
    set_pm(name, Matrix.Translation(p) @ R3.to_4x4() @ Matrix.Translation(-p) @ M)


def two_bone(upper, lower, eff, target, pole):
    S = pm(upper).translation
    E0 = pm(lower).translation
    H0 = pm(eff).translation
    a = (E0 - S).length
    c = (H0 - E0).length
    Tt = Vector(target)
    d = min(max((Tt - S).length, abs(a - c) + 1e-4), a + c - 1e-4)
    u = (Tt - S).normalized()
    pv = Vector(pole) - S
    v = pv - u * pv.dot(u)
    v = v.normalized() if v.length > 1e-6 else Vector((0, -1, 0))
    cos_a = (a * a + d * d - c * c) / (2 * a * d)
    E = S + a * (cos_a * u + math.sqrt(max(0.0, 1 - cos_a * cos_a)) * v)
    rotate_about(upper, (E0 - S).normalized().rotation_difference((E - S).normalized()).to_matrix())
    E1 = pm(lower).translation
    H1 = pm(eff).translation
    rotate_about(lower, (H1 - E1).normalized().rotation_difference((Tt - E1).normalized()).to_matrix())


def pose_from(action, frame):
    """Pose the rig as `action` at `frame` (may be fractional), then detach the action so edits stick."""
    arm = C.rig()
    arm.animation_data.action = action
    bpy.context.scene.frame_set(int(math.floor(frame)), subframe=frame - math.floor(frame))
    _upd()
    snap = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy()) for pb in arm.pose.bones}
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location, pb.rotation_quaternion, pb.scale = snap[pb.name]
    _upd()


def rest_pose():
    arm = C.rig()
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    _upd()


def seat_low(body):
    """The body's lowest seat vertex (skinned, the current pose): within 0.2 m of the hips horizontally (the knees and
    shins are ~0.38 m in front of them when seated)."""
    arm = C.rig()
    hips = arm.pose.bones["hips"].head
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    mw = arm.matrix_world.inverted() @ body.matrix_world
    low = 1e9
    for v in me.vertices:
        p = mw @ v.co
        if abs(p.x - hips.x) < 0.2 and abs(p.y - hips.y) < 0.2:
            low = min(low, p.z)
    ev.to_mesh_clear()
    return low


def _kaykit_legs(row):
    """KayKit's own leg rotations at a recorded sit frame (the refit starts from them, not from an earlier refit)."""
    arm = C.rig()
    for n, q in row["leg_rot"].items():
        arm.pose.bones[n].rotation_quaternion = q
    _upd()


def _rekey(action, bones_props, frames_poses):
    """Rewrite these channels of `action` with a key per given frame (the other channels untouched)."""
    paths = {('pose.bones["%s"].%s' % (b, p)) for b, p in bones_props}
    for f in [f for f in action.fcurves if f.data_path in paths]:
        action.fcurves.remove(f)
    arm = C.rig()
    arm.animation_data.action = action
    for fr, pose in frames_poses:
        for b, p in bones_props:
            pb = arm.pose.bones[b]
            setattr(pb, p, pose[b][p])
            pb.keyframe_insert(p, frame=fr, group=b)
    arm.animation_data.action = None


def refit_sit(body_name="Base_Body", seat_y=C.SEAT_Y):
    arm = C.rig()
    _assert_hips_axes(arm)
    body = bpy.data.objects[body_name]
    data = C.load_json(C.SIT_JSON)
    idle_rows = data["clips"]["Sit_Chair_Idle"]["rows"]
    loc0 = idle_rows[0]["hips_loc"]
    # the channel assert, on the recorded KayKit values: location[1] the height (+0.0753), location[2] back (-0.397)
    assert abs(loc0[0]) < 0.005 and abs(loc0[1] - 0.0753) < 0.003 and abs(loc0[2] + C.KAYKIT_SIT_BACK) < 0.003, "KayKit sit channels %s" % loc0
    k = leg_ratio(arm)
    # 1) the seated height: pose Sit_Chair_Idle with its back offset, measure the seat, solve the height
    idle = bpy.data.actions["Sit_Chair_Idle"]
    pose_from(idle, 0)
    _kaykit_legs(idle_rows[0])
    hb = arm.pose.bones["hips"]
    hb.location = (loc0[0], 0.0, loc0[2])
    _upd()
    h_idle = seat_y - seat_low(body)
    print("seated hips height offset %.4f (hips head at %.4f)" % (h_idle, arm.data.bones["hips"].head_local.z + h_idle))
    feet_bones = ("upperleg", "lowerleg", "foot", "toes")
    out = {}
    for clip in C.SIT_CLIPS:
        act = bpy.data.actions[clip]
        rows = {r["frame"]: r for r in data["clips"][clip]["rows"]}
        f_end = act.frame_range[1]
        keys = [f for f in C.frames(act)] + ([f_end] if f_end - math.floor(f_end) > 1e-3 else [])
        poses = []
        for fr in keys:
            r = rows.get(int(math.floor(fr)), rows[max(rows)])
            back = -r["hips_loc"][2]                             # 0 standing .. 0.397 seated
            p = min(1.0, max(0.0, back / C.KAYKIT_SIT_BACK))
            h = r["hips_loc"][1] * k * (1 - p) + h_idle * p
            pose_from(act, fr)
            _kaykit_legs(r)
            arm.pose.bones["hips"].location = (r["hips_loc"][0], h, r["hips_loc"][2])
            _upd()
            # the feet planted where they stand at rest, soles flat, through all three clips (KayKit keeps the root under
            # the feet and slides the hips back onto the seat; its chibi feet dangle 0.23 m up, ours reach the floor)
            for s in ("l", "r"):
                rest_foot = arm.data.bones["foot." + s].matrix_local
                pole = pm("lowerleg." + s).translation + Vector((0, -0.6, 0.1))
                two_bone("upperleg." + s, "lowerleg." + s, "foot." + s, rest_foot.translation, pole)
                f1 = pm("foot." + s)
                set_pm("foot." + s, Matrix.Translation(f1.translation) @ rest_foot.to_3x3().to_4x4())
                arm.pose.bones["toes." + s].rotation_quaternion = (1, 0, 0, 0)
            _upd()
            pose = {"hips": {"location": arm.pose.bones["hips"].location.copy()}}
            for s in ("l", "r"):
                for b in feet_bones:
                    pose[b + "." + s] = {"rotation_quaternion": arm.pose.bones[b + "." + s].rotation_quaternion.copy()}
            poses.append((fr, pose))
        if clip == "Sit_Chair_Idle":
            poses[-1] = (poses[-1][0], poses[0][1])              # the loop's last key repeats its first
        chans = [("hips", "location")] + [(b + "." + s, "rotation_quaternion") for s in ("l", "r") for b in feet_bones]
        _rekey(act, chans, poses)
        act["anime_sit_refit"] = seat_y
        out[clip] = len(poses)
    rest_pose()
    # the result, by FK on the rewritten curves
    cv = C.Curves(idle)
    m = C.fk(arm, cv, 0, ["hips", "upperarm.l", "upperarm.r", "foot.l"])
    sit_hips_y = m["hips"].translation.z
    dn = bpy.data.actions["Sit_Chair_Down"]
    up = bpy.data.actions["Sit_Chair_StandUp"]
    h0 = m["hips"].translation
    d_end = C.fk(arm, C.Curves(dn), dn.frame_range[1], ["hips"])["hips"].translation
    u_0 = C.fk(arm, C.Curves(up), 0, ["hips"])["hips"].translation
    print("refit_sit: %s keys; SIT_HIPS_Y %.4f (Godot model-local y); hips back (armature +y) %.4f; Down ends %.4f / StandUp starts %.4f from the seat pose"
          % (out, sit_hips_y, h0.y, (d_end - h0).length, (u_0 - h0).length))
    return sit_hips_y


# ------------------------------------------------------------------ the foot report and the contact correction

def foot_report(body_name="Base_Body", correct=True):
    arm = C.rig()
    _assert_hips_axes(arm)
    body = bpy.data.objects[body_name]
    pts = C.sole_points(arm, [body])
    fb = sorted({b for s in ("l", "r") for b, _ in pts[s]})
    kk = C.load_json(C.FEET_JSON)["lowest_foot"]
    table = {}
    for act in sorted(bpy.data.actions, key=lambda a: a.name):
        if act.name in C.SIT_CLIPS or act.name not in kk:
            continue
        fr = C.frames(act)
        low = [C.lowest_foot(C.fk(arm, C.Curves(act), f, fb), pts) for f in fr]
        contact = [i for i, f in enumerate(fr) if i < len(kk[act.name]) and kk[act.name][i] <= CONTACT]
        before = max((abs(low[i]) for i in contact), default=0.0)
        after = before
        if correct and before > LIMIT and contact:
            _correct(act, fr, low, contact)
            low2 = [C.lowest_foot(C.fk(arm, C.Curves(act), f, fb), pts) for f in fr]
            after = max(abs(low2[i]) for i in contact)
            act["anime_contact_corrected"] = True
        table[act.name] = (round(before, 4), round(after, 4), len(contact), len(fr))
    over = {c: v for c, v in table.items() if v[1] > LIMIT}
    game = {c: table[c] for c in C.GAME_CLIPS}
    C.save_json(C.BLEND + "anime_base_foot_report.json", {"limit": LIMIT, "contact": CONTACT, "columns": ["before", "after", "contact frames", "frames"],
                                                         "clips": table, "over_after": over})
    print("foot report (clip: before, after, contact frames, frames): game %s" % game)
    print("over %.2f after the correction: %s" % (LIMIT, over))
    return table, over


def _correct(act, fr, low, contact):
    """On contact frames shift the hips height so the lowest foot lands on the floor; interpolate between contacts,
    smooth, keep a loop's ends equal; write a key per frame (and at a fractional end) on hips location[1]."""
    n = len(fr)
    dz = [None] * n
    for i in contact:
        dz[i] = -low[i]
    known = [i for i in range(n) if dz[i] is not None]
    for i in range(n):
        if dz[i] is None:
            a = max([j for j in known if j < i], default=None)
            b = min([j for j in known if j > i], default=None)
            if a is None:
                dz[i] = dz[b]
            elif b is None:
                dz[i] = dz[a]
            else:
                dz[i] = dz[a] + (dz[b] - dz[a]) * (i - a) / (b - a)
    sm = [(dz[max(i - 1, 0)] + 2 * dz[i] + dz[min(i + 1, n - 1)]) / 4 for i in range(n)]
    for i in contact:                                        # contacts land exactly (the smoothing is for the gaps)
        sm[i] = dz[i]
    if act.name in LOOP_CLIPS:
        e = (sm[0] + sm[-1]) / 2
        sm[0] = sm[-1] = e
    fc = next((f for f in act.fcurves if f.data_path == 'pose.bones["hips"].location' and f.array_index == 1), None)
    base = [fc.evaluate(f) if fc else 0.0 for f in fr]
    end = act.frame_range[1]
    tail = end - math.floor(end) > 1e-3
    end_v = (fc.evaluate(end) if fc else 0.0) + (sm[0] if act.name in LOOP_CLIPS else sm[-1])
    if fc is None:
        fc = act.fcurves.new('pose.bones["hips"].location', index=1, action_group="hips")
    while len(fc.keyframe_points):
        fc.keyframe_points.remove(fc.keyframe_points[len(fc.keyframe_points) - 1], fast=True)
    for i, f in enumerate(fr):
        fc.keyframe_points.insert(f, base[i] + sm[i], options={"FAST"})
    if tail:
        fc.keyframe_points.insert(end, end_v, options={"FAST"})
    for kp in fc.keyframe_points:
        kp.interpolation = "LINEAR"
    fc.update()


def seated_room():
    arm = C.rig()
    idle = bpy.data.actions["Sit_Chair_Idle"]
    out = {}
    for f in (0, idle.frame_range[1] / 2):
        m = C.fk(arm, C.Curves(idle), f, ["upperarm.l", "upperarm.r"])
        out[round(f, 1)] = (round(m["upperarm.l"].translation.z, 4), round(m["upperarm.r"].translation.z, 4))
    print("seated room (Sit_Chair_Idle upperarm heads, root-local; >= %.2f): %s" % (C.DESK_TOP + 0.20, out))
    return out
