# real_chain.py - route RL's chain configs (Story 25.31 S1.0; the spike 2026-10-04 is commit 5ae8dc0): the realistic
# bases REAL-1 (a 1.86 m man) and REAL-2 (a 1.70 m woman, a slimmer frame; Raphael's Q1), each a config dict for the
# generic chain code (tools/blender/anime: anime_base_build, anime_rig, anime_retarget, anime_common.open_base_as)
# plus route RL's own steps (real_body.build_neutral, real_arms.run). Nothing is patched: every step is given its chain
# (or finds it by the rig's stamp, anime_common.chain_of) and writes only that chain's files. Importing this module
# registers REAL-1 and REAL-2 (anime_common.register_chain), so a step run in a realistic file without a chain finds it.
#
# Steps, one MCP call each (a file load leaves a stale context: the step after it goes in its own call):
#   1a open_kit(ch)        the untouched KayKit kit saved as ch's base .blend (refuses an existing base)
#   1b finish(ch)          anime_base_build.finish: KayKit legs, feet, sit and rest recorded (ch's *_kaykit_*.json)
#   2  rig(ch)             anime_rig.run(chain=ch): the rest pose to ch's table; the handslot at the palm; stamped
#   3  base_body(ch)       Base_Body: the neutral mannequin (real_body.build_neutral(ch["body"])), built straight on
#                          the open rig: REAL-1 an average man, REAL-2 a woman (25.31 S1.0 v2, after Raphael's "not
#                          really much of a woman ... a bit thick on the belly side" on the spike-derived bodies)
#   4  ratio(ch)           anime_retarget.ratio_step: hips + root location keys x the leg ratio (never twice)
#   5  sit(ch)             anime_retarget.refit_sit("Base_Body", chain=ch): the sit clips for the 0.45 m chairs
#                          (R-5: bar stools get a foot ring at seat - 0.45); prints SIT_HIPS_Y. Repeatable
#   6  feet(ch)            anime_retarget.foot_report: the 76-clip foot report + contact correction, stamped
#   7  arms(ch)            real_arms.run: the arm pass on the game clips (ARM_CLIPS), from the recorded source arms
#                          (ch's *_arm_src.json); repeatable
#   8  open_base_as(p, ch) the finished base saved as a character's file (every stamp of 2, 4, 5, 6, 7 required)
#
# REAL-1's table: a 1.86 m man measured off Raphael's chosen concept sheet (realistic_test/ref_bartender_concept.png,
# 714 px crown to sole -> 2.605 mm/px): crown 1.86, chin ~1.61, shoulder joints 1.48, belt 1.03, hip joints 0.95, knees
# 0.51, KayKit's own ankle (0.145, so the foot rig stays). ~7.35 heads (the sheet's own proportion).
# REAL-2's table: REAL-1's heights scaled about KayKit's ankle by K2 = (1.70 - 0.145) / (1.86 - 0.145) (crown 1.70,
# the ankle and the foot rig kept), shoulder joints 0.170 off the midline (0.195 x 0.872), hip joints 0.095, wrist
# and hand bones x 0.92. Each base's body is its own params ("body" below, in that rig's metres).
import os

import bpy

import anime_common as C

BLEND = C.BLEND
ANKLE = 0.145                     # KayKit's own ankle height (lowerleg tail): every chain keeps it
ARM_CLIPS = ("Idle", "Walking_A", "Running_A", "Sit_Chair_Down", "Sit_Chair_Idle", "Sit_Chair_StandUp", "Cheer", "Interact")
SEAT_Y = 0.45                     # R-5 / AC 3b: the realistic sits fit the 0.45 m table chairs


def _files(stem):
    return C.chain_files(BLEND + stem + ".blend", BLEND + stem + "_kaykit_feet.json", BLEND + stem + "_kaykit_sit.json",
                         BLEND + stem + "_kaykit_rest.json", BLEND + stem + "_foot_report.json")


