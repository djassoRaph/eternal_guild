# anime_rig.py - route AN step 2 (Story 25.30): stretch the KayKit rig's REST pose to anime SD proportions.
# Every bone keeps its KayKit direction and roll; only heads and lengths change, so the 76 clips (FK-keyed rotations;
# the IK and control bones are inert, no constraints) still read on the new limbs. It runs ONCE per chain build, on
# the fresh save-as of the kit (anime_base_build): directions are read from the bones as they are, i.e. KayKit's.
# The one allowed exception: an optional adduction of the whole arm chain (ADDUCT_DEG, <= 15), rigid about the
# upperarm head, so only the upper arm's rest relative to the chest changes.
#
# The table is N2's candidate B (Raphael's T0 sheet, 2026-09-27): the approved anime test's rig with 0.08 m shorter
# legs and a 0.10 m longer torso, so she sits with her shoulders 0.22 m above the guild desk. Top about 2.14 m.
import math

import bpy
from mathutils import Matrix, Vector

import anime_common as C

TABLE = {
    # bone: (head, length); the arms and legs mirror to .r
    "hips": ((0.0, 0.0, 0.742), 0.198),
    "spine": ((0.0, 0.0, 0.940), 0.280),
    "chest": ((0.0, 0.0, 1.220), 0.250),
    "head": ((0.0, 0.0, 1.487), 0.251),
    "upperarm.l": ((0.16, 0.0, 1.38), 0.30),
    "lowerarm.l": (None, 0.28),               # None: at its parent's tail
    "upperleg.l": ((0.105, 0.0, 0.843), None),  # None length: to the knee / the ankle (below)
}
KNEE_Z = 0.466            # thigh ~0.377, shin ~0.326 to KayKit's own ankle (legs ~0.70; the approved test had 0.78)
ADDUCT_DEG = 0.0          # optional, decided in T2's renders


def run(adduct_deg=ADDUCT_DEG):
    assert 0.0 <= adduct_deg <= 15.0
    arm = C.rig()
    assert "kaykit_thigh" in arm and "anime_rig" not in arm, "run once, on the fresh base (anime_base_build)"
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
        e = put("upperarm." + s, Vector((TABLE["upperarm.l"][0][0] * sx, 0.0, TABLE["upperarm.l"][0][2])), TABLE["upperarm.l"][1])
        w = put("lowerarm." + s, e, TABLE["lowerarm.l"][1])
        h = put("wrist." + s, w)
        put("hand." + s, h)
        # N6: the handslot re-seated in the new (smaller) hand, at the palm's centre, keeping its axes; the hand mesh
        # is built round it (anime_kit.build_hand). KayKit's slot sat 0.11 m out, beyond an anime hand
        put("handslot." + s, eb["hand." + s].head + d("hand." + s) * 0.010 + Vector((0.0, 0.0, -0.004)))
        hip = Vector((TABLE["upperleg.l"][0][0] * sx, 0.0, TABLE["upperleg.l"][0][2]))
        k = put("upperleg." + s, hip, (hip.z - KNEE_Z) / -d("upperleg." + s).z)
        a = put("lowerleg." + s, k, (k.z - old["lowerleg." + s][1].z) / -d("lowerleg." + s).z)   # the ankle lands on KayKit's
        f = put("foot." + s, a, vec=old["foot." + s][1] - old["foot." + s][0])
        put("toes." + s, f, vec=old["toes." + s][1] - old["toes." + s][0])
        # the inert IK and control bones follow their joints (tidiness only: nothing drives them)
        put("kneeIK." + s, k + (old["kneeIK." + s][0] - old["upperleg." + s][1]))
        put("elbowIK." + s, e + (old["elbowIK." + s][0] - old["upperarm." + s][1]))
        put("handIK." + s, w + (old["handIK." + s][0] - old["lowerarm." + s][1]))
        dz = a.z - old["lowerleg." + s][1].z                  # the foot rig moves with the ankle (0 here: it stays)
        for c in ("control-toe-roll.", "control-heel-roll.", "control-foot-roll.", "heelIK.", "IK-foot.", "IK-toe."):
            n = c + s
            put(n, old[n][0] + Vector((a.x - old["lowerleg." + s][1].x, a.y - old["lowerleg." + s][1].y, dz)))
        if adduct_deg > 0.0:
            # rigid about the upperarm head, toward the body: a rotation about the front axis (armature Y)
            piv = eb["upperarm." + s].head.copy()
            R = Matrix.Rotation(math.radians(-adduct_deg * sx), 4, "Y")
            for n in ("upperarm.", "lowerarm.", "wrist.", "hand.", "handslot.", "elbowIK.", "handIK."):
                b = eb[n + s]
                roll_axis = b.z_axis.copy()
                b.head = piv + (R @ (b.head - piv))
                b.tail = piv + (R @ (b.tail - piv))
                b.align_roll(R.to_3x3() @ roll_axis)
    bpy.ops.object.mode_set(mode="OBJECT")
    arm["anime_rig"] = "N2-B"
    arm["anime_adduct_deg"] = adduct_deg
    rows = []
    for n in ("hips", "spine", "chest", "head", "upperarm.l", "lowerarm.l", "hand.l", "handslot.l", "upperleg.l", "lowerleg.l", "foot.l", "toes.l"):
        b = arm.data.bones[n]
        rows.append("%-11s head (%.3f, %.3f, %.3f) len %.3f" % ((n,) + tuple(b.head_local) + (b.length,)))
    print("\n".join(rows))
    return rows
