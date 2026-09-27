# anime_atlas.py - route AN (Story 25.30): one small palette atlas per body. Flat-colour parts collapse their UVs onto
# the centre of one cell, so they sample exactly one colour (no mip blur: collapsed UVs have no derivatives) and a
# recolour (25.31's variants) is an edit of this PNG. Cells are CELL px on a CELL-px grid (>= 4: safe even if an
# importer compressed it to 4x4 blocks). No baked lighting.
import os

import bpy
import numpy as np

import anime_kit as K

CELL = 8
GRID = 4                     # 4 x 4 cells: a 32 x 32 image


def build(name, path, colours):
    """colours: {key: "RRGGBB"} in cell order. Returns (material, {key: (u, v)} cell centres)."""
    assert len(colours) <= GRID * GRID
    size = CELL * GRID
    px = np.ones((size, size, 4), dtype=np.float32)
    centres = {}
    for i, (key, hexrgb) in enumerate(colours.items()):
        cx, cy = i % GRID, i // GRID
        r, g, b = (int(hexrgb[j:j + 2], 16) / 255.0 for j in (0, 2, 4))
        px[cy * CELL:(cy + 1) * CELL, cx * CELL:(cx + 1) * CELL, :3] = (r, g, b)   # sRGB bytes, as the PNG stores them
        centres[key] = ((cx + 0.5) / GRID, (cy + 0.5) / GRID)
    img = bpy.data.images.get(name)
    if img is None or img.size[0] != size:
        if img:
            bpy.data.images.remove(img)
        img = bpy.data.images.new(name, size, size, alpha=False)
    img.pixels.foreach_set(px.ravel())
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.use_fake_user = True
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = False
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None) or nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Alpha"].default_value = 1.0
    return m, centres


def paint_part(ob, material, uv):
    """Give a flat part the atlas material with every UV at one cell centre."""
    me = ob.data
    me.materials.clear()
    me.materials.append(material)
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    lay = me.uv_layers[0]
    lay.name = "UVMap"
    n = len(lay.data)
    lay.data.foreach_set("uv", np.tile(np.array(uv, dtype=np.float32), n))
