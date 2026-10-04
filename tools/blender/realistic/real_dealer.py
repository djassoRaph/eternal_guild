# real_dealer.py - the Quest Dealer remade on route RL (Story 25.31 S1, AC 6b, R-2; catalogue G13): the silver-haired
# elf of Raphael's pick (eternal_guild_art/picked/C_G13_quest_dealer.png) on REAL-2 (1.70 m): long straight silver
# hair to mid-back, long pointed ears, a gold circlet with a red gem, a fitted plum coat buttoned to a high stand
# collar, gold trim down its front and on its cuffs, split below the belt over dark trousers, a back vent; tall cuffed
# boots. R-9: her hands are empty; the quill is a separate prop on handslot.r, hidden by the game except while she
# writes (quest_dealer.gd). Her anime body (route AN, the v2 face-seam re-export) is her fallback (Q3).
# One call per step (README's runner):
#   open_base_as_dealer()  realistic_base_w.blend (REAL-2) saved as g13_quest_dealer_real.blend (a file load: own call)
#   build()                her parts on the REAL-2 rig, joined into Dealer_Body (the head projection + the body atlas)
#                          + the Dealer_Quill prop on handslot.r
#   paint_head()           the painted head pass (real_bake)
#   build_clips()          Idle (straightened, arms by her coat), Walk_Bar, Write, Brief (the 25.30 desk method on her
#                          reach), her own Walking_A stride
#   measure()              her body block at the desk (anime_clearcheck.measure / desk_report, her seated shoulders)
#   export()               Rig + body + quill to assets/characters/custom/g13_quest_dealer_real.glb
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import anime_anims as AN
import anime_common as C
import anime_kit as K
import anime_merge as MG
import anime_retarget as RT
import real_bartender as RBT
import real_body as RB
import real_chain as RC
import real_layout as L
import real_player as RP

ART = C.ART
CFG = {
    "role": "desk_manager",
    "blend": C.BLEND + "g13_quest_dealer_real.blend",
    "head_png": ART + "textures/realistic/g13_quest_dealer_real_head.png",
    "head_paint_png": ART + "textures/realistic/g13_quest_dealer_real_headpaint.png",
    "body_png": ART + "textures/realistic/g13_quest_dealer_real_body.png",
    "glb": "F:/GAME I AM MAKING/shiningsun/assets/characters/custom/g13_quest_dealer_real.glb",
    "body": "Dealer_Body",
    "props": ["Dealer_Quill"],
}
SHEET = L.DEALER
TRI_BUDGET = 10000
CH = RC.REAL_2
W = RC.WOMAN
HEAD = dict(W["head"], width=0.90, jaw=0.14)      # REAL-2's head, a little narrower in the face (her pick)


def head_shape(p):
    """build_neutral_head's placement (the jaw narrowed, scaled about REAL-1's head pivot onto REAL-2's head bone)."""
    sc, wd, jaw = HEAD["scale"], HEAD["width"], HEAD["jaw"]
    q = p.copy()
    q.x *= 1.0 - jaw * K.smoothstep(1.71, 1.61, p.z)
    q = q - RB.HEAD_PIVOT_SRC
    return K.H("head") + Vector((q.x * sc * wd, q.y * sc, q.z * sc))


def open_base_as_dealer(overwrite_ok=False):
    return RC.open_base_as(CFG["blend"], RC.REAL_2, overwrite_ok=overwrite_ok)


def _materials():
    head = K.mat("RT_Dealer_Head", "C6A08A", CFG["head_png"])
    body = K.mat("RT_Dealer_Body", "64545C", CFG["body_png"])
    for m, name in ((head, "dealer_head"), (body, "dealer_body")):
        im = next(n for n in m.node_tree.nodes if n.type == "TEX_IMAGE").image
        im.name = name
        im.reload()
    return head, body


# ------------------------------------------------------------------ her hair: the cap and the long fall

def _hair_low(th):
    a = abs(math.degrees(th))
    return RB._interp([(0, 1.800), (30, 1.795), (55, 1.770), (75, 1.745), (95, 1.700), (130, 1.660), (180, 1.640)], a)


