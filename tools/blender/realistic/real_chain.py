# real_chain.py - route RL's chain configs (Story 25.31 S1.0; the spike 2026-10-04 is commit 5ae8dc0): the realistic
# bases REAL-1 (a 1.86 m man) and REAL-2 (a 1.70 m woman, a slimmer frame; Raphael's Q1), each a config dict for the
# generic chain code (tools/blender/anime: anime_base_build, anime_rig, anime_retarget, anime_common.open_base_as)
# plus route RL's own steps (real_body.build_base, real_arms.run). Nothing is patched: every step is given its chain
# (or finds it by the rig's stamp, anime_common.chain_of) and writes only that chain's files. Importing this module
# registers REAL-1 and REAL-2 (anime_common.register_chain), so a step run in a realistic file without a chain finds it.
#
# Steps, one MCP call each (a file load leaves a stale context: the step after it goes in its own call):
#   1a open_kit(ch)        the untouched KayKit kit saved as ch's base .blend (refuses an existing base)
#   1b finish(ch)          anime_base_build.finish: KayKit legs, feet, sit and rest recorded (ch's *_kaykit_*.json)
#   2  rig(ch)             anime_rig.run(chain=ch): the rest pose to ch's table; the handslot at the palm; stamped
#   3  base_body(ch)       Base_Body: REAL-1's neutral body (real_body.build_base); on REAL-2 the same parts built on
#                          REAL-1's recorded rest and carried onto REAL-2's (real_body.transfer_rest: lengths, girths,
#                          bust). REAL-1's rest is recorded once by record_rest(REAL_1) (in REAL-1's base)
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
# and hand bones x 0.92; the body slimmer (girth below), a bust.
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
              rig_rest_json=BLEND + "realistic_base_rig_rest.json",     # REAL-1's rest (record_rest): REAL-2's source
              base_body=None)

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
              base_body={
                  "src_chain": "REAL-1",
                  # the girth across each bone, (local X, local Z): torso and head X across, Z front-back; limbs both
                  # across; the feet keep their height (Z 1.0: the soles stay on the floor)
                  "girth": {"hips": (0.93, 0.88), "spine": (0.80, 0.72), "chest": (0.872, 0.84), "head": (0.92, 0.92),
                            "upperarm.l": (0.82, 0.82), "upperarm.r": (0.82, 0.82),
                            "lowerarm.l": (0.84, 0.84), "lowerarm.r": (0.84, 0.84),
                            "wrist.l": (0.90, 0.90), "wrist.r": (0.90, 0.90), "hand.l": (0.90, 0.90), "hand.r": (0.90, 0.90),
                            "upperleg.l": (0.92, 0.92), "upperleg.r": (0.92, 0.92),
                            "lowerleg.l": (0.88, 0.88), "lowerleg.r": (0.88, 0.88),
                            "foot.l": (0.90, 1.0), "foot.r": (0.90, 1.0), "toes.l": (0.90, 1.0), "toes.r": (0.90, 1.0)},
                  # the trunk fitted to a woman's silhouette on REAL-2's rest (real_body.fit_profile): half-widths,
                  # and depths in front of / behind the spine line (y 0); hips widest at 0.84, the waist at 1.00-1.04
                  "profile": {"width": [(0.80, 0.180), (0.84, 0.190), (0.88, 0.185), (0.92, 0.170), (0.96, 0.150),
                                        (1.00, 0.135), (1.04, 0.133), (1.08, 0.138), (1.12, 0.148), (1.20, 0.160),
                                        (1.28, 0.170), (1.34, 0.180)],
                              "front": [(0.80, 0.100), (0.84, 0.115), (0.88, 0.120), (0.92, 0.115), (0.96, 0.110),
                                        (1.00, 0.105), (1.08, 0.105), (1.12, 0.110), (1.20, 0.120), (1.28, 0.125),
                                        (1.34, 0.120)],
                              "back": [(0.80, 0.120), (0.84, 0.135), (0.88, 0.130), (0.92, 0.110), (0.96, 0.090),
                                       (1.00, 0.085), (1.08, 0.085), (1.20, 0.095), (1.28, 0.100), (1.34, 0.100)]},
                  # (amplitude m, (x, z) centre on the new rest, sigma m): REAL-1's chest line z 1.36 on REAL-2
                  "bust": (0.045, (0.085, _z2(1.36)), 0.055)})

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
    """ch's rig rest (real_body.rest_record) -> ch["rig_rest_json"]: the source REAL-2's Base_Body is built on. Only
    in ch's own finished-rig base; refuses to overwrite a different record (the rest never changes after step 2)."""
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
    if not ch.get("base_body"):
        return RB.build_base()
    src = CHAINS[ch["base_body"]["src_chain"]]
    tr = dict(ch["base_body"], src_rest=C.load_json(src["rig_rest_json"]))
    return RB.build_base(transfer=tr)


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
