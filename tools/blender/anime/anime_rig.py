# anime_rig.py - chain step 2 (Story 25.30; every chain since 25.31 S1.0): stretch the KayKit rig's REST pose to a
# chain's table (anime_common.AN: anime SD proportions; real_chain.REAL_1 / REAL_2: realistic adults).
# Every bone keeps its KayKit direction and roll; only heads and lengths change, so the 76 clips (FK-keyed rotations;
# the IK and control bones are inert, no constraints) still read on the new limbs. It runs ONCE per chain build, on
# the fresh save-as of the kit (anime_base_build): directions are read from the bones as they are, i.e. KayKit's.
# The one allowed exception: an optional adduction of the whole arm chain (adduct_deg, <= 15), rigid about the
# upperarm head, so only the upper arm's rest relative to the chest changes.
#
# A chain's table: bone -> (head, length) for hips, spine, chest, head, upperarm.l, lowerarm.l (head None: at the
# upper arm's tail), optionally wrist.l and hand.l (None or absent: KayKit's own lengths), upperleg.l (length None: to
# knee_z); the legs end on KayKit's own ankle (the foot rig stays). The handslot sits at the palm (chain["palm"]).
# AN's table is N2's candidate B (Raphael's T0 sheet, 2026-09-27): the approved anime test's rig with 0.08 m shorter
# legs and a 0.10 m longer torso, so she sits with her shoulders 0.22 m above the guild desk. Top about 2.14 m.
import math

import bpy
from mathutils import Matrix, Vector

import anime_common as C

TABLE = C.AN["table"]        # route AN's (kept under its old names)
KNEE_Z = C.AN["knee_z"]
ADDUCT_DEG = C.AN["adduct_deg"]


def _mirror(p, sx):
    return Vector((p[0] * sx, p[1], p[2]))


def run(adduct_deg=None, chain=C.AN):
    table, knee_z = chain["table"], chain["knee_z"]
    adduct_deg = chain["adduct_deg"] if adduct_deg is None else adduct_deg
    assert 0.0 <= adduct_deg <= 15.0
    assert C.is_open(chain["base_blend"]), "open chain %s's base first (%r)" % (chain["name"], bpy.data.filepath)
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

    def length_of(n, s):
        """wrist / hand: the table's length, else KayKit's x chain["hand_scale"] (REAL-2), else KayKit's (None)."""
        row = table.get(n + ".l")
        if row:
            return row[1]
        if chain.get("hand_scale"):
            return (old[n + "." + s][1] - old[n + "." + s][0]).length * chain["hand_scale"]
        return None

    for n in ("hips", "spine", "chest", "head"):
        put(n, Vector(table[n][0]), table[n][1])
    palm_from, palm_dir, palm_along, palm_down = chain["palm"]
    for s, sx in (("l", 1.0), ("r", -1.0)):
        e = put("upperarm." + s, _mirror(table["upperarm.l"][0], sx), table["upperarm.l"][1])
        w = put("lowerarm." + s, e, table["lowerarm.l"][1])
        h = put("wrist." + s, w, length_of("wrist", s))
        put("hand." + s, h, length_of("hand", s))
        # N6: the handslot re-seated at the palm's centre (KayKit's sat 0.11 m out, past a chibi fist), its axes kept
        put("handslot." + s, eb[palm_from + "." + s].head + d(palm_dir + "." + s) * palm_along + Vector((0.0, 0.0, palm_down)))
        hip = _mirror(table["upperleg.l"][0], sx)
        k = put("upperleg." + s, hip, (hip.z - knee_z) / -d("upperleg." + s).z)
        a = put("lowerleg." + s, k, (k.z - old["lowerleg." + s][1].z) / -d("lowerleg." + s).z)   # the ankle lands on KayKit's
        f = put("foot." + s, a, vec=old["foot." + s][1] - old["foot." + s][0])
        put("toes." + s, f, vec=old["toes." + s][1] - old["toes." + s][0])
        # the inert IK and control bones follow their joints (tidiness only: nothing drives them)
        put("kneeIK." + s, k + (old["kneeIK." + s][0] - old["upperleg." + s][1]))
        put("elbowIK." + s, e + (old["elbowIK." + s][0] - old["upperarm." + s][1]))
        put("handIK." + s, w + (old["handIK." + s][0] - old["lowerarm." + s][1]))
        da = a - old["lowerleg." + s][1]                       # the foot rig moves with the ankle (0 in z: it stays)
        for c in ("control-toe-roll.", "control-heel-roll.", "control-foot-roll.", "heelIK.", "IK-foot.", "IK-toe."):
            n = c + s
            put(n, old[n][0] + Vector((da.x, da.y, da.z)))
        if adduct_deg > 0.0:
            # rigid about the upperarm head, toward the body: a rotation about the front axis (armature Y). Right-handed
            # about +Y, x' = x cos + z sin, z' = -x sin + z cos: a positive angle takes +X down, so the left arm (+X,
            # sx 1) lowers at +adduct_deg and the right (-X, sx -1) at -adduct_deg. (Was -adduct_deg * sx, which raised
            # both; ADDUCT_DEG is 0.0, so the shipped base never ran this branch.)
            piv = eb["upperarm." + s].head.copy()
            R = Matrix.Rotation(math.radians(adduct_deg * sx), 4, "Y")
            for n in ("upperarm.", "lowerarm.", "wrist.", "hand.", "handslot.", "elbowIK.", "handIK."):
                b = eb[n + s]
                roll_axis = b.z_axis.copy()
                b.head = piv + (R @ (b.head - piv))
                b.tail = piv + (R @ (b.tail - piv))
                b.align_roll(R.to_3x3() @ roll_axis)
    bpy.ops.object.mode_set(mode="OBJECT")
    arm["anime_rig"] = chain["stamp"]
    for k, v in chain.get("extra_stamps", {}).items():
        arm[k] = v
    arm["anime_adduct_deg"] = adduct_deg
    rows = []
    for n in ("hips", "spine", "chest", "head", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l", "upperleg.l",
              "lowerleg.l", "foot.l", "toes.l"):
        b = arm.data.bones[n]
        rows.append("%-11s head (%.4f, %.4f, %.4f) len %.4f" % ((n,) + tuple(b.head_local) + (b.length,)))
    print("\n".join(rows))
    return rows