# ------------------------------------------------------------------ the neutral bodies (real_body.build_neutral)
# trunk rows: (z, half-width, front y, back y, superellipse n front, n back), y 0 = the hip joints' line (front -y);
# neck rows (z, half-width, front y, back y); upperarm / forearm rows (t along the bone, r up, r front-back) in the
# T-pose rest; leg rows (z, r front-back, r across, y offset: + is back, the calf); head: the analytic head's scale
# about its pivot, width on top, the jaw narrowed, brow ridge and nose multipliers; boot: real_body.BOOT's keys.
# Girth is a character's own param: "belly" (amp m, z, sigma z, sigma x), "trunk_scale" (x, y); the bases have none.
MAN = {"name": "REAL-1 neutral man", "skin": "C4A084",
       "trunk": [(0.855, 0.105, -0.060, 0.080, 2.2, 2.2), (0.885, 0.158, -0.094, 0.114, 2.3, 2.3),
                 (0.940, 0.181, -0.106, 0.130, 2.4, 2.4), (0.985, 0.180, -0.108, 0.126, 2.4, 2.4),
                 (1.040, 0.170, -0.110, 0.110, 2.4, 2.4), (1.100, 0.160, -0.112, 0.097, 2.4, 2.4),
                 (1.160, 0.161, -0.114, 0.097, 2.4, 2.4), (1.220, 0.167, -0.122, 0.103, 2.4, 2.4),
                 (1.280, 0.175, -0.132, 0.111, 2.4, 2.4), (1.340, 0.181, -0.139, 0.115, 2.4, 2.4),
                 (1.400, 0.186, -0.136, 0.115, 2.4, 2.4), (1.450, 0.186, -0.126, 0.108, 2.4, 2.4),
                 (1.495, 0.172, -0.110, 0.096, 2.3, 2.3), (1.530, 0.145, -0.097, 0.082, 2.2, 2.2),
                 (1.560, 0.108, -0.088, 0.062, 2.1, 2.1), (1.590, 0.076, -0.082, 0.044, 2.0, 2.0)],
       "neck": [(1.50, 0.074, -0.094, 0.040), (1.56, 0.071, -0.090, 0.032), (1.62, 0.066, -0.088, 0.024),
                (1.67, 0.060, -0.084, 0.016)],
       "head": {"scale": 1.0, "width": 0.94, "jaw": 0.0, "brow": 1.0, "nose": 1.0},
       "upperarm": [(-0.22, 0.060, 0.064), (0.0, 0.065, 0.068), (0.20, 0.059, 0.060), (0.45, 0.053, 0.054),
                    (0.70, 0.049, 0.049), (0.93, 0.043, 0.045)],
       "forearm": [(0.08, 0.042, 0.047), (0.28, 0.046, 0.051), (0.55, 0.039, 0.045), (0.82, 0.029, 0.036),
                   (1.00, 0.023, 0.031), (1.06, 0.022, 0.030)],
       "hand": 1.0,
       "leg": [(1.000, 0.060, 0.060, 0.000), (0.945, 0.086, 0.080, -0.002), (0.910, 0.088, 0.086, -0.004),
               (0.810, 0.081, 0.081, -0.006),
               (0.710, 0.072, 0.072, -0.006), (0.610, 0.061, 0.060, -0.003), (0.535, 0.053, 0.053, 0.000),
               (0.480, 0.050, 0.050, 0.004), (0.420, 0.054, 0.052, 0.012), (0.360, 0.052, 0.050, 0.012),
               (0.300, 0.045, 0.043, 0.008), (0.240, 0.038, 0.036, 0.004), (0.175, 0.034, 0.032, 0.000)],
       "boot": None}                                         # REAL-1's boots: the spike's (real_body.BOOT)

