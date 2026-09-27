# anime_hair.py - route AN (Story 25.30): the hair builder: a cap shaped by a hairline, a fringe of tapered clumps,
# face-framing locks and long back hair. Opaque clumps only (no alpha cards: the outline hull would ink a card's full
# shape). Parametrised; the defaults are the silver-elf Quest Dealer's (the approved anime test's). Needs
# anime_kit.setup() first (the head's centre follows the rig).
import math

import bmesh
from mathutils import Vector

import anime_kit as K


def hairline(theta, front=1.905, side_drop=0.105, back_drop=0.19):
    a = abs(theta)
    return K.Z(front) - side_drop * K.smoothstep(0.45, 1.3, a) - back_drop * K.smoothstep(1.6, 2.5, a)


def long_hair_w(co):
    Z = K.Z
    if co.z > Z(1.58):
        return {"head": 1.0}
    if co.z > Z(1.40):
        return K.blend("chest", "head", (co.z - Z(1.40)) / (Z(1.58) - Z(1.40)))
    if co.z > Z(1.15):
        return {"chest": 1.0}
    return K.blend("spine", "chest", 0.4 + (co.z - Z(0.95)) / 0.5)


def build_cap(name, material, useg=36, vseg=22):
    hc, HR = K.HC(), K.HR
    bm = bmesh.new()
    res = bmesh.ops.create_uvsphere(bm, u_segments=useg, v_segments=vseg, radius=1.0)
    for v in res["verts"]:
        v.co = hc + Vector((v.co.x * (HR.x + 0.02), v.co.y * (HR.y + 0.02) * (1.06 if v.co.y > 0 else 1.0), v.co.z * (HR.z + 0.022) + 0.006))
    kill = [v for v in bm.verts if v.co.z < hairline(math.atan2(v.co.x, -v.co.y)) - 0.004]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    for v in [v for v in bm.verts if any(e.is_boundary for e in v.link_edges)]:    # a smooth hairline, no stair-steps
        th = math.atan2(v.co.x, -v.co.y)
        z = hairline(th) - 0.006
        x, y = K.head_radius_at(th, z, grow=0.021)
        v.co = Vector((x, y * (1.06 if y > 0 else 1.0), z))
    ob = K.new_obj(name, bm, material)
    K.skin(ob, K.head_w)
    return ob


def build_fringe(name, material, clumps=5, part=0.16, sides=8, rings=10):
    bm = bmesh.new()
    top = K.Z(2.03)
    for sx in (1, -1):
        for j in range(clumps):
            th_r = sx * (part + 0.25 * j)                 # a wide centre parting: the circlet's gem shows
            th_t = sx * (0.30 + 0.30 * j)
            z_t = K.Z(1.842) - 0.010 * j - (0.09 if j == clumps - 1 else 0.0)
            rx, ry = K.head_radius_at(th_r, top, grow=0.02)
            root = Vector((rx, ry, top))
            tx, ty = K.head_radius_at(th_t, z_t, grow=0.035)
            tip = Vector((tx, ty, z_t))
            mid = (root + tip) / 2
            mid += K.radial(mid) * 0.05 + Vector((0, 0, 0.02))
            pts = K.catmull([root, mid, tip], rings)
            radii = [0.050 * (1 - i / (rings - 1)) ** 0.8 + 0.003 for i in range(rings)]
            K.strand(bm, pts, radii, sides=sides, flat=0.42, up_of=lambda p: K.radial(p).cross(Vector((0, 0, 1))), pole_tip=True)
    ob = K.new_obj(name, bm, material)
    K.skin(ob, K.head_w)
    return ob


def build_locks(name, material, to_z=1.48, sides=8, rings=14):
    """Face-framing locks down to the collarbone (T5: longer, their tips sat where the arms reach forward)."""
    Z = K.Z
    bm = bmesh.new()
    for sx in (1, -1):
        ctrl = [Vector((0.205 * sx, -0.13, Z(1.93))), Vector((0.262 * sx, -0.16, Z(1.74))), Vector((0.250 * sx, -0.165, Z(1.52))),
                Vector((0.215 * sx, -0.15, Z(to_z)))]
        pts = K.catmull(ctrl, rings)
        K.strand(bm, pts, [0.056 * (1 - i / (rings - 1)) ** 0.7 + 0.004 for i in range(rings)], sides=sides, flat=0.45,
                 up_of=lambda p: Vector((0, -1, 0)), pole_tip=True)
    ob = K.new_obj(name, bm, material)
    K.skin(ob, long_hair_w)
    return ob


def build_back(name, material, tip_z=1.00, sides=8, rings=16):
    """Long back hair: clumps to the waist, a central sheet from 149 degrees round the back (T5: clumps at the sides hung
    where the lowered arms go, and Walking_A swings the arms 0.21 m behind the shoulders)."""
    Z = K.Z
    bm = bmesh.new()
    thetas = [2.6, 2.78, 2.96, math.pi, -2.96, -2.78, -2.6]
    for i, th in enumerate(thetas):
        z_r = Z(1.97) - 0.05 * abs(abs(th) - math.pi)
        rx, ry = K.head_radius_at(th, z_r, grow=0.018)
        root = Vector((rx, ry, z_r))
        dirv = Vector((math.sin(th), -math.cos(th), 0))
        side = abs(math.sin(th))
        nape = Vector((dirv.x * 0.275, dirv.y * 0.285, Z(1.63)))
        mid = Vector((dirv.x * 0.22, dirv.y * 0.27 + 0.02, Z(1.38)))
        tip = Vector((dirv.x * 0.18, dirv.y * 0.23 + 0.03, Z(tip_z + 0.05 * side + (0.03 if i % 2 else 0.0))))
        pts = K.catmull([root, nape, mid, tip], rings)
        K.strand(bm, pts, [0.080 * (1 - k / (rings - 1)) ** 0.6 + 0.006 for k in range(rings)], sides=sides, flat=0.5,
                 up_of=lambda p: K.radial(p).cross(Vector((0, 0, 1))), pole_tip=True)
    ob = K.new_obj(name, bm, material)
    K.skin(ob, long_hair_w)
    return ob


def build_all(prefix, material, lod=1.0):
    q = lambda n: max(4, int(round(n * lod)))
    return [build_cap(prefix + "HairCap", material, useg=q(36), vseg=q(22)),
            build_fringe(prefix + "HairFringe", material, sides=q(8), rings=q(10)),
            build_locks(prefix + "HairLocks", material, sides=q(8), rings=q(14)),
            build_back(prefix + "HairBack", material, sides=q(8), rings=q(16))]
