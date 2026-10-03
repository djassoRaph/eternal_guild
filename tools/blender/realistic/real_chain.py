# real_chain.py - the REALISTIC-proportion spike (2026-10-04, Raphael: "realistic proportions, gritty cel-shaded"):
# route AN's chain (tools/blender/anime/README.md) run for a realistic adult man, into NEW files only. Nothing in the
# anime pipeline is edited: this module points anime_common's chain paths at realistic_* files (import-time patch of
# the module object, so every anime_* step that reads C.BASE_BLEND / C.FEET_JSON / ... uses them) and guards
# C.save_json so no anime_base_* file can be written from a call that imported this module.
#
# Steps, one MCP call each (a file load leaves a stale context):
#   1a open_kit()        the untouched KayKit kit saved as realistic_base.blend
#   1b finish()          anime_base_build.finish(): KayKit legs, feet, sit and rest recorded (realistic_base_kaykit_*.json)
#   2  rig()             the rest pose stretched to TABLE (below); handslot at the palm's centre; stamped REAL-1
#   3  base_body()       Base_Body: the realistic neutral body (real_body.build_base), the foot report's reference
#   4  ratio()           anime_retarget.ratio_step(): hips + root location keys x the leg ratio
#   5  sit()             anime_retarget.refit_sit("Base_Body") (optional for the Bartender: he never sits)
#   6  feet()            anime_retarget.foot_report(): the 76-clip foot report -> realistic_base_foot_report.json
#   7  open_base_as(p)   the base saved as a character's file (stamps of 2, 4, 6 required; 5 reported, not required)
#
# The table: a 1.86 m man measured off Raphael's chosen concept sheet (realistic_test/ref_bartender_concept.png,
# 714 px crown to sole -> 2.605 mm/px): crown 1.86, chin ~1.61, shoulder joints 1.48, belt 1.03, hip joints 0.95,
# knees 0.51, KayKit's own ankle (0.145, so the foot rig stays). ~7.35 heads (the sheet's own proportion).
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

import anime_common as C

BLEND = C.BLEND
REAL_BASE = BLEND + "realistic_base.blend"
REAL_FEET = BLEND + "realistic_base_kaykit_feet.json"
REAL_SIT = BLEND + "realistic_base_kaykit_sit.json"
REAL_REST = BLEND + "realistic_base_kaykit_rest.json"
REAL_FOOT_REPORT = BLEND + "realistic_base_foot_report.json"
RIG_STAMP = "REAL-1"

# ------------------------------------------------------------------ the patch (import time; idempotent)
if not getattr(C, "_realistic_patched", False):
    C._anime_save_json = C.save_json

    def _guarded_save_json(path, data):
        base = os.path.basename(path)
        if base == "anime_base_foot_report.json":           # anime_retarget.foot_report's hard-coded name
            path = REAL_FOOT_REPORT
        elif not os.path.basename(path).startswith("realistic_"):
            raise RuntimeError("realistic chain: refusing to write %s (only realistic_* files)" % path)
        return C._anime_save_json(path, data)

    C.save_json = _guarded_save_json
    C._realistic_patched = True
C.BASE_BLEND = REAL_BASE
C.FEET_JSON = REAL_FEET
C.SIT_JSON = REAL_SIT
C.REST_JSON = REAL_REST

TABLE = {
    # bone: (head, length); the arms and legs mirror to .r. Heads in Blender rest (front -Y, left +X, up Z).
    "hips": ((0.0, 0.0, 0.900), 0.170),
    "spine": ((0.0, 0.0, 1.070), 0.250),
    "chest": ((0.0, -0.010, 1.320), 0.240),
    "head": ((0.0, -0.050, 1.580), 0.240),       # the neck's pivot; the concept's head sits forward of the spine line
    "upperarm.l": ((0.195, 0.0, 1.480), 0.300),
    "lowerarm.l": (None, 0.270),
    "upperleg.l": ((0.100, 0.0, 0.950), None),
}
KNEE_Z = 0.510
PALM = (0.080, -0.026)       # handslot: this far along the arm from the wrist joint, this far toward the palm (-Z rest)


def open_kit():
    import anime_base_build as B
    assert not os.path.exists(REAL_BASE), "%s exists: delete it by hand to rebuild the realistic base" % REAL_BASE
    return B.open_kit()


def finish():
    import anime_base_build as B
    return B.finish()