def build_hair_cap(name, mat, cols=34, rows=7):
    """A thin shell over the (unshaped) head from the hairline up, parted at the centre (a groove at th 0)."""
    bm = bmesh.new()
    ths = [RB.head_theta(k, cols) for k in range(cols)]
    grid = []
    for j in range(rows + 1):
        s = j / rows
        row = []
        for k, th in enumerate(ths):
            zb = _hair_low(th)
            z = zb + (1.852 - zb) * s ** 0.85
            p = RB.head_point(th, z)
            c = Vector((0.0, (RB.head_ring(z)[1] + RB.head_ring(z)[2]) / 2.0, z))
            d = Vector((p.x - c.x, p.y - c.y, 0.0))
            d = d.normalized() if d.length > 1e-6 else Vector((0, 1, 0))
            n = (d * (1.0 - 0.6 * K.smoothstep(0.55, 1.0, s)) + Vector((0, 0, 1)) * K.smoothstep(0.55, 1.0, s)).normalized()
            t = (0.010 + 0.004 * K.smoothstep(0.0, 0.4, s)) * (1.0 - 0.5 * RB.gauss(math.degrees(th), 6.0) * s)
            row.append(bm.verts.new(p + n * t))
        grid.append(row)
    for a, b in zip(grid[:-1], grid[1:]):
        for k in range(cols):
            bm.faces.new((a[k], a[(k + 1) % cols], b[(k + 1) % cols], b[k]))
    top = bm.verts.new((0.0, -0.075, 1.861 + 0.012))
    for k in range(cols):
        bm.faces.new((grid[-1][k], grid[-1][(k + 1) % cols], top))
    RB._reshape(bm, head_shape)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    f0 = max(bm.faces, key=lambda f: f.calc_center_median().z)
    if f0.normal.z < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    print("hair cap views", RB.projection_uvs(bm, sheet=SHEET))
    return RB.finish(name, bm, mat, RB.head_w)


def build_hair_fall(name, mat, cols=16, rows=12):
    """The long straight hair down her back: a sheet from behind the ears (z 1.60) to the tips (z 1.02 at the centre,
    higher toward its sides), hanging just off the head, then the neck, shoulders and coat back (always outside them),
    a little fuller toward the tips. Weights: head at the top, chest below the shoulders (it rides the upper body)."""
    zh = K.H("head").z
    top, tip_c = 1.62, 1.02
    grid = []
    for j in range(rows + 1):
        t = j / rows
        row = []
        for i in range(cols + 1):
            u = i / cols
            th = math.radians(118.0 + (360.0 - 236.0) * u)            # 118..242 degrees: behind the ears, round the back
            side = abs(math.cos(math.pi * (u - 0.5)))                    # 0 at the centre, 1 at its edges
            tip = tip_c + (1.30 - tip_c) * (abs(u - 0.5) * 2) ** 2.2
            z = top + (tip - top) * t
            # what it must clear at this height: the head (above the neck), the neck, the coat
            ring = coat_ring(min(z, 1.44))
            p_body = RP._contour(ring, th, n=2.2, grow=0.022 + 0.010 * t)
            if z > 1.46:
                hp = head_shape(RB.head_point(th, min(1.80, (z - K.H("head").z) / HEAD["scale"] + RB.HEAD_PIVOT_SRC.z)))
                c = Vector((0.0, K.H("head").y, z))
                d = Vector((hp.x - c.x, hp.y - c.y, 0.0))
                p_head = c + d * (1.0 + 0.012 / max(d.length, 1e-4))
                k = K.smoothstep(1.46, 1.54, z)
                p = Vector((p_head.x * k + p_body.x * (1 - k), p_head.y * k + p_body.y * (1 - k), z))
            else:
                p = Vector((p_body.x, p_body.y, z))
            p.x *= 1.0 + 0.08 * t                                       # fuller toward the tips
            p.y += 0.006 * math.sin(i * 1.7) * t                         # strands
            row.append(Vector((p.x, p.y, p.z + (0.012 * ((i * 7) % 3 - 1) if j == rows else 0.0))))
        grid.append(row)
    bm = bmesh.new()
    RB.grid_slab(bm, grid, 0.010, lambda p: Vector((-p.x, -(p.y - K.H("head").y), 0)).normalized())
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print("hair fall views", RB.projection_uvs(bm, sheet=SHEET))

    def w(co):
        return K.blend("chest", "head", K.clamp01((co.z - (zh - 0.02)) / 0.10))
    return RB.finish(name, bm, mat, w)


