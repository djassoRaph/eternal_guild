# real_bake.py - route RL's painted head pass (Story 25.31 S1): the head projection (real_body.projection_uvs) gives
# each face ONE concept view, so where the front view hands over to the side view the two drawings meet in a step (a
# jagged beard edge, a second brow line at the temple; S1's portrait and three-quarter renders). This pass bakes the
# head material into its own unwrap with the three views BLENDED by the surface normal (w_view = max(0, n.view)^k,
# normalised), so the hand-over is a soft cross-fade instead of a seam, then puts the baked image and the unwrap on the
# body's head faces. The body atlas is untouched. Run on the joined <Role>_Body in rest, after build() (own call).
#   bake_head(body, head_mat, sheet, out_png, overwrite_ok=False)    -> the baked PNG (size x size, lossless), the
#                                                head faces re-UV'd; re-runnable (it reads the recorded concept source,
#                                                never its own last bake); refuses an existing PNG unless overwrite_ok
# Uses Cycles' EMIT bake (CPU); the scene's engine, Cycles' settings and the material slot are restored after.
import math
import os

import bmesh
import bpy

import anime_common as C
import anime_retarget as RT
import real_layout as L

VIEWS = ("front", "side", "back")


def _face_uvs(me, head_idx, layer, fn):
    uv = me.uv_layers[layer].data
    for p in me.polygons:
        if p.material_index != head_idx:
            continue
        for li in p.loop_indices:
            uv[li].uv = fn(me.vertices[me.loops[li].vertex_index].co)


def _top_uv(sheet):
    top = sheet["top_from_back"]
    wx, wy, u0, v0 = sheet["head_crops"]["back"]
    win = sheet["head_win"]
    y0, y1 = top["y"]
    r0, r1 = top["rows"]

    def fn(p):
        px, _ = L.to_px("back", p.x, p.y, p.z, sheet)
        t = min(1.0, max(0.0, (p.y - y0) / (y1 - y0)))
        py = r0 + (r1 - r0) * t
        return (u0 + 0.5 * (px - wx) / win, v0 + 0.5 * (1.0 - (py - wy) / win))
    return fn


def _node(nt, kind, loc, **inputs):
    n = nt.nodes.new(kind)
    n.location = loc
    for k, v in inputs.items():
        setattr(n, k, v)
    return n


def _bake_material(img_src, img_out, sheet, k):
    """Emission = the views' projected colours mixed by normal weights."""
    m = bpy.data.materials.new("RT_bake_head")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = _node(nt, "ShaderNodeOutputMaterial", (1600, 0))
    emi = _node(nt, "ShaderNodeEmission", (1400, 0))
    nt.links.new(emi.outputs[0], out.inputs[0])
    geo = _node(nt, "ShaderNodeNewGeometry", (-800, 400))
    sep = _node(nt, "ShaderNodeSeparateXYZ", (-600, 400))
    nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    sepp = _node(nt, "ShaderNodeSeparateXYZ", (-600, 700))
    nt.links.new(geo.outputs["Position"], sepp.inputs[0])

    def math_(op, a, b=None, loc=(0, 0)):
        n = _node(nt, "ShaderNodeMath", loc)
        n.operation = op
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                nt.links.new(v, n.inputs[i])
        return n.outputs[0]

    nx, ny, nz = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    w = {}
    # the front view owns the face itself (forward of face_y: the side view draws the eye and brow in profile there)
    fy = sheet.get("face_y", 0.10)
    face = math_("MINIMUM", math_("MAXIMUM", math_("DIVIDE", math_("SUBTRACT", math_("MULTIPLY", sepp.outputs[1], -1.0), fy), 0.04), 0.0), 1.0)
    w["front"] = math_("MULTIPLY", math_("POWER", math_("MAXIMUM", math_("MULTIPLY", ny, -1.0), 0.0), k),
                       math_("ADD", 1.0, math_("MULTIPLY", face, 4.0)))
    w["side"] = math_("POWER", math_("ABSOLUTE", nx), k)
    w["back"] = math_("POWER", math_("MAXIMUM", ny, 0.0), k)
    layers = list(VIEWS)
    if sheet.get("top_from_back"):
        top = sheet["top_from_back"]
        above = math_("GREATER_THAN", sepp.outputs[2], top["z_min"])
        w["top"] = math_("MULTIPLY", math_("POWER", math_("MAXIMUM", nz, 0.0), k), above)
        layers.append("top")
    total = None
    acc = None
    for i, v in enumerate(layers):
        uvn = _node(nt, "ShaderNodeUVMap", (-400, -300 * i))
        uvn.uv_map = "P_" + v
        tex = _node(nt, "ShaderNodeTexImage", (-200, -300 * i))
        tex.image = img_src
        tex.interpolation = "Cubic"
        tex.extension = "EXTEND"
        nt.links.new(uvn.outputs[0], tex.inputs[0])
        sc = _node(nt, "ShaderNodeVectorMath", (200, -300 * i))
        sc.operation = "SCALE"
        nt.links.new(tex.outputs["Color"], sc.inputs[0])
        nt.links.new(w[v], sc.inputs["Scale"])
        if acc is None:
            acc = sc.outputs[0]
            total = w[v]
        else:
            ad = _node(nt, "ShaderNodeVectorMath", (400, -300 * i))
            ad.operation = "ADD"
            nt.links.new(acc, ad.inputs[0])
            nt.links.new(sc.outputs[0], ad.inputs[1])
            acc = ad.outputs[0]
            total = math_("ADD", total, w[v])
    inv = math_("DIVIDE", 1.0, math_("MAXIMUM", total, 1e-4))
    fin = _node(nt, "ShaderNodeVectorMath", (1000, 0))
    fin.operation = "SCALE"
    nt.links.new(acc, fin.inputs[0])
    nt.links.new(inv, fin.inputs["Scale"])
    nt.links.new(fin.outputs[0], emi.inputs["Color"])
    tgt = _node(nt, "ShaderNodeTexImage", (1400, -400))
    tgt.image = img_out
    nt.nodes.active = tgt
    return m


