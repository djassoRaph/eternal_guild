# real_arms.py - route RL's arm pass at the base (Story 25.31 S1.0, AC 3b): KayKit's clips hold the arms 35-60
# degrees out from a chibi body; on an adult they read as a wrestler's. Once per base, for the game clips (the chain's
# arm_pass["clips"]: Idle, Walking_A, Running_A, the three Sit_Chair clips, Cheer, Interact), every key frame's upper
# arm is turned toward the body about the chest's front-back axis through the shoulder: the whole arm moves in the
# chest's frontal plane, so its forward / back swing, its height and the elbow bend stay KayKit's (the timing reads the
# same), and it stops `gap` outside the body beside it (the base's Base_Body, posed in that frame: the torso, pelvis and
# legs within `window` of each forearm / hand / elbow point front-back and up-down). Raised hands (Cheer) are left as
# they are (`lift`). Only the upperarm.l / upperarm.r rotation channels are rewritten (a key per frame); everything
# else, the stamps included, stays. Each pass starts from the source arms recorded the first time (the chain's
# arm_src_json), so it is repeatable and never compounds. Stamped act["real_arm_pass"] = gap.
# report(ch) re-measures the clearance (the same measure) per clip.
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

import anime_common as C
import anime_retarget as RT

SIDES = (("l", 1.0), ("r", -1.0))
BODY_BONES = ("hips", "spine", "chest", "upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r", "root")
ELBOW_FROM = 0.67                # upper-arm points this far from the shoulder joint (x the upper arm's length) count: the elbow end
LOOPS = ("Idle", "Walking_A", "Running_A", "Sit_Chair_Idle")


def _keys(act):
    f_end = act.frame_range[1]
    return [float(f) for f in C.frames(act)] + ([f_end] if f_end - math.floor(f_end) > 1e-3 else [])


def _dominant(body):
    names = {g.index: g.name for g in body.vertex_groups}
    out = []
    for v in body.data.vertices:
        ws = [(g.weight, names[g.group]) for g in v.groups if g.weight > 1e-4]
        out.append(max(ws)[1] if ws else "")
    return out


def _source(ch, clips):
    """The source upper-arm rotations per clip and key frame: recorded on the first pass (before any action carries the
    stamp), read back on every later one."""
    path = ch["arm_src_json"]
    if os.path.exists(path):
        src = C.load_json(path)
        assert src.get("chain") == ch["stamp"] and all(c in src["clips"] for c in clips), "%s: not this chain's arms" % path
        return src
    stamped = [c for c in clips if "real_arm_pass" in bpy.data.actions[c]]
    assert not stamped, "%s carry the arm pass but %s is missing: rebuild the base" % (stamped, path)
    src = {"chain": ch["stamp"], "clips": {}}
    for c in clips:
        act = bpy.data.actions[c]
        cv = C.Curves(act)
        rows = []
        for f in _keys(act):
            rows.append([f] + [[cv.value("upperarm." + s, "rotation_quaternion", i, f, (1.0, 0.0, 0.0, 0.0)[i]) for i in range(4)]
                               for s, _ in SIDES])
        src["clips"][c] = rows
    C.save_json(path, src)
    print("arm pass: source arms recorded ->", path)
    return src


def _pose(act, row):
    RT.pose_from(act, row[0])
    arm = C.rig()
    for (s, _), q in zip(SIDES, row[1:]):
        arm.pose.bones["upperarm." + s].rotation_quaternion = q
    RT._upd()


def _frame_points(body, dom):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    mw = C.rig().matrix_world.inverted() @ body.matrix_world
    co = np.array([(mw @ v.co)[:] for v in me.vertices])
    ev.to_mesh_clear()
    return co


def _chest_frame():
    """(rotation posed-armature <- chest-rest-aligned axes, i.e. x across, y back, z up as at rest)."""
    arm = C.rig()
    rest = arm.data.bones["chest"].matrix_local.to_3x3()
    return arm.pose.bones["chest"].matrix.to_3x3() @ rest.inverted()


def _sets(dom, side):
    arm_bones = {"lowerarm." + side, "wrist." + side, "hand." + side}
    a = np.array([d in arm_bones for d in dom])
    u = np.array([d == "upperarm." + side for d in dom])
    b = np.array([d in BODY_BONES for d in dom])
    return a, u, b