WOMAN = {"name": "REAL-2 neutral woman", "skin": "C4A084",
         "trunk": [(0.775, 0.090, -0.050, 0.065, 2.1, 2.1), (0.805, 0.165, -0.086, 0.112, 2.2, 2.2),
                   (0.860, 0.192, -0.098, 0.128, 2.2, 2.2), (0.900, 0.191, -0.099, 0.124, 2.2, 2.2),
                   (0.940, 0.179, -0.097, 0.110, 2.2, 2.2), (0.980, 0.158, -0.095, 0.092, 2.2, 2.2),
                   (1.020, 0.137, -0.093, 0.080, 2.2, 2.2), (1.060, 0.127, -0.093, 0.076, 2.2, 2.2),
                   (1.100, 0.130, -0.097, 0.080, 2.2, 2.2), (1.140, 0.136, -0.104, 0.086, 2.2, 2.2),
                   (1.180, 0.141, -0.110, 0.091, 2.2, 2.2), (1.220, 0.145, -0.113, 0.094, 2.2, 2.2),
                   (1.260, 0.149, -0.112, 0.096, 2.2, 2.2), (1.300, 0.151, -0.106, 0.096, 2.2, 2.2),
                   (1.335, 0.148, -0.098, 0.092, 2.2, 2.2), (1.365, 0.138, -0.090, 0.084, 2.1, 2.1),
                   (1.390, 0.118, -0.082, 0.074, 2.0, 2.0), (1.410, 0.094, -0.074, 0.062, 2.0, 2.0),
                   (1.428, 0.070, -0.068, 0.050, 2.0, 2.0), (1.440, 0.056, -0.064, 0.040, 2.0, 2.0)],
         "bust": (0.036, 0.072, 1.235, 0.052, 0.036),        # (amp m, x, z, sigma across / above, sigma below)
         "neck": [(1.36, 0.062, -0.078, 0.040), (1.42, 0.054, -0.074, 0.028), (1.47, 0.051, -0.074, 0.018),
                  (1.53, 0.049, -0.072, 0.012)],
         "head": {"scale": 0.93, "width": 0.94, "jaw": 0.10, "brow": 0.3, "nose": 0.6},
         "upperarm": [(-0.22, 0.044, 0.047), (0.0, 0.046, 0.049), (0.20, 0.043, 0.044), (0.45, 0.039, 0.040),
                      (0.70, 0.036, 0.036), (0.93, 0.032, 0.034)],
         "forearm": [(0.08, 0.032, 0.036), (0.28, 0.035, 0.039), (0.55, 0.029, 0.034), (0.82, 0.022, 0.028),
                     (1.00, 0.018, 0.025), (1.06, 0.018, 0.024)],
         "hand": 0.86,
         "leg": [(0.925, 0.060, 0.060, 0.000), (0.880, 0.086, 0.094, -0.001), (0.840, 0.088, 0.098, -0.002),
                 (0.760, 0.075, 0.081, -0.004),
                 (0.680, 0.065, 0.066, -0.004), (0.580, 0.054, 0.054, -0.002), (0.500, 0.046, 0.047, 0.000),
                 (0.450, 0.044, 0.044, 0.004), (0.400, 0.047, 0.045, 0.010), (0.350, 0.045, 0.043, 0.010),
                 (0.300, 0.039, 0.037, 0.006), (0.250, 0.033, 0.031, 0.003), (0.200, 0.029, 0.028, 0.000),
                 (0.170, 0.028, 0.027, 0.000)],
         "boot": {"length": 0.84, "width": 0.86, "height": 0.88, "girth": 0.72, "top": 0.25, "cuff": False}}

ARM_PASS = {"clips": ARM_CLIPS,
            "gap": 0.03,          # the forearm / hand / elbow kept this far (m) outside the body beside it
            "max_deg": 45.0,      # never more than this toward the body per frame
            "lift": (0.05, 0.30),  # full pass when the hand is >= 0.30 below the shoulder, none above 0.05 below (Cheer's raised arms)
            "window": 0.035,      # the body points beside an arm point: within this (m) of it front-back and up-down
            "midline": 0.06}      # an arm point with no body beside it (in front of the belly) stays gap outside this

REAL_1 = dict(_files("realistic_base"), name="REAL-1", stamp="REAL-1",
              table={
                  # bone: (head, length); the arms and legs mirror to .r. Heads in Blender rest (front -Y, left +X, up Z).
                  "hips": ((0.0, 0.0, 0.900), 0.170),
                  "spine": ((0.0, 0.0, 1.070), 0.250),
                  "chest": ((0.0, -0.010, 1.320), 0.240),
                  "head": ((0.0, -0.050, 1.580), 0.240),       # the neck's pivot; the concept's head sits forward of the spine line
                  "upperarm.l": ((0.195, 0.0, 1.480), 0.300),
                  "lowerarm.l": (None, 0.270),
                  "upperleg.l": ((0.100, 0.0, 0.950), None)},
              knee_z=0.510,
              # handslot: 0.080 along the forearm from the wrist joint, 0.026 toward the palm (-Z rest)
              palm=("wrist", "lowerarm", 0.080, -0.026),
              adduct_deg=0.0, extra_stamps={"real_rig": "REAL-1"},
              seat_y=SEAT_Y, arm_pass=ARM_PASS,
              arm_src_json=BLEND + "realistic_base_arm_src.json",
              rig_rest_json=BLEND + "realistic_base_rig_rest.json",     # REAL-1's rest (record_rest)
              body=MAN)

