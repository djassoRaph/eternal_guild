# real_townsfolk.py - the six townsfolk on route RL (Story 25.31 S2, AC 11; catalogue G19, G24), from Raphael's picks
# (eternal_guild_art/picked/C_G19_<id>.png): the farmer, the local, the traveller, the guard and the merchant on REAL-1
# (the player's head, projected from each pick), the old woman on REAL-2. One module (the shared parts: hair shells,
# hats, tunics, panels, capes, belts; the per-variant recipes and palettes), ONE .blend and ONE GLB per variant (V13:
# actions are file-global, so each body's re-posed Idle / Walking_A / Running_A and any sit re-fit stay its own).
# R-9 (refined): hands empty. Worn things are on the body (hats, the traveller's pack and bedroll) or a visible prop on
# hips (the merchant's purse); the old woman's cane is a separate prop on handslot.r that the game HIDES by default
# (shown only if the game ever needs it: she walks without it).
# One call per step (README's runner), for a variant id V:
#   open_base_as(V)      the base (REAL-1 / REAL-2) saved as g19_<V>_real.blend (a file load: own call)
#   build(V)             its parts joined into <Role>_Body (the head projection + the body atlas) + its props
#   paint_head(V)        the painted head pass (real_bake)
#   build_clips(V)       Idle (straightened, hands by the clothes), Walking_A (its own stride, arms swinging),
#                        Running_A (a jog: KayKit's sprint legs cut toward Idle), arms kept outside the clothes in
#                        Running_A and the sit clips (real_player.arms_out)
#   measure(V)           ground speeds (Walking_A, Running_A), seat thickness vs the base, tops, widths
#   export(V)            Rig + body + props to assets/characters/custom/g19_<V>_real.glb
import math
import os

import bmesh
import bpy
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
TRI_BUDGET = 10000
GLB_DIR = "F:/GAME I AM MAKING/shiningsun/assets/characters/custom/"
ROLE = {"farmer": "Farmer", "local": "Local", "traveller": "Traveller", "guard": "Guard", "merchant": "Merchant",
        "old_woman": "OldWoman"}
WOMEN = ("old_woman",)
SRC_RUN = "SRC_Running_A"


def cfg(v):
    r = ROLE[v]
    return {
        "id": v, "role": r,
        "blend": C.BLEND + "g19_%s_real.blend" % v,
        "head_png": ART + "textures/realistic/g19_%s_real_head.png" % v,
        "head_paint_png": ART + "textures/realistic/g19_%s_real_headpaint.png" % v,
        "body_png": ART + "textures/realistic/g19_%s_real_body.png" % v,
        "glb": GLB_DIR + "g19_%s_real.glb" % v,
        "body": r + "_Body",
        "props": {"merchant": [r + "_Purse"], "old_woman": [r + "_Cane"]}.get(v, []),
        "chain": RC.REAL_2 if v in WOMEN else RC.REAL_1,
        "sheet": L.TOWNSFOLK_SHEETS[v],
    }


# ------------------------------------------------------------------ heads

# the men: the player's head (the Bartender's analytic head narrowed and lowered 0.02 m: eyes 1.710) at each face's width
HEAD_X = {"farmer": 0.92, "local": 0.88, "traveller": 0.88, "guard": 0.89, "merchant": 0.91}
DZ = -0.020


def man_shape(v):
    hx = HEAD_X[v]
    return lambda p: Vector((p.x * hx, p.y, p.z + DZ))


W = RC.WOMAN
OLD_HEAD = dict(W["head"], width=0.92, jaw=0.12, nose=0.75, brow=0.5)    # REAL-2's head, an older face (her pick)


def woman_shape(p):
    """REAL-2's analytic head placement (real_dealer.head_shape with OLD_HEAD)."""
    sc, wd, jaw = OLD_HEAD["scale"], OLD_HEAD["width"], OLD_HEAD["jaw"]
    q = p.copy()
    q.x *= 1.0 - jaw * K.smoothstep(1.71, 1.61, p.z)
    q = q - RB.HEAD_PIVOT_SRC
    return K.H("head") + Vector((q.x * sc * wd, q.y * sc, q.z * sc))


def shape_of(v):
    return woman_shape if v in WOMEN else man_shape(v)


def unshape_z(v, z):
    """The analytic head's own z for a rest z on variant v's head (the inverse of its shape along z)."""
    if v in WOMEN:
        return (z - K.H("head").z) / OLD_HEAD["scale"] + RB.HEAD_PIVOT_SRC.z
    return z - DZ


def head_ring_at(v, z):
    """(half-width, front y, back y, centre y) of variant v's shaped head at rest height z (no nose)."""
    zu = unshape_z(v, z)
    w, yf, yb = RB.head_ring(zu)
    sh = shape_of(v)
    pw = sh(Vector((w, (yf + yb) / 2, zu)))
    pf = sh(Vector((0.0, yf, zu)))
    pb = sh(Vector((0.0, yb, zu)))
    return pw.x, pf.y, pb.y, (pf.y + pb.y) / 2


def hair_shell(name, mat, v, low, top=1.852, apex=1.881, thick=None, mess=1.0, cols=34, rows=8, part=False):
    """A hair shell over the (unshaped) analytic head from the lower edge low(theta deg) up (real_player.build_hair,
    parametrised): thick(theta deg) the shell's thickness, mess the tufts' size, part a centre parting; shaped onto the
    variant's head and projected from its sheet."""
    thick = thick or (lambda a: RB._interp([(0, 0.020), (40, 0.018), (70, 0.012), (100, 0.012), (140, 0.018), (180, 0.020)], a))
    bm = bmesh.new()
    ths = [RB.head_theta(k, cols) for k in range(cols)]
    grid = []
    for j in range(rows + 1):
        s = j / rows
        row = []
        for k, th in enumerate(ths):
            a = abs(math.degrees(th))
            zb = low(a)
            z = zb + (top - zb) * s ** 0.85
            p = RB.head_point(th, z)
            c = Vector((0.0, (RB.head_ring(z)[1] + RB.head_ring(z)[2]) / 2.0, z))
            d = Vector((p.x - c.x, p.y - c.y, 0.0))
            d = d.normalized() if d.length > 1e-6 else Vector((0, 1, 0))
            n = (d * (1.0 - 0.6 * K.smoothstep(0.55, 1.0, s)) + Vector((0, 0, 1)) * K.smoothstep(0.55, 1.0, s)).normalized()
            t = thick(a) * (0.25 + 0.75 * K.smoothstep(0.0, 0.35, s)) + 0.004 * K.smoothstep(0.6, 1.0, s)
            t += mess * (0.003 + 0.005 * s * (1.0 - s)) * math.sin(k * 2.7 + j * 1.3) * (0.5 + 0.5 * math.sin(k * 0.9))
            if part:
                t *= 1.0 - 0.5 * RB.gauss(math.degrees(th), 6.0) * s
            row.append(bm.verts.new(p + n * t))
        grid.append(row)
    for a_, b_ in zip(grid[:-1], grid[1:]):
        for k in range(cols):
            bm.faces.new((a_[k], a_[(k + 1) % cols], b_[(k + 1) % cols], b_[k]))
    tip = bm.verts.new((0.0, -0.075, apex))
    for k in range(cols):
        bm.faces.new((grid[-1][k], grid[-1][(k + 1) % cols], tip))
    RB._reshape(bm, shape_of(v))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    f0 = max(bm.faces, key=lambda f: f.calc_center_median().z)
    if f0.normal.z < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    print("%s views" % name, RB.projection_uvs(bm, sheet=cfg(v)["sheet"]))
    return RB.finish(name, bm, mat, RB.head_w)


def _hair_low(table):
    return lambda a: RB._interp(table, a)


# the player's hairline (unshaped z by column angle): the hairline, the temples, over the ears, the nape
HAIRLINE = [(0, 1.812), (25, 1.808), (45, 1.795), (62, 1.776), (78, 1.762), (100, 1.758), (125, 1.735), (150, 1.700),
            (180, 1.688)]


# ------------------------------------------------------------------ hats (rest frame, fitted round the shaped head)

def _ring_pts(cx, cy, rx, ry, z, n, th0=0.0, th1=2 * math.pi, closed=True, ne=2.2):
    out = []
    m = n if closed else n + 1
    for i in range(m):
        th = th0 + (th1 - th0) * i / n
        out.append(Vector((cx + rx * RB.se(math.sin(th), ne), cy - ry * RB.se(math.cos(th), ne), z)))
    return out