def clearance(A, B, sx, window, midline=None):
    """The least lateral clearance (m) of arm points A over the body points B beside them (both in the chest frame):
    A.x*sx minus the outermost B.x*sx within `window` front-back and up-down; an arm point with no body beside it (in
    front of the belly, say) is measured against `midline` (m off the chest's midline; None: unconstrained). +inf when
    nothing constrains any arm point."""
    if len(A) == 0:
        return float("inf")
    if len(B):
        dy = np.abs(A[:, None, 1] - B[None, :, 1]) < window
        dz = np.abs(A[:, None, 2] - B[None, :, 2]) < window
        bx = np.where(dy & dz, B[None, :, 0] * sx, -np.inf).max(axis=1)
    else:
        bx = np.full(len(A), -np.inf)
    if midline is not None:
        bx = np.maximum(bx, midline)
    return float((A[:, 0] * sx - bx).min())


def _rot(A, gamma, sx):
    """A turned by gamma toward the body about the y axis (x' = x cos + z sin for the left arm; mirrored)."""
    c, s_ = math.cos(gamma), math.sin(gamma)
    x, z = A[:, 0] * sx, A[:, 2]
    out = A.copy()
    out[:, 0] = (x * c + z * s_) * sx
    out[:, 2] = -x * s_ + z * c
    return out


def _solve(A, B, sx, p, w, mid):
    """The largest turn in [0, max_deg * w] keeping the clearance >= gap (bisection; 0 if KayKit's arm is already closer).
    mid: the midline limit in the shoulder-relative frame (_midline)."""
    def ok(g):
        return clearance(_rot(A, g, sx) if g else A, B, sx, p["window"], mid) >= p["gap"]
    hi = math.radians(p["max_deg"]) * w
    if hi <= 0.0 or not ok(0.0):
        return 0.0
    if ok(hi):
        return hi
    lo = 0.0
    for _ in range(18):
        m = (lo + hi) / 2
        if ok(m):
            lo = m
        else:
            hi = m
    return lo


def _midline(p, S, Rinv, sx):
    """p["midline"] (m off the chest's midline) in the shoulder-relative chest frame of arm points."""
    arm = C.rig()
    off = (Rinv @ (S - arm.pose.bones["chest"].head)).x * sx
    return p["midline"] - off


def _arm_points(co, sets, S, Rinv):
    a, u, b = sets
    P = (co - np.array(S[:])) @ np.array(Rinv).T            # chest-frame, shoulder at the origin
    far = np.linalg.norm(P, axis=1) > ELBOW_FROM * C.rig().data.bones["upperarm.l"].length   # its root always meets the armpit
    A, B = P[a | (u & far)], P[b]
    if len(A):
        # only body points that can ever be beside an arm point (the turn keeps y; z stays within the arm's reach)
        reach = float(np.linalg.norm(A, axis=1).max()) + 0.05
        B = B[(B[:, 1] > A[:, 1].min() - 0.05) & (B[:, 1] < A[:, 1].max() + 0.05) & (B[:, 2] > -reach) & (B[:, 2] < A[:, 2].max() + 0.05)]
    return A, B


def _measure_frame(act, row, body, dom, p):
    """Per side: (turn allowed, lift weight, the current clearance) for the pose `row` of `act`."""
    _pose(act, row)
    arm = C.rig()
    co = _frame_points(body, dom)
    R = _chest_frame()
    Rinv = R.inverted()
    out = []
    for s, sx in SIDES:
        S = arm.pose.bones["upperarm." + s].head
        A, B = _arm_points(co, _sets(dom, s), S, Rinv)
        hand = Rinv @ (arm.pose.bones["handslot." + s].head - S)
        lo, hi = p["lift"]
        w = min(1.0, max(0.0, (-hand.z - lo) / (hi - lo)))
        mid = _midline(p, S, Rinv, sx)
        out.append((_solve(A, B, sx, p, w, mid), w, clearance(A, B, sx, p["window"], mid)))
    return out


