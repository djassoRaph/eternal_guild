# anime_hair.py - route AN (Stories 25.30, 25.31): the hair builder: a cap shaped by a hairline, a fringe of tapered
# clumps, face-framing locks, back hair (long or short), a ponytail and a bun. Opaque clumps only (no alpha cards: the
# outline hull would ink a card's full shape). Parametrised; the defaults are the silver-elf Quest Dealer's (the
# approved anime test's): build_all() is hers. build_preset(name) builds the cast's presets (PRESETS: long, short,
# cropped, bald, ponytail, bun; a grey bun is the bun in a grey palette cell). Needs anime_kit.setup() first.
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
    # spine -> chest, continuous at Z(1.15) (25.31: it jumped from 0.89 to 1.0 chest there, a kink when the chest leans)
    return K.blend("spine", "chest", 0.4 + 0.6 * (co.z - Z(0.95)) / (Z(1.15) - Z(0.95)))


def build_cap(name, material, useg=36, vseg=22, line=None, grow=0.02, grow_z=0.022, line_grow=0.021):
    """The hair's cap over the skull down to the hairline; line: hairline()'s keyword overrides (front, side_drop,
    back_drop: a cropped cut has a higher, tighter line); grow / grow_z / line_grow: its thickness over the scalp
    (sides, top, at the hairline)."""
    hc, HR = K.HC(), K.HR
    line = line or {}
    hl = lambda th: hairline(th, **line)
    bm = bmesh.new()
    res = bmesh.ops.create_uvsphere(bm, u_segments=useg, v_segments=vseg, radius=1.0)
    for v in res["verts"]:
        v.co = hc + Vector((v.co.x * (HR.x + grow), v.co.y * (HR.y + grow) * (1.06 if v.co.y > 0 else 1.0), v.co.z * (HR.z + grow_z) + 0.006))
    kill = [v for v in bm.verts if v.co.z < hl(math.atan2(v.co.x, -v.co.y)) - 0.004]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    for v in [v for v in bm.verts if any(e.is_boundary for e in v.link_edges)]:    # a smooth hairline, no stair-steps
        th = math.atan2(v.co.x, -v.co.y)
        z = hl(th) - 0.006
        x, y = K.head_radius_at(th, z, grow=line_grow)
        v.co = Vector((x, y * (1.06 if y > 0 else 1.0), z))
    ob = K.new_obj(name, bm, material)
    K.skin(ob, K.head_w)
    return ob


def build_fringe(name, material, clumps=5, part=0.16, sides=8, rings=10, tip_z=1.842, side_drop=0.09, width=0.050):
    """The fringe: clumps from a parting (part, radians from the front) to tips at test height tip_z (the outermost
    clump side_drop lower); width: a clump's root radius."""
    bm = bmesh.new()
    top = K.Z(2.03)
    for sx in (1, -1):
        for j in range(clumps):
            th_r = sx * (part + 0.25 * j)                 # a wide centre parting: the circlet's gem shows
            th_t = sx * (0.30 + 0.30 * j)
            z_t = K.Z(tip_z) - 0.010 * j - (side_drop if j == clumps - 1 else 0.0)
            rx, ry = K.head_radius_at(th_r, top, grow=0.02)
            root = Vector((rx, ry, top))
            tx, ty = K.head_radius_at(th_t, z_t, grow=0.035)
            tip = Vector((tx, ty, z_t))
            mid = (root + tip) / 2
            mid += K.radial(mid) * 0.05 + Vector((0, 0, 0.02))
            pts = K.catmull([root, mid, tip], rings)
            radii = [width * (1 - i / (rings - 1)) ** 0.8 + 0.003 for i in range(rings)]
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


