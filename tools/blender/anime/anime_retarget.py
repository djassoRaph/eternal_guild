# anime_retarget.py - route AN step 4 (Story 25.30): the 76 KayKit clips on the stretched rig.
#   ratio_step()   the hips and root location keys scaled by the leg ratio (anime thigh + shin over KayKit's, read from
#                  rig["kaykit_thigh"/"kaykit_shin"]); every other deform bone's location curve reported, left as is;
#                  each action stamped act["anime_leg_ratio"]. Refuses a stamped file: it is never run twice; refuses
#                  a rig anime_rig.run hasn't stretched (rig["anime_rig"]): the ratio would be 1.0 and lock the clips.
#   refit_sit()    Sit_Chair_Down / Idle / StandUp rewritten absolutely from anime_base_kaykit_sit.json: KayKit's back
#                  offset kept (0 -> 0.397 m, unscaled: RealisticPatron's SIT_HIP_BACK 0.40 stays true), the height
#                  solved so the body's lowest seat vertex rests on the 0.44 m seat, the feet planted by two-bone leg IK;
#                  since 25.31 iterated (seat solve -> foot IK -> re-measure on the stored clip, until |error| < 0.002;
#                  over 0.01 refuses) and measured on body vertices only (seat_verts: skin, leggings, pelvis; never a
#                  robe's hem). Repeatable (never scales), not blocked by the stamp; prints SIT_HIPS_Y (Test 19's
#                  AN_SIT_HIPS_Y, from the post-IK clip). Refuses a file that already has a role's own clips (actions
#                  ratio_step never stamped) unless rebuild_ok=True: then re-run the role's build_clips.
#   foot_report()  every clip, every frame KayKit's own foot is down (contact), the body's lowest foot within 0.03 m of
#                  the floor; over the limit, a hips-height contact correction (smoothed); a before/after table;
#                  the rig stamped rig["anime_foot_report"] (anime_dealer.open_base_as_dealer checks it).
#   seated_room()  the upperarm heads in Sit_Chair_Idle (frame 0 and mid), root-local: >= 1.05 (the desk top + 0.20).
# Chains (25.31 S1.0): refit_sit and foot_report read the chain's recorded KayKit JSONs (anime_common.chain_of: the
# rig's stamp, or the chain passed in) and refit_sit's default seat is the chain's (AN 0.44, RL 0.45); foot_report
# writes the chain's foot report JSON only when the open file IS that chain's base (else pass `out`).
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
    assert "anime_rig" in arm, "the rig isn't stretched: run anime_rig.run() first (else the ratio is 1.0 and the clips lock unscaled)"
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
                b = arm.data.bones.get(bone)
                if bone not in SKIP_REPORT and b is not None and b.use_deform:
                    peak = max(abs(kp.co[1]) for kp in f.keyframe_points) if len(f.keyframe_points) else 0.0
                    if peak > report.get(bone, (0.0, ""))[0]:
                        report[bone] = (peak, act.name)
        act["anime_leg_ratio"] = k
    rows = sorted(report.items(), key=lambda kv: -kv[1][0])
    print("leg ratio %.4f; hips + root location keys scaled in %d actions" % (k, len(bpy.data.actions)))
    print("other deform-bone location offsets (left unscaled), %d bones:" % len(rows))
    for b, (p, a) in rows:
        print("  %-12s %.3f (%s)" % (b, p, a))
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


def seat_low(body, verts=None):
    """The body's lowest seat vertex (skinned, the current pose): within 0.2 m of the hips horizontally (the knees and
    shins are ~0.38 m in front of them when seated). verts: the vertex indices allowed to sit (the body's own skin,
    leggings and pelvis; a robe's hem hangs and must never set the seat); None: every vertex (Base_Body is all skin)."""
    arm = C.rig()
    hips = arm.pose.bones["hips"].head
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    mw = arm.matrix_world.inverted() @ body.matrix_world
    allowed = None if verts is None else set(verts)
    low = None
    for v in me.vertices:
        if allowed is not None and v.index not in allowed:
            continue
        p = mw @ v.co
        if abs(p.x - hips.x) < 0.2 and abs(p.y - hips.y) < 0.2:
            low = p.z if low is None else min(low, p.z)
    ev.to_mesh_clear()
    if low is None:
        raise RuntimeError("seat_low: no vertex of %s within 0.2 m of the hips (wrong body, or not skinned to Rig?)" % body.name)
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


SEAT_TOL = 0.002            # refit_sit iterates until the stored clip's seat is this close to the seat top
SEAT_GATE = 0.01            # ... and refuses beyond this after MAX_ITER rounds
MAX_ITER = 10                # the error roughly halves per round (a 0.50 m seat: 0.0345 -> 0.0019 in 5)


