# anime_common.py - route AN (Story 25.30): what the anime pipeline scripts share. Imported inside Blender 4.5
# (exec'd through the Blender MCP server; see README.md for the runner pattern).
#
# Frames: Blender armature space is front -Y, left +X, up +Z. Godot (x, y, z) = Blender (x, z, -y).
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

ART = "F:/GAME I AM MAKING/eternal_guild_art/"
BLEND = ART + "blender/"
SHOTS = ART + "shots/staff/anime/"
KIT_BLEND = BLEND + "g19_g24_townsfolk_kit.blend"      # the verified KayKit rig + 76 clips (Story 25.14): never modified
BASE_BLEND = BLEND + "anime_base.blend"
FEET_JSON = BLEND + "anime_base_kaykit_feet.json"
SIT_JSON = BLEND + "anime_base_kaykit_sit.json"
REST_JSON = BLEND + "anime_base_kaykit_rest.json"
SIT_CLIPS = ("Sit_Chair_Down", "Sit_Chair_Idle", "Sit_Chair_StandUp")
GAME_CLIPS = ("Idle", "Walking_A", "Running_A", "Cheer", "Interact")   # FT CAST_CLIPS minus the Sit_Chair_* clips
SEAT_Y = 0.44                                           # every seat in the game: bar stools, the desk stool
DESK_TOP = 0.85                                         # the guild desk's top, root-local when seated
KAYKIT_SIT_BACK = 0.397                                 # KayKit's Sit_Chair_Idle hips, back from the root (armature +Y)
TEXTURES = ART + "textures/anime/"
SCRATCH_TEXTURES = TEXTURES + "scratch/"                # regression rebuilds write here, never over a shipped PNG (25.31 V3)


# ------------------------------------------------------------------ chain configs (25.31 S1.0)
# A chain is one base built from the untouched KayKit kit: its files, its rest-pose table and its stamps. The generic
# steps (anime_base_build, anime_rig, anime_retarget, open_base_as) take a chain and touch only that chain's files;
# nothing patches this module. AN (below) is route AN's anime base; route RL's REAL-1 / REAL-2 live in
# tools/blender/realistic/real_chain.py and are registered with register_chain(). A step that is not given a chain
# finds it by the rig's stamp (rig["anime_rig"]); a stamp nobody registered refuses.

def chain_files(base_blend, feet_json, sit_json, rest_json, foot_report_json):
    return {"base_blend": base_blend, "feet_json": feet_json, "sit_json": sit_json, "rest_json": rest_json,
            "foot_report_json": foot_report_json}


AN = dict(chain_files(BASE_BLEND, FEET_JSON, SIT_JSON, REST_JSON, BLEND + "anime_base_foot_report.json"),
          name="AN", stamp="N2-B",
          # the rest-pose table (anime_rig.run): N2's candidate B. bone: (head, length); arms and legs mirror to .r;
          # None: at the parent's tail / to the knee (knee_z) / KayKit's own length
          table={"hips": ((0.0, 0.0, 0.742), 0.198), "spine": ((0.0, 0.0, 0.940), 0.280),
                 "chest": ((0.0, 0.0, 1.220), 0.250), "head": ((0.0, 0.0, 1.487), 0.251),
                 "upperarm.l": ((0.16, 0.0, 1.38), 0.30), "lowerarm.l": (None, 0.28),
                 "upperleg.l": ((0.105, 0.0, 0.843), None)},
          knee_z=0.466,
          # the handslot at the palm: (from the head of bone, along the direction of bone, this far, this far down)
          palm=("hand", "hand", 0.010, -0.004),
          adduct_deg=0.0, extra_stamps={},
          seat_y=SEAT_Y,              # refit_sit's seat (every AN seat is 0.44)
          arm_pass=None)              # route AN keeps KayKit's arms


CHAINS = {AN["stamp"]: AN}


def register_chain(chain):
    """Make a chain findable by its rig stamp (real_chain registers REAL-1 / REAL-2). A stamp is one chain's."""
    old = CHAINS.get(chain["stamp"])
    assert old is None or old["base_blend"] == chain["base_blend"], "stamp %s is already chain %s" % (chain["stamp"], old["name"])
    CHAINS[chain["stamp"]] = chain
    return chain