def build_back(name, material, tip_z=1.00, sides=8, rings=16, thetas=(2.6, 2.78, 2.96, math.pi, -2.96, -2.78, -2.6), width=0.080):
    """Back hair: clumps to tip_z (the dealer's: to the waist), a central sheet from 149 degrees round the back (T5:
    clumps at the sides hung where the lowered arms go, and Walking_A swings the arms 0.21 m behind the shoulders).
    A tip above the shoulders (tip_z >= 1.45) is short hair: root, nape, tip (no mid point below the tip)."""
    Z = K.Z
    bm = bmesh.new()
    for i, th in enumerate(thetas):
        z_r = Z(1.97) - 0.05 * abs(abs(th) - math.pi)
        rx, ry = K.head_radius_at(th, z_r, grow=0.018)
        root = Vector((rx, ry, z_r))
        dirv = Vector((math.sin(th), -math.cos(th), 0))
        side = abs(math.sin(th))
        nape = Vector((dirv.x * 0.275, dirv.y * 0.285, Z(1.63)))
        mid = Vector((dirv.x * 0.22, dirv.y * 0.27 + 0.02, Z(1.38)))
        tip = Vector((dirv.x * 0.18, dirv.y * 0.23 + 0.03, Z(tip_z + 0.05 * side + (0.03 if i % 2 else 0.0))))
        if tip_z >= 1.45:
            nape = Vector((dirv.x * 0.27, dirv.y * 0.28, Z(min(1.70, tip_z + 0.08))))
            pts = K.catmull([root, nape, tip], rings)
        else:
            pts = K.catmull([root, nape, mid, tip], rings)
        K.strand(bm, pts, [width * (1 - k / (rings - 1)) ** 0.6 + 0.006 for k in range(rings)], sides=sides, flat=0.5,
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


def build_ponytail(name, material, tie_z=1.86, tip_z=1.30, r=0.055, sides=8, rings=12):
    """A ponytail tied at the back of the head (test height tie_z), falling to tip_z behind the shoulders (clear of the
    arms' backswing: it stays on the spine's line), with a tie ring."""
    Z = K.Z
    hc = K.HC()
    _, yb = K.head_radius_at(math.pi, Z(tie_z), grow=0.02)
    root = Vector((0.0, yb - 0.01, Z(tie_z)))
    ctrl = [root, root + Vector((0, 0.07, -0.04)), Vector((0, yb + 0.03, Z(max(tip_z + 0.25, 1.55)))), Vector((0, yb + 0.0, Z(tip_z)))]
    bm = bmesh.new()
    pts = K.catmull(ctrl, rings)
    K.strand(bm, pts, [r * (0.75 + 0.5 * math.sin(math.pi * min(1.0, k / (rings - 1) * 1.6))) * (1 - k / (rings - 1)) ** 0.5 + 0.006
                       for k in range(rings)], sides=sides, flat=0.8, up_of=lambda p: Vector((1, 0, 0)), pole_tip=True)
    tie = root + Vector((0, 0.03, -0.01))
    K.loop_tube(bm, [tie + Vector((0.032 * math.cos(2 * math.pi * k / 10), 0.0, 0.032 * math.sin(2 * math.pi * k / 10))) for k in range(10)], 0.010, sides=4)
    ob = K.new_obj(name, bm, material)
    K.skin(ob, long_hair_w)
    return ob


def build_bun(name, material, z=1.93, r=0.085, seg=12, rings=8):
    """A bun at the back of the crown (the old woman's grey bun), head-weighted."""
    Z = K.Z
    _, yb = K.head_radius_at(math.pi, Z(z), grow=0.02)
    bm = bmesh.new()
    K.ellipsoid(bm, Vector((0.0, yb + r * 0.55, Z(z))), r, r * 0.85, r * 0.9, seg, rings)
    ob = K.new_obj(name, bm, material)
    K.skin(ob, K.head_w)
    return ob


# The cast's presets: [(builder, suffix, kwargs)]; lod-scaled segment counts are applied by build_preset.
PRESETS = {
    "long": None,                                                                          # build_all (the dealer's)
    "short": [(build_cap, "HairCap", {"line": {"side_drop": 0.12, "back_drop": 0.24}}),
              (build_fringe, "HairFringe", {"clumps": 4, "part": 0.30, "tip_z": 1.90, "side_drop": 0.06, "width": 0.045}),
              (build_back, "HairBack", {"tip_z": 1.58, "thetas": (2.2, 2.5, 2.8, math.pi, -2.8, -2.5, -2.2), "width": 0.070})],
    "cropped": [(build_cap, "HairCap", {"line": {"front": 1.93, "side_drop": 0.09, "back_drop": 0.20}, "grow": 0.012, "grow_z": 0.014, "line_grow": 0.013})],
    "bald": [],                                                                            # a beard is a garment (anime_garments.build_beard)
    "ponytail": [(build_cap, "HairCap", {}),
                 (build_fringe, "HairFringe", {"clumps": 4, "tip_z": 1.86}),
                 (build_ponytail, "HairTail", {})],
    "bun": [(build_cap, "HairCap", {"line": {"front": 1.93, "side_drop": 0.10, "back_drop": 0.20}, "grow": 0.016, "grow_z": 0.018, "line_grow": 0.017}),
            (build_bun, "HairBun", {})],
}
_SEGS = {build_cap: ("useg", 36, "vseg", 22), build_fringe: ("sides", 8, "rings", 10), build_back: ("sides", 8, "rings", 16),
         build_ponytail: ("sides", 8, "rings", 12), build_bun: ("seg", 12, "rings", 8)}


def build_preset(preset, prefix, material, lod=1.0):
    """The parts of a hair preset (PRESETS), named prefix + suffix; [] for bald."""
    if preset not in PRESETS:
        raise ValueError("unknown hair preset %r (known: %s)" % (preset, sorted(PRESETS)))
    if PRESETS[preset] is None:
        return build_all(prefix, material, lod=lod)
    q = lambda n: max(4, int(round(n * lod)))
    out = []
    for fn, suffix, kw in PRESETS[preset]:
        a, na, b, nb = _SEGS[fn]
        kw = dict(kw)
        kw.setdefault(a, q(na))
        kw.setdefault(b, q(nb))
        out.append(fn(prefix + suffix, material, **kw))
    return out