def _smooth(vals, loop):
    """1-2-1 smoothing of the per-frame turns (a loop wraps), never past a frame's own allowed turn; a loop's ends equal."""
    n = len(vals)
    if n < 3:
        return list(vals)
    if loop:                                                  # the last key repeats the first: wrap over the n - 1 frames
        m = n - 1
        sm = [(vals[(i - 1) % m] + 2 * vals[i % m] + vals[(i + 1) % m]) / 4 for i in range(n)]
    else:
        sm = [(vals[max(i - 1, 0)] + 2 * vals[i] + vals[min(i + 1, n - 1)]) / 4 for i in range(n)]
    sm = [min(a, b) for a, b in zip(sm, vals)]
    if loop:
        sm[0] = sm[-1] = min(sm[0], sm[-1])
    return sm


def run(ch, body_name="Base_Body"):
    p = ch["arm_pass"]
    assert p, "chain %s has no arm pass" % ch["name"]
    assert C.is_open(ch["base_blend"]), "the arm pass runs at the base (%s)" % ch["base_blend"]
    arm = C.rig()
    assert arm.get("anime_rig") == ch["stamp"]
    clips = list(p["clips"])
    src = _source(ch, clips)
    body = bpy.data.objects[body_name]
    dom = _dominant(body)
    report = {}
    for c in clips:
        act = bpy.data.actions[c]
        rows = src["clips"][c]
        assert [r[0] for r in rows] == _keys(act), "%s: the key frames changed since the source was recorded" % c
        meas = [_measure_frame(act, r, body, dom, p) for r in rows]
        loop = c in LOOPS
        g = {s: _smooth([m[i][0] for m in meas], loop) for i, (s, _) in enumerate(SIDES)}
        poses = []
        for k, r in enumerate(rows):
            _pose(act, r)
            R = _chest_frame()
            axis = R @ Vector((0.0, 1.0, 0.0))
            for s, sx in SIDES:
                ang = g[s][k] * sx
                if ang:
                    RT.rotate_about("upperarm." + s, Matrix.Rotation(ang, 3, axis), pivot=arm.pose.bones["upperarm." + s].head.copy())
            poses.append((r[0], {"upperarm." + s: {"rotation_quaternion": arm.pose.bones["upperarm." + s].rotation_quaternion.copy()}
                                 for s, _ in SIDES}))
        RT._rekey(act, [("upperarm.l", "rotation_quaternion"), ("upperarm.r", "rotation_quaternion")], poses)
        act["real_arm_pass"] = p["gap"]
        report[c] = {s: (round(math.degrees(min(g[s])), 1), round(math.degrees(max(g[s])), 1)) for s, _ in SIDES}
        report[c]["clear_before"] = round(min(min(m[0][2], m[1][2]) for m in meas), 4)
    RT.rest_pose()
    C.drop_cached_clouds()
    for c, r in report.items():
        print("arm pass %-17s turn deg l %s r %s; least clearance before %.4f" % (c, r["l"], r["r"], r["clear_before"]))
    return report


def report(ch, body_name="Base_Body"):
    """Per clip: the least clearance (m) of the forearms / hands / elbows to the body beside them, both sides, every
    key frame, and the Idle frame-0 hand slots' distance off the midline (the chest frame)."""
    p = ch["arm_pass"]
    body = bpy.data.objects[body_name]
    dom = _dominant(body)
    arm = C.rig()
    out = {}
    for c in p["clips"]:
        act = bpy.data.actions[c]
        worst = float("inf")
        for f in _keys(act):
            RT.pose_from(act, f)
            co = _frame_points(body, dom)
            Rinv = _chest_frame().inverted()
            for s, sx in SIDES:
                S = arm.pose.bones["upperarm." + s].head
                A, B = _arm_points(co, _sets(dom, s), S, Rinv)
                worst = min(worst, clearance(A, B, sx, p["window"], _midline(p, S, Rinv, sx)))
        out[c] = round(worst, 4)
    RT.pose_from(bpy.data.actions["Idle"], 0)
    Rinv = _chest_frame().inverted()
    ch_head = arm.pose.bones["chest"].head
    out["idle_hand_x"] = [round((Rinv @ (arm.pose.bones["handslot." + s].head - ch_head)).x * sx, 3) for s, sx in SIDES]
    RT.rest_pose()
    print("arm clearance (least, m):", out)
    return out