def scratch_chain(chain, folder, prefix):
    """A copy of `chain` whose every file is `folder/prefix...` (a regression rebuild of a whole base; never
    registered: pass it to each step explicitly, and a step that falls back to the stamp writes nothing of it)."""
    out = dict(chain)
    out.update(chain_files(folder + prefix + ".blend", folder + prefix + "_kaykit_feet.json",
                           folder + prefix + "_kaykit_sit.json", folder + prefix + "_kaykit_rest.json",
                           folder + prefix + "_foot_report.json"))
    out["name"] = chain["name"] + "-scratch"
    if chain.get("arm_src_json"):
        out["arm_src_json"] = folder + prefix + "_arm_src.json"
    return out


def chain_of(arm=None, chain=None):
    """The chain of the open file's rig (by its stamp); a given chain must carry that stamp."""
    arm = arm or rig()
    stamp = arm.get("anime_rig")
    if chain is not None:
        assert stamp is None or stamp == chain["stamp"], "this rig is %r, not chain %s's %r" % (stamp, chain["name"], chain["stamp"])
        return chain
    if stamp not in CHAINS:
        raise RuntimeError("no chain registered for the rig stamp %r (import real_chain for REAL-1 / REAL-2)" % stamp)
    return CHAINS[stamp]


def rig():
    return bpy.data.objects["Rig"]


def norm_path(p):
    return os.path.normcase(os.path.normpath(os.path.abspath(p)))


def is_open(path):
    """The open .blend is `path` (case and slash insensitive)."""
    return bool(bpy.data.filepath) and norm_path(bpy.data.filepath) == norm_path(path)


