"""Export the baked kit buildings and the nature pieces into the game repo (exec'd after the other q* files).
Every asset is a .gltf + .bin; all of them share ONE texture folder (assets/environment/kit_textures/).
"""
import bpy
import os

REPO = "F:/GAME I AM MAKING/shiningsun/assets/environment/"
VILLAGE_DIR = REPO + "village_kit/"
NATURE_DIR = REPO + "nature_kit/"
NATURE = ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5", "CommonTree_1", "CommonTree_2", "CommonTree_3",
          "CommonTree_4", "CommonTree_5", "DeadTree_1", "DeadTree_2", "DeadTree_3", "TwistedTree_1", "TwistedTree_2",
          "Bush_Common", "Fern_1", "Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Grass_Wispy_Tall", "Plant_1_Big"]


def consolidate_images(max_px=1024):
    by_path = {}
    merged = 0
    for im in list(bpy.data.images):
        if im.source != "FILE" or not im.filepath:
            continue
        key = os.path.normcase(bpy.path.abspath(im.filepath))
        if key in by_path and by_path[key] != im:
            im.user_remap(by_path[key])
            merged += 1
        else:
            by_path[key] = im
    scaled = 0
    for im in by_path.values():
        if im.size[0] > max_px or im.size[1] > max_px:
            im.scale(min(max_px, im.size[0]), min(max_px, im.size[1]))
            scaled += 1
    return merged, scaled


def _export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", export_texture_dir="../kit_textures",
                              use_selection=True, export_yup=True, export_apply=False, export_image_format="AUTO",
                              export_lights=False, export_cameras=False)


def export_buildings(names):
    os.makedirs(VILLAGE_DIR, exist_ok=True)
    out = []
    for n in names:
        ob = bpy.data.objects[n]
        keep = ob.location.copy()
        ob.location = (0, 0, 0)
        bpy.context.view_layer.update()
        _export([ob] + list(ob.children), VILLAGE_DIR + n + ".gltf")
        ob.location = keep
        out.append(n)
    return out


def export_nature(place, clear, coll):
    os.makedirs(NATURE_DIR, exist_ok=True)
    clear("NEX")
    coll("NEX")
    out = []
    for p in NATURE:
        o = place(p, 0, 0, 0, 0, kit="nature", into="NEX")
        o.name = p
        bpy.context.view_layer.update()
        _export([o], NATURE_DIR + p + ".gltf")
        out.append(p)
    clear("NEX")
    return out
