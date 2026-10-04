# anime_merge.py - route AN (Story 25.30): join a character's skinned parts into one <Role>_Body and prove the
# export contract. Props stay separate objects on item bones (parent_type BONE). Before the join every part has its
# non-Armature modifiers applied and exactly one UV layer named "UVMap" (join keeps only the active object's
# modifiers and merges UV layers by name). After the join, the asserts:
#   one UV layer; one Armature modifier on Rig, parent Rig; <= SURFACE_CAP material slots; every vertex in >= 1 real
#   deform bone group, <= 4 influences, normalised; unsplit smooth normals (normals_domain POINT, no sharp_edge /
#   sharp_face, no custom normals, every face smooth: the outline's grow moves each exported vertex along its own
#   normal, and glTF splits a vertex wherever its corner normals differ, opening a crack in the ink); Rig and body at
#   scale 1 (grow_amount is in local metres); every material opaque (BSDF Alpha unlinked at 1.0) with backface
#   culling off; no emission except on a prop's own material at roughness 0 (AH-3, 25.31: emission_ok). Rig's matrix_world is the identity (the parts are parented without a parent inverse, and every
#   measurement assumes the rig at the origin).
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


def emission_ok(m, bsdf, body_mats):
    """AH-3 / V5 (25.31): emission only on a PROP's own material (never on a body material, never on one the body
    shares: the quill shares the palette, the Healer's crystal has its own), and an emissive material at roughness 0
    (light, not ink: the edge shader leaves roughness 0 un-inked; anime_look keeps it emissive without an outline)."""
    if not is_emissive(m, bsdf):
        return True
    return m not in body_mats and bsdf.inputs["Roughness"].default_value == 0.0


def is_emissive(m, bsdf):
    """The material can emit: the BSDF's emission is colour x strength, so it glows when the strength is linked (a
    texture or a node drives it) or above 0 AND the colour is linked (an emission texture) or not black; an Emission
    shader node anywhere in the tree also counts. A black colour at strength > 0 is not a glow."""
    s, c = bsdf.inputs["Emission Strength"], bsdf.inputs["Emission Color"]
    strength = s.is_linked or s.default_value > 0.0
    colour = c.is_linked or max(tuple(c.default_value)[:3]) > 0.0
    return (strength and colour) or any(n.type == "EMISSION" for n in m.node_tree.nodes)


def _deform_bones(arm):
    return {b.name for b in arm.data.bones if b.use_deform}


def check(body, props=(), tri_budget=TRI_BUDGET, surface_cap=SURFACE_CAP):
    arm = C.rig()
    off = max(abs(arm.matrix_world[i][j] - (1.0 if i == j else 0.0)) for i in range(4) for j in range(4))
    assert off < 1e-6, "Rig's matrix_world isn't the identity (off by %.2e): the parts and every measurement assume Rig at the origin" % off
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
    body_mats = set(m for m in me.materials if m)
    all_mats = list(me.materials) + [m for p in props for m in p.data.materials]
    for m in all_mats:
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m and m.use_nodes else None
        if m is None or bsdf is None or bsdf.inputs["Alpha"].is_linked or abs(bsdf.inputs["Alpha"].default_value - 1.0) > 1e-6 \
                or m.use_backface_culling or bsdf.inputs["Metallic"].default_value > 0.0 or not emission_ok(m, bsdf, body_mats):
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