SRC_KEY = "real_bake_src"          # on the head material: the concept crops image the projection reads (its first bake)
BAKED_KEY = "real_head_bake"       # on the body mesh: the PNG its head faces were last baked to (their UVs are its unwrap)


def _abs(path):
    return C.norm_path(bpy.path.abspath(path))


def bake_source(hm, out_png):
    """The projection's source image path for head material `hm`: the one recorded at its first bake, else the image the
    material reads now (build() points it at the concept crops). Never the bake's own output: a second bake that read
    its own result through the concept-sheet UVs wrote garbage over the art (25.31 review P2)."""
    tex = next(n for n in hm.node_tree.nodes if n.type == "TEX_IMAGE")
    src = hm.get(SRC_KEY) or (tex.image and tex.image.filepath) or ""
    src = bpy.path.abspath(src) if src else ""
    if not src or _abs(src) == _abs(out_png):
        raise RuntimeError("bake_head: the head material %s reads %r, the bake's own output (baked before the source was "
                           "recorded): run build() first (it points the material at the concept crops)" % (hm.name, src))
    if not os.path.exists(src):
        raise RuntimeError("bake_head: the projection source %s is missing" % src)
    return src


def bake_head(body_name, head_mat_name, sheet, out_png, size=1024, k=4.0, margin=0.004, overwrite_ok=False):
    """Re-runnable: the projection reads bake_source() (the concept crops, recorded on the material at the first bake),
    never the material's current image, which is the bake after one run. Refuses an existing out_png unless overwrite_ok
    (the shipped <role>_headpaint.png). Everything it adds to the file for the bake (the helper UV layers, the bake
    material, the dummy image nodes, Cycles' samples / device / margin and the engine, edit mode) is undone in a
    finally; the head faces take the bake's unwrap only when the bake succeeded."""
    if os.path.exists(out_png) and not overwrite_ok:
        raise RuntimeError("bake_head: %s exists (pass overwrite_ok=True to re-bake it)" % out_png)
    RT.rest_pose()
    body = bpy.data.objects[body_name]
    me = body.data
    head_idx = next(i for i, m in enumerate(me.materials) if m and m.name == head_mat_name)
    hm = me.materials[head_idx]
    src_path = bake_source(hm, out_png)
    src = bpy.data.images.load(src_path, check_existing=True)
    names = ["P_" + v for v in VIEWS] + (["P_top"] if sheet.get("top_from_back") else [])
    sc = bpy.context.scene
    keep = {"engine": sc.render.engine}
    keep_active = {}
    tmp = dummy = img_out = None
    done = False
    try:
        # the projection per view (continuous per vertex), and the top mapping
        for n in names + ["BK"]:
            if n in me.uv_layers:
                me.uv_layers.remove(me.uv_layers[n])
            me.uv_layers.new(name=n)
        for v in VIEWS:
            _face_uvs(me, head_idx, "P_" + v, lambda p, v=v: L.head_uv(v, p.x, p.y, p.z, sheet))
        if sheet.get("top_from_back"):
            _face_uvs(me, head_idx, "P_top", _top_uv(sheet))
        # the bake's unwrap: the head faces alone, smart-projected into BK
        for o in bpy.context.selected_objects:
            o.select_set(False)
        body.select_set(True)
        bpy.context.view_layer.objects.active = body
        me.uv_layers.active = me.uv_layers["BK"]
        bpy.ops.object.mode_set(mode="EDIT")
        bm = bmesh.from_edit_mesh(me)
        for f in bm.faces:
            f.select = f.material_index == head_idx
        bmesh.update_edit_mesh(me)
        bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=margin, area_weight=0.0, correct_aspect=True,
                                 scale_to_bounds=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        # bake
        img_out = bpy.data.images.new(os.path.basename(out_png).rsplit(".", 1)[0], size, size, alpha=False)
        tmp = _bake_material(src, img_out, sheet, k)
        me.materials[head_idx] = tmp
        # a bake writes into the ACTIVE image node of every material on the object: the other slots' (the body atlas)
        # must point at a non-image node, or the atlas's pixels in memory are overwritten (and exported)
        # (making another node active is not enough: the image node keeps its active-texture flag), so each other slot
        # gets a throwaway image node, active, removed after
        dummy = bpy.data.images.new("RT_bake_dummy", 8, 8)
        for m in me.materials:
            if m and m is not tmp and m.use_nodes:
                keep_active[m.name] = m.node_tree.nodes.active
                dn = m.node_tree.nodes.new("ShaderNodeTexImage")
                dn.name = "RT_bake_dummy"
                dn.image = dummy
                m.node_tree.nodes.active = dn
        sc.render.engine = "CYCLES"
        keep.update(samples=sc.cycles.samples, device=sc.cycles.device, margin=sc.render.bake.margin)
        sc.cycles.samples = 4
        sc.cycles.device = "CPU"
        sc.render.bake.margin = 8
        bpy.ops.object.bake(type="EMIT", uv_layer="BK", margin=8, use_clear=True)
        img_out.filepath_raw = out_png
        img_out.file_format = "PNG"
        img_out.save()
        # the baked unwrap becomes the head faces' UVs
        uv = me.uv_layers["UVMap"].data
        bk = me.uv_layers["BK"].data
        for p in me.polygons:
            if p.material_index == head_idx:
                for li in p.loop_indices:
                    uv[li].uv = bk[li].uv
        done = True
    finally:
        if body.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        me.materials[head_idx] = hm
        if tmp is not None:
            bpy.data.materials.remove(tmp)
        for m in me.materials:
            if m and m.name in keep_active:
                dn = m.node_tree.nodes.get("RT_bake_dummy")
                if dn:
                    m.node_tree.nodes.remove(dn)
                m.node_tree.nodes.active = keep_active[m.name]
        if dummy is not None:
            bpy.data.images.remove(dummy)
        if "samples" in keep:
            sc.cycles.samples, sc.cycles.device, sc.render.bake.margin = keep["samples"], keep["device"], keep["margin"]
        try:
            sc.render.engine = keep["engine"]
        except TypeError:
            pass
        # the helper layers go
        if "UVMap" in me.uv_layers:
            me.uv_layers.active = me.uv_layers["UVMap"]
        for n in names + ["BK"]:
            if n in me.uv_layers:
                me.uv_layers.remove(me.uv_layers[n])
        if img_out is not None:
            bpy.data.images.remove(img_out)
    assert done
    # the head material reads the baked image: one datablock per file (an earlier bake's is replaced, not stacked);
    # the source stays recorded on the material, and the mesh is stamped with its bake
    hm[SRC_KEY] = src_path
    tex = next(n for n in hm.node_tree.nodes if n.type == "TEX_IMAGE")
    for im in [i for i in bpy.data.images if i.filepath and _abs(i.filepath) == _abs(out_png)]:
        bpy.data.images.remove(im)
    tex.image = bpy.data.images.load(out_png, check_existing=False)
    tex.image.use_fake_user = True
    me[BAKED_KEY] = out_png
    print("painted head pass:", out_png, size, "px; views", names, "source", src_path)
    return out_png