K2 = (1.70 - ANKLE) / (1.86 - ANKLE)


def _z2(z):
    return ANKLE + (z - ANKLE) * K2


REAL_2 = dict(_files("realistic_base_w"), name="REAL-2", stamp="REAL-2",
              table={
                  "hips": ((0.0, 0.0, _z2(0.900)), 0.170 * K2),
                  "spine": ((0.0, 0.0, _z2(1.070)), 0.250 * K2),
                  "chest": ((0.0, -0.010 * K2, _z2(1.320)), 0.240 * K2),
                  "head": ((0.0, -0.050 * K2, _z2(1.580)), 0.240 * K2),
                  "upperarm.l": ((0.170, 0.0, _z2(1.480)), 0.300 * K2),
                  "lowerarm.l": (None, 0.270 * K2),
                  "upperleg.l": ((0.095, 0.0, _z2(0.950)), None)},
              knee_z=_z2(0.510),
              hand_scale=0.92,                                  # the wrist and hand bones (KayKit's lengths x 0.92)
              palm=("wrist", "lowerarm", 0.080 * 0.92, -0.026 * 0.92),
              adduct_deg=0.0, extra_stamps={"real_rig": "REAL-2"},
              seat_y=SEAT_Y, arm_pass=ARM_PASS,
              arm_src_json=BLEND + "realistic_base_w_arm_src.json",
              body=WOMAN)

CHAINS = {c["name"]: c for c in (REAL_1, REAL_2)}
for _c in (REAL_1, REAL_2):
    C.register_chain(_c)

# the spike's names (real_bartender and older notes)
REAL_BASE, RIG_STAMP, TABLE, KNEE_Z = REAL_1["base_blend"], REAL_1["stamp"], REAL_1["table"], REAL_1["knee_z"]


def _on_base(ch):
    assert C.is_open(ch["base_blend"]), "open chain %s's base first (%r)" % (ch["name"], bpy.data.filepath)
    assert C.rig().get("anime_rig") in (None, ch["stamp"]), "this base's rig is %r" % C.rig().get("anime_rig")


def open_kit(ch):
    import anime_base_build as B
    return B.open_kit(ch)


def finish(ch):
    import anime_base_build as B
    return B.finish(ch)


def rig(ch):
    import anime_rig as R
    _on_base(ch)
    return R.run(chain=ch)


def record_rest(ch=REAL_1):
    """ch's rig rest (real_body.rest_record) -> ch["rig_rest_json"] (real_body.transfer_rest's source; REAL-2's v1 body
    was built on it, the v2 bodies are not). Only in ch's own finished-rig base; refuses to overwrite a different record
    (the rest never changes after step 2)."""
    import real_body as RB
    _on_base(ch)
    assert C.rig().get("anime_rig") == ch["stamp"], "run rig() first"
    rec = RB.rest_record(C.rig())
    path = ch["rig_rest_json"]
    if os.path.exists(path):
        old = C.load_json(path)
        same = old.keys() == rec.keys() and all(max(abs(a - b) for a, b in zip(old[n]["matrix"], rec[n]["matrix"])) < 1e-6
                                                  for n in rec)
        assert same, "%s holds a different rest: the base's rig changed?" % path
        print("rest record unchanged:", path)
        return path
    C.save_json(path, rec)
    print("rest recorded:", path, len(rec), "bones")
    return path


def base_body(ch):
    import real_body as RB
    _on_base(ch)
    assert C.rig().get("anime_rig") == ch["stamp"], "run rig() first"
    return RB.build_neutral(ch["body"])


def ratio(ch):
    import anime_retarget as RT
    _on_base(ch)
    assert C.rig().get("anime_rig") == ch["stamp"]
    return RT.ratio_step()


def sit(ch, body="Base_Body"):
    import anime_retarget as RT
    _on_base(ch)
    return RT.refit_sit(body, chain=ch)


def feet(ch, correct=True, body="Base_Body"):
    import anime_retarget as RT
    _on_base(ch)
    return RT.foot_report(body, correct=correct, chain=ch)


def arms(ch, body="Base_Body"):
    import real_arms as RA
    _on_base(ch)
    return RA.run(ch, body)


def open_base_as(path, ch=REAL_1, overwrite_ok=False):
    return C.open_base_as(path, overwrite_ok=overwrite_ok, chain=ch)
