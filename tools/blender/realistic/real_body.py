# real_body.py - route RL's body parts (the spike 2026-10-04; 25.31 S1.0), built in the REST pose of the REAL-1 rig
# (real_chain.REAL_1's table) from the concept sheet's own silhouette rows (real_layout). anime_kit supplies the
# primitives (new_obj, skin, chain, blend, ellipsoid) and the rig lookups (K.setup, K.H, K.T); every shape here is
# new: the anime kit's parts are drawn for the SD test's landmarks and head. The shapes' heights are REAL-1's (the
# Bartender's sheet); a REAL-2 body is built in REAL-1's frame and carried onto the REAL-2 rest by transfer_rest
# (build_base(transfer=...): REAL-2's Base_Body).
#
# Two texture schemes:
#   - the head material (the head, beard, ears, neck): each face takes one of the concept's three views by its normal
#     (front / side / back) and its corners project onto that view's pixels (real_layout.head_uv, on any sheet:
#     projection_uvs(bm, sheet=...); the head builders pass `sheet` through): the face, scar, brows, beard strands
#     and ears ARE the concept's drawing.
#   - the body atlas (everything else): each part's own (u, v) parameters mapped into its region (real_layout.REG);
#     a closed ring wraps over 1 + PAD of its region and the painter tiles that region (real_paint.body_texture).
# Blender frame: front -Y, his left +X, up Z. Godot (x, y, z) = Blender (x, z, -y).
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import anime_common as C
import anime_kit as K
import real_layout as L

# ------------------------------------------------------------------ the concept's head rows (px, measured 2026-10-04)
# front view: (row, half-width px of the skull; the ears' rows 75-93 left out)
HEAD_FRONT = [(32, 0.5), (33, 7.5), (36, 15.5), (39, 20.5), (42, 24.5), (45, 27.5), (48, 29.5), (51, 31.5), (54, 32.5),
              (57, 33.5), (60, 34.5), (63, 34.5), (66, 35.5), (72, 35.5)]
# side view (his left; front is image-left): (row, front px, back px) of the head's silhouette
HEAD_SIDE = [(36, 674, 691), (39, 663, 702), (42, 658, 707), (45, 654, 711), (48, 651, 714), (51, 648, 716), (54, 646, 718),
             (57, 645, 719), (60, 644, 720), (63, 643, 721), (66, 642, 722), (69, 641, 722), (72, 641, 723), (75, 639, 723),
             (78, 639, 723), (81, 639, 722), (84, 641, 722), (87, 640, 721), (90, 639, 720), (93, 638, 719), (96, 636, 717),
             (99, 635, 716), (102, 633, 715), (105, 634, 715), (108, 640, 716), (111, 640, 716), (114, 640, 717),
             (117, 643, 718), (120, 643, 719)]
# the beard: front view half-widths (row, px) and side view fronts (row, px)
BEARD_FRONT = [(96, 40.5), (102, 36.5), (108, 37.5), (114, 38.5), (120, 39.5), (126, 39.0), (132, 37.2), (137, 35.0),
               (143, 28.8), (149, 23.0), (155, 11.5), (158, 4.6)]
BEARD_SIDE = [(100, 637), (108, 640), (114, 640), (117, 643), (120, 643), (123, 642), (126, 641), (129, 640), (132, 639),
              (135, 638), (141, 638), (144, 639), (147, 640), (150, 642), (153, 641), (156, 643)]


def _z(view, row):
    cx, top, sole = L.VIEWS[view]
    return L.HEIGHT - (row - top) * L.scale(view)


def _interp(table, z):
    """table [(z, value)] in any order: linear in z, clamped at the ends."""
    t = sorted(table)
    if z <= t[0][0]:
        return t[0][1]
    if z >= t[-1][0]:
        return t[-1][1]
    for (z0, a), (z1, b) in zip(t[:-1], t[1:]):
        if z0 <= z <= z1:
            return a + (b - a) * (z - z0) / (z1 - z0)
    return t[-1][1]


SF, SS, SB = L.scale("front"), L.scale("side"), L.scale("back")
_W = [(_z("front", r), w * SF) for r, w in HEAD_FRONT]
_YF = [(_z("side", r), (f - L.VIEWS["side"][0]) * SS) for r, f, b in HEAD_SIDE]
_YB = [(_z("side", r), (b - L.VIEWS["side"][0]) * SS) for r, f, b in HEAD_SIDE]
_BW = [(_z("front", r), w * SF) for r, w in BEARD_FRONT]
_BF = [(_z("side", r), (f - L.VIEWS["side"][0]) * SS) for r, f in BEARD_SIDE]


def se(t, n):
    """A superellipse coordinate: |t|^(2/n) with t's sign (n 2: an ellipse; larger: boxier)."""
    return math.copysign(abs(t) ** (2.0 / n), t)


def gauss(d, s):
    return math.exp(-(d / s) ** 2)


# ------------------------------------------------------------------ the head (analytic: rings + features)

def head_ring(z):
    """(half-width, front y at the midline WITHOUT the nose, back y) of the skull/face at height z."""
    if z >= 1.745:
        w = _interp(_W, z)
    elif z >= 1.69:
        w = 0.0925 - (1.745 - z) * 0.05
    else:
        w = _interp([(1.69, 0.0898), (1.665, 0.086), (1.645, 0.079), (1.625, 0.069), (1.612, 0.060), (1.60, 0.050)], z)
    yb = _interp(_YB, z) if z >= 1.64 else _interp([(1.64, 0.016), (1.60, 0.020)], z)
    if z >= 1.735:
        yf = _interp(_YF, z)
    elif z >= 1.672:                                         # the face plane under the nose (the nose is a feature)
        yf = -0.1890 + (1.735 - z) * 0.055
    else:                                                     # upper lip, mouth, chin (under the beard)
        yf = _interp([(1.672, -0.1855), (1.645, -0.180), (1.62, -0.168), (1.60, -0.13)], z)
    return w, yf, yb


def nose(x, z):
    """Forward displacement of the nose, brows, sockets and cheekbones at (x, z) on the face."""
    d = 0.0
    if 1.668 < z < 1.74:
        tip = _interp([(1.668, 0.0), (1.676, 0.012), (1.686, 0.024), (1.70, 0.019), (1.72, 0.009), (1.738, 0.002)], z)
        sig = _interp([(1.668, 0.020), (1.68, 0.019), (1.70, 0.014), (1.738, 0.010)], z)
        d += tip * gauss(x, sig)
        d += 0.006 * gauss(abs(x) - 0.019, 0.007) * gauss(z - 1.679, 0.007)          # the nostril wings
    d += 0.007 * gauss(z - 1.751, 0.0085) * (1 - gauss(x, 0.02)) * gauss(abs(x) - 0.04, 0.035)   # the brow ridge
    d -= 0.011 * gauss(abs(x) - 0.042, 0.019) * gauss(z - 1.733, 0.011)                  # the eye sockets
    d += 0.006 * gauss(abs(x) - 0.064, 0.020) * gauss(z - 1.703, 0.014)                  # the cheekbones
    return d


HEAD_Z = [1.856, 1.848, 1.835, 1.818, 1.798, 1.778, 1.762, 1.752, 1.743, 1.735, 1.727, 1.718, 1.709, 1.700, 1.691, 1.683,
          1.676, 1.668, 1.656, 1.642, 1.627, 1.612]