def refit_sit(body_name="Base_Body", seat_y=None, rebuild_ok=False, seat_verts=None, chain=None):
    arm = C.rig()
    _assert_hips_axes(arm)
    chain = C.chain_of(arm, chain)
    seat_y = chain["seat_y"] if seat_y is None else seat_y
    # a role's own clips (anime_anims.build_clips) are the actions ratio_step never stamped; some are built from the
    # sit clips (the dealer's Write / Brief), so a re-fit under them needs the role's clips rebuilt after it
    own = sorted(a.name for a in bpy.data.actions if "anime_leg_ratio" not in a)
    if own and not rebuild_ok:
        raise RuntimeError("%s: a role's own clips (anime_anims.build_clips) exist: refit_sit(..., rebuild_ok=True), "
                           "then re-run the role's build_clips()" % own)
    body = bpy.data.objects[body_name]
    data = C.load_json(chain["sit_json"])
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
    h_idle = seat_y - seat_low(body, seat_verts)
    print("seated hips height offset %.4f (hips head at %.4f), KayKit's legs" % (h_idle, arm.data.bones["hips"].head_local.z + h_idle))
    # 2) rewrite the clips with the feet planted (the IK moves the thighs, so the seat moves): re-measure on the stored
    # clip and correct the height until the seat is within SEAT_TOL
    for it in range(1, MAX_ITER + 1):
        out = _refit_clips(data, k, h_idle, seat_y)
        pose_from(idle, 0)
        seat_after = seat_low(body, seat_verts)
        err = seat_y - seat_after
        print("refit_sit round %d: hips offset %.4f -> stored clip's seat low %.4f (error %+.4f)" % (it, h_idle, seat_after, err))
        if abs(err) < SEAT_TOL:
            break
        h_idle += err
    rest_pose()
    if abs(err) > SEAT_GATE:
        raise RuntimeError("refit_sit: the seat is %.4f m off after %d rounds (gate %.2f): the clips are rewritten but wrong" % (err, it, SEAT_GATE))
    return _refit_result(arm, idle, out, seat_after, seat_y, own)


def _refit_clips(data, k, h_idle, seat_y):
    """The three sit clips rewritten for this seated hips height (KayKit's own leg rotations, the feet planted)."""
    arm = C.rig()
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
    return out


def _refit_result(arm, idle, out, seat_after, seat_y, own):
    C.drop_cached_clouds()
    # the result, by FK on the rewritten curves
    cv = C.Curves(idle)
    m = C.fk(arm, cv, 0, ["hips", "upperarm.l", "upperarm.r", "foot.l"])
    sit_hips_y = m["hips"].translation.z
    dn = bpy.data.actions["Sit_Chair_Down"]
    up = bpy.data.actions["Sit_Chair_StandUp"]
    h0 = m["hips"].translation
    d_end = C.fk(arm, C.Curves(dn), dn.frame_range[1], ["hips"])["hips"].translation
    u_0 = C.fk(arm, C.Curves(up), 0, ["hips"])["hips"].translation
    print("refit_sit: %s keys; SIT_HIPS_Y %.4f (Godot model-local y); seat low re-measured on the stored clip %.4f (seat %.2f); "
          "hips back (armature +y) %.4f; Down ends %.4f / StandUp starts %.4f from the seat pose"
          % (out, sit_hips_y, seat_after, seat_y, h0.y, (d_end - h0).length, (u_0 - h0).length))
    if own:
        print("refit_sit: %s were built from the old sit clips: re-run the role's build_clips() now" % own)
    return sit_hips_y


# ------------------------------------------------------------------ the foot report and the contact correction

def foot_report(body_name="Base_Body", correct=True, chain=None, out=None):
    arm = C.rig()
    _assert_hips_axes(arm)
    chain = C.chain_of(arm, chain)
    if out is None:
        assert C.is_open(chain["base_blend"]), "foot_report: not chain %s's base: pass out= (never its base's JSON)" % chain["name"]
        out = chain["foot_report_json"]
    body = bpy.data.objects[body_name]
    pts = C.sole_points(arm, [body])
    fb = sorted({b for s in ("l", "r") for b, _ in pts[s]})
    kk = C.load_json(chain["feet_json"])["lowest_foot"]
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
    arm["anime_foot_report"] = LIMIT
    C.save_json(out, {"limit": LIMIT, "contact": CONTACT, "columns": ["before", "after", "contact frames", "frames"],
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