def open_base_as(role_blend_path, overwrite_ok=False, chain=AN):
    """Chain step 7 for any role: the chain's base (AN: anime_base.blend) saved as the role's own .blend, once the base
    carries every chain step's stamp (rig, ratio, sit re-fit at the chain's seat, foot report, the arm pass if the
    chain has one). A file load: the next step goes in its own call. Refuses the base's own path, and an existing file
    unless overwrite_ok (N5: a rebuild over a shipped file is a decision)."""
    assert norm_path(role_blend_path) != norm_path(chain["base_blend"]), "open_base_as: the base itself is not a role file"
    assert overwrite_ok or not os.path.exists(role_blend_path), \
        "open_base_as: %s exists (pass overwrite_ok=True to rebuild it)" % role_blend_path
    bpy.ops.wm.open_mainfile(filepath=chain["base_blend"])
    arm = bpy.data.objects["Rig"]
    assert arm.get("anime_rig") == chain["stamp"], "not chain %s's base (rig %r)" % (chain["name"], arm.get("anime_rig"))
    assert any("anime_leg_ratio" in a for a in bpy.data.actions), "not a finished base"
    unfit = [n for n in SIT_CLIPS if abs(bpy.data.actions[n].get("anime_sit_refit", -1.0) - chain["seat_y"]) > 1e-6]
    assert not unfit, "not a finished base: %s not re-fitted for the %.2f m seat (anime_retarget.refit_sit)" % (unfit, chain["seat_y"])
    assert "anime_foot_report" in arm, "not a finished base: no foot report / contact correction (anime_retarget.foot_report)"
    if chain.get("arm_pass"):
        unpassed = [n for n in chain["arm_pass"]["clips"] if "real_arm_pass" not in bpy.data.actions[n]]
        assert not unpassed, "not a finished base: %s without the arm pass (real_arms.run)" % unpassed
    os.makedirs(os.path.dirname(role_blend_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=role_blend_path)
    return bpy.data.filepath


def to_godot(p):
    return Vector((p.x, p.z, -p.y))


def save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def drop_cached_clouds():
    """anime_clearcheck caches a point cloud per (clip, frame): anything that rewrites a clip or the body calls this
    (the live module, if it is loaded; a reload starts it empty anyway)."""
    cc = sys.modules.get("anime_clearcheck")
    if cc is not None:
        cc.clear_cache()


# ------------------------------------------------------------------ forward kinematics from an action's curves

class Curves:
    """An action's pose channels, evaluated without touching the scene (no depsgraph, no frame_set)."""

    def __init__(self, action):
        self.action = action
        self.fc = {}
        for f in action.fcurves:
            if f.data_path.startswith('pose.bones["'):
                bone = f.data_path.split('"')[1]
                prop = f.data_path.rsplit(".", 1)[1]
                self.fc[(bone, prop, f.array_index)] = f

    def value(self, bone, prop, i, frame, default):
        f = self.fc.get((bone, prop, i))
        return f.evaluate(frame) if f else default

    def basis(self, bone, frame):
        loc = Vector([self.value(bone, "location", i, frame, 0.0) for i in range(3)])
        q = Quaternion([self.value(bone, "rotation_quaternion", i, frame, (1.0, 0.0, 0.0, 0.0)[i]) for i in range(4)])
        s = [self.value(bone, "scale", i, frame, 1.0) for i in range(3)]
        return Matrix.Translation(loc) @ q.normalized().to_matrix().to_4x4() @ Matrix.Diagonal((s[0], s[1], s[2], 1.0))


def fk(arm, curves, frame, names):
    """Armature-space pose matrices of `names` (and their parents) at `frame`, as Blender poses them (no constraints:
    KayKit's IK and control bones are inert)."""
    cache = {}

    def mat(name):
        if name in cache:
            return cache[name]
        b = arm.data.bones[name]
        basis = curves.basis(name, frame) if curves else Matrix.Identity(4)
        m = (mat(b.parent.name) @ (b.parent.matrix_local.inverted() @ b.matrix_local) if b.parent else b.matrix_local) @ basis
        cache[name] = m
        return m

    return {n: mat(n) for n in names}


def frames(action):
    a, b = action.frame_range
    return list(range(int(math.floor(a)), int(math.floor(b)) + 1))


# ------------------------------------------------------------------ the soles: rigid points in their bones' rest frames

def sole_points(arm, objs, band=0.03):
    """The lowest vertices (within `band` of each foot's lowest) of meshes skinned to foot/toes, each stored in its
    dominant bone's rest frame, so a pose's lowest foot point is min_z(M_bone @ p) (the sole is rigid)."""
    inv = arm.matrix_world.inverted()
    pts = {"l": [], "r": []}
    for ob in objs:
        names = {g.index: g.name for g in ob.vertex_groups}
        mw = inv @ ob.matrix_world
        cand = {"l": [], "r": []}
        for v in ob.data.vertices:
            ws = [(g.weight, names[g.group]) for g in v.groups if g.weight > 1e-4]
            if not ws:
                continue
            w, bone = max(ws)
            if bone.split(".")[0] not in ("foot", "toes"):
                continue
            cand[bone[-1]].append((mw @ v.co, bone))
        for s in ("l", "r"):
            if not cand[s]:
                continue
            low = min(p.z for p, _ in cand[s])
            for p, bone in cand[s]:
                if p.z <= low + band:
                    pts[s].append((bone, arm.data.bones[bone].matrix_local.inverted() @ p))
    return pts


def lowest_foot(mats, pts):
    return min((mats[b] @ p).z for s in ("l", "r") for b, p in pts[s])


# ------------------------------------------------------------------ renders (through a camera; never the viewport)

def shot(path, target, yaw, elev, ortho, res, cam_name="AN_cam"):
    sc = bpy.context.scene
    cam = bpy.data.objects.get(cam_name)
    if cam is None:
        cam = bpy.data.objects.new(cam_name, bpy.data.cameras.new(cam_name))
        sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.data.clip_end = 100.0
    a, e = math.radians(yaw), math.radians(elev)
    t = Vector(target)
    cam.location = t + 8.0 * Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.view_settings.view_transform = "Standard"
    sh = sc.display.shading
    sh.light = "FLAT"
    sh.color_type = "TEXTURE"
    sh.show_object_outline = True
    sh.object_outline_color = (0.10, 0.06, 0.08)
    sc.render.film_transparent = False
    w = sc.world or bpy.data.worlds.new("AN_world")
    sc.world = w
    w.color = (0.60, 0.50, 0.40)
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path