HEAD_SEGS = 34


def head_theta(k, segs=HEAD_SEGS):
    """Column angles, denser at the front (the nose needs columns): 0 = front, + = his left."""
    t = (k / segs) * 2.0
    if t > 1.0:
        t -= 2.0                                              # 0..1 then -1..0
    return math.pi * math.copysign(abs(t) ** 1.35, t)


def head_point(th, z, nf=2.6, nb=2.2):
    w, yf, yb = head_ring(z)
    cy, d = (yf + yb) / 2.0, (yb - yf) / 2.0
    s, c = math.sin(th), math.cos(th)
    n = nf if c >= 0 else nb
    x = w * se(s, n)
    y = cy - d * se(c, n)
    if c > 0:
        y -= nose(x, z) * min(1.0, c * 2.0)
    return Vector((x, y, z))


def head_contour(z, n=48):
    return [head_point(2 * math.pi * k / n - math.pi, z) for k in range(n)]


def ray_radius(contour, c, d):
    """The distance from c along the horizontal direction d to the contour polygon (its farthest crossing)."""
    best = 0.0
    m = len(contour)
    for i in range(m):
        a, b = contour[i], contour[(i + 1) % m]
        ex, ey = b.x - a.x, b.y - a.y
        den = d.x * (-ey) - d.y * (-ex)
        if abs(den) < 1e-9:
            continue
        rx, ry = a.x - c.x, a.y - c.y
        t = (rx * (-ey) - ry * (-ex)) / den
        u = (d.x * ry - d.y * rx) / den
        if t > 0 and 0.0 <= u <= 1.0:
            best = max(best, t)
    return best


# ------------------------------------------------------------------ UV helpers

def region_uv(region, u, v, wrap_u=False, wrap_v=False):
    u0, v0, u1, v1 = L.REG[region]
    uu = u / (1.0 + L.PAD) if wrap_u else 0.01 + 0.98 * u
    vv = v / (1.0 + L.PAD) if wrap_v else 0.01 + 0.98 * v
    return (u0 + (u1 - u0) * uu, v0 + (v1 - v0) * vv)


def param_uvs(bm, params, region, wrap_u=False, wrap_v=False):
    """Loop UVs from per-vertex parameters {vert: (u, v)} in [0, 1); a face across a wrapping seam takes u + 1."""
    lay = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        uvs = [params.get(l.vert, (0.0, 0.0)) for l in f.loops]
        us = [p[0] for p in uvs]
        vs = [p[1] for p in uvs]
        if wrap_u and max(us) - min(us) > 0.5:
            us = [u + 1.0 if u < 0.5 else u for u in us]
        if wrap_v and max(vs) - min(vs) > 0.5:
            vs = [v + 1.0 if v < 0.5 else v for v in vs]
        for l, u, v in zip(f.loops, us, vs):
            l[lay].uv = region_uv(region, u, v, wrap_u, wrap_v)


def flat_uvs(bm, uv):
    lay = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for l in f.loops:
            l[lay].uv = uv


def projection_uvs(bm, under_front_y=-0.10, sheet=None):
    """The head material: each face's corners projected onto the concept view its normal faces most (front / side /
    back); faces looking down take the front view when they are in front of under_front_y, else the back. sheet: the
    concept sheet (real_layout.make_sheet; default the spike's Bartender)."""
    bm.normal_update()
    lay = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    counts = {"front": 0, "side": 0, "back": 0}
    for f in bm.faces:
        n = f.normal
        c = f.calc_center_median()
        # the face zone (forward of y -0.10) keeps the front view round the cheeks: there the side view shows the
        # eye and brow in profile, and taking it gave a second brow on the temple at three-quarters
        face = K.clamp01((-c.y - 0.10) / 0.04)
        score = {"front": -n.y + 0.45 * face, "side": abs(n.x) * 1.08, "back": n.y}
        view = max(score, key=score.get)
        if n.z < -0.75:
            view = "front" if c.y < under_front_y else "back"
        counts[view] += 1
        for l in f.loops:
            p = l.vert.co
            l[lay].uv = L.head_uv(view, p.x, p.y, p.z, sheet)
    return counts


# ------------------------------------------------------------------ mesh helpers

def loft(bm, rings, segs, theta=None, cap_bottom=False, cap_top=False):
    """rings: [(z, rx, y_front, y_back, n_front, n_back[, x_centre])] (any order: faces join consecutive rings).
    Returns (ring vertex lists, {vert: (u, v)}) with u = column / segs (0 at the front, then his left), v by z."""
    theta = theta or (lambda k: 2 * math.pi * k / segs)
    out, params = [], {}
    zs = [r[0] for r in rings]
    z0, z1 = min(zs), max(zs)
    for r in rings:
        z, rx, yf, yb, nf, nb = r[:6]
        cx = r[6] if len(r) > 6 else 0.0
        cy, d_f, d_b = (yf + yb) / 2.0, (yb - yf) / 2.0, (yb - yf) / 2.0
        ring = []
        for k in range(segs):
            th = theta(k)
            s, c = math.sin(th), math.cos(th)
            n = nf if c >= 0 else nb
            v = bm.verts.new((cx + rx * se(s, n), cy - (d_f if c >= 0 else d_b) * se(c, n), z))
            params[v] = (((th / (2 * math.pi)) + 0.5) % 1.0, (z - z0) / max(z1 - z0, 1e-6))
            ring.append(v)
        out.append(ring)
    for a, b in zip(out[:-1], out[1:]):
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    if cap_bottom:
        bm.faces.new(list(reversed(out[0])) if zs[0] < zs[-1] else out[0])
    if cap_top:
        bm.faces.new(out[-1] if zs[0] < zs[-1] else list(reversed(out[-1])))
    return out, params


def tube(bm, pts, rads, sides, up=None, cap0=True, cap1=True, pole_tip=False, flat=None, v_range=(0.0, 1.0)):
    """A tube along pts; rads per point (r or (r_up, r_side)); up(p, d) the ring's first axis. Returns ({vert: (u, v)},
    rings) with u around (0 at the up axis) and v along."""
    rings, params = [], {}
    n = len(pts)
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        u0 = up(p, d) if up else Vector((0, 0, 1))
        u = (u0 - d * u0.dot(d))
        if u.length < 1e-5:
            u = Vector((1, 0, 0)) - d * d.x
        u.normalize()
        w = d.cross(u).normalized()
        r = rads[i]
        ra, rb = (r, r) if not isinstance(r, tuple) else r
        vv = v_range[0] + (v_range[1] - v_range[0]) * i / max(n - 1, 1)
        if pole_tip and i == n - 1:
            v = bm.verts.new(p)
            params[v] = (0.5, vv)
            rings.append([v])
            continue
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            v = bm.verts.new(p + u * math.cos(a) * ra + w * math.sin(a) * rb)
            params[v] = (k / sides, vv)
            ring.append(v)
        rings.append(ring)
    for a, b in zip(rings[:-1], rings[1:]):
        for k in range(sides):
            if len(b) == 1:
                bm.faces.new((a[k], a[(k + 1) % sides], b[0]))
            else:
                bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    if cap0:
        bm.faces.new(list(reversed(rings[0])))
    if cap1 and len(rings[-1]) > 1:
        bm.faces.new(rings[-1])
    return params, rings


