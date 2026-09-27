# anime_merge.py - route AN (Story 25.30): join a character's skinned parts into one <Role>_Body and prove the
# export contract. Props stay separate objects on item bones (parent_type BONE). Before the join every part has its
# non-Armature modifiers applied and exactly one UV layer named "UVMap" (join keeps only the active object's
# modifiers and merges UV layers by name). After the join, the asserts:
#   one UV layer; one Armature modifier on Rig, parent Rig; <= SURFACE_CAP material slots; every vertex in >= 1 real
#   deform bone group, <= 4 influences, normalised; unsplit smooth normals (normals_domain POINT, no sharp_edge /
#   sharp_face, no custom normals, every face smooth: the outline's grow moves each exported vertex along its own
#   normal, and glTF splits a vertex wherever its corner normals differ, opening a crack in the ink); Rig and body at
#   scale 1 (grow_amount is in local metres); every material opaque (BSDF Alpha unlinked at 1.0) with backface
#   culling off.
# The report prints NORMALS / UV / WEIGHTS / TRIS / SURFACES / MATERIALS as OK / OVER.
import bpy

import anime_common as C

TRI_BUDGET = 10000            # AN_TRI_BUDGET: the cap until T3 measures the dealer, then min(10000, ceil(x 1.15 / 500) x 500)
SURFACE_CAP = 3


def _prep(ob):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        if m.type != "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=m.name)
    me = ob.data
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[1])
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    me.uv_layers[0].name = "UVMap"


def join(name, parts):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for ob in parts:
        _prep(ob)
    for ob in parts:
        ob.select_set(True)
    active = next(o for o in parts if any(m.type == "ARMATURE" for m in o.modifiers))
    bpy.context.view_layer.objects.active = active
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = name
    body.data.name = name
    return body


def _deform_bones(arm):
    return {b.name for b in arm.data.bones if b.use_deform}


def check(body, props=(), tri_budget=TRI_BUDGET, surface_cap=SURFACE_CAP):
    arm = C.rig()
    me = body.data
    rows = {}
    arms = [m for m in body.modifiers if m.type == "ARMATURE"]
    rows["STRUCTURE"] = len(arms) == 1 and arms[0].object == arm and len(body.modifiers) == 1 and body.parent == arm \
        and body.parent_type == "OBJECT" and tuple(body.scale) == (1.0, 1.0, 1.0) and tuple(arm.scale) == (1.0, 1.0, 1.0)
    rows["UV"] = len(me.uv_layers) == 1 and me.uv_layers[0].name == "UVMap"
    deform = _deform_bones(arm)
    gname = {g.index: g.name for g in body.vertex_groups}
    bad_w = 0
    for v in me.vertices:
        ws = [(gname[g.group], g.weight) for g in v.groups if g.weight > 1e-5]
        real = [w for n, w in ws if n in deform]
        if not real or len(ws) > 4 or abs(sum(w for _, w in ws) - 1.0) > 1e-3 or len(real) != len(ws):
            bad_w += 1
    rows["WEIGHTS"] = bad_w == 0
    sharp = any(a.name in ("sharp_edge", "sharp_face") and any(d.value for d in a.data) for a in me.attributes)
    rows["NORMALS"] = me.normals_domain == "POINT" and not sharp and not me.has_custom_normals and all(p.use_smooth for p in me.polygons)
    mats_ok = True
    all_mats = list(me.materials) + [m for p in props for m in p.data.materials]
    for m in all_mats:
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m and m.use_nodes else None
        if m is None or bsdf is None or bsdf.inputs["Alpha"].is_linked or abs(bsdf.inputs["Alpha"].default_value - 1.0) > 1e-6 \
                or m.use_backface_culling or bsdf.inputs["Metallic"].default_value > 0.0 or bsdf.inputs["Emission Strength"].default_value > 0.0:
            mats_ok = False
    rows["MATERIALS"] = mats_ok
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    ptris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in props)
    rows["TRIS"] = tris + ptris <= tri_budget
    rows["SURFACES"] = 1 <= len(me.materials) <= surface_cap
    for p in props:
        rows["PROP " + p.name] = p.parent == arm and p.parent_type == "BONE" and not p.vertex_groups and not p.modifiers and len(p.data.materials) >= 1
    top = max((body.matrix_world @ v.co).z for v in me.vertices)
    report = "  ".join("%s %s" % (k, "OK" if ok else "OVER") for k, ok in rows.items())
    print("%s: %d tris + props %d = %d (budget %d), %d surfaces (cap %d), rest top %.3f, bad weights %d\n%s"
          % (body.name, tris, ptris, tris + ptris, tri_budget, len(me.materials), surface_cap, top, bad_w, report))
    return all(rows.values()), {"tris": tris + ptris, "surfaces": len(me.materials), "top": top}
