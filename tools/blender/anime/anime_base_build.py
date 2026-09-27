# anime_base_build.py - route AN step 1 (Story 25.30): the anime base starts from the untouched townsfolk kit.
#   1. open the kit and save it as anime_base.blend BEFORE any change (the kit file is never written)
#   2. record what the stretch will change: KayKit's leg lengths (rig["kaykit_thigh"], rig["kaykit_shin"], read from
#      the rig), its rest (anime_base_kaykit_rest.json), the lowest foot point of a KayKit body on every frame of every
#      clip (anime_base_kaykit_feet.json: the foot report's contact frames) and the Sit_Chair_* hips and feet
#      (anime_base_kaykit_sit.json: refit_sit's only source)
#   3. strip to Rig + the 76 KayKit actions (their muted NLA tracks and fake users), by explicit list
import bpy

import anime_common as C

REF_LEGS = ("Knight_LegLeft", "Knight_LegRight")        # the KayKit body whose soles give the contact frames
LEG_BONES = ("upperleg.l", "lowerleg.l", "foot.l", "upperleg.r", "lowerleg.r", "foot.r")


def open_kit_as_base():
    bpy.ops.wm.open_mainfile(filepath=C.KIT_BLEND)
    arm = bpy.data.objects.get("Rig")
    assert arm and len(arm.data.bones) == 41 and len(bpy.data.actions) == 76, "not the verified kit (Rig, 41 bones, 76 actions)"
    assert "kaykit_thigh" not in arm, "this file is already a base"
    bpy.ops.wm.save_as_mainfile(filepath=C.BASE_BLEND)
    return bpy.data.filepath


def record():
    arm = C.rig()
    b = arm.data.bones
    arm["kaykit_thigh"] = b["upperleg.l"].length
    arm["kaykit_shin"] = b["lowerleg.l"].length
    arm["kaykit_hips_z"] = b["hips"].head_local.z
    C.save_json(C.REST_JSON, {n.name: {"head": list(n.head_local), "tail": list(n.tail_local),
                                       "parent": n.parent.name if n.parent else None} for n in b})
    pts = C.sole_points(arm, [bpy.data.objects[n] for n in REF_LEGS])
    feet_bones = sorted({bone for s in ("l", "r") for bone, _ in pts[s]})
    feet = {}
    for act in sorted(bpy.data.actions, key=lambda a: a.name):
        cv = C.Curves(act)
        feet[act.name] = [round(C.lowest_foot(C.fk(arm, cv, f, feet_bones), pts), 5) for f in C.frames(act)]
    C.save_json(C.FEET_JSON, {"body": list(REF_LEGS), "sole_points": {s: len(pts[s]) for s in pts}, "lowest_foot": feet})
    sit = {}
    names = ["hips", "foot.l", "foot.r", "toes.l", "toes.r", "upperleg.l", "upperleg.r"]
    for clip in C.SIT_CLIPS:
        act = bpy.data.actions[clip]
        cv = C.Curves(act)
        rows = []
        for f in C.frames(act):
            m = C.fk(arm, cv, f, names)
            rows.append({"frame": f,
                         "hips_loc": [cv.value("hips", "location", i, f, 0.0) for i in range(3)],
                         "hips_rot": [cv.value("hips", "rotation_quaternion", i, f, (1, 0, 0, 0)[i]) for i in range(4)],
                         "leg_rot": {n: [cv.value(n, "rotation_quaternion", i, f, (1, 0, 0, 0)[i]) for i in range(4)]
                                     for n in LEG_BONES},
                         "heads": {n: list(m[n].translation) for n in names},
                         "lowest_foot": C.lowest_foot(m, pts)})
        sit[clip] = {"frame_range": list(act.frame_range), "rows": rows}
    C.save_json(C.SIT_JSON, {"hips_rest_z": b["hips"].head_local.z, "clips": sit})
    out = {c: (min(v), max(v)) for c, v in feet.items() if c in C.GAME_CLIPS}
    print("KayKit legs %.4f + %.4f; soles %s; game clips lowest foot (min, max): %s" % (arm["kaykit_thigh"], arm["kaykit_shin"],
          {s: len(pts[s]) for s in pts}, {k: (round(a, 3), round(b_, 3)) for k, (a, b_) in out.items()}))


def strip():
    keep = {"Rig"}
    doomed = [o for o in bpy.data.objects if o.name not in keep]
    data = [o.data for o in doomed if o.data is not None]
    names = [o.name for o in doomed]
    for o in doomed:
        bpy.data.objects.remove(o, do_unlink=True)
    for d in data:
        if d.users == 0:
            if isinstance(d, bpy.types.Mesh):
                bpy.data.meshes.remove(d)
            elif isinstance(d, bpy.types.Camera):
                bpy.data.cameras.remove(d)
    for m in [m for m in bpy.data.materials if m.users == 0]:
        bpy.data.materials.remove(m)
    for im in [i for i in bpy.data.images if i.users == 0]:
        bpy.data.images.remove(im)
    for a in bpy.data.actions:
        a.use_fake_user = True
    arm = C.rig()
    assert len(bpy.data.actions) == 76 and len(arm.animation_data.nla_tracks) == 76
    print("stripped %d objects: %s" % (len(names), names))


def run():
    print("base:", open_kit_as_base())
    record()
    strip()
    bpy.ops.wm.save_mainfile()
    print("saved", bpy.data.filepath)
