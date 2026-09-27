# anime_common.py - route AN (Story 25.30): what the anime pipeline scripts share. Imported inside Blender 4.5
# (exec'd through the Blender MCP server; see README.md for the runner pattern).
#
# Frames: Blender armature space is front -Y, left +X, up +Z. Godot (x, y, z) = Blender (x, z, -y).
import json
import math
import os

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


def rig():
    return bpy.data.objects["Rig"]


def to_godot(p):
    return Vector((p.x, p.z, -p.y))


def save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


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
