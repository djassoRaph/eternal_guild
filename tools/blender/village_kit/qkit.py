"""Quaternius kit helpers for Blender (exec'd inside Blender).

load(name, kit)  -> imports <kit>/glTF/<name>.gltf once into the hidden KIT collection, joined into one object
place(name, x, y, z=0, rot=0, kit='village', coll='BUILD') -> linked duplicate at a Blender position (Z up)
Blender coords: glTF (x, y, z) -> Blender (x, -z, y). Pieces keep their own origin.
"""
import bpy
import math
import os

ROOT = "F:/GAME I AM MAKING/eternal_guild_art/downloads/quaternius"
KITS = {"village": ROOT + "/village/glTF", "nature": ROOT + "/nature/glTF"}


def coll(name, hide=False):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    lc = bpy.context.view_layer.layer_collection.children.get(name)
    if lc is not None:
        lc.exclude = False
        c.hide_viewport = hide
        c.hide_render = hide
    return c


def load(name, kit="village"):
    key = "KIT_" + name
    ob = bpy.data.objects.get(key)
    if ob is not None:
        return ob
    path = os.path.join(KITS[kit], name + ".gltf")
    if not os.path.exists(path):
        raise FileNotFoundError(path)
    before = set(bpy.data.objects)
    # an active object must exist for the importer in some states; it's fine if none
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("no mesh in " + name)
    # apply parent transforms into mesh data, then join
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for o in new:
        if o != ob and o.name in bpy.data.objects:
            bpy.data.objects.remove(o, do_unlink=True)
    ob.name = key
    ob.data.name = key
    kc = coll("KIT", hide=True)
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    kc.objects.link(ob)
    return ob


def place(name, x, y, z=0.0, rot=0.0, kit="village", into="BUILD", sx=1.0):
    src = load(name, kit)
    ob = bpy.data.objects.new(name, src.data)
    ob.location = (x, y, z)
    ob.rotation_euler = (0.0, 0.0, math.radians(rot))
    ob.scale = (sx, 1.0, 1.0)
    coll(into).objects.link(ob)
    return ob


def clear(into="BUILD"):
    c = bpy.data.collections.get(into)
    if c is None:
        return 0
    n = 0
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
        n += 1
    return n