def rig():
    """Chain step 2 for the realistic table (anime_rig.run's method: directions and rolls kept, heads and lengths set)."""
    arm = C.rig()
    assert C.is_open(REAL_BASE), "open realistic_base.blend first (%r)" % bpy.data.filepath
    assert "kaykit_thigh" in arm and "anime_rig" not in arm, "run once, on the fresh base (finish() first)"
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    old = {b.name: (b.head.copy(), b.tail.copy(), b.roll) for b in eb}

    def d(n):
        h, t, _ = old[n]
        return (t - h).normalized()

    def put(n, head, length=None, vec=None):
        b = eb[n]
        v = vec if vec is not None else d(n) * (length if length is not None else (old[n][1] - old[n][0]).length)
        b.use_connect = False
        b.head = head
        b.tail = head + v
        b.roll = old[n][2]
        return b.tail.copy()

    for n in ("hips", "spine", "chest", "head"):
        put(n, Vector(TABLE[n][0]), TABLE[n][1])
    for s, sx in (("l", 1.0), ("r", -1.0)):
        ua = TABLE["upperarm.l"][0]
        e = put("upperarm." + s, Vector((ua[0] * sx, ua[1], ua[2])), TABLE["upperarm.l"][1])
        w = put("lowerarm." + s, e, TABLE["lowerarm.l"][1])
        h = put("wrist." + s, w)
        put("hand." + s, h)
        # the slot at the palm's centre (KayKit's sat 0.11 m out, past a chibi fist), its axes kept
        put("handslot." + s, w + d("lowerarm." + s) * PALM[0] + Vector((0.0, 0.0, PALM[1])))
        hip = Vector((TABLE["upperleg.l"][0][0] * sx, TABLE["upperleg.l"][0][1], TABLE["upperleg.l"][0][2]))
        k = put("upperleg." + s, hip, (hip.z - KNEE_Z) / -d("upperleg." + s).z)
        a = put("lowerleg." + s, k, (k.z - old["lowerleg." + s][1].z) / -d("lowerleg." + s).z)   # KayKit's ankle height
        f = put("foot." + s, a, vec=old["foot." + s][1] - old["foot." + s][0])
        put("toes." + s, f, vec=old["toes." + s][1] - old["toes." + s][0])
        put("kneeIK." + s, k + (old["kneeIK." + s][0] - old["upperleg." + s][1]))
        put("elbowIK." + s, e + (old["elbowIK." + s][0] - old["upperarm." + s][1]))
        put("handIK." + s, w + (old["handIK." + s][0] - old["lowerarm." + s][1]))
        da = a - old["lowerleg." + s][1]
        for c in ("control-toe-roll.", "control-heel-roll.", "control-foot-roll.", "heelIK.", "IK-foot.", "IK-toe."):
            n = c + s
            put(n, old[n][0] + da)
    bpy.ops.object.mode_set(mode="OBJECT")
    arm["anime_rig"] = RIG_STAMP
    arm["real_rig"] = RIG_STAMP
    arm["anime_adduct_deg"] = 0.0
    rows = []
    for n in ("hips", "spine", "chest", "head", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l", "upperleg.l",
              "lowerleg.l", "foot.l", "toes.l"):
        b = arm.data.bones[n]
        rows.append("%-11s head (%.3f, %.3f, %.3f) len %.3f" % ((n,) + tuple(b.head_local) + (b.length,)))
    print("\n".join(rows))
    return rows


def base_body():
    import real_body as RB
    assert C.is_open(REAL_BASE)
    return RB.build_base()


def ratio():
    import anime_retarget as RT
    assert C.is_open(REAL_BASE) and C.rig().get("real_rig") == RIG_STAMP
    return RT.ratio_step()


def sit():
    import anime_retarget as RT
    assert C.is_open(REAL_BASE)
    return RT.refit_sit("Base_Body")


def feet():
    import anime_retarget as RT
    assert C.is_open(REAL_BASE)
    return RT.foot_report("Base_Body")


def open_base_as(path, overwrite_ok=False):
    assert C.norm_path(path) != C.norm_path(REAL_BASE)
    assert overwrite_ok or not os.path.exists(path), "%s exists (overwrite_ok=True to rebuild)" % path
    bpy.ops.wm.open_mainfile(filepath=REAL_BASE)
    arm = bpy.data.objects["Rig"]
    assert arm.get("real_rig") == RIG_STAMP and any("anime_leg_ratio" in a for a in bpy.data.actions), "not a finished realistic base"
    assert "anime_foot_report" in arm, "no foot report on the realistic base"
    unfit = [n for n in C.SIT_CLIPS if "anime_sit_refit" not in bpy.data.actions[n]]
    if unfit:
        print("note: %s not re-fitted for the 0.44 m seats (the Bartender never sits)" % unfit)
    bpy.ops.wm.save_as_mainfile(filepath=path)
    return bpy.data.filepath