def grid_slab(bm, grid, thick, inward):
    """A closed slab from a grid [row][col] (rows top to bottom), outer sheet + inner sheet + edge strips.
    Returns {vert: (u, v)}: u across the columns, v up the rows (top row v 1)."""
    R, Cn = len(grid), len(grid[0])
    params = {}
    outer, inner = [], []
    for j, row in enumerate(grid):
        o, i_ = [], []
        for i, p in enumerate(row):
            a = bm.verts.new(p)
            b = bm.verts.new(p + inward(p) * thick)
            params[a] = params[b] = (i / (Cn - 1), 1.0 - j / (R - 1))
            o.append(a)
            i_.append(b)
        outer.append(o)
        inner.append(i_)
    for j in range(R - 1):
        for i in range(Cn - 1):
            bm.faces.new((outer[j][i], outer[j + 1][i], outer[j + 1][i + 1], outer[j][i + 1]))
            bm.faces.new((inner[j][i], inner[j][i + 1], inner[j + 1][i + 1], inner[j + 1][i]))
    for j in range(R - 1):
        for i in (0, Cn - 1):
            bm.faces.new((outer[j][i], inner[j][i], inner[j + 1][i], outer[j + 1][i]))
    for i in range(Cn - 1):
        for j in (0, R - 1):
            bm.faces.new((outer[j][i], outer[j][i + 1], inner[j][i + 1], inner[j][i]))
    return params


def finish(name, bm, material, weights):
    ob = K.new_obj(name, bm, material)
    K.skin(ob, weights)
    return ob


# ------------------------------------------------------------------ weights (realistic heights)

def torso_w(co):
    z = co.z
    if z < 1.00:
        w = {"hips": 1.0}
    elif z < 1.12:
        w = K.blend("hips", "spine", (z - 1.00) / 0.12)
    elif z < 1.24:
        w = {"spine": 1.0}
    elif z < 1.36:
        w = K.blend("spine", "chest", (z - 1.24) / 0.12)
    else:
        w = {"chest": 1.0}
    if z > 1.38 and abs(co.x) > 0.14:
        s = "l" if co.x > 0 else "r"
        k = K.clamp01((abs(co.x) - 0.14) / 0.10) * K.clamp01((z - 1.38) / 0.07)
        w = {b: v * (1 - 0.65 * k) for b, v in w.items()}
        w["upperarm." + s] = w.get("upperarm." + s, 0.0) + 0.65 * k
    return w


def neck_w(co):
    return K.blend("chest", "head", (co.z - 1.53) / 0.09)


def head_w(co):
    return {"head": 1.0}


def arm_w(s):
    f = K.chain(["upperarm." + s, "lowerarm." + s, "wrist." + s, "hand." + s], 0.05)

    def fn(co):
        w = f(co)
        k = K.clamp01((0.25 - abs(co.x)) / 0.08)
        if k > 0:
            w = {b: v * (1 - k) for b, v in w.items()}
            w["chest"] = w.get("chest", 0.0) + k
        return w
    return fn


def leg_w(s):
    f = K.chain(["upperleg." + s, "lowerleg." + s, "foot." + s], 0.06)

    def fn(co):
        w = f(co)
        k = K.clamp01((co.z - 0.86) / 0.08)
        if k > 0:
            w = {b: v * (1 - k) for b, v in w.items()}
            w["hips"] = w.get("hips", 0.0) + k
        return w
    return fn


def skirt_w(top_z, hem_z, front_follow=0.55, legs=0.85):
    def fn(co):
        h = K.clamp01((top_z - co.z) / (top_z - hem_z))
        s = K.clamp01(0.5 + co.x / 0.24)
        front = K.clamp01(0.5 - co.y / 0.20)
        wl = legs * h ** front_follow * (0.25 + 0.75 * front)
        return {"hips": 1 - wl, "upperleg.l": wl * s, "upperleg.r": wl * (1 - s)}
    return fn


# ------------------------------------------------------------------ the parts