def build_ears(name, mat):
    """Long pointed elf ears: a flat leaf from the side of the head (z ~1.56) out, up and back to a tip (her pick:
    the tip ~0.12 m off the midline, level with the brows)."""
    bm = bmesh.new()
    for sx in (1.0, -1.0):
        base = Vector((0.064 * sx, K.H("head").y + 0.004, 1.548))
        tip = base + Vector((0.068 * sx, 0.030, 0.062))
        ax = (tip - base).normalized()
        up = Vector((0, 0, 1)) - ax * ax.z
        up.normalize()
        flat = ax.cross(up).normalized()
        n_u, n_v = 8, 6
        ring = []
        for i in range(n_u + 1):
            t = i / n_u
            hw = 0.022 * (1 - t) ** 0.7 * (0.55 + 0.45 * math.sin(math.pi * min(1.0, t * 1.6 + 0.2)))
            th = 0.006 * (1 - t) + 0.0015
            c = base.lerp(tip, t)
            r = []
            for k in range(n_v):
                a = 2 * math.pi * k / n_v
                r.append(bm.verts.new(c + up * (hw * math.cos(a) - 0.004 * t) + flat * (th * math.sin(a))))
            ring.append(r)
        for a, b in zip(ring[:-1], ring[1:]):
            for k in range(n_v):
                bm.faces.new((a[k], a[(k + 1) % n_v], b[(k + 1) % n_v], b[k]))
        bm.faces.new(list(reversed(ring[0])))
        bm.faces.new(ring[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print("ear views", RB.projection_uvs(bm, sheet=SHEET))
    return RB.finish(name, bm, mat, RB.head_w)


def build_circlet(name, mat):
    """The gold circlet across her forehead (z 1.624 in her pick) and round under the hair: a slim band close on the
    skin (its ink reads as the circlet's edges); the gem is the projection's own (a gem mesh drew an ink ring)."""
    bm = bmesh.new()
    z0 = 1.624
    segs = 28
    rings = []
    for li, (dz, g) in enumerate(((-0.005, 0.004), (0.005, 0.004), (0.005, 0.0), (-0.005, 0.0))):
        r = []
        for k in range(segs):
            th = 2 * math.pi * k / segs
            zu = (z0 + dz - K.H("head").z) / HEAD["scale"] + RB.HEAD_PIVOT_SRC.z
            hp = head_shape(RB.head_point(th, zu))
            c = Vector((0.0, K.H("head").y - 0.01, hp.z))
            d = Vector((hp.x - c.x, hp.y - c.y, 0.0))
            p = c + d * (1.0 + (0.0025 + g * 0.6) / max(d.length, 1e-4))
            r.append(bm.verts.new((p.x, p.y, z0 + dz)))
        rings.append(r)
    for a, b in zip(rings, rings[1:] + rings[:1]):
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print("circlet views", RB.projection_uvs(bm, sheet=SHEET))
    return RB.finish(name, bm, mat, RB.head_w)


# ------------------------------------------------------------------ her coat

def trunk_ring(z, grow=0.0):
    """REAL-2's trunk (WOMAN) at z, grown by `grow`: (half-width, front y, back y)."""
    tab = W["trunk"]
    w, yf, yb = (RB.pchip(RB._col(tab, j), z) for j in (1, 2, 3))
    return w + grow, yf - grow, yb + grow


# the coat below the waist: (z, half-width, front y, back y), flaring over the hips to the hem
SKIRT = [(0.356, 0.232, -0.150, 0.168), (0.50, 0.222, -0.142, 0.160), (0.66, 0.210, -0.132, 0.152),
         (0.80, 0.196, -0.122, 0.146), (0.88, 0.186, -0.116, 0.144), (0.95, 0.178, -0.112, 0.130),
         (1.02, 0.152, -0.112, 0.102)]


def coat_ring(z):
    if z <= 1.02:
        return tuple(RB._interp([(r[0], r[i]) for r in SKIRT], z) for i in (1, 2, 3))
    return trunk_ring(z, 0.016)


def _gap_half(z):
    return RB._interp([(0.356, 0.070), (0.70, 0.055), (0.98, 0.030), (1.02, 0.020)], z)


def build_coat_body(name, mat, segs=32, step=0.02):
    """The coat over her trunk, closed (buttoned) from the waist (0.98) to the collar (1.43): her trunk + 0.016, the
    bust kept (real_body.bust_dome, a little softened under the cloth)."""
    bust = dict(W["bust"], amp=W["bust"]["amp"] * 0.92, rx=W["bust"]["rx"] * 1.08)
    z0, z1 = 0.98, 1.43
    nz = int(round((z1 - z0) / step))
    rings = []
    for i in range(nz + 1):
        z = z0 + (z1 - z0) * i / nz
        w, yf, yb = trunk_ring(z, 0.016)
        rings.append((z, w, yf, yb, 2.2, 2.2))
    bm = bmesh.new()
    rv, params = RB.loft(bm, rings, segs)
    for v in bm.verts:
        p = v.co
        if p.y >= 0.0:
            continue
        front = K.clamp01(-p.y / 0.06)
        d, dx = RB.bust_dome(Vector((p.x, p.y, p.z)), bust)
        p.y -= d * front
        p.x += dx * front
    RB.param_uvs(bm, params, "shirt", wrap_u=True)
    return RB.finish(name, bm, mat, RB._trunk_w())


def build_collar(name, mat, segs=22):
    """The high stand collar: up the neck from the coat's top, a little open at the throat."""
    rows = [(1.405, 0.010), (1.44, 0.012), (1.475, 0.010), (1.50, 0.008)]
    grid = []
    for z, g in rows:
        nk = W["neck"]
        w = RB._interp([(r[0], r[1]) for r in nk], z)
        yf = RB._interp([(r[0], r[2]) for r in nk], z)
        yb = RB._interp([(r[0], r[3]) for r in nk], z)
        if z < 1.43:
            tw, tyf, tyb = trunk_ring(1.43, 0.016)
            k = (1.43 - z) / 0.025
            w, yf, yb = w + (tw - w) * k, yf + (tyf - yf) * k, yb + (tyb - yb) * k
        row = []
        for i in range(segs + 1):
            th = math.radians(14.0) + (2 * math.pi - math.radians(28.0)) * i / segs
            p = RP._contour((w, yf, yb), th, n=2.0, grow=g)
            row.append(Vector((p.x, p.y, z)))
        grid.append(row)
    bm = bmesh.new()
    params = RB.grid_slab(bm, grid, 0.005, lambda p: Vector((-p.x, -(p.y - (-0.02)), 0)).normalized())
    RB.param_uvs(bm, params, "bib")
    return RB.finish(name, bm, mat, RB._neck_w())


def build_coat_skirt(name, mat, side, cols=10, rows=10, legs=0.85, front_follow=0.45):
    sx = 1.0 if side == "l" else -1.0
    top, hem = 1.02, 0.356
    grid = []
    for j in range(rows + 1):
        z = top + (hem - top) * j / rows
        ring = coat_ring(z)
        g = math.asin(min(0.99, (_gap_half(z) / ring[0]) ** (2.4 / 2.0)))
        row = []
        for i in range(cols + 1):
            th = g + (math.pi - g) * i / cols
            p = RP._contour(ring, th)
            t = j / rows
            rip = 0.006 * math.sin(th * 6.0 + 0.4 * sx) * t ** 0.8
            cy = (ring[1] + ring[2]) / 2
            rr = math.hypot(p.x, p.y - cy) or 1.0
            x = p.x + p.x / rr * rip
            y = p.y + (p.y - cy) / rr * rip
            if i == cols and z < 0.70:
                y += 0.004 * (0.70 - z) / 0.35
            z2 = z + (0.008 * ((i * 5) % 3 - 1) if j == rows else 0.0)
            row.append(Vector((x * sx, y, z2)))
        grid.append(row)
    if sx < 0:
        grid = [list(reversed(r)) for r in grid]
    bm = bmesh.new()
    params = RB.grid_slab(bm, grid, 0.007, lambda p: Vector((-p.x, -p.y, 0)).normalized())
    RB.param_uvs(bm, params, "apron")
    # the back follows the thighs too (back 0.6): seated, it lies over the stool instead of hanging through it
    # (hips-dominant, 0.25, it went 0.175 m into the stool)
    return RB.finish(name, bm, mat, RB.skirt_w(top, hem, front_follow, legs, back=SKIRT_BACK))


def build_sleeve(name, mat, s):
    S, E, Wr = RB.arm_frame(s)
    du, dl = (E - S).normalized(), (Wr - E).normalized()
    pts = [S - du * 0.065, S - du * 0.012, S + du * 0.060, S + du * 0.140, E - du * 0.018, E + dl * 0.036, E + dl * 0.120,
           Wr - dl * 0.045, Wr + dl * 0.004]
    rads = [(0.060, 0.066), (0.062, 0.068), (0.056, 0.060), (0.051, 0.054), (0.048, 0.050), (0.046, 0.048), (0.042, 0.044),
            (0.040, 0.041), (0.040, 0.041)]
    bm = bmesh.new()
    params, _ = RB.tube(bm, pts, rads, 12, up=RB.up_z, cap0=True, cap1=False)
    RB.param_uvs(bm, params, "sleeve", wrap_u=True)
    return RB.finish(name, bm, mat, RB._arm_w(s))


def build_cuff(name, mat, s):
    """The coat's broad cuff with its gold edge, round the wrist end of the sleeve."""
    S, E, Wr = RB.arm_frame(s)
    dl = (Wr - E).normalized()
    pts = [Wr - dl * 0.075, Wr - dl * 0.040, Wr - dl * 0.004]
    bm = bmesh.new()
    params, _ = RB.tube(bm, pts, [(0.046, 0.048), (0.047, 0.049), (0.046, 0.048)], 12, up=RB.up_z, cap0=False, cap1=False)
    RB.param_uvs(bm, params, "roll", wrap_u=True, wrap_v=False)
    return RB.finish(name, bm, mat, RB._arm_w(s))


PELVIS = [(0.78, 0.090, -0.050, 0.065, 2.2, 2.2), (0.83, 0.150, -0.085, 0.112, 2.2, 2.3), (0.88, 0.165, -0.092, 0.124, 2.2, 2.3),
          (0.94, 0.160, -0.092, 0.110, 2.2, 2.3), (1.00, 0.134, -0.092, 0.086, 2.2, 2.3)]


def build_pelvis(name, mat):
    bm = bmesh.new()
    rv, params = RB.loft(bm, PELVIS, 20, cap_bottom=True)
    RB.param_uvs(bm, params, "seat", wrap_u=True)
    return RB.finish(name, bm, mat, lambda co: {"hips": 1.0})


def build_leg(name, mat, s):
    """Her dark trousers: REAL-2's thigh, knee and calf (WOMAN's leg rows) + 0.008, from the hip to the boot top."""
    rows = [r for r in W["leg"] if r[0] >= 0.30]
    hip, knee, ank = K.H("upperleg." + s), K.T("upperleg." + s), K.T("lowerleg." + s)
    sx = 1 if s == "l" else -1

    def at(z):
        if z >= knee.z:
            return hip.lerp(knee, (hip.z - z) / (hip.z - knee.z))
        return knee.lerp(ank, (knee.z - z) / (knee.z - ank.z))
    pts, rads = [], []
    for z, rf, rs, dy in rows:
        pts.append(at(z) + Vector((0.004 * sx, dy, 0.0)))
        rads.append((rf + 0.008, rs + 0.008))
    bm = bmesh.new()
    params, _ = RB.tube(bm, pts, rads, 12, up=lambda p, d: Vector((0, -1, 0)), cap0=True, cap1=False)
    RB.param_uvs(bm, params, "trousers", wrap_u=True)
    return RB.finish(name, bm, mat, RB._leg_w(s))


def build_belt(name, mat, z=1.015, h=0.034, segs=24):
    bm = bmesh.new()
    params = {}
    layers = [(z - h / 2, 0.008), (z + h / 2, 0.008), (z + h / 2, 0.001), (z - h / 2, 0.001)]
    rings = []
    for li, (zz, g) in enumerate(layers):
        ring = []
        for k in range(segs):
            th = 2 * math.pi * k / segs
            p = RP._contour(coat_ring(z), th, n=2.2, grow=g)
            v = bm.verts.new((p.x, p.y, zz))
            params[v] = (k / segs, li / 4.0)
            ring.append(v)
        rings.append(ring)
    for a, b in zip(rings, rings[1:] + rings[:1]):
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    RB.param_uvs(bm, params, "belt", wrap_u=True, wrap_v=True)
    y = RP._contour(coat_ring(z), 0.0, grow=0.012).y
    bk = bmesh.new()
    c = Vector((0.0, y - 0.002, z))
    for v in K.ellipsoid(bk, c, 0.020, 0.006, 0.018, 8, 4):
        q = v.co - c
        v.co = c + Vector((RB.se(q.x / 0.020, 3.5) * 0.020, q.y, RB.se(q.z / 0.018, 3.5) * 0.018))
    RB.flat_uvs(bk, L.misc_uv("buckle"))
    tmp = bpy.data.meshes.new("_bk")
    bk.to_mesh(tmp)
    bk.free()
    bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    return RB.finish(name, bm, mat, RB._trunk_w())


SKIRT_BACK = 0.6
BOOT = {"length": 0.84, "width": 0.86, "height": 0.88, "girth": 0.82, "top": 0.31, "cuff": True}   # tall, turned-down


# ------------------------------------------------------------------ the quill (R-9: a prop, shown only while she writes)

QUILL_DIR = Vector((0.70, -0.30, 0.64))      # rest frame: up and back out of the writing fist (25.30's)


def build_quill(name, mat):
    bm = bmesh.new()
    params = {}
    pp, _ = RB.tube(bm, [Vector((0, 0, -0.05)), Vector((0, 0, 0.22))], [(0.004, 0.004), (0.002, 0.002)], 5,
                    up=lambda p, d: Vector((1, 0, 0)), cap0=True, cap1=True)
    params.update({v: (0.5, 0.05) for v in pp})
    vane = [(0.04, 0.0), (0.08, 0.016), (0.15, 0.021), (0.20, 0.013), (0.235, 0.0)]
    for sx in (1, -1):
        prev = None
        for z, w in vane:
            a = bm.verts.new((0.0, 0.002 * sx, z))
            b = bm.verts.new((w * sx, 0.002 * sx, z + 0.016))
            params[a] = (0.5, z / 0.24)
            params[b] = (0.5 + 0.45 * sx, z / 0.24)
            if prev:
                bm.faces.new((prev[0], a, b, prev[1]) if sx > 0 else (prev[0], prev[1], b, a))
            prev = (a, b)
    RB.param_uvs(bm, params, "cloth")
    arm = C.rig()
    grip = arm.matrix_world @ arm.data.bones["handslot.r"].head_local
    R = Vector((0, 0, 1)).rotation_difference(QUILL_DIR.normalized()).to_matrix()
    for v in bm.verts:
        v.co = R @ v.co + grip
    ob = K.new_obj(name, bm, mat)
    mw = ob.matrix_world.copy()
    ob.parent = arm
    ob.parent_type = "BONE"
    ob.parent_bone = "handslot.r"
    ob.matrix_world = mw
    return ob


# ------------------------------------------------------------------ build

def build():
    assert C.is_open(CFG["blend"]), "open_base_as_dealer() first (%r)" % bpy.data.filepath
    RT.rest_pose()
    K.remove(["Base_Body"])
    m = bpy.data.materials.get("AN_BaseSkin")
    if m and m.users == 0:
        bpy.data.materials.remove(m)
    K.setup()
    old = [o.name for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(("RB_", "RD_", "Dealer_"))]
    K.remove(old)
    head, body = _materials()
    neck = [(z, w, f, b, 2.0, 2.0) for z, w, f, b in W["neck"]]
    nb = bmesh.new()
    RB.loft(nb, neck, 14)
    bmesh.ops.recalc_face_normals(nb, faces=nb.faces)
    print("neck views", RB.projection_uvs(nb, sheet=SHEET))
    neck_ob = RB.finish("RD_Neck", nb, head, RB._neck_w())
    parts = [RB.build_head("RD_Head", head, sheet=SHEET, face=HEAD, shape=head_shape), build_hair_cap("RD_HairCap", head),
             build_hair_fall("RD_HairFall", head), build_ears("RD_Ears", head), build_circlet("RD_Circlet", head), neck_ob,
             build_coat_body("RD_Coat", body), build_collar("RD_Collar", body), build_belt("RD_Belt", body),
             build_pelvis("RD_Seat", body)]
    for s in ("l", "r"):
        parts += [build_coat_skirt("RD_Skirt_" + s, body, s), build_sleeve("RD_Sleeve_" + s, body, s),
                  build_cuff("RD_Cuff_" + s, body, s), RB.build_hand_real("RD_Hand_" + s, body, s, scale=0.86),
                  build_leg("RD_Leg_" + s, body, s), RB.build_boot("RD_Boot_" + s, body, s, BOOT)]
    counts = {p.name: sum(len(f.vertices) - 2 for f in p.data.polygons) for p in parts}
    props = [build_quill("Dealer_Quill", body)]
    out = MG.join(CFG["body"], parts)
    C.drop_cached_clouds()
    ok, stats = MG.check(out, props=props, tri_budget=TRI_BUDGET)
    print("parts (tris):", sorted(counts.items(), key=lambda kv: -kv[1]))
    return ok, stats


def paint_head():
    import real_bake as BK
    out = BK.bake_head(CFG["body"], "RT_Dealer_Head", SHEET, CFG["head_paint_png"])
    ok, stats = MG.check(bpy.data.objects[CFG["body"]], props=[bpy.data.objects[n] for n in CFG["props"]], tri_budget=TRI_BUDGET)
    return ok, stats, out


# ------------------------------------------------------------------ her clips

HIP_BACK = 0.45                      # her root this far in front of the WorkPoint: her hips 0.05 m forward of the stool's centre
                                     # (REAL-2's arms are shorter than the anime's: at 0.397 her writing hand fell 0.10 m short
                                     # of the ledger; Sit_Chair_Idle's hips stay 0.397 behind the root)
IDLE_HAND = (0.265, -0.020, 0.80)    # by her coat (REAL-2's chest frame), the pick's relaxed stance
IDLE_POLE = (0.70, 0.45, 1.10)


def _use_her_soles():
    RBT._SOLES["pts"] = C.sole_points(C.rig(), [bpy.data.objects[CFG["body"]]])


def pose_idle(t):
    AN.base_pose(RBT.SRC["Idle"], t)
    RBT.stand_tall()
    for s, sx in (("l", 1), ("r", -1)):
        RBT.reach(s, AN.in_frame_of("chest", (IDLE_HAND[0] * sx, IDLE_HAND[1], IDLE_HAND[2])),
                  AN.in_frame_of("chest", (IDLE_POLE[0] * sx, IDLE_POLE[1], IDLE_POLE[2])), (-sx, 0.15, 0.0))


def pose_walk_bar(t):
    """Walk_Bar: the shuffle near the desk, both hands held in front of her waist, elbows out a little (her hair's
    behind her back), riding the chest's bob."""
    RBT.short_walk(t, RBT.BAR_STRIDE)
    sw = 0.02 * math.sin(2 * math.pi * t / AN.WALKING_A_S)
    for s, sx in (("l", 1), ("r", -1)):
        RBT.reach(s, AN.in_frame_of("chest", (0.11 * sx, -0.24, 0.92 + sw * sx)),
                  AN.in_frame_of("chest", (0.50 * sx, 0.05, 1.02)), (-0.6 * sx, 0.8, -0.2))


def ledger(hip_back=HIP_BACK):
    """The open ledger's near page, root-relative when seated (anime_dealer's: the desk's geometry, not her body's)."""
    return Vector((-0.12, -(0.64 - hip_back + 0.04), 0.92))


def pose_write(t, length=AN.SIT_IDLE_S, hip_back=HIP_BACK):
    """Seated: the quill hand makes small strokes on the ledger's near page, lifting to pause once a loop; the left
    hand rests on the desk; head down (the 25.30 method on REAL-2's reach)."""
    AN.base_pose("Sit_Chair_Idle", t)
    AN.lean(WRITE_LEAN, bone="chest")
    k = t / length
    pause = max(0.0, 1 - abs(k - 0.8) / 0.1)
    AN.turn_head(pitch=16.0 - 12.0 * pause)
    stroke = Vector((0.03 * math.sin(2 * math.pi * 6 * k), 0.012 * math.sin(2 * math.pi * 12 * k), 0.0)) * (1 - pause)
    quill = ledger(hip_back) + stroke + Vector((0.0, 0.03, 0.09)) * pause
    AN.arm_to("r", quill, Vector((-0.6, 0.3, 0.5)))
    AN.arm_to("l", Vector((0.12, -(0.64 - hip_back), 0.93)), Vector((0.7, 0.3, 0.6)))


WRITE_LEAN = 24.0                    # the chest's lean over the ledger (the slot's worst miss 0.033 m)


def pose_brief(t, length=AN.SIT_IDLE_S, hip_back=HIP_BACK):
    AN.base_pose("Sit_Chair_Idle", t)
    k = t / length
    AN.turn_head(pitch=-4.0, yaw=6.0 * math.sin(2 * math.pi * k))
    dy = hip_back - 0.32
    open_r = Vector((-0.18, -0.20 + dy, 1.04 + 0.04 * math.sin(2 * math.pi * 2 * k)))
    open_l = Vector((0.18, -0.18 + dy, 1.02 + 0.035 * math.sin(2 * math.pi * 2 * k + 1.3)))
    count = max(0.0, 1 - abs(k - 0.5) / 0.18)
    AN.arm_to("r", open_r.lerp(Vector((-0.06, -0.24 + dy, 1.10)), count), Vector((-0.6, 0.3, 0.95)))
    AN.arm_to("l", open_l.lerp(Vector((0.06, -0.22 + dy, 1.07)), count), Vector((0.6, 0.3, 0.95)))


WALK_STRIDE = 0.70                   # her Walking_A: KayKit's swing toward Idle (a lighter step than the Bartender's 0.55)


def pose_walk(t):
    RBT.short_walk(t, WALK_STRIDE)
    fl, fr = RT.pm("foot.l").translation, RT.pm("foot.r").translation
    lead = fl.y - fr.y
    for s, sx, sw in (("l", 1, -lead), ("r", -1, lead)):
        hand = (0.27 * sx, -0.02 + 0.38 * sw, 0.84 + 0.08 * abs(sw))
        RBT.reach(s, AN.in_frame_of("chest", hand), AN.in_frame_of("chest", (0.65 * sx, 0.50, 1.10)), (-sx, 0.15, 0.0))


CLIPS = [("Idle", AN.IDLE_S, pose_idle, True), ("Walking_A", AN.WALKING_A_S, pose_walk, True),
         ("Walk_Bar", AN.WALKING_A_S, pose_walk_bar, True), ("Write", AN.SIT_IDLE_S, pose_write, True),
         ("Brief", AN.SIT_IDLE_S, pose_brief, True)]


def build_clips(names=None):
    assert C.is_open(CFG["blend"])
    RBT.ensure_sources()
    _use_her_soles()
    order = ["Walk_Bar", "Write", "Brief", "Idle", "Walking_A"]
    clips = sorted([c for c in CLIPS if not names or c[0] in names], key=lambda c: order.index(c[0]))
    out = AN.build_clips(clips)
    for a in bpy.data.actions:
        if a.name in [c[0] for c in clips]:
            a.use_fake_user = True
    print("clips", out)
    return out


def write_reach(hip_back=HIP_BACK):
    arm = C.rig()
    act = bpy.data.actions["Write"]
    worst = 0.0
    for f in C.frames(act):
        m = C.fk(arm, C.Curves(act), f, ["handslot.r"])
        k = f / (AN.SIT_IDLE_S * AN.FPS)
        if max(0.0, 1 - abs(k - 0.8) / 0.1) == 0.0:
            worst = max(worst, (m["handslot.r"].translation - ledger(hip_back)).length)
    return round(worst, 4)


def check_cfg():
    """anime_clearcheck's config for her (measure / desk_report / proof): the dealer's desk geometry and clip lists."""
    import anime_dealer as D
    ck = dict(D.DEALER["check"], hip_back=HIP_BACK)
    return {"role": "dealer_real", "body": CFG["body"], "props": CFG["props"], "check": ck}


def measure():
    import anime_clearcheck as CC
    cfg = check_cfg()
    nums = CC.measure(cfg=cfg)
    rep = CC.desk_report(nums, cfg=cfg)
    # her seated shoulders (25.30 N2: >= the desk top + 0.20 = 1.05 root-local)
    arm = C.rig()
    act = bpy.data.actions["Sit_Chair_Idle"]
    sh = min(min(C.fk(arm, C.Curves(act), f, ["upperarm.l", "upperarm.r"])[b].translation.z for b in ("upperarm.l", "upperarm.r"))
             for f in C.frames(act))
    print("seated shoulders (upperarm heads) lowest: %.3f (the 25.30 rule: >= 1.05)" % sh)
    return nums, rep, round(sh, 3)


def export():
    assert C.is_open(CFG["blend"])
    RT.rest_pose()
    arm = C.rig()
    body = bpy.data.objects[CFG["body"]]
    props = [bpy.data.objects[n] for n in CFG["props"]]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in [arm, body] + props:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.wm.save_mainfile()
    for src in RBT.SRC.values():
        if src in bpy.data.actions:
            bpy.data.actions.remove(bpy.data.actions[src])
    bpy.ops.export_scene.gltf(filepath=CFG["glb"], use_selection=True, export_apply=False, export_skins=True,
                              export_animations=True, export_yup=True)
    print("exported", CFG["glb"], os.path.getsize(CFG["glb"]))
    bpy.ops.wm.revert_mainfile()
    return CFG["glb"]