def _loft_rings(bm, rings, n):
    """rings: [[Vector] * n] bottom to top (closed): side faces; returns {vert: (u, v)}."""
    params, vs = {}, []
    R = len(rings)
    for j, ring in enumerate(rings):
        row = []
        for i, p in enumerate(ring):
            vv = bm.verts.new(p)
            params[vv] = (i / n, j / max(R - 1, 1))
            row.append(vv)
        vs.append(row)
    for a, b in zip(vs[:-1], vs[1:]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    return params, vs


def build_hat(name, mat, v, kind):
    """The variant's headwear on the body atlas ("cloth": the crown / dome, "bib": the brim / peak, "strap_dark": the
    feather): kind straw (the farmer: a wide frayed brim), cap (the local: a puffy cloth cap, a short peak), beret (the
    merchant: slanted to his left, a feather), helmet (the guard: AH-9's crested morion-like helmet, a peak, cheek and
    neck guards), scarf (the old woman's headscarf over the crown, above her bun)."""
    zb = {"straw": 1.776, "cap": 1.786, "beret": 1.792, "helmet": 1.745}[kind]
    w, yf, yb, cy = head_ring_at(v, zb + 0.015)
    rx0, ry0 = w + 0.026, (yb - yf) / 2 + 0.026          # the band: over the hair
    n = 24
    bm = bmesh.new()
    parts = []                                            # (bmesh, params, region)

    def crown(profile, tilt=0.0, shift=0.0, region="cloth"):
        b = bmesh.new()
        rings = []
        for dz, k, g, dy in profile:
            r = _ring_pts(shift, cy + dy, rx0 * k + g, ry0 * k + g, zb + dz, n)
            if tilt:
                r = [Vector((p.x, p.y, p.z + tilt * (p.x - shift))) for p in r]
            rings.append(r)
        params, vs = _loft_rings(b, rings, n)
        top = vs[-1]
        c = sum((x.co for x in top), Vector()) / len(top) + Vector((0, 0, 0.006))
        tv = b.verts.new(c)
        params[tv] = (0.5, 1.0)
        for i in range(n):
            b.faces.new((top[i], top[(i + 1) % n], tv))
        b.faces.new(list(reversed(vs[0])))
        parts.append((b, params, region, True))

    def brim(out, droop, lift_front=0.0, th0=0.0, th1=2 * math.pi, closed=True, rows=3, jag=0.0, region="bib",
             thick=0.010, down=0.0, zoff=0.0, back_droop=0.0):
        grid = []
        m = n if closed else n
        for j in range(rows + 1):
            t = j / rows
            row = []
            for i in range(m + (0 if closed else 1)):
                th = th0 + (th1 - th0) * i / m
                ext = out(th) * t
                p = Vector((rx0 * RB.se(math.sin(th), 2.2) * (1 + 0.0), cy - ry0 * RB.se(math.cos(th), 2.2), zb + zoff))
                d = Vector((p.x, p.y - cy, 0.0)).normalized()
                q = p + d * ext
                q.z += -droop * t * t + lift_front * t * max(0.0, math.cos(th)) - down * t \
                    - back_droop * t * t * max(0.0, -math.cos(th)) ** 1.5
                if j == rows and jag:
                    q += d * jag * ((i * 7) % 3 - 1)
                    q.z += 0.5 * jag * ((i * 5) % 3 - 1)
                row.append(q)
            if closed:
                row.append(row[0])
            grid.append(row)
        b = bmesh.new()
        params = RB.grid_slab(b, grid, thick, lambda p: Vector((0, 0, 1)))
        parts.append((b, params, region, False))

    if kind == "straw":
        crown([(0.0, 1.0, 0.0, 0.0), (0.035, 1.02, 0.004, 0.0), (0.085, 0.96, 0.0, 0.0), (0.125, 0.78, 0.0, 0.0),
               (0.148, 0.42, 0.0, 0.0)])
        brim(lambda th: 0.185 + 0.012 * math.cos(2 * th), droop=0.030, lift_front=0.035, rows=3, jag=0.012, thick=0.009,
             back_droop=0.060)
    elif kind == "cap":
        crown([(0.0, 1.0, 0.0, 0.0), (0.028, 1.12, 0.010, -0.012), (0.062, 1.16, 0.012, -0.024), (0.088, 0.95, 0.0, -0.026),
               (0.104, 0.55, 0.0, -0.022)])
        brim(lambda th: 0.062, droop=0.0, th0=math.radians(-62), th1=math.radians(62), closed=False, rows=2,
             down=0.018, thick=0.008, zoff=0.004)
    elif kind == "beret":
        crown([(0.0, 1.0, 0.0, 0.0), (0.022, 1.18, 0.012, 0.004), (0.050, 1.26, 0.014, 0.008), (0.075, 1.05, 0.0, 0.008),
               (0.090, 0.55, 0.0, 0.006)], tilt=0.28, shift=0.018)
        fb = bmesh.new()                                  # the feather: a thin blade at his left, up and back
        base = Vector((rx0 + 0.030, cy + 0.02, zb + 0.050))
        tipv = base + Vector((0.030, 0.065, 0.085))
        ax = (tipv - base).normalized()
        side = ax.cross(Vector((1, 0, 0))).normalized()
        grid = []
        for j in range(7):
            t = j / 6
            c = base.lerp(tipv, t) + Vector((0.012, 0, 0)) * math.sin(math.pi * t)
            hw = 0.018 * math.sin(math.pi * min(1.0, 0.15 + t * 0.95))
            grid.append([c - side * hw, c + side * hw])
        params = RB.grid_slab(fb, grid, 0.004, lambda p: Vector((1, 0, 0)))
        parts.append((fb, params, "straps", False))
    elif kind == "helmet":
        # the dome (a little higher at the back of the brow: the pick's profile), from the brow band to the top
        crown([(0.0, 1.0, 0.004, 0.0), (0.040, 1.02, 0.006, 0.002), (0.085, 0.95, 0.004, 0.004), (0.120, 0.76, 0.0, 0.006),
               (0.142, 0.42, 0.0, 0.008)])
        # the peak: forward over the brow, pointed, tipped down a little
        brim(lambda th: 0.070 * max(0.0, math.cos(th)) ** 0.7, droop=0.0, th0=math.radians(-70), th1=math.radians(70),
             closed=False, rows=2, down=0.016, thick=0.008, region="cloth")
        # cheek and neck guards: a skirt from the band down round the sides and back (open at the face), flaring
        gb = bmesh.new()
        grid = []
        th0, th1 = math.radians(62), math.radians(298)
        cols = 18
        for j, (dz, fl) in enumerate(((0.002, 0.000), (-0.045, 0.006), (-0.095, 0.016), (-0.140, 0.034))):
            row = []
            for i in range(cols + 1):
                th = th0 + (th1 - th0) * i / cols
                back = max(0.0, -math.cos(th))
                p = Vector((rx0 * RB.se(math.sin(th), 2.2), cy - ry0 * RB.se(math.cos(th), 2.2), zb + dz))
                d = Vector((p.x, p.y - cy, 0)).normalized()
                p += d * (fl * (0.5 + back))
                if back < 0.25:                          # the cheek guards hug the face's sides a little lower
                    p.z -= 0.010 * j
                row.append(p)
            grid.append(row)
        params = RB.grid_slab(gb, grid, 0.008, lambda p: -Vector((p.x, p.y - cy, 0)).normalized())
        parts.append((gb, params, "cloth", False))
        # the crest: a fin along the midline from the brow to the back of the dome
        cb = bmesh.new()
        grid = []
        for j in range(9):
            t = j / 8
            ang = math.radians(-70 + 150 * t)               # over the top, front to back
            y = cy + ry0 * 0.98 * math.sin(ang)
            zs = zb + 0.140 * math.cos(ang) ** 0.6 if math.cos(ang) > 0 else zb
            hgt = 0.072 * (1.0 - 0.45 * t) * (1.0 if t > 0.05 else 0.6)     # AH-9: the crest is the guard's tell
            grid.append([Vector((0.0, y, zs - 0.012)), Vector((0.0, y + 0.006, zs + hgt))])
        params = RB.grid_slab(cb, grid, 0.014, lambda p: Vector((1, 0, 0)))
        for vv in cb.verts:
            vv.co.x -= 0.007
        parts.append((cb, params, "cloth", False))
    elif kind == "scarf":
        raise ValueError("the old woman's scarf is build_headscarf")
    out = bmesh.new()
    lay = out.loops.layers.uv.new("UVMap")
    for b, params, region, wrap in parts:
        if region == "straps" and kind == "beret":
            RB.flat_uvs(b, L.misc_uv("strap_dark"))
        else:
            RB.param_uvs(b, params, region, wrap_u=wrap)
        bmesh.ops.recalc_face_normals(b, faces=b.faces)
        tmp = bpy.data.meshes.new("_hat")
        b.to_mesh(tmp)
        b.free()
        out.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    return RB.finish(name, out, mat, RB.head_w)


# ------------------------------------------------------------------ the men's clothes (REAL-1's neutral man + cloth)

def man_ring(z, grow=0.0):
    w, yf, yb = RP._man_trunk(z)
    return w + grow, yf - grow, yb + grow


def tunic(name, mat, rows_below, grow=0.014, top=1.575, region="shirt", legs=0.85, front_follow=0.55, back=0.60,
          jag=0.010, n=2.4, segs=28, belt_z=1.03, step=0.045, slit=None):
    """A closed tunic / shirt / dress: the trunk + grow from the neck base (top) down to belt_z, then rows_below
    [(z, half-width, front y, back y)] flaring to the hem (the last row). One loft (u round from his back seam, his
    front at u 0.5); above belt_z the torso's weights, below it the skirt's (follows the thighs: legs, front_follow,
    back). slit: (theta deg, half-gap deg) side slits from the hem up (the guard's surcoat)."""
    zs = []
    z = top
    while z > belt_z + 1e-6:
        zs.append(z)
        z -= step
    rings = [(z, ) + man_ring(z, grow) + (n, n) for z in zs]
    rings += [(r[0], r[1], r[2], r[3], n, n) for r in rows_below]
    rings.sort(key=lambda r: r[0])
    bm = bmesh.new()
    rv, params = RB.loft(bm, rings, segs)
    hem = rings[0][0]
    if jag:
        for k, vv in enumerate(rv[0]):
            vv.co.z += jag * ((k * 5) % 3 - 1)
    RB.param_uvs(bm, params, region, wrap_u=True)
    sk = RB.skirt_w(belt_z, hem, front_follow, legs, back=back)

    def w(co):
        if co.z >= belt_z:
            return RB.torso_w(co)
        return sk(co)
    return RB.finish(name, bm, mat, w)


def panels(name, mat, rows, spans, region="apron", legs=0.85, front_follow=0.45, back=0.30, thick=0.007, cols=10,
           jag=0.006, top=1.04):
    """Hanging panels (the guard's tabard, open at the sides): rows [(z, half-width, front y, back y)] top to hem;
    spans [(theta0 deg, theta1 deg)] (0 his front)."""
    bm = bmesh.new()
    params_all = {}
    hem = rows[-1][0]
    for t0, t1 in spans:
        grid = []
        for j, (z, w, yf, yb) in enumerate(rows):
            cyc = (yf + yb) / 2
            d = (yb - yf) / 2
            row = []
            for i in range(cols + 1):
                th = math.radians(t0 + (t1 - t0) * i / cols)
                p = Vector((w * RB.se(math.sin(th), 2.4), cyc - d * RB.se(math.cos(th), 2.4), z))
                if j == len(rows) - 1 and jag:
                    p.z += jag * ((i * 5) % 3 - 1)
                row.append(p)
            grid.append(row)
        params_all.update(RB.grid_slab(bm, grid, thick, lambda p: Vector((-p.x, -p.y, 0)).normalized()))
    RB.param_uvs(bm, params_all, region)
    return RB.finish(name, bm, mat, RB.skirt_w(top, hem, front_follow, legs, back=back))


def sleeve(name, mat, s, k=1.0, cuff_r=None, region="sleeve", woman=False):
    """A long sleeve from inside the shoulder to the wrist (real_player.build_coat_sleeve's line, radii x k; cuff_r
    narrows the wrist end: a gathered cuff)."""
    S, E, Wr = RB.arm_frame(s)
    du, dl = (E - S).normalized(), (Wr - E).normalized()
    pts = [S - du * 0.075, S - du * 0.015, S + du * 0.070, S + du * 0.160, E - du * 0.020, E + dl * 0.040, E + dl * 0.130,
           Wr - dl * 0.050, Wr + dl * 0.006]
    rads = [(0.078, 0.084), (0.080, 0.088), (0.074, 0.080), (0.068, 0.072), (0.064, 0.068), (0.062, 0.064), (0.058, 0.060),
            (0.054, 0.056), (0.053, 0.055)]
    if woman:
        pts = [S - du * 0.065, S - du * 0.012, S + du * 0.060, S + du * 0.140, E - du * 0.018, E + dl * 0.036, E + dl * 0.120,
               Wr - dl * 0.045, Wr + dl * 0.004]
        rads = [(0.060, 0.066), (0.062, 0.068), (0.056, 0.060), (0.051, 0.054), (0.048, 0.050), (0.046, 0.048), (0.042, 0.044),
                (0.040, 0.041), (0.040, 0.041)]
    rads = [(a * k, b * k) for a, b in rads]
    if cuff_r:
        rads[-2] = (cuff_r, cuff_r * 1.04)
        rads[-1] = (cuff_r * 0.98, cuff_r * 1.02)
    bm = bmesh.new()
    params, _ = RB.tube(bm, pts, rads, 12, up=RB.up_z, cap0=True, cap1=False)
    RB.param_uvs(bm, params, region, wrap_u=True)
    return RB.finish(name, bm, mat, RB._arm_w(s) if woman else RB.arm_w(s))


def band(name, mat, ring_fn, z, h, region="belt", grow=0.010, segs=24, buckle=True, n=2.4, weights=None):
    """A belt / band round ring_fn(z) (half-width, front y, back y), grow outside it, with a buckle in front."""
    bm = bmesh.new()
    params = {}
    layers = [(z - h / 2, grow), (z + h / 2, grow), (z + h / 2, grow * 0.2), (z - h / 2, grow * 0.2)]
    rings = []
    for li, (zz, g) in enumerate(layers):
        ring = []
        for k in range(segs):
            th = 2 * math.pi * k / segs
            p = RP._contour(ring_fn(z), th, n=n, grow=g)
            vv = bm.verts.new((p.x, p.y, zz))
            params[vv] = (k / segs, li / 4.0)
            ring.append(vv)
        rings.append(ring)
    for a, b in zip(rings, rings[1:] + rings[:1]):
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    RB.param_uvs(bm, params, region, wrap_u=True, wrap_v=True)
    if buckle:
        y = RP._contour(ring_fn(z), 0.0, n=n, grow=grow + 0.004).y
        bk = bmesh.new()
        c = Vector((0.0, y - 0.002, z))
        for vv in K.ellipsoid(bk, c, 0.024, 0.006, h * 0.55, 8, 4):
            q = vv.co - c
            vv.co = c + Vector((RB.se(q.x / 0.024, 3.5) * 0.024, q.y, RB.se(q.z / (h * 0.55), 3.5) * h * 0.55))
        RB.flat_uvs(bk, L.misc_uv("buckle"))
        tmp = bpy.data.meshes.new("_bk")
        bk.to_mesh(tmp)
        bk.free()
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    return RB.finish(name, bm, mat, weights or RB.torso_w)


def rope_ends(name, mat, z, x=0.06):
    """The farmer's rope belt's knot and two hanging ends at his front left."""
    bm = bmesh.new()
    y0 = man_ring(z, 0.03)[1]
    base = Vector((x, y0 - 0.006, z))
    K.ellipsoid(bm, base, 0.016, 0.012, 0.016, 8, 5)
    for dx, ln in ((-0.006, 0.20), (0.012, 0.15)):
        pts = [base + Vector((dx, -0.006 * t, -ln * t)) for t in (0.0, 0.35, 0.7, 1.0)]
        RB.tube(bm, pts, [0.009, 0.008, 0.008, 0.007], 6, up=lambda p, d: Vector((0, -1, 0)), cap0=False, cap1=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    RB.flat_uvs(bm, L.misc_uv("knot"))
    return RB.finish(name, bm, mat, RB.skirt_w(z, z - 0.20, 0.55, 0.6))


def cape(name, mat, top_rows, hem, open_half, region="apron", cols=16, rows=11, thick=0.008, jag=0.012):
    """The traveller's cloak: a sheet from the shoulders round his back to the front edges (open in front: open_half(z)
    m each side of the midline), hanging to the hem. top_rows [(z, half-width, front y, back y)] top to hem. Weights:
    the chest over the shoulders (with the upper arms near them), then the hips and the thighs (a hanging cloth)."""
    grid = []
    for j in range(rows + 1):
        z = top_rows[0][0] + (hem - top_rows[0][0]) * j / rows
        w = RB._interp([(r[0], r[1]) for r in top_rows], z)
        yf = RB._interp([(r[0], r[2]) for r in top_rows], z)
        yb = RB._interp([(r[0], r[3]) for r in top_rows], z)
        ring = (w, yf, yb)
        g = math.asin(min(0.99, (open_half(z) / w) ** (2.4 / 2.0)))
        row = []
        for i in range(cols + 1):
            th = g + (2 * math.pi - 2 * g) * i / cols
            p = RP._contour(ring, th)
            q = Vector((p.x, p.y, z))
            t = j / rows
            q.x += 0.006 * math.sin(th * 7.0) * t
            q.y += 0.006 * math.cos(th * 7.0) * t
            if j == rows:
                q.z += jag * ((i * 5) % 3 - 1)
            row.append(q)
        grid.append(row)
    bm = bmesh.new()
    params = RB.grid_slab(bm, grid, thick, lambda p: Vector((-p.x, -p.y, 0)).normalized())
    RB.param_uvs(bm, params, region)
    top = top_rows[0][0]
    sk = RB.skirt_w(1.05, hem, 0.6, 0.55, back=0.20)

    def w(co):
        if co.z >= 1.05:
            ww = RB.torso_w(co)
            if co.z > 1.30 and abs(co.x) > 0.16:          # over the shoulder points: ride the upper arm a little
                s = "l" if co.x > 0 else "r"
                k = 0.35 * K.clamp01((abs(co.x) - 0.16) / 0.08) * K.clamp01((co.z - 1.30) / 0.10)
                ww = {b: v * (1 - k) for b, v in ww.items()}
                ww["upperarm." + s] = ww.get("upperarm." + s, 0.0) + k
            return ww
        return sk(co)
    return RB.finish(name, bm, mat, w)


def roll_ring(name, mat, rings, region, segs=20, wv=False, weights=None):
    """A closed loft of rings [(z, half-width, front y, back y, n)] (a scarf, a cowl), u round, v by z."""
    bm = bmesh.new()
    rv, params = RB.loft(bm, [(z, w, yf, yb, n, n) for z, w, yf, yb, n in rings], segs, cap_bottom=False, cap_top=False)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    RB.param_uvs(bm, params, region, wrap_u=True, wrap_v=wv)
    return RB.finish(name, bm, mat, weights or (lambda co: K.blend("chest", "head", 0.10 * K.clamp01((co.z - 1.55) / 0.06))))


def box(bm, c, size, rot=None):
    """An axis box (rest frame) at c of size (x, y, z); returns its verts."""
    res = bmesh.ops.create_cube(bm, size=1.0)
    for vv in res["verts"]:
        q = Vector((vv.co.x * size[0], vv.co.y * size[1], vv.co.z * size[2]))
        vv.co = c + (rot @ q if rot else q)
    return res["verts"]


def build_pack(name, mat):
    """The traveller's backpack (leather, a flap and two straps) with the grey bedroll across its top, on his back
    over the cloak (worn: on the body, chest-weighted)."""
    bm = bmesh.new()
    before = set(bm.faces)
    box(bm, Vector((0.0, 0.265, 1.29)), (0.30, 0.13, 0.31))
    box(bm, Vector((0.0, 0.333, 1.36)), (0.31, 0.02, 0.16))            # the flap
    box(bm, Vector((0.0, 0.338, 1.21)), (0.17, 0.025, 0.09))           # the outer pocket
    pack_f = set(bm.faces) - before
    for f in pack_f:
        for l in f.loops:
            pass
    rv = set(bm.verts)
    bmp = {}
    for vv in rv:
        bmp[vv] = (0.5 + vv.co.x / 0.4, (vv.co.z - 1.13) / 0.34)
    RB.param_uvs(bm, bmp, "straps")
    roll = bmesh.new()
    pts = [Vector((x, 0.255, 1.495)) for x in (-0.23, -0.12, 0.0, 0.12, 0.23)]
    pp, _ = RB.tube(roll, pts, [0.072] * 5, 12, up=lambda p, d: Vector((0, 0, 1)), cap0=True, cap1=True)
    RB.param_uvs(roll, pp, "cloth", wrap_u=True)
    for x in (-0.10, 0.10):                                            # the bedroll's straps
        st = bmesh.new()
        ring = []
        for k in range(10):
            a = 2 * math.pi * k / 10
            ring.append((x, 0.255 + 0.078 * math.cos(a), 1.495 + 0.078 * math.sin(a)))
        pts2 = [Vector(p) for p in ring]
        RB.tube(st, pts2 + [pts2[0]], [0.010] * 11, 4, up=lambda p, d: Vector((1, 0, 0)), cap0=False, cap1=False)
        RB.flat_uvs(st, L.misc_uv("strap_dark"))
        tmp = bpy.data.meshes.new("_st")
        st.to_mesh(tmp)
        st.free()
        roll.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    tmp = bpy.data.meshes.new("_roll")
    roll.to_mesh(tmp)
    roll.free()
    bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return RB.finish(name, bm, mat, lambda co: {"chest": 1.0})


def shoulder_straps(name, mat):
    """The pack's shoulder straps over the cloak, front of the shoulders down to the armpits."""
    bm = bmesh.new()
    for sx in (1, -1):
        pts = [Vector((0.11 * sx, 0.20, 1.50)), Vector((0.13 * sx, 0.02, 1.54)), Vector((0.14 * sx, -0.13, 1.47)),
               Vector((0.15 * sx, -0.16, 1.36)), Vector((0.16 * sx, -0.10, 1.24))]
        RB.tube(bm, pts, [(0.006, 0.022)] * 5, 4, up=lambda p, d: Vector((p.x, p.y, 0)).normalized(), cap0=True, cap1=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    RB.flat_uvs(bm, L.misc_uv("strap_dark"))
    return RB.finish(name, bm, mat, lambda co: {"chest": 1.0})


def pouches(name, mat, z, xs):
    bm = bmesh.new()
    for x in xs:
        y = man_ring(z, 0.03)[1] if abs(x) < 0.1 else RP._contour(man_ring(z, 0.03), math.asin(min(0.99, abs(x) / man_ring(z, 0.03)[0])), n=2.4).y
        c = Vector((x, y - 0.010, z - 0.06))
        box(bm, c, (0.075, 0.035, 0.085))
        box(bm, c + Vector((0, -0.019, 0.03)), (0.079, 0.006, 0.035))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    RB.flat_uvs(bm, L.misc_uv("strap_dark"))
    return RB.finish(name, bm, mat, lambda co: {"hips": 1.0})


def bracer(name, mat, s, region="roll"):
    S, E, Wr = RB.arm_frame(s)
    dl = (Wr - E).normalized()
    pts = [Wr - dl * 0.16, Wr - dl * 0.09, Wr - dl * 0.015]
    bm = bmesh.new()
    params, _ = RB.tube(bm, pts, [(0.062, 0.066), (0.060, 0.064), (0.058, 0.062)], 12, up=RB.up_z, cap0=False, cap1=False)
    RB.param_uvs(bm, params, region, wrap_u=True)
    return RB.finish(name, bm, mat, RB.arm_w(s))


def mantle(name, mat, region="bib", n=2.4, rows=None):
    """The guard's mail mantle: a short shoulder cape round the neck to z 1.30 over the chest and the upper arms'
    tops (closed; mail). The traveller's capelet is the same piece in his cloak's cloth, rounder (n 2.0, sloped)."""
    rows = rows or [(1.585, 0.090, -0.098, 0.060), (1.555, 0.150, -0.118, 0.100), (1.525, 0.210, -0.138, 0.132),
                    (1.480, 0.255, -0.155, 0.150), (1.420, 0.268, -0.162, 0.158), (1.360, 0.262, -0.165, 0.157),
                    (1.310, 0.250, -0.165, 0.152)]
    bm = bmesh.new()
    rv, params = RB.loft(bm, [(z, w, yf, yb, n, n) for z, w, yf, yb in rows], 28)
    for k, vv in enumerate(rv[-1]):                      # the lower edge: scalloped a little
        vv.co.z += 0.006 * ((k * 5) % 3 - 1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    RB.param_uvs(bm, params, region, wrap_u=True)

    def w(co):
        ww = RB.torso_w(co)
        if abs(co.x) > 0.17 and co.z < 1.50:
            s = "l" if co.x > 0 else "r"
            k = 0.45 * K.clamp01((abs(co.x) - 0.17) / 0.07)
            ww = {b: v * (1 - k) for b, v in ww.items()}
            ww["upperarm." + s] = ww.get("upperarm." + s, 0.0) + k
        return ww
    return RB.finish(name, bm, mat, w)


def purse(name, mat):
    """The merchant's coin purse at his right hip, front (a prop on hips, worn: visible)."""
    bm = bmesh.new()
    c = Vector((-0.175, -0.125, 0.995))
    for vv in K.ellipsoid(bm, c, 0.050, 0.030, 0.052, 10, 6):
        q = vv.co - c
        if q.z > 0.02:
            vv.co.x = c.x + q.x * (1 - 0.6 * (q.z - 0.02) / 0.032)
            vv.co.y = c.y + q.y * (1 - 0.5 * (q.z - 0.02) / 0.032)
    K.ellipsoid(bm, c + Vector((0, 0, 0.050)), 0.022, 0.014, 0.012, 8, 4)   # the gathered neck
    RB.flat_uvs(bm, L.misc_uv("knot"))
    ob = K.new_obj(name, bm, mat)
    return _bone_prop(ob, "hips")


def _bone_prop(ob, bone):
    arm = C.rig()
    mw = ob.matrix_world.copy()
    ob.parent = arm
    ob.parent_type = "BONE"
    ob.parent_bone = bone
    ob.matrix_world = mw
    return ob


# ------------------------------------------------------------------ the old woman (REAL-2)

def woman_ring(z, grow=0.0):
    tab = W["trunk"]
    w, yf, yb = (RB.pchip(RB._col(tab, j), z) for j in (1, 2, 3))
    return w + grow, yf - grow, yb + grow


def dress(name, mat):
    """Her long dress: the bodice over REAL-2's trunk (a soft bust), gathered at the waist, the skirt flaring to the
    ankles (wide: her legs inside it), a patched, worn hem. Weights: the torso's above the waist, the skirt's below
    (the front follows the thighs, the back hangs)."""
    bust = dict(W["bust"], amp=W["bust"]["amp"] * 0.55, rx=W["bust"]["rx"] * 1.2, power=1.4, power_up=1.6)
    rows = []
    z = 1.430
    while z > 1.03:
        w, yf, yb = woman_ring(z, 0.018)
        rows.append((z, w, yf, yb, 2.3, 2.3))
        z -= 0.03
    skirt = [(1.020, 0.150, -0.112, 0.100), (0.960, 0.178, -0.118, 0.128), (0.880, 0.198, -0.128, 0.148),
             (0.780, 0.214, -0.146, 0.162), (0.640, 0.232, -0.170, 0.180), (0.480, 0.250, -0.195, 0.198),
             (0.320, 0.268, -0.214, 0.214), (0.180, 0.282, -0.226, 0.228), (0.120, 0.286, -0.230, 0.232)]
    rows += [(z, w, yf, yb, 2.2, 2.2) for z, w, yf, yb in skirt]
    rows.sort(key=lambda r: r[0])
    bm = bmesh.new()
    rv, params = RB.loft(bm, rows, 32)
    for vv in bm.verts:
        p = vv.co
        if p.y < 0 and p.z > 1.10:
            d, dx = RB.bust_dome(Vector((p.x, p.y, p.z)), bust)
            f = K.clamp01(-p.y / 0.06)
            p.y -= d * f
            p.x += dx * f
    for k, vv in enumerate(rv[0]):
        vv.co.z += 0.010 * ((k * 5) % 3 - 1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    RB.param_uvs(bm, params, "shirt", wrap_u=True)
    # the back follows the thighs too (0.85): seated, a hips-led back hem went 0.10 m through the floor; the legs'
    # share only 0.6 (h^0.8): at 0.9 the ankle-length hem swung forward like a board in Walking_A
    sk = RB.skirt_w(1.02, 0.12, 0.80, 0.60, back=0.85)
    tw = RB._trunk_w()
    return RB.finish(name, bm, mat, lambda co: tw(co) if co.z >= 1.02 else sk(co))


def shawl(name, mat):
    """The lavender shawl round her shoulders: draped over the shoulders and upper arms' tops, down to a point at her
    back (z ~1.00) and in two hanging ends in front, pinned at the throat; a fringed edge."""
    # Stage D 2 (2026-10-04): wider over the upper arms and longer at the sides (it read as a bib on her chest; the
    # pick's shawl drapes over the shoulders and the arms to the elbows)
    rows = [(1.455, 0.078, -0.086, 0.054), (1.425, 0.150, -0.110, 0.096), (1.395, 0.228, -0.132, 0.128),
            (1.350, 0.278, -0.150, 0.148), (1.290, 0.296, -0.158, 0.156), (1.230, 0.300, -0.160, 0.158)]
    cols = 32
    grid = []
    for j in range(len(rows) + 3):
        row = []
        for i in range(cols + 1):
            th = math.radians(-180 + 360 * i / cols)
            if j < len(rows):
                z, w, yf, yb = rows[j]
                p = RP._contour((w, yf, yb), th, n=2.3)
                row.append(Vector((p.x, p.y, z)))
            else:
                # below the last ring: the back drops to a point, the front ends hang, the sides stop (the arms)
                k = j - len(rows) + 1
                z0, w, yf, yb = rows[-1]
                a = abs(math.degrees(th))
                back = K.clamp01((a - 120) / 60.0)          # 1 at the back centre
                front = K.clamp01((40 - a) / 40.0)          # 1 at the front centre
                drop = 0.07 * k * (0.85 + 1.0 * back ** 1.5 + 0.7 * front)
                p = RP._contour((w - 0.004 * k, yf + 0.002 * k, yb - 0.004 * k), th, n=2.3)
                row.append(Vector((p.x, p.y, z0 - drop)))
        grid.append(row)
    bm = bmesh.new()
    params = RB.grid_slab(bm, grid, 0.009, lambda p: Vector((-p.x, -p.y, 0)).normalized())
    RB.param_uvs(bm, params, "bib")
    tw = RB._trunk_w()

    def w(co):
        ww = tw(co)
        if abs(co.x) > 0.15 and co.z > 1.0:
            s = "l" if co.x > 0 else "r"
            k = 0.80 * K.clamp01((abs(co.x) - 0.15) / 0.09)
            ww = {b: v * (1 - k) for b, v in ww.items()}
            ww["upperarm." + s] = ww.get("upperarm." + s, 0.0) + k
        return ww
    return RB.finish(name, bm, mat, w)


def headscarf(name, mat, v):
    """Her rust headscarf over the crown, from the hairline at the front to above the bun at the back (a hair shell
    grown out further), tied at the nape."""
    low = _hair_low([(0, 1.800), (30, 1.792), (55, 1.770), (80, 1.745), (110, 1.735), (140, 1.745), (180, 1.760)])
    return hair_shell(name, mat, v, low, top=1.856, apex=1.886, thick=lambda a: 0.026, mess=0.6, cols=30, rows=6)


def bun(name, mat, v):
    hb = K.H("head")
    c = Vector((0.0, hb.y + 0.118, hb.z + 0.110))
    bm = bmesh.new()
    K.ellipsoid(bm, c, 0.048, 0.040, 0.044, 12, 7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print("bun views", RB.projection_uvs(bm, sheet=cfg(v)["sheet"]))
    return RB.finish(name, bm, mat, RB.head_w)


CANE_WANT = Vector((0.0, -0.12, -1.0))     # in her Idle: down to the floor, a little ahead of the hand


def _cane_dir():
    """The cane's rest-frame direction: the one handslot.r carries to CANE_WANT in Idle's first frame (built in
    rest; the bone takes it along)."""
    arm = C.rig()
    act = bpy.data.actions["Idle"]          # her re-posed Idle once build_clips has run (build again after it)
    m = C.fk(arm, C.Curves(act), act.frame_range[0], ["handslot.r"])["handslot.r"]
    rest = arm.data.bones["handslot.r"].matrix_local
    R = (m.to_3x3() @ rest.to_3x3().inverted())
    return (R.inverted() @ CANE_WANT.normalized()).normalized()


def cane(name, mat):
    """The old woman's walking stick (R-9 refined: a separate prop on handslot.r, hidden by the game by default)."""
    bm = bmesh.new()
    d = _cane_dir()
    pts = [Vector((0, 0, 0)) - d * 0.06 + Vector((0.03, 0, 0)), Vector((0, 0, 0)) - d * 0.05, Vector((0, 0, 0))]
    pts += [d * (0.90 * t) for t in (0.33, 0.66, 1.0)]
    RB.tube(bm, pts, [0.016, 0.016, 0.015, 0.014, 0.013, 0.012], 6, up=lambda p, dd: Vector((1, 0, 0)), cap0=True, cap1=True)
    RB.flat_uvs(bm, L.misc_uv("metal_dark"))
    arm = C.rig()
    grip = arm.matrix_world @ arm.data.bones["handslot.r"].head_local
    for vv in bm.verts:
        vv.co = vv.co + grip
    ob = K.new_obj(name, bm, mat)
    return _bone_prop(ob, "handslot.r")


# ------------------------------------------------------------------ the recipes

FARMER_SHIRT = [(0.98, 0.205, -0.128, 0.142), (0.92, 0.222, -0.138, 0.150), (0.87, 0.232, -0.142, 0.154)]
LOCAL_TUNIC = [(0.98, 0.200, -0.124, 0.140), (0.90, 0.222, -0.134, 0.150), (0.80, 0.238, -0.142, 0.158)]
TRAV_TUNIC = [(0.98, 0.200, -0.124, 0.140), (0.90, 0.222, -0.134, 0.150), (0.80, 0.238, -0.142, 0.158)]
GUARD_TABARD = [(1.04, 0.205, -0.134, 0.132), (0.94, 0.222, -0.142, 0.150), (0.80, 0.240, -0.150, 0.162),
                (0.62, 0.252, -0.156, 0.170), (0.45, 0.258, -0.160, 0.174)]
CLOAK = [(1.525, 0.150, -0.110, 0.115), (1.480, 0.225, -0.140, 0.155), (1.420, 0.272, -0.150, 0.178),
         (1.300, 0.282, -0.150, 0.186), (1.100, 0.278, -0.150, 0.190), (0.800, 0.290, -0.160, 0.205),
         (0.400, 0.315, -0.175, 0.225)]
# the traveller's capelet (Stage D 1: the mail mantle's profile read as square shoulders in his cloth): sloped, rounder
CAPELET = [(1.590, 0.095, -0.104, 0.068), (1.560, 0.160, -0.124, 0.108), (1.520, 0.222, -0.144, 0.140),
           (1.470, 0.258, -0.158, 0.158), (1.410, 0.270, -0.165, 0.166), (1.340, 0.268, -0.168, 0.168),
           (1.270, 0.262, -0.168, 0.168)]
BOOTS = {"farmer": {"top": 0.42, "cuff": False, "girth": 1.06}, "local": {"top": 0.24, "cuff": False},
         "traveller": {"top": 0.40, "cuff": True}, "guard": {"top": 0.37, "cuff": True},
         "merchant": {"top": 0.33, "cuff": True},
         "old_woman": {"length": 0.84, "width": 0.86, "height": 0.88, "girth": 0.74, "top": 0.21, "cuff": False}}


def trouser_leg(name, mat, s, girth=0.90, bottom=0.335):
    """real_body.build_trouser_leg (the spike's rows) carried on down to `bottom` over a low boot's top (r 0.070 at
    the ankle), the frayed hem kept."""
    sx = 1 if s == "l" else -1
    hip, knee, ank = K.H("upperleg." + s), K.T("upperleg." + s), K.T("lowerleg." + s)
    zs = [0.93, 0.85, 0.75, 0.65, 0.56, 0.50, 0.45, 0.40, 0.36, 0.335]
    rad = [0.106, 0.100, 0.092, 0.083, 0.075, 0.073, 0.075, 0.078, 0.077, 0.068]
    if bottom < 0.335:
        zs[-1] = 0.31
        rad[-1] = 0.074
        zs += [0.5 * (0.31 + bottom), bottom]
        rad += [0.074 / girth * 0.98, 0.078 / girth * 0.98]

    def at(z):
        if z >= knee.z:
            return hip.lerp(knee, (hip.z - z) / (hip.z - knee.z))
        return knee.lerp(ank, (knee.z - z) / (knee.z - ank.z))
    pts = [at(z) + Vector((0.006 * sx, 0, 0)) for z in zs]
    rads = [(r * girth, r * girth * 1.02) for r in rad]
    bm = bmesh.new()
    params, rings = RB.tube(bm, pts, rads, 12, up=lambda p, d: Vector((0, -1, 0)), cap0=True, cap1=False)
    for k, vv in enumerate(rings[-1]):
        vv.co.z -= 0.010 * (k % 2)
    RB.param_uvs(bm, params, "trousers", wrap_u=True)
    return RB.finish(name, bm, mat, RB.leg_w(s))


# the trousers' seat: just outside REAL-1's neutral trunk, its crotch cap at 0.845 (the base's trunk ends at 0.855):
# seated it rests on the 0.45 chair like the base body (the spike's pelvis, capped at 0.80, sat 0.044 m into the seat)
PELVIS = [(0.845, 0.110, -0.066, 0.088, 2.2, 2.2), (0.885, 0.166, -0.100, 0.122, 2.3, 2.3),
          (0.940, 0.189, -0.113, 0.138, 2.4, 2.4), (0.990, 0.187, -0.114, 0.133, 2.4, 2.4), (1.060, 0.177, -0.116, 0.116, 2.4, 2.4)]


def pelvis(name, mat):
    bm = bmesh.new()
    rv, params = RB.loft(bm, PELVIS, 20, cap_bottom=True)
    RB.param_uvs(bm, params, "seat", wrap_u=True)
    return RB.finish(name, bm, mat, lambda co: {"hips": 1.0})


def _materials(c):
    head = K.mat("RT_%s_Head" % c["role"], "C29A7C", c["head_png"])
    body = K.mat("RT_%s_Body" % c["role"], "6A5A4C", c["body_png"])
    for m, name in ((head, "%s_head" % c["id"]), (body, "%s_body" % c["id"])):
        im = next(n for n in m.node_tree.nodes if n.type == "TEX_IMAGE").image
        im.name = name
        im.reload()
    return head, body


def _men_head(v, head, P):
    sh = man_shape(v)
    neck = [(1.47, 0.068, -0.112, 0.040, 2.2, 2.2), (1.54, 0.064, -0.106, 0.028, 2.2, 2.2), (1.60, 0.061, -0.102, 0.022, 2.2, 2.2),
            (1.67, 0.060, -0.096, 0.018, 2.2, 2.2)]
    hx = HEAD_X[v]
    sheet = cfg(v)["sheet"]
    parts = [RB.build_head(P + "Head", head, sheet=sheet, shape=sh),
             RB.build_ears(P + "Ears", head, sheet=sheet, shape=sh),
             RB.build_neck(P + "Neck", head, sheet=sheet, rings=[(z, w / hx, f, b, n1, n2) for z, w, f, b, n1, n2 in neck], shape=sh)]
    if v != "guard":                                     # the guard's helmet covers his hair
        if v == "traveller":
            low = _hair_low([(0, 1.818), (25, 1.814), (45, 1.800), (62, 1.782), (78, 1.768), (100, 1.762), (125, 1.738),
                             (150, 1.705), (180, 1.692)])
            parts.append(hair_shell(P + "Hair", head, v, low, top=1.846, apex=1.866,
                                    thick=lambda a: RB._interp([(0, 0.012), (70, 0.008), (140, 0.010), (180, 0.012)], a), mess=0.5))
        else:
            parts.append(hair_shell(P + "Hair", head, v, _hair_low(HAIRLINE), top=1.835, apex=1.855))
    return parts


def build(v):
    c = cfg(v)
    assert C.is_open(c["blend"]), "open_base_as(%r) first (%r)" % (v, bpy.data.filepath)
    RT.rest_pose()
    K.remove(["Base_Body"])
    m = bpy.data.materials.get("AN_BaseSkin")
    if m and m.users == 0:
        bpy.data.materials.remove(m)
    K.setup()
    P = "RT_"
    old = [o.name for o in bpy.data.objects if o.type == "MESH" and (o.name.startswith(P) or o.name.startswith(c["role"] + "_"))]
    K.remove(old)
    head, body = _materials(c)
    parts, props = [], []
    if v in WOMEN:
        sheet = c["sheet"]
        nb = bmesh.new()
        RB.loft(nb, [(z, w, f, b, 2.0, 2.0) for z, w, f, b in W["neck"]], 14)
        bmesh.ops.recalc_face_normals(nb, faces=nb.faces)
        print("neck views", RB.projection_uvs(nb, sheet=sheet))
        hair_low = _hair_low([(0, 1.782), (30, 1.776), (55, 1.762), (75, 1.742), (95, 1.712), (130, 1.680), (180, 1.668)])
        parts += [RB.build_head(P + "Head", head, sheet=sheet, face=OLD_HEAD, shape=woman_shape), RB.finish(P + "Neck", nb, head, RB._neck_w()),
                  RB.build_ears(P + "Ears", head, sheet=sheet, shape=woman_shape),
                  hair_shell(P + "Hair", head, v, hair_low, top=1.850, apex=1.872, thick=lambda a: 0.012, mess=0.4, part=True),
                  headscarf(P + "Scarf", head, v), bun(P + "Bun", head, v),
                  dress(P + "Dress", body), shawl(P + "Shawl", body),
                  band(P + "Sash", body, lambda z: woman_ring(z, 0.018), 1.045, 0.030, region="belt", grow=0.006, buckle=False, n=2.3,
                       weights=RB._trunk_w())]
        for s in ("l", "r"):
            parts += [sleeve(P + "Sleeve_" + s, body, s, k=1.05, woman=True),
                      RB.build_hand_real(P + "Hand_" + s, body, s, scale=0.84),
                      RB.build_boot(P + "Boot_" + s, body, s, BOOTS[v])]
        props.append(cane(c["props"][0], body))
    else:
        parts += _men_head(v, head, P)
        if v == "farmer":
            parts += [build_hat(P + "Hat", body, v, "straw"),
                      tunic(P + "Shirt", body, FARMER_SHIRT, grow=0.020, jag=0.014),
                      band(P + "Rope", body, lambda z: man_ring(z, 0.024), 1.035, 0.026, buckle=False),
                      rope_ends(P + "RopeEnds", body, 1.035)]
            sl = dict(k=1.12, cuff_r=0.050)
        elif v == "local":
            parts += [build_hat(P + "Cap", body, v, "cap"),
                      tunic(P + "Tunic", body, LOCAL_TUNIC, grow=0.016, jag=0.010),
                      band(P + "Belt", body, lambda z: man_ring(z, 0.018), 1.050, 0.040)]
            sl = dict(k=1.0)
        elif v == "traveller":
            parts += [tunic(P + "Tunic", body, TRAV_TUNIC, grow=0.016, jag=0.012),
                      band(P + "Belt", body, lambda z: man_ring(z, 0.018), 1.050, 0.040),
                      pouches(P + "Pouches", body, 1.04, (0.14, -0.14)),
                      cape(P + "Cloak", body, CLOAK, 0.40, lambda z: RB._interp([(1.525, 0.05), (1.40, 0.10), (1.10, 0.15), (0.40, 0.17)], z)),
                      roll_ring(P + "Cowl", body, [(1.455, 0.205, -0.125, 0.150, 2.3), (1.495, 0.175, -0.140, 0.150, 2.3),
                                                    (1.530, 0.130, -0.130, 0.130, 2.2), (1.545, 0.100, -0.110, 0.090, 2.2)], "apron"),
                      roll_ring(P + "Scarf", body, [(1.485, 0.105, -0.140, 0.075, 2.2), (1.525, 0.100, -0.145, 0.072, 2.2),
                                                    (1.565, 0.088, -0.132, 0.062, 2.2), (1.600, 0.078, -0.120, 0.050, 2.2)], "bib"),
                      mantle(P + "Capelet", body, region="apron", n=2.05, rows=CAPELET),
                      build_pack(P + "Pack", body), shoulder_straps(P + "Straps", body)]
            parts += [bracer(P + "Bracer_" + s, body, s) for s in ("l", "r")]
            sl = dict(k=0.95)
        elif v == "guard":
            parts += [build_hat(P + "Helmet", body, v, "helmet"),
                      tunic(P + "Gambeson", body, [(0.98, 0.196, -0.122, 0.138), (0.93, 0.205, -0.128, 0.142)], grow=0.014,
                            jag=0.0, region="shirt"),
                      panels(P + "Tabard", body, GUARD_TABARD, [(-80, 80), (100, 260)]),
                      mantle(P + "Mantle", body),
                      band(P + "Belt", body, lambda z: man_ring(z, 0.022), 1.075, 0.042)]
            sl = dict(k=1.02)
        elif v == "merchant":
            parts += [build_hat(P + "Beret", body, v, "beret"),
                      RP.build_vest(P + "Tunic", body), RP.build_coat_body(P + "Coat", body), RP.build_lapels(P + "Lapels", body),
                      RP.build_collar(P + "Collar", body),
                      band(P + "Belt", body, lambda z: RP.coat_ring(z), 1.075, 0.044, grow=0.006)]
            parts += [RP.build_coat_skirt(P + "Skirt_" + s, body, s, legs=0.85, front_follow=0.45) for s in ("l", "r")]
            parts += [RP.build_cuff(P + "Cuff_" + s, body, s) for s in ("l", "r")]
            props.append(purse(c["props"][0], body))
            sl = dict(k=1.0)
        parts.append(pelvis(P + "Seat", body))
        for s in ("l", "r"):
            parts += [sleeve(P + "Sleeve_" + s, body, s, **sl),
                      RB.build_hand_real(P + "Hand_" + s, body, s, scale=1.0),
                      trouser_leg(P + "Leg_" + s, body, s, girth=0.90, bottom=min(0.335, BOOTS[v]["top"] - 0.025)),
                      RB.build_boot(P + "Boot_" + s, body, s, BOOTS[v])]
    counts = {p.name: sum(len(f.vertices) - 2 for f in p.data.polygons) for p in parts}
    out = MG.join(c["body"], parts)
    C.drop_cached_clouds()
    ok, stats = MG.check(out, props=props, tri_budget=TRI_BUDGET)
    print("parts (tris):", sorted(counts.items(), key=lambda kv: -kv[1]))
    return ok, stats


def open_base_as(v, overwrite_ok=False):
    c = cfg(v)
    return RC.open_base_as(c["blend"], c["chain"], overwrite_ok=overwrite_ok)


def paint_head(v):
    import real_bake as BK
    c = cfg(v)
    out = BK.bake_head(c["body"], "RT_%s_Head" % c["role"], c["sheet"], c["head_paint_png"])
    ok, stats = MG.check(bpy.data.objects[c["body"]], props=[bpy.data.objects[n] for n in c["props"]], tri_budget=TRI_BUDGET)
    return ok, stats, out


# ------------------------------------------------------------------ clips

# (hand, chest lean deg): the hands by the clothes, close in (Stage D 1: at 0.33-0.345 the six stood like gunslingers)
IDLE = {"farmer": ((0.305, -0.030, 0.870), 0.0), "local": ((0.290, -0.030, 0.875), 0.0),
        "traveller": ((0.300, -0.060, 0.875), 0.0), "guard": ((0.300, -0.030, 0.880), 0.0),
        "merchant": ((0.300, -0.040, 0.880), 0.0), "old_woman": ((0.255, -0.050, 0.795), 9.0)}
IDLE_POLE = (0.50, 0.65, 0.32)            # the elbows back and a little out (x, y, z over the hand's height)
WALK_STRIDE = {"farmer": 0.62, "local": 0.66, "traveller": 0.66, "guard": 0.64, "merchant": 0.60, "old_woman": 0.60}
TORSO = ["hips", "spine", "chest", "head"]
JOG_LEAN = 0.45
JOG_STRIDE = {"farmer": 0.45, "local": 0.48, "traveller": 0.45, "guard": 0.46, "merchant": 0.42, "old_woman": 0.32}


def _c():
    for v, k in ROLE.items():
        if C.is_open(cfg(v)["blend"]):
            return cfg(v)
    raise AssertionError("not a townsfolk file: %r" % bpy.data.filepath)


ARMS_OUT = ("Running_A", "Sit_Chair_Down", "Sit_Chair_Idle", "Sit_Chair_StandUp", "Cheer", "Interact")
SRC_OF = {c: "SRC_" + c for c in ARMS_OUT if c != "Running_A"}


def _ensure_run_src():
    """The base's clips this file rewrites, copied once (SRC_*, fake user, removed for the export): every rebuild
    starts from them, so a re-run never compounds."""
    RBT.ensure_sources()
    for clip, src in [("Running_A", SRC_RUN)] + list(SRC_OF.items()):
        if src not in bpy.data.actions:
            a = bpy.data.actions[clip]
            assert "real_player_arms_out" not in a, "%s was already rewritten: rebuild the file from the base" % clip
            cp = a.copy()
            cp.name = src
            cp.use_fake_user = True


def _stoop(deg):
    if deg:
        AN.lean(deg, bone="chest")
        AN.turn_head(pitch=-deg * 0.8)


def pose_idle_of(v):
    hand, stoop = IDLE[v]

    def pose(t):
        AN.base_pose(RBT.SRC["Idle"], t)
        RBT.stand_tall()
        _stoop(stoop)
        for s, sx in (("l", 1), ("r", -1)):
            RBT.reach(s, AN.in_frame_of("chest", (hand[0] * sx, hand[1], hand[2])),
                      AN.in_frame_of("chest", (IDLE_POLE[0] * sx, IDLE_POLE[1], hand[2] + IDLE_POLE[2])), (-sx, 0.15, 0.0))
    return pose


def pose_walk_of(v):
    hand, stoop = IDLE[v]
    stride = WALK_STRIDE[v]

    def pose(t):
        RBT.short_walk(t, stride)
        _stoop(stoop)
        fl, fr = RT.pm("foot.l").translation, RT.pm("foot.r").translation
        lead = fl.y - fr.y
        for s, sx, sw in (("l", 1, -lead), ("r", -1, lead)):
            h = (hand[0] * sx, hand[1] + 0.38 * sw, hand[2] + 0.06 + 0.08 * abs(sw))
            RBT.reach(s, AN.in_frame_of("chest", h), AN.in_frame_of("chest", (IDLE_POLE[0] * sx, IDLE_POLE[1], hand[2] + IDLE_POLE[2])), (-sx, 0.15, 0.0))
    return pose


def pose_jog_of(v):
    """Running_A as a jog: its legs' swing and the hips' bob blended toward Idle by JOG_STRIDE (KayKit's sprint on
    adult legs is 7 m/s; a patron hurries at 2.5), the torso and arms Running_A's; the soles back on the floor."""
    k = JOG_STRIDE[v]
    hand, stoop = IDLE[v]

    def pose(t):
        AN.base_pose(RBT.SRC["Idle"], t)
        arm = C.rig()
        idle = {b: arm.pose.bones[b].rotation_quaternion.copy() for b in AN.LEG_BONES + TORSO}
        idle_h = arm.pose.bones["hips"].location.copy()
        AN.base_pose(SRC_RUN, t)
        for b in AN.LEG_BONES:
            pb = arm.pose.bones[b]
            pb.rotation_quaternion = idle[b].slerp(pb.rotation_quaternion, k)
        for b in TORSO:                                   # the sprint's forward lean halved: an upright jog
            pb = arm.pose.bones[b]
            pb.rotation_quaternion = idle[b].slerp(pb.rotation_quaternion, JOG_LEAN)
        hb = arm.pose.bones["hips"]
        hb.location = idle_h.lerp(hb.location, k)
        RT._upd()
        RBT._ground()
        _stoop(stoop * 0.5)
    return pose


def build_clips(v):
    c = cfg(v)
    assert C.is_open(c["blend"])
    _ensure_run_src()
    RBT._SOLES["pts"] = C.sole_points(C.rig(), [bpy.data.objects[c["body"]]])
    src = bpy.data.actions[SRC_RUN]
    run_s = (src.frame_range[1] - src.frame_range[0]) / AN.FPS
    out = AN.build_clips([("Idle", AN.IDLE_S, pose_idle_of(v), True), ("Walking_A", AN.WALKING_A_S, pose_walk_of(v), True),
                          ("Running_A", run_s, pose_jog_of(v), True)])
    for n in ("Idle", "Walking_A", "Running_A"):
        bpy.data.actions[n].use_fake_user = True
    for clip in ARMS_OUT:
        if clip != "Running_A":                           # repeatable: start from the base's clip, recorded once
            a = bpy.data.actions[clip]
            src = bpy.data.actions[SRC_OF[clip]]
            a.fcurves.clear()
            for fc in src.fcurves:
                n = a.fcurves.new(fc.data_path, index=fc.array_index, action_group=fc.group.name if fc.group else "")
                n.keyframe_points.add(len(fc.keyframe_points))
                for k, kp in zip(n.keyframe_points, fc.keyframe_points):
                    k.co, k.interpolation = kp.co, kp.interpolation
                    k.handle_left, k.handle_right = kp.handle_left, kp.handle_right
                n.update()
        # at most 6 degrees: the arm pass already fits the base; this only clears the cloth a few cm wider than it (a
        # cloak or capelet over the arms is cloth the arms move UNDER, never pushed out of)
        out.append((clip + " arms out", RP.arms_out(clip, body_name=c["body"], gap=0.02, max_deg=6.0)))
    print("clips", out)
    return out


def _region_verts(body, regions):
    """The body atlas vertices whose faces' UV centres lie in real_layout.REG's regions (the head material excluded)."""
    me = body.data
    uv = me.uv_layers[0].data
    bi = [i for i, m in enumerate(me.materials) if m and m.name.endswith("_Body")]
    out = set()
    for p in me.polygons:
        if p.material_index not in bi:
            continue
        cu = sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total
        cv = sum(uv[i].uv.y for i in p.loop_indices) / p.loop_total
        for r in regions:
            u0, v0, u1, v1 = L.REG[r]
            if u0 <= cu <= u1 and v0 <= cv <= v1:
                out.update(p.vertices)
    return sorted(out)


def measure(v):
    """Ground speeds (the villagers' Walking_A, the patrons' Running_A), the seat (the body's lowest seat vertex in
    Sit_Chair_Idle vs the 0.45 chair), tops and widths."""
    import anime_clearcheck as CC
    c = cfg(v)
    body = bpy.data.objects[c["body"]]
    nums = {}
    for clip in ("Walking_A", "Running_A"):
        nums[clip] = round(CC.ground_speed(clip, {"body": c["body"], "props": c["props"]}), 3)
    CC._rest()
    arm = C.rig()
    nums["top_rest"] = round(max((body.matrix_world @ vv.co).z for vv in body.data.vertices), 3)
    dg = bpy.context.evaluated_depsgraph_get()
    for clip, f, key in (("Idle", 0, "idle"), ("Sit_Chair_Idle", 10, "sit")):
        arm.animation_data.action = bpy.data.actions[clip]
        bpy.context.scene.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        ev = body.evaluated_get(dg)
        me = ev.to_mesh()
        co = [vv.co.copy() for vv in me.vertices]
        ev.to_mesh_clear()
        nums[key + "_top"] = round(max(p.z for p in co), 3)
        nums[key + "_halfwidth"] = round(max(abs(p.x) for p in co), 3)
        if key == "sit":
            hips = arm.matrix_world @ arm.pose.bones["hips"].head
            seat = [p for p in co if (Vector((p.x, p.y)) - Vector((hips.x, hips.y))).length < 0.20 and p.z < hips.z]
            nums["seat_low_all"] = round(min(p.z for p in seat), 4) if seat else None
            # V13's seat thickness: the body's own seat (the trousers' seat / the legs, never a hem) vs the 0.45 chair
            idx = _region_verts(body, ("seat", "trousers") if v not in WOMEN else ("shirt",))
            sb = [co[i] for i in idx if (Vector((co[i].x, co[i].y)) - Vector((hips.x, hips.y))).length < 0.20 and co[i].z < hips.z]
            nums["seat_low"] = round(min(p.z for p in sb), 4) if sb else None
            nums["sit_hips_y"] = round(hips.z, 4)
            nums["sit_front"] = round(-min(p.y for p in co), 3)
    arm.animation_data.action = None
    RT.rest_pose()
    print(v, nums)
    return nums


def export(v):
    c = cfg(v)
    assert C.is_open(c["blend"])
    RT.rest_pose()
    arm = C.rig()
    arm.animation_data.action = None
    body = bpy.data.objects[c["body"]]
    props = [bpy.data.objects[n] for n in c["props"]]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in [arm, body] + props:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.wm.save_mainfile()
    for src in list(RBT.SRC.values()) + [SRC_RUN] + list(SRC_OF.values()):
        if src in bpy.data.actions:
            bpy.data.actions.remove(bpy.data.actions[src])
    if os.path.exists(c["glb"]):
        print("re-exporting (a new asset of this story):", c["glb"])
    bpy.ops.export_scene.gltf(filepath=c["glb"], use_selection=True, export_apply=False, export_skins=True,
                              export_animations=True, export_yup=True)
    print("exported", c["glb"], os.path.getsize(c["glb"]))
    bpy.ops.wm.revert_mainfile()
    return c["glb"]
