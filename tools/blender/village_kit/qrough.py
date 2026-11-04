"""Rough / hand-made pass for Quaternius kit houses (exec'd in Blender after qkit.py + qhouse.py).

bake(place, house, name, w, d, floors, seed, **look) builds a house at the origin, joins it into one mesh,
densifies long edges so straight lines can bend, then deforms every vertex with one continuous function
of its position (so pieces that touched still touch):
  - sag:   the roof ridge dips in the middle            (swayback, like the reference's curved roofs)
  - kick:  the gable ends rise                          (the ridge curls up at both ends)
  - bow:   walls bulge outward between floor and eaves
  - lean:  upper storeys lean outward
  - tilt:  the whole house leans a little
  - wob:   low-frequency noise: no ruler-straight line survives
Normals are recomputed (custom normals cleared, smooth by angle) so the toon light follows the curves.
"""
import bpy
import bmesh
import math
import random
from mathutils import Vector, noise


def _smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def join_collection(cname, name):
    c = bpy.data.collections[cname]
    objs = [o for o in c.objects if o.type == "MESH"]
    for o in objs:
        o.data = o.data.copy()
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def densify(me, max_len=0.6, rounds=5):
    bm = bmesh.new()
    bm.from_mesh(me)
    for _ in range(rounds):
        long = [e for e in bm.edges if e.calc_length() > max_len]
        if not long:
            break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bm.to_mesh(me)
    bm.free()
    me.update()


def deform(me, w, d, floors, seed, sag=0.55, kick=0.35, bow=0.10, lean=0.12, tilt=0.018, wob=0.07, wob_f=0.33):
    rng = random.Random(seed)
    hx, hy = w / 2.0, d / 2.0
    z0 = 3.0 * floors
    zs = [v.co.z for v in me.vertices]
    zt = max(zs)
    xs = [abs(v.co.x) for v in me.vertices if v.co.z > z0 - 1.0]
    ys = [abs(v.co.y) for v in me.vertices if v.co.z > z0 - 1.0]
    hxr = max(xs) if xs else hx
    hyr = max(ys) if ys else hy
    tx = rng.uniform(-1, 1) * tilt
    ty = rng.uniform(-1, 1) * tilt
    off = Vector((rng.uniform(0, 100), rng.uniform(0, 100), rng.uniform(0, 100)))
    for v in me.vertices:
        x, y, z = v.co
        roof = _smooth(z0 - 0.9, zt, z)
        u = min(1.0, abs(y) / hyr)
        dz = -sag * roof * (1.0 - u * u) + kick * roof * u ** 4
        wz = max(0.0, min(1.0, z / z0))
        b = bow * math.sin(math.pi * wz)
        dx = math.copysign(1, x) * b * _smooth(0.45 * hx, hx, abs(x))
        dy = math.copysign(1, y) * b * _smooth(0.45 * hy, hy, abs(y))
        dx += math.copysign(1, x) * lean * wz ** 1.5 * _smooth(0.3 * hx, hx, abs(x))
        dy += math.copysign(1, y) * lean * 0.6 * wz ** 1.5 * _smooth(0.3 * hy, hy, abs(y))
        dx += tx * z
        dy += ty * z
        n = noise.noise_vector(Vector((x, y, z)) * wob_f + off)
        v.co = Vector((x + dx + n.x * wob, y + dy + n.y * wob, z + dz + n.z * wob * 0.7))
    me.update()


def renormal(ob, angle=40.0):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    try:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    except RuntimeError:
        pass
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))


def bake_with(builder, clear, coll, name, w, d, floors, seed, max_len=0.6, **look):
    """Like bake() but any builder(into) fills TMP (the smithy, the pottery)."""
    clear("TMP")
    coll("TMP")
    builder("TMP")
    ob = join_collection("TMP", name)
    t0 = len(ob.data.polygons)
    densify(ob.data, max_len)
    deform(ob.data, w, d, floors, seed, **look)
    renormal(ob)
    out = coll("ROUGH")
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    out.objects.link(ob)
    return ob, t0, len(ob.data.polygons)


def bake(place, house, clear, coll, name, w, d, floors, seed, max_len=0.6, **look):
    clear("TMP")
    coll("TMP")
    house(place, 0, 0, w, d, floors, seed=seed, into="TMP")
    ob = join_collection("TMP", name)
    t0 = len(ob.data.polygons)
    densify(ob.data, max_len)
    deform(ob.data, w, d, floors, seed, **look)
    renormal(ob)
    out = coll("ROUGH")
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    out.objects.link(ob)
    return ob, t0, len(ob.data.polygons)