def build_head(name, mat, sheet=None):
    bm = bmesh.new()
    segs = HEAD_SEGS
    rings = []
    for z in HEAD_Z:
        rings.append([bm.verts.new(head_point(head_theta(k), z)) for k in range(segs)])
    w, yf, yb = head_ring(1.86)
    top = bm.verts.new((0.0, -0.080, 1.861))
    w, yf, yb = head_ring(1.60)
    bot = bm.verts.new((0.0, (yf + yb) / 2.0, 1.600))
    for a, b in zip(rings[:-1], rings[1:]):
        for k in range(segs):
            bm.faces.new((a[k], b[k], b[(k + 1) % segs], a[(k + 1) % segs]))
    for k in range(segs):
        bm.faces.new((top, rings[0][k], rings[0][(k + 1) % segs]))
        bm.faces.new((bot, rings[-1][(k + 1) % segs], rings[-1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    counts = projection_uvs(bm, sheet=sheet)
    print("head views", counts)
    return finish(name, bm, mat, head_w)


BEARD_YC = -0.070


def beard_top(th):
    a = abs(math.degrees(th))
    return _interp([(0, 1.674), (14, 1.671), (26, 1.664), (38, 1.672), (55, 1.693), (70, 1.712), (84, 1.728), (100, 1.706),
                    (180, 1.69)], a)


def beard_bot(th, k):
    a = abs(math.degrees(th))
    z = _interp([(0, 1.536), (12, 1.540), (26, 1.552), (40, 1.566), (55, 1.585), (70, 1.612), (84, 1.640), (100, 1.650),
                 (180, 1.635)], a)
    if a < 80 and k % 2:                                       # tufts: every other column's tip stops short
        z += 0.012 + 0.004 * math.sin(k * 2.3)
    return z


def beard_point(th, z, s):
    """The beard's outer surface at column angle th (round (0, BEARD_YC)), height z, depth into the beard s (0 top)."""
    w = _interp(_BW, z)
    yf = _interp(_BF, z)
    if z > 1.69:
        yf = -0.192
    df = BEARD_YC - yf
    sn, c = math.sin(th), math.cos(th)
    x = w * se(sn, 2.3)
    y = BEARD_YC - df * se(c, 2.3) if c >= 0 else BEARD_YC + 0.035 * se(-c, 2.3)
    p = Vector((x, y, z))
    # clumps: vertical grooves that deepen down the beard; the moustache: a full bar under the nose
    a = abs(math.degrees(th))
    bump = 0.005 * math.sin(th * 13.0) * K.smoothstep(0.1, 0.8, s)
    if a < 42 and z > 1.646:
        bump += 0.007 * gauss(z - 1.660, 0.008) * (1 - a / 42.0)
    cen = Vector((0.0, BEARD_YC, z))
    d = Vector((p.x - cen.x, p.y - cen.y, 0.0))
    if d.length < 1e-6:
        return p
    d.normalize()
    r = (p - cen).length + bump
    # never inside the head (or the neck below the chin): the top edge just proud of the skin, thicker below
    clear = 0.004 + 0.010 * K.smoothstep(0.0, 0.35, s)
    if z >= 1.605:
        rh = ray_radius(head_contour(z), cen, d)
    else:
        rh = ray_radius([Vector((0.072 * math.cos(t), -0.045 + 0.068 * math.sin(t), z)) for t in [2 * math.pi * i / 32 for i in range(32)]], cen, d)
    if c > -0.2:
        r = max(r, rh + clear)
    return Vector((cen.x + d.x * r, cen.y + d.y * r, z))


def build_beard(name, mat, cols=40, rows=9, sheet=None):
    bm = bmesh.new()
    ths = [head_theta(k, cols) for k in range(cols)]
    grid = []
    for j in range(rows):
        s = j / (rows - 1)
        row = []
        for k, th in enumerate(ths):
            zt, zb = beard_top(th), beard_bot(th, k)
            row.append(bm.verts.new(beard_point(th, zt + (zb - zt) * (s ** 0.9), s)))
        grid.append(row)
    for a, b in zip(grid[:-1], grid[1:]):
        for k in range(cols):
            bm.faces.new((a[k], b[k], b[(k + 1) % cols], a[(k + 1) % cols]))
    cz = sum(v.co.z for v in grid[-1]) / cols
    tip = bm.verts.new((0.0, BEARD_YC - 0.03, cz - 0.004))
    for k in range(cols):
        bm.faces.new((tip, grid[-1][(k + 1) % cols], grid[-1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # the top edge is open (it lies on the face): make sure normals point outward (recalc can flip an open shell)
    f0 = max(bm.faces, key=lambda f: -f.calc_center_median().y)
    if f0.normal.y > 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    print("beard views", projection_uvs(bm, sheet=sheet))
    return finish(name, bm, mat, head_w)


def build_ears(name, mat, sheet=None):
    bm = bmesh.new()
    for sx in (1, -1):
        c = Vector((0.090 * sx, -0.058, 1.726))
        vs = K.ellipsoid(bm, c, 0.013, 0.027, 0.041, 10, 7)
        R = Matrix.Rotation(math.radians(-24 * sx), 3, "Z") @ Matrix.Rotation(math.radians(12), 3, "X")
        for v in vs:
            q = v.co - c
            if q.x * sx > 0:                                   # the outer face cupped: the rim stands out
                rr = math.sqrt((q.y / 0.027) ** 2 + (q.z / 0.041) ** 2)
                q.x -= sx * 0.006 * max(0.0, 1 - rr * 1.3)
            v.co = c + R @ q
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print("ear views", projection_uvs(bm, sheet=sheet))
    return finish(name, bm, mat, head_w)


def build_neck(name, mat, sheet=None):
    bm = bmesh.new()
    rings = [(1.47, 0.080, -0.125, 0.045, 2.2, 2.2), (1.54, 0.074, -0.118, 0.026, 2.2, 2.2), (1.60, 0.070, -0.112, 0.022, 2.2, 2.2),
             (1.66, 0.064, -0.10, 0.018, 2.2, 2.2)]
    loft(bm, rings, 14)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print("neck views", projection_uvs(bm, sheet=sheet))
    return finish(name, bm, mat, neck_w)


# the shirt: (z, rx, y front, y back, n front, n back), bottom to top (measured off the side and front views)
TORSO = [(0.905, 0.214, -0.182, 0.146, 2.2, 2.4), (0.975, 0.209, -0.192, 0.133, 2.2, 2.4), (1.040, 0.212, -0.222, 0.122, 2.2, 2.5),
         (1.100, 0.215, -0.243, 0.119, 2.2, 2.5), (1.170, 0.213, -0.245, 0.119, 2.2, 2.5), (1.240, 0.206, -0.228, 0.121, 2.3, 2.5),
         (1.310, 0.200, -0.202, 0.125, 2.3, 2.5), (1.380, 0.205, -0.192, 0.126, 2.4, 2.5), (1.440, 0.214, -0.180, 0.122, 2.4, 2.5),
         (1.485, 0.220, -0.165, 0.114, 2.4, 2.4), (1.520, 0.214, -0.152, 0.102, 2.3, 2.3), (1.552, 0.180, -0.140, 0.085, 2.2, 2.2),
         (1.578, 0.135, -0.130, 0.060, 2.2, 2.2), (1.598, 0.090, -0.121, 0.034, 2.2, 2.2)]


def torso_ring(z):
    """The shirt's ring (rx, y front, y back, n front, n back) at z."""
    zs = [r[0] for r in TORSO]
    z = max(zs[0], min(zs[-1], z))
    for a, b in zip(TORSO[:-1], TORSO[1:]):
        if a[0] <= z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(a[i] + (b[i] - a[i]) * t for i in (1, 2, 3, 4, 5))
    return TORSO[-1][1:6]


def torso_contour(th, z, grow=0.0):
    rx, yf, yb, nf, nb = torso_ring(z)
    cy, d = (yf + yb) / 2.0, (yb - yf) / 2.0
    s, c = math.sin(th), math.cos(th)
    n = nf if c >= 0 else nb
    return (rx + grow) * se(s, n), cy - (d + grow) * se(c, n)


def torso_front_y(x, z, gap=0.0):
    """The shirt's front surface y at (x, z) (the bib and the apron follow it)."""
    rx, yf, yb, nf, nb = torso_ring(z)
    cy, d = (yf + yb) / 2.0, (yb - yf) / 2.0
    u = min(0.999, abs(x) / rx)
    s_ = u ** (nf / 2.0)                                       # invert x = rx * se(sin)
    cth = math.sqrt(max(0.0, 1 - s_ * s_))
    return cy - d * se(cth, nf) - gap


def build_torso(name, mat, rings=TORSO, segs=28, hem_jag=True):
    bm = bmesh.new()
    ring_verts, params = loft(bm, rings, segs, theta=lambda k: 2 * math.pi * k / segs)
    if hem_jag:                                                # the untucked hem: ragged at the back
        for k, v in enumerate(ring_verts[0]):
            if v.co.y > 0:
                v.co.z += 0.012 * (k % 2) + 0.006 * math.sin(k * 1.7)
    param_uvs(bm, params, "shirt", wrap_u=True)
    return finish(name, bm, mat, torso_w)


def build_collar(name, mat):
    bm = bmesh.new()
    rings = [(1.582, 0.096, -0.126, 0.044, 2.2, 2.2), (1.614, 0.084, -0.121, 0.036, 2.2, 2.2),
             (1.614, 0.074, -0.111, 0.026, 2.2, 2.2), (1.582, 0.084, -0.115, 0.034, 2.2, 2.2)]
    rv, params = loft(bm, rings, 16)
    for a, b in zip(rv[-1:], rv[:1]):                          # close the band (inner bottom to outer bottom)
        for k in range(16):
            bm.faces.new((a[k], a[(k + 1) % 16], b[(k + 1) % 16], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    lay = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for l in f.loops:
            l[lay].uv = region_uv("shirt", 0.5, 0.97)
    return finish(name, bm, mat, lambda co: K.blend("chest", "head", 0.15))


def arm_frame(s):
    S, E, W = K.H("upperarm." + s), K.H("lowerarm." + s), K.H("wrist." + s)
    return S, E, W


def up_z(p, d):
    return Vector((0, 0, 1))


def build_sleeve(name, mat, s, girth=1.0):
    """The shirt's upper sleeve, from inside the shoulder to the roll below the elbow (rest: the T-pose arm)."""
    S, E, W = arm_frame(s)
    du, dl = (E - S).normalized(), (W - E).normalized()
    pts = [S - du * 0.070, S - du * 0.010, S + du * 0.060, S + du * 0.140, S + du * 0.220, E - du * 0.020, E + dl * 0.030]
    rads = [(a * girth, b * girth) for a, b in ((0.070, 0.080), (0.074, 0.088), (0.072, 0.084), (0.067, 0.076), (0.063, 0.070),
                                                (0.062, 0.066), (0.062, 0.064))]
    bm = bmesh.new()
    params, _ = tube(bm, pts, rads, 12, up=up_z, cap0=True, cap1=False)
    param_uvs(bm, params, "sleeve", wrap_u=True)
    return finish(name, bm, mat, arm_w(s))


def build_roll(name, mat, s, girth=1.0):
    """The rolled sleeve: a chunky torus just below the elbow (two turns' worth)."""
    S, E, W = arm_frame(s)
    dl = (W - E).normalized()
    c = E + dl * 0.045
    u = Vector((0, 0, 1))
    u = (u - dl * u.dot(dl)).normalized()
    w = dl.cross(u).normalized()
    R, ta, tr = 0.066 * girth, 0.030, 0.019               # major radius, tube half-length along the arm, tube radius
    bm = bmesh.new()
    nu, nv = 14, 6
    vs = []
    params = {}
    for i in range(nu):
        a = 2 * math.pi * i / nu
        radial = u * math.cos(a) + w * math.sin(a)
        row = []
        for j in range(nv):
            b = 2 * math.pi * j / nv
            p = c + radial * (R + tr * math.cos(b)) + dl * (ta * math.sin(b))
            p += radial * 0.004 * math.sin(3 * a + 1.0)        # an uneven roll
            v = bm.verts.new(p)
            params[v] = (i / nu, j / nv)
            row.append(v)
        vs.append(row)
    for i in range(nu):
        for j in range(nv):
            a, b, c_, d = vs[i][j], vs[(i + 1) % nu][j], vs[(i + 1) % nu][(j + 1) % nv], vs[i][(j + 1) % nv]
            bm.faces.new((a, b, c_, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    param_uvs(bm, params, "roll", wrap_u=True, wrap_v=True)
    return finish(name, bm, mat, arm_w(s))


def build_forearm(name, mat, s, girth=1.0):
    S, E, W = arm_frame(s)
    dl = (W - E).normalized()
    L_ = (W - E).length
    ts = [0.03, 0.07, 0.11, 0.16, 0.21, L_ - 0.01, L_ + 0.02]
    rad = [0.050, 0.054, 0.052, 0.047, 0.041, 0.034, 0.031]
    flat = [(1.00, 1.00), (0.98, 1.03), (0.95, 1.06), (0.92, 1.10), (0.88, 1.14), (0.80, 1.20), (0.78, 1.22)]
    pts = [E + dl * t for t in ts]
    rads = [(r * girth * f[0], r * girth * f[1]) for r, f in zip(rad, flat)]
    bm = bmesh.new()
    params, _ = tube(bm, pts, rads, 10, up=up_z, cap0=True, cap1=True)
    param_uvs(bm, params, "forearm", wrap_u=True)
    return finish(name, bm, mat, arm_w(s))


def build_hand(name, mat, s, scale=1.0):
    """A big working hand in the T-pose rest (palm down, thumb forward): a boxy palm, four slightly curled fingers
    and a thumb. Skinned to the wrist and hand bones."""
    S, E, W = arm_frame(s)
    sx = 1 if s == "l" else -1
    d = (W - E).normalized()
    side = Vector((0, -1, 0))                                  # toward the thumb (front)
    side = (side - d * side.dot(d)).normalized()
    down = d.cross(side).normalized() * (1 if sx > 0 else -1)
    if down.z > 0:
        down = -down
    k = scale
    bm = bmesh.new()
    params = {}
    pc = W + d * 0.058 * k + down * 0.004
    for v in K.ellipsoid(bm, Vector((0, 0, 0)), 1.0, 1.0, 1.0, 10, 6):
        q = v.co.copy()
        q = Vector((se(q.x, 3.0), se(q.y, 3.0), se(q.z, 2.6)))
        v.co = pc + d * q.x * 0.058 * k + side * q.y * 0.047 * k + down * q.z * 0.019 * k
        params[v] = (0.5 + 0.5 * q.x, 0.5 + 0.5 * q.y)
    fingers = [(-0.031, 0.083, 0.0105), (-0.010, 0.091, 0.0108), (0.011, 0.086, 0.0104), (0.030, 0.070, 0.0094)]
    for off, ln, r in fingers:
        base = pc + d * 0.050 * k - side * off * k
        pts, p = [], base
        dirs = [(0.0, 0.40), (4.0, 0.33), (10.0, 0.27)]               # relaxed, nearly flat: more curl read as claws
                                                                       # and sank the fingertips into the counter
        pts.append(base)
        for ang, f in dirs:
            a = math.radians(ang)
            p = p + (d * math.cos(a) + down * math.sin(a)) * ln * f * k
            pts.append(p)
        pp, _ = tube(bm, pts, [r * k, r * k, r * 0.95 * k, r * 0.85 * k], 6, up=lambda p_, d_: down, cap0=False, cap1=True)
        for v in pp:
            params[v] = (0.80, 0.2 + 0.6 * pp[v][1])
    tb = W + d * 0.030 * k + side * 0.040 * k + down * 0.006 * k
    # the thumb lies beside the palm, barely below it (it hung 2.5 cm under the palm: into the counter while wiping)
    tpts = [tb, tb + (d * 0.55 + side * 0.75 + down * 0.10).normalized() * 0.035 * k]
    tpts.append(tpts[-1] + (d * 0.85 + side * 0.35 + down * 0.12).normalized() * 0.035 * k)
    tpts.append(tpts[-1] + (d * 0.90 + side * 0.10 + down * 0.16).normalized() * 0.026 * k)
    pp, _ = tube(bm, tpts, [0.017 * k, 0.014 * k, 0.012 * k, 0.010 * k], 6, up=lambda p_, d_: down, cap0=False, cap1=True)
    for v in pp:
        params[v] = (0.15, 0.2 + 0.6 * pp[v][1])
    param_uvs(bm, params, "hand")
    return finish(name, bm, mat, K.chain(["lowerarm." + s, "wrist." + s, "hand." + s], 0.03))


PELVIS = [(0.810, 0.120, -0.060, 0.070, 2.2, 2.2), (0.860, 0.190, -0.125, 0.122, 2.2, 2.3), (0.915, 0.205, -0.152, 0.140, 2.2, 2.3),
          (0.985, 0.205, -0.165, 0.130, 2.2, 2.3), (1.065, 0.200, -0.170, 0.112, 2.2, 2.3)]


def build_pelvis(name, mat):
    bm = bmesh.new()
    rv, params = loft(bm, PELVIS, 24, cap_bottom=True)
    param_uvs(bm, params, "seat", wrap_u=True)
    return finish(name, bm, mat, lambda co: {"hips": 1.0})


def build_trouser_leg(name, mat, s, girth=1.0):
    sx = 1 if s == "l" else -1
    hip, knee, ank = K.H("upperleg." + s), K.T("upperleg." + s), K.T("lowerleg." + s)
    zs = [0.93, 0.85, 0.75, 0.65, 0.56, 0.50, 0.45, 0.40, 0.36, 0.335]
    rad = [0.106, 0.100, 0.092, 0.083, 0.075, 0.073, 0.075, 0.078, 0.077, 0.068]

    def at(z):
        if z >= knee.z:
            t = (hip.z - z) / (hip.z - knee.z)
            return hip.lerp(knee, t)
        t = (knee.z - z) / (knee.z - ank.z)
        return knee.lerp(ank, t)
    pts = [at(z) + Vector((0.006 * sx, 0, 0)) for z in zs]
    rads = [(r * girth, r * girth * 1.02) for r in rad]
    bm = bmesh.new()
    params, rings = tube(bm, pts, rads, 12, up=lambda p, d: Vector((0, -1, 0)), cap0=True, cap1=False)
    for k, v in enumerate(rings[-1]):                          # the frayed hem over the boot cuff
        v.co.z -= 0.010 * (k % 2)
    param_uvs(bm, params, "trousers", wrap_u=True)
    return finish(name, bm, mat, leg_w(s))


def build_boot(name, mat, s):
    sx = 1 if s == "l" else -1
    ank = K.T("lowerleg." + s)
    xc, yc = ank.x, ank.y - 0.012
    bm = bmesh.new()
    params = {}
    # the shaft (around a vertical axis), bottom into the foot
    shaft = [(0.150, 0.059), (0.22, 0.059), (0.30, 0.062), (0.37, 0.066)]
    pp, srings = tube(bm, [Vector((xc, yc + 0.012, z)) for z, r in shaft], [(r, r * 1.04) for z, r in shaft], 12,
                      up=lambda p, d: Vector((0, -1, 0)), cap0=False, cap1=False, v_range=(0.40, 1.0))
    params.update({v: (u * 0.5, v_) for v, (u, v_) in pp.items()})
    # the foot: rings across Y (heel back to toe), each a flat-bottomed oval in X-Z
    foot = [(0.090, 0.030, 0.075), (0.075, 0.044, 0.118), (0.045, 0.051, 0.158), (0.005, 0.054, 0.172), (-0.050, 0.056, 0.140),
            (-0.100, 0.058, 0.104), (-0.150, 0.059, 0.082), (-0.195, 0.054, 0.070), (-0.230, 0.042, 0.062), (-0.250, 0.024, 0.052)]
    n = 14
    rings = []
    for i, (y, hw, top) in enumerate(foot):
        ring = []
        for k in range(n):
            a = 2 * math.pi * k / n
            x = xc + hw * se(math.cos(a), 2.3) + sx * 0.004 * (1 if y < -0.1 else 0)
            z = top / 2.0 + (top / 2.0) * se(math.sin(a), 2.3)
            z = max(z, 0.004)
            v = bm.verts.new((x, yc + y, z))
            params[v] = (0.5 + 0.5 * k / n, 0.38 * z / 0.172)
            ring.append(v)
        rings.append(ring)
    for a, b in zip(rings[:-1], rings[1:]):
        for k in range(n):
            bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    tip = bm.verts.new((xc, yc - 0.262, 0.024))
    params[tip] = (0.75, 0.05)
    for k in range(n):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % n], tip))
    # the turned-down cuff at the top
    cuff = [(0.334, 0.071), (0.360, 0.075), (0.392, 0.076), (0.392, 0.066), (0.350, 0.064)]
    cr = []
    for z, r in cuff:
        ring = []
        for k in range(12):
            a = 2 * math.pi * k / 12
            v = bm.verts.new((xc + r * math.sin(a) + 0.003 * math.sin(5 * a), yc + 0.012 - r * 1.04 * math.cos(a), z + 0.004 * math.sin(3 * a + sx)))
            params[v] = (0.5 * k / 12, 0.92)
            ring.append(v)
        cr.append(ring)
    for a, b in zip(cr, cr[1:] + cr[:1]):
        for k in range(12):
            bm.faces.new((a[k], a[(k + 1) % 12], b[(k + 1) % 12], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    param_uvs(bm, params, "boots", wrap_u=True)
    return finish(name, bm, mat, K.chain(["lowerleg." + s, "foot." + s, "toes." + s], 0.04))


# ------------------------------------------------------------------ the apron, its straps and ties, the belt

APRON_TOP, APRON_HEM = 1.038, 0.455
APRON_SPAN = 150.0          # degrees each side of the front: open at the back (the ties cross the gap)


def apron_ring(z):
    """The skirt's hanging contour at z: (half-width, front y, back y)."""
    return (_interp([(0.455, 0.282), (0.60, 0.266), (0.75, 0.252), (0.90, 0.236), (1.038, 0.226)], z),
            _interp([(0.455, -0.226), (0.60, -0.229), (0.75, -0.233), (0.90, -0.240), (1.000, -0.246), (1.038, -0.238)], z),
            _interp([(0.455, 0.162), (0.75, 0.170), (0.90, 0.170), (1.038, 0.142)], z))


def build_apron_skirt(name, mat, cols=18, rows=11):
    grid = []
    for j in range(rows + 1):
        z = APRON_TOP + (APRON_HEM - APRON_TOP) * (j / rows)
        w, yf, yb = apron_ring(z)
        cy, d = (yf + yb) / 2.0, (yb - yf) / 2.0
        row = []
        for i in range(cols + 1):
            th = math.radians(-APRON_SPAN + 2 * APRON_SPAN * i / cols)
            x = w * se(math.sin(th), 2.2)
            y = cy - d * se(math.cos(th), 2.2)
            # hanging folds: vertical ripples that deepen toward the hem (the sheet's apron is never a flat board:
            # the ripples break its silhouette and give the toon band folds to catch)
            t = j / rows
            rip = 0.013 * math.sin(th * 7.0 + 0.6) * t ** 0.8
            rr = math.hypot(x, y - cy) or 1.0
            x += x / rr * rip
            y += (y - cy) / rr * rip
            if j == rows:                                     # the frayed hem: uneven, with a torn notch left of centre
                z2 = z + 0.010 * ((i * 7) % 3 - 1) + (0.035 if i in (8,) else 0.0)
            else:
                z2 = z
            row.append(Vector((x, y, z2)))
        grid.append(row)
    bm = bmesh.new()
    params = grid_slab(bm, grid, 0.008, lambda p: Vector((-p.x, -(p.y - 0.0), 0)).normalized())
    param_uvs(bm, params, "apron")
    return finish(name, bm, mat, skirt_w(APRON_TOP, APRON_HEM))


def build_bib(name, mat, cols=8, rows=8):
    zt, zb = 1.425, 1.020
    grid = []
    for j in range(rows + 1):
        z = zt + (zb - zt) * j / rows
        t = j / rows
        hw = 0.128 + (0.205 - 0.128) * t ** 1.6
        row = []
        for i in range(cols + 1):
            x = -hw + 2 * hw * i / cols
            row.append(Vector((x, torso_front_y(x, z, gap=0.010), z)))
        grid.append(row)
    bm = bmesh.new()
    params = grid_slab(bm, grid, 0.007, lambda p: Vector((0, 1, 0)))
    param_uvs(bm, params, "bib")
    return finish(name, bm, mat, torso_w)


def build_pocket(name, mat):
    zt, zb, x0, x1 = 1.355, 1.285, 0.040, 0.112
    grid = []
    for j in range(3):
        z = zt + (zb - zt) * j / 2
        grid.append([Vector((x, torso_front_y(x, z, gap=0.019), z)) for x in (x0, (x0 + x1) / 2, x1)])
    bm = bmesh.new()
    params = grid_slab(bm, grid, 0.006, lambda p: Vector((0, 1, 0)))
    lay = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    u0, v0, u1, v1 = L.REG["straps"]
    for f in bm.faces:
        for l in f.loops:
            u, v = params[l.vert]
            l[lay].uv = (u0 + (u1 - u0) * (0.55 + 0.4 * u), v0 + (v1 - v0) * (0.1 + 0.8 * v))
    return finish(name, bm, mat, torso_w)


def build_straps(name, mat):
    """The bib's neck strap: one loop from the bib's top corners up the chest and round the back of the neck."""
    pts = []
    side = []
    for sx in (-1, 1):
        x0 = 0.118 * sx
        seg = [Vector((x0, torso_front_y(x0, 1.415, 0.013), 1.415)), Vector((0.112 * sx, torso_front_y(0.112, 1.47, 0.012), 1.470)),
               Vector((0.105 * sx, -0.128, 1.525)), Vector((0.094 * sx, -0.090, 1.566)), Vector((0.084 * sx, -0.030, 1.585)),
               Vector((0.058 * sx, 0.026, 1.585))]
        side.append(seg)
    pts = list(reversed(side[0])) + [Vector((0.0, 0.050, 1.580))] + side[1]
    pts = K.catmull(pts, 22)
    bm = bmesh.new()
    cen = Vector((0, -0.045, 0))

    def up(p, d):
        o = Vector((p.x - cen.x, p.y - cen.y, 0.25))
        return o.normalized()
    params, _ = tube(bm, pts, [(0.004, 0.0125)] * len(pts), 4, up=up, cap0=True, cap1=True)
    lay = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    u0, v0, u1, v1 = L.REG["straps"]
    for f in bm.faces:
        for l in f.loops:
            u, v = params[l.vert]
            l[lay].uv = (u0 + (u1 - u0) * (0.05 + 0.4 * v), v0 + (v1 - v0) * (0.5 + 0.3 * u))
    return finish(name, bm, mat, lambda co: {"chest": 1.0} if co.z < 1.56 else K.blend("chest", "head", 0.1))


def build_ties(name, mat):
    """The apron's waist ties across the back gap, a knot and two hanging tails."""
    bm = bmesh.new()
    params = {}
    z = 0.992
    pts = []
    for i in range(9):
        th = math.radians(APRON_SPAN - 6 + (360 - 2 * APRON_SPAN + 12) * i / 8)
        x, y = torso_contour(th, z, 0.012)
        pts.append(Vector((x, y, z)))
    pp, _ = tube(bm, pts, [(0.018, 0.004)] * len(pts), 4, up=lambda p, d: Vector((0, 0, 1)), cap0=True, cap1=True)
    params.update(pp)
    knot = Vector((0.0, torso_contour(math.pi, z, 0.026)[1], z))
    for v in K.ellipsoid(bm, knot, 0.026, 0.016, 0.020, 8, 5):
        params[v] = (0.5, 0.5)
    for sx, ln in ((1, 0.24), (-1, 0.20)):
        tp = [knot + Vector((0.010 * sx, 0.004, -0.010)), knot + Vector((0.030 * sx, 0.010, -ln * 0.5)), knot + Vector((0.038 * sx, 0.008, -ln))]
        pp, _ = tube(bm, tp, [(0.014, 0.004)] * 3, 4, up=lambda p, d: Vector((1, 0, 0)), cap0=True, cap1=True)
        params.update(pp)
    lay = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    u0, v0, u1, v1 = L.REG["straps"]
    for f in bm.faces:
        for l in f.loops:
            u, v = params.get(l.vert, (0.5, 0.5))
            l[lay].uv = (u0 + (u1 - u0) * (0.05 + 0.4 * v), v0 + (v1 - v0) * (0.1 + 0.3 * u))
    return finish(name, bm, mat, lambda co: {"hips": 1.0})


def build_belt(name, mat, z=1.030, h=0.046):
    """A broad leather belt over the apron's waist (front) and the shirt (back), the buckle in front."""
    segs = 30
    bm = bmesh.new()
    params = {}

    def contour(th, grow):
        return torso_contour(th, z, grow)
    layers = [(z - h / 2, 0.026), (z + h / 2, 0.026), (z + h / 2, 0.015), (z - h / 2, 0.015)]
    rings = []
    for li, (zz, g) in enumerate(layers):
        ring = []
        for k in range(segs):
            th = 2 * math.pi * k / segs
            x, y = contour(th, g)
            v = bm.verts.new((x, y, zz))
            params[v] = (k / segs, li / 4.0)
            ring.append(v)
        rings.append(ring)
    for a, b in zip(rings, rings[1:] + rings[:1]):
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    param_uvs(bm, params, "belt", wrap_u=True, wrap_v=True)
    # the buckle: a squared frame in front (its own flat cell)
    x, y = contour(0.0, 0.030)
    bk = bmesh.new()
    vs = K.ellipsoid(bk, Vector((0.0, y - 0.004, z)), 0.030, 0.008, 0.028, 8, 4)
    for v in vs:
        q = v.co - Vector((0.0, y - 0.004, z))
        v.co = Vector((0.0, y - 0.004, z)) + Vector((se(q.x / 0.030, 3.5) * 0.030, q.y, se(q.z / 0.028, 3.5) * 0.028))
    flat_uvs(bk, L.misc_uv("buckle"))
    tmp = bpy.data.meshes.new("_bk")
    bk.to_mesh(tmp)
    bk.free()
    bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    return finish(name, bm, mat, torso_w)


# ------------------------------------------------------------------ REAL-1 -> another rest (REAL-2)

def rest_record(arm):
    """A rig's rest, for transfer_rest: {bone: {"matrix": matrix_local (16 floats, row major), "head", "tail",
    "length"}}."""
    return {b.name: {"matrix": [x for row in b.matrix_local for x in row], "head": list(b.head_local),
                     "tail": list(b.tail_local), "length": b.length} for b in arm.data.bones}


def _rest_matrix(row):
    m = row["matrix"]
    return Matrix([m[0:4], m[4:8], m[8:12], m[12:16]])


def transfer_rest(ob, src_rest, girth):
    """Carry a skinned mesh built on the rest `src_rest` (rest_record of another rig whose bones have the same
    directions and rolls: every chain keeps KayKit's) onto the open rig's rest: each vertex goes through its bones'
    src -> dst rest frames, weighted, with each bone's length ratio along it (so a bone's head and tail land on the
    new ones) and its girth factors across it: girth {bone: (gx, gz)} in the bone's local X and Z (torso and head:
    X across, Z front-back; absent: 1.0). The weights are kept. Returns the vertex count moved."""
    arm = C.rig()
    T = {}
    for b in arm.data.bones:
        if b.name not in src_rest:
            continue
        gx, gz = girth.get(b.name, (1.0, 1.0))
        along = b.length / src_rest[b.name]["length"]
        T[b.name] = b.matrix_local @ Matrix.Diagonal((gx, along, gz, 1.0)) @ _rest_matrix(src_rest[b.name]).inverted()
    names = {g.index: g.name for g in ob.vertex_groups}
    mw = ob.matrix_world.copy()
    inv = mw.inverted()
    moved = 0
    for v in ob.data.vertices:
        p = mw @ v.co
        acc, tot = Vector((0.0, 0.0, 0.0)), 0.0
        for g in v.groups:
            n = names[g.group]
            if g.weight > 1e-6 and n in T:
                acc += (T[n] @ p) * g.weight
                tot += g.weight
        if tot <= 0.0:
            raise RuntimeError("transfer_rest: vertex %d of %s has no deform weight" % (v.index, ob.name))
        v.co = inv @ (acc / tot)
        moved += 1
    ob.data.update()
    return moved


def _weight_on(ob, bones):
    names = {g.index: g.name for g in ob.vertex_groups}
    out = []
    for v in ob.data.vertices:
        ws = [(g.weight, names[g.group]) for g in v.groups if g.weight > 1e-4]
        tot = sum(w for w, _ in ws) or 1.0
        out.append((sum(w for w, n in ws if n in bones) / tot, bool(ws) and max(ws)[1] in bones))
    return out


def fit_profile(ob, profile, bones=("hips", "spine", "chest"), bin_h=0.04, min_verts=16):
    """Reshape a skinned body's trunk to a silhouette on the open rig's rest (REAL-2's woman's frame: the shoulders, a
    waist, the hips): profile {"width": [(z, half-width)], "front": [(z, depth in front of the spine line)], "back":
    [(z, depth behind it)], "centre_y": the spine line's y (default 0: the rig's spine)}. Per height band, the trunk's
    own extents (vertices whose dominant bone is in `bones`) are measured, and every vertex is scaled about the spine
    line toward the profile by its weight on `bones` (the thigh tops and shoulder caps follow part way); eased in over
    0.04 m past the profile's ends, nothing moves beyond. Returns {band z: (sx, s_front, s_back)}."""
    me = ob.data
    wt = _weight_on(ob, bones)
    zs = [z for z, _ in profile["width"]]
    z0, z1 = min(zs), max(zs)
    bands = {}
    for v, (w, dom) in zip(me.vertices, wt):
        if dom and z0 - bin_h <= v.co.z <= z1 + bin_h:
            e = bands.setdefault(int(round(v.co.z / bin_h)), [0.0, 1e9, -1e9, 0])
            e[0], e[1], e[2], e[3] = max(e[0], abs(v.co.x)), min(e[1], v.co.y), max(e[2], v.co.y), e[3] + 1
    rows = {}
    cy = profile.get("centre_y", 0.0)
    for b, (xmax, ymin, ymax, n) in bands.items():
        if n < min_verts or ymin >= cy or ymax <= cy:       # a band that is not a whole trunk ring measures nothing
            continue
        z = b * bin_h
        rows[z] = (_interp(profile["width"], z) / xmax, _interp(profile["front"], z) / (cy - ymin),
                   _interp(profile["back"], z) / (ymax - cy), cy)
    keys = sorted(rows)

    def at(z):
        if z <= keys[0]:
            return rows[keys[0]]
        if z >= keys[-1]:
            return rows[keys[-1]]
        for a, b in zip(keys[:-1], keys[1:]):
            if a <= z <= b:
                t = (z - a) / (b - a)
                return tuple(rows[a][i] + (rows[b][i] - rows[a][i]) * t for i in range(4))
        return rows[keys[-1]]

    for v, (w, _) in zip(me.vertices, wt):
        if w <= 0.0 or not (z0 - 0.04 <= v.co.z <= z1 + 0.04):
            continue
        k = w * K.clamp01(min(v.co.z - (z0 - 0.04), (z1 + 0.04) - v.co.z) / 0.04)
        sx, sf, sb, cy = at(v.co.z)
        v.co.x *= 1.0 + (sx - 1.0) * k
        sy = sf if v.co.y < cy else sb
        v.co.y = cy + (v.co.y - cy) * (1.0 + (sy - 1.0) * k)
    me.update()
    return {round(z, 2): tuple(round(x, 3) for x in rows[z][:3]) for z in keys}


def add_bust(ob, bust, bones=("chest", "spine")):
    """bust: (amplitude m, (x, z) centre, sigma m): the front of the chest pushed forward (and a little down-filled),
    both sides, on the open rig's rest; only vertices weighted to the trunk, in front of its centre line."""
    amp, (bx, bz), sig = bust
    wt = _weight_on(ob, bones)
    n = 0
    for v, (w, _) in zip(ob.data.vertices, wt):
        if w <= 0.0 or v.co.y >= 0.0:
            continue
        d = sum(gauss(math.hypot(v.co.x - sx * bx, v.co.z - bz), sig) for sx in (1.0, -1.0))
        if d > 1e-3:
            v.co.y -= amp * min(1.0, d) * w * K.clamp01(-v.co.y / 0.06)
            n += 1
    ob.data.update()
    return n


# ------------------------------------------------------------------ the neutral base body (chain step 3)

def build_base(transfer=None):
    """Base_Body: the realistic neutral body (skin material, no apron/beard), the foot report's and the sit re-fit's
    reference. Never exported. transfer: None on REAL-1; for another chain's base (REAL-2) {"src_rest": REAL-1's
    rest_record, "girth": ..., "profile": ..., "bust": ...}: the parts are built on REAL-1's bones (the rig lookups read
    src_rest), skinned to the open rig, carried onto its rest (transfer_rest), the trunk fitted to the profile
    (fit_profile) and the bust added (add_bust)."""
    K.setup()
    if transfer:
        src = transfer["src_rest"]
        K.S["bone"] = {n: (Vector(r["head"]), Vector(r["tail"])) for n, r in src.items()}
    K.remove(["Base_Body"])
    m = K.mat("AN_BaseSkin", "C4A084")
    parts = [build_head("RB_Head", m), build_neck("RB_Neck", m), build_torso("RB_Torso", m, hem_jag=False),
             build_pelvis("RB_Pelvis", m)]
    for s in ("l", "r"):
        parts += [build_sleeve("RB_Sleeve_" + s, m, s), build_forearm("RB_Forearm_" + s, m, s), build_hand("RB_Hand_" + s, m, s),
                  build_trouser_leg("RB_Leg_" + s, m, s), build_boot("RB_Boot_" + s, m, s)]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = body.data.name = "Base_Body"
    if transfer:
        K.setup()                                              # the rig lookups back on the open rig
        print("transfer_rest: %d vertices onto %s's rest" % (transfer_rest(body, transfer["src_rest"], transfer["girth"]),
                                                             C.rig().get("anime_rig")))
        if transfer.get("profile"):
            print("fit_profile (band z: sx, front, back):", fit_profile(body, transfer["profile"]))
        if transfer.get("bust"):
            print("add_bust: %d vertices" % add_bust(body, transfer["bust"]))
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("Base_Body (realistic): %d tris, top %.3f" % (tris, max(v.co.z for v in body.data.vertices)))
    return body
