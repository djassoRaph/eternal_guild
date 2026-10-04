# real_body.py - route RL's body parts (the spike 2026-10-04; 25.31 S1.0), built in the REST pose of the REAL-1 rig
# (real_chain.REAL_1's table) from the concept sheet's own silhouette rows (real_layout). anime_kit supplies the
# primitives (new_obj, skin, chain, blend, ellipsoid) and the rig lookups (K.setup, K.H, K.T); every shape here is
# new: the anime kit's parts are drawn for the SD test's landmarks and head. The shapes' heights are REAL-1's (the
# Bartender's sheet). The bases' neutral bodies (build_neutral, 25.31 S1.0 v2) are built straight on the open rig from
# a body's params (real_chain.MAN / WOMAN); transfer_rest carries a mesh built on one rest onto another (unused by the
# bases since v2).
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


def nose(x, z, face=None):
    """Forward displacement of the nose, brows, sockets and cheekbones at (x, z) on the face. face: {"nose": k,
    "brow": k} multiplies the nose (tip and wings) and the brow ridge (None: the Bartender's, x 1.0)."""
    kn = face.get("nose", 1.0) if face else 1.0
    kb = face.get("brow", 1.0) if face else 1.0
    d = 0.0
    if 1.668 < z < 1.74:
        tip = _interp([(1.668, 0.0), (1.676, 0.012), (1.686, 0.024), (1.70, 0.019), (1.72, 0.009), (1.738, 0.002)], z)
        sig = _interp([(1.668, 0.020), (1.68, 0.019), (1.70, 0.014), (1.738, 0.010)], z)
        d += (tip * kn) * gauss(x, sig)
        d += (0.006 * kn) * gauss(abs(x) - 0.019, 0.007) * gauss(z - 1.679, 0.007)          # the nostril wings
    d += (0.007 * kb) * gauss(z - 1.751, 0.0085) * (1 - gauss(x, 0.02)) * gauss(abs(x) - 0.04, 0.035)   # the brow ridge
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


def head_point(th, z, nf=2.6, nb=2.2, face=None):
    w, yf, yb = head_ring(z)
    cy, d = (yf + yb) / 2.0, (yb - yf) / 2.0
    s, c = math.sin(th), math.cos(th)
    n = nf if c >= 0 else nb
    x = w * se(s, n)
    y = cy - d * se(c, n)
    if c > 0:
        y -= nose(x, z, face) * min(1.0, c * 2.0)
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
        fy = sheet.get("face_y", 0.10) if sheet else 0.10       # 25.31 S1: a sheet may move the front view's zone back
        face = K.clamp01((-c.y - fy) / 0.04)
        score = {"front": -n.y + 0.45 * face, "side": abs(n.x) * 1.08, "back": n.y}
        view = max(score, key=score.get)
        if n.z < -0.75:
            view = "front" if c.y < under_front_y else "back"
        top = sheet.get("top_from_back") if sheet else None
        if top and n.z > top["nz"] and c.z > top["z_min"]:
            # (25.31 S1, the player's hair) a face looking up has no view of its own: the front / side projections
            # squeeze it into the drawing's top rows (streaks). It takes the back view's hair instead, laid flat:
            # x across as the back view sees it, y (front to back) over the rows top["rows"]
            counts["top"] = counts.get("top", 0) + 1
            y0, y1 = top["y"]
            r0, r1 = top["rows"]
            for l in f.loops:
                p = l.vert.co
                px, _ = L.to_px("back", p.x, p.y, p.z, sheet)
                py = r0 + (r1 - r0) * K.clamp01((p.y - y0) / (y1 - y0))
                wx, wy, u0, v0 = sheet["head_crops"]["back"]
                win = sheet["head_win"]
                l[lay].uv = (u0 + 0.5 * (px - wx) / win, v0 + 0.5 * (1.0 - (py - wy) / win))
            continue
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

def _reshape(bm, shape):
    """shape(Vector) -> Vector on every vertex (25.31 S1: one head mesh fitted to another character's sheet), before
    the normals and the projection."""
    if shape is not None:
        for v in bm.verts:
            v.co = shape(v.co.copy())


def build_head(name, mat, sheet=None, face=None, shape=None):
    bm = bmesh.new()
    segs = HEAD_SEGS
    rings = []
    for z in HEAD_Z:
        rings.append([bm.verts.new(head_point(head_theta(k), z, face=face)) for k in range(segs)])
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
    _reshape(bm, shape)
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


def build_ears(name, mat, sheet=None, shape=None):
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
    _reshape(bm, shape)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print("ear views", projection_uvs(bm, sheet=sheet))
    return finish(name, bm, mat, head_w)


def build_neck(name, mat, sheet=None, shape=None, rings=None):
    bm = bmesh.new()
    rings = rings or [(1.47, 0.080, -0.125, 0.045, 2.2, 2.2), (1.54, 0.074, -0.118, 0.026, 2.2, 2.2),
                      (1.60, 0.070, -0.112, 0.022, 2.2, 2.2), (1.66, 0.064, -0.10, 0.018, 2.2, 2.2)]
    loft(bm, rings, 14)
    _reshape(bm, shape)
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


# The production hand (25.31 S1; the spike's build_hand stays for the bases' mannequins): a palm lofted from the wrist
# to the knuckles (narrow at the wrist, widest across the knuckles, a padded heel and a thenar mound under the thumb),
# four three-jointed fingers fanned a little and curled at rest (index to little: offset toward the thumb, length,
# radius, spread in degrees), and a thumb that leaves the palm's side near the wrist. Sizes are a 1.86 m man's
# (hand length ~0.19 m at k 1.0). Rest: the T-pose arm, palm down (-Z), thumb forward (-Y).
HAND_REAL = {
    "palm": [(-0.006, 0.030, 0.016), (0.020, 0.036, 0.017), (0.045, 0.041, 0.017), (0.070, 0.044, 0.016),
             (0.090, 0.045, 0.014), (0.102, 0.043, 0.012)],      # (t along the forearm, half-width, half-thickness)
    "fingers": [(0.030, 0.073, 0.0098, -5.0), (0.010, 0.082, 0.0100, -1.5), (-0.010, 0.077, 0.0096, 2.0),
                (-0.029, 0.061, 0.0086, 6.5)],
    "curl": (8.0, 16.0, 12.0),       # each finger joint's bend toward the palm, degrees (relaxed, open enough to read)
    "phalanx": (0.46, 0.30, 0.24),   # the three segments' shares of a finger's length
    "thumb": [(0.046, 0.0165), (0.036, 0.0140), (0.028, 0.0118)],    # (segment length, radius at its start)
    "sides": 10,
}


def _bend(v, axis_hint, toward, ang):
    """v turned by ang (radians) toward `toward` in the plane they span."""
    ax = v.cross(toward)
    if ax.length < 1e-6:
        return v
    return (Matrix.Rotation(ang, 3, ax.normalized()) @ v).normalized()


def build_hand_real(name, mat, s, scale=1.0, P=None):
    """The production hand (HAND_REAL, x scale): a lofted palm, three-jointed fingers and a thumb, skinned to the
    forearm, wrist and hand bones like build_hand; UVs in the "hand" region (the palm by its rings, the fingers
    u 0.8, the thumb u 0.15)."""
    P = dict(HAND_REAL, **(P or {}))
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
    n = P["sides"]
    rings = []
    rows = P["palm"]
    for j, (t, hw, ht) in enumerate(rows):
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n
            cs, sn = math.cos(a), math.sin(a)                  # cs: across (+ the thumb side), sn: + the palm side
            x_ = hw * se(cs, 3.0)
            y_ = ht * se(sn, 2.6)
            if sn > 0:                                         # the palm's padded heel and the thenar mound
                y_ += 0.004 * sn * gauss(t - 0.025, 0.03)
                y_ += 0.006 * max(0.0, cs) * sn * gauss(t - 0.035, 0.025)
            else:                                              # the back of the hand: flatter, knuckles at the far end
                y_ *= 0.85
                if t > 0.085:
                    y_ -= 0.002 * (0.5 + 0.5 * math.cos(4 * a))
            v = bm.verts.new(W + d * (t * k) + side * (x_ * k) + down * ((y_ + 0.002) * k))
            params[v] = (0.05 + 0.6 * j / (len(rows) - 1), i / n)
            ring.append(v)
        rings.append(ring)
    for a_, b_ in zip(rings[:-1], rings[1:]):
        for i in range(n):
            bm.faces.new((a_[i], a_[(i + 1) % n], b_[(i + 1) % n], b_[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    t_end = rows[-1][0]
    cu = [math.radians(c) for c in P["curl"]]
    for off, ln, r, spread in P["fingers"]:
        base = W + d * ((t_end - 0.010) * k) + side * (off * k) + down * (0.001 * k)
        dirv = (Matrix.Rotation(math.radians(spread) * sx, 3, down) @ d).normalized()
        if spread and dirv.dot(side) * spread > 0:             # + spread fans away from the thumb, whichever hand
            dirv = (Matrix.Rotation(-math.radians(spread) * sx, 3, down) @ d).normalized()
        pts, p = [base], base
        for seg, share in enumerate(P["phalanx"]):
            dirv = _bend(dirv, None, down, cu[seg])
            p = p + dirv * (ln * share * k)
            pts.append(p)
        rads = [(r * k * 0.92, r * k), (r * k * 0.88, r * k * 0.95), (r * k * 0.82, r * k * 0.88), (r * k * 0.74, r * k * 0.78)]
        pp, _ = tube(bm, pts, rads, 6, up=lambda p_, d_: down, cap0=False, cap1=True)
        for v in pp:
            params[v] = (0.80, 0.2 + 0.6 * pp[v][1])
    tb = W + d * (0.022 * k) + side * (0.030 * k) + down * (0.010 * k)
    dirs = [(d * 0.50 + side * 0.72 + down * 0.48), (d * 0.78 + side * 0.42 + down * 0.40), (d * 0.86 + side * 0.18 + down * 0.48)]
    tpts, p = [tb], tb
    for (ln, _r), dv in zip(P["thumb"], dirs):
        p = p + dv.normalized() * (ln * k)
        tpts.append(p)
    tr = [(r * k * 0.9, r * k) for _ln, r in P["thumb"]] + [(P["thumb"][-1][1] * k * 0.75, P["thumb"][-1][1] * k * 0.8)]
    pp, _ = tube(bm, tpts, tr, 6, up=lambda p_, d_: down, cap0=False, cap1=True)
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


BOOT = {"length": 1.0, "width": 1.0, "height": 1.0, "girth": 1.0, "top": 0.37, "cuff": True}


def build_boot(name, mat, s, boot=None):
    """The boot round the ankle. boot (BOOT's keys): the foot's length (y about the ankle), width (x), instep height
    (z), the shaft's girth, its top z (the shaft stretched from 0.15) and the turned-down cuff (True / False). The
    defaults are REAL-1's (the Bartender's) boot, vertex-identical to the spike's."""
    bt = dict(BOOT, **(boot or {}))
    kl, kw, kh, kg = bt["length"], bt["width"], bt["height"], bt["girth"]
    sx = 1 if s == "l" else -1
    ank = K.T("lowerleg." + s)
    xc, yc = ank.x, ank.y - 0.012
    bm = bmesh.new()
    params = {}
    # the shaft (around a vertical axis), bottom into the foot
    shaft = [(0.150, 0.059), (0.22, 0.059), (0.30, 0.062), (0.37, 0.066)]
    if bt["top"] != 0.37:
        shaft = [(0.150 + (z - 0.150) * (bt["top"] - 0.150) / (0.37 - 0.150), r) for z, r in shaft]
    if kg != 1.0:
        shaft = [(z, r * kg) for z, r in shaft]
    pp, srings = tube(bm, [Vector((xc, yc + 0.012, z)) for z, r in shaft], [(r, r * 1.04) for z, r in shaft], 12,
                      up=lambda p, d: Vector((0, -1, 0)), cap0=False, cap1=False, v_range=(0.40, 1.0))
    params.update({v: (u * 0.5, v_) for v, (u, v_) in pp.items()})
    # the foot: rings across Y (heel back to toe), each a flat-bottomed oval in X-Z
    foot = [(0.090, 0.030, 0.075), (0.075, 0.044, 0.118), (0.045, 0.051, 0.158), (0.005, 0.054, 0.172), (-0.050, 0.056, 0.140),
            (-0.100, 0.058, 0.104), (-0.150, 0.059, 0.082), (-0.195, 0.054, 0.070), (-0.230, 0.042, 0.062), (-0.250, 0.024, 0.052)]
    if (kl, kw, kh) != (1.0, 1.0, 1.0):
        foot = [(y * kl, hw * kw, top * kh) for y, hw, top in foot]
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
    tip = bm.verts.new((xc, yc - 0.262 * kl, 0.024 * kh))
    params[tip] = (0.75, 0.05)
    for k in range(n):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % n], tip))
    if not bt["cuff"]:                                          # no cuff: the shaft's top edge rolled in a little
        top = srings[-1]
        inner = [bm.verts.new(Vector((xc, yc + 0.012, v.co.z - 0.01)) + (v.co - Vector((xc, yc + 0.012, v.co.z))) * 0.86)
                 for v in top]
        for v in inner:
            params[v] = (0.0, 1.0)
        for k in range(12):
            bm.faces.new((top[k], top[(k + 1) % 12], inner[(k + 1) % 12], inner[k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        param_uvs(bm, params, "boots", wrap_u=True)
        return finish(name, bm, mat, K.chain(["lowerleg." + s, "foot." + s, "toes." + s], 0.04))
    # the turned-down cuff at the top
    cuff = [(0.334, 0.071), (0.360, 0.075), (0.392, 0.076), (0.392, 0.066), (0.350, 0.064)]
    if bt["top"] != 0.37 or kg != 1.0:
        cuff = [(z + bt["top"] - 0.37, r * kg) for z, r in cuff]
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


def apron_folds(th, t, folds):
    """The apron's hanging folds (25.31 S1): [(amplitude m, frequency, phase)] ripples plus [(angle deg, depth m,
    width deg)] deep troughs, all growing toward the hem (t 1) from a flat waist (t 0)."""
    rip = sum(a * math.sin(th * f + ph) for a, f, ph in folds["ripples"]) * t ** folds.get("power", 0.8)
    for ang, depth, wid in folds.get("troughs", ()):
        rip -= depth * gauss(math.degrees(th) - ang, wid) * t ** 0.7
    rip += folds.get("ease", 0.0) * t * max(0.0, math.cos(th)) ** 2      # the front hangs off the belly, clear of the knees
    return rip


def build_apron_skirt(name, mat, cols=18, rows=11, folds=None, legs=0.85, front_follow=0.55):
    """folds: apron_folds' dict (None: the spike's single 0.013 m ripple, vertex-identical); legs / front_follow:
    skirt_w's (the spike's 0.85 swings the hem forward with the thigh like a board: 0.18 m up in Walk_Bar)."""
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
            rip = 0.013 * math.sin(th * 7.0 + 0.6) * t ** 0.8 if folds is None else apron_folds(th, t, folds)
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
    return finish(name, bm, mat, skirt_w(APRON_TOP, APRON_HEM, front_follow, legs))


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


# ------------------------------------------------------------------ the spike's body (superseded)

def build_base():
    """The spike's REAL-1 Base_Body (the Bartender's shirt, sleeves, trousers and belly; skin material): the bases' body
    until 25.31 S1.0 v2 replaced it with build_neutral (Raphael: "a bit thick on the belly side"). Kept to rebuild the
    spike's reference; no chain step calls it."""
    K.setup()
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
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("Base_Body (the spike's): %d tris, top %.3f" % (tris, max(v.co.z for v in body.data.vertices)))
    return body


# ------------------------------------------------------------------ the neutral base bodies (25.31 S1.0 v2)
# Raphael (2026-10-04) on the first bases: "not really much of a woman avatar ... a bit thick on the belly side". The
# bases were the spike Bartender's shirt-and-belly body (REAL-2 that body reshaped). build_neutral() makes a neutral,
# clothing-less mannequin straight on the OPEN rig from a body's params (real_chain's REAL_1["body"] / REAL_2["body"]),
# every height in that rig's own metres: a trunk lofted through a smooth (monotone cubic) profile, a neck, the
# analytic head scaled onto the rig's head bone, one tube per arm and leg, the hands, the boots. A character's girth
# (the Bartender's belly) is its own param ("belly", "trunk_scale"), never the base's.

def pchip(table, z):
    """Monotone cubic (Fritsch-Carlson) through table [(z, v)] (any order), clamped at the ends: smooth, no overshoot."""
    t = sorted(table)
    xs, ys = [a for a, _ in t], [b for _, b in t]
    n = len(t)
    if z <= xs[0]:
        return ys[0]
    if z >= xs[-1]:
        return ys[-1]
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    dl = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    m[0], m[-1] = dl[0], dl[-1]
    for i in range(1, n - 1):
        if dl[i - 1] * dl[i] <= 0:
            m[i] = 0.0
        else:
            w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / dl[i - 1] + w2 / dl[i])
    i = max(k for k in range(n - 1) if xs[k] <= z)
    u = (z - xs[i]) / h[i]
    h00, h10, h01, h11 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u, -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
    return h00 * ys[i] + h10 * h[i] * m[i] + h01 * ys[i + 1] + h11 * h[i] * m[i + 1]


def _col(table, j):
    return [(r[0], r[j]) for r in table]


def _rig_scale():
    """This rig's size against REAL-1's (shoulder joint height 1.48): the weight blends' widths scale with it."""
    return K.H("upperarm.l").z / 1.48


def _trunk_w():
    f = _rig_scale()
    zs, zc, zsh, sj = K.H("spine").z, K.H("chest").z, K.H("upperarm.l").z, K.H("upperarm.l").x

    def fn(co):
        z = co.z
        if z < zs - 0.07 * f:
            w = {"hips": 1.0}
        elif z < zs + 0.05 * f:
            w = K.blend("hips", "spine", (z - (zs - 0.07 * f)) / (0.12 * f))
        elif z < zc - 0.08 * f:
            w = {"spine": 1.0}
        elif z < zc + 0.04 * f:
            w = K.blend("spine", "chest", (z - (zc - 0.08 * f)) / (0.12 * f))
        else:
            w = {"chest": 1.0}
        if z > zsh - 0.10 * f and abs(co.x) > sj - 0.055:
            s = "l" if co.x > 0 else "r"
            k = K.clamp01((abs(co.x) - (sj - 0.055)) / 0.10) * K.clamp01((z - (zsh - 0.10 * f)) / (0.07 * f))
            w = {b: v * (1 - 0.65 * k) for b, v in w.items()}
            w["upperarm." + s] = w.get("upperarm." + s, 0.0) + 0.65 * k
        return w
    return fn


def _neck_w():
    f = _rig_scale()
    zh = K.H("head").z
    return lambda co: K.blend("chest", "head", (co.z - (zh - 0.05 * f)) / (0.09 * f))


def _arm_w(s):
    sj = K.H("upperarm.l").x
    f = K.chain(["upperarm." + s, "lowerarm." + s, "wrist." + s, "hand." + s], 0.05)

    def fn(co):
        w = f(co)
        k = K.clamp01((sj + 0.055 - abs(co.x)) / 0.08)
        if k > 0:
            w = {b: v * (1 - k) for b, v in w.items()}
            w["chest"] = w.get("chest", 0.0) + k
        return w
    return fn


def _leg_w(s):
    sc = _rig_scale()
    hz = K.H("upperleg." + s).z
    f = K.chain(["upperleg." + s, "lowerleg." + s, "foot." + s], 0.06)

    def fn(co):
        w = f(co)
        k = K.clamp01((co.z - (hz - 0.09 * sc)) / (0.08 * sc))
        if k > 0:
            w = {b: v * (1 - k) for b, v in w.items()}
            w["hips"] = w.get("hips", 0.0) + k
        return w
    return fn


def bust_dome(p, b):
    """The bust as two rounded domes (REAL-2 v3, after Raphael's "more female chest"): per side an ellipse on the front
    of the trunk centred (+-b["x"], b["z"]), radii b["rx"] across and b["rz_up"] / b["rz_down"] above / below (a tighter
    fold under it), pushed forward by b["amp"] x (1 - r^2)^b["power"] (a power near 1 is a full, round dome; larger
    is a softer cone); the two sides meet by max(), so the cleavage stays. b["out"] spreads the outer half sideways
    (x amp x out). Returns (forward push, sideways push) for the vertex p."""
    best, bdx = 0.0, 0.0
    for side in (1.0, -1.0):
        ux = (p.x - side * b["x"]) / b["rx"]
        dz = p.z - b["z"]
        uz = dz / (b["rz_up"] if dz > 0 else b["rz_down"])
        r2 = ux * ux + uz * uz
        if r2 >= 1.0:
            continue
        p_lo = b.get("power", 1.0)
        p_hi = b.get("power_up", p_lo)                     # a softer edge above and outside (no ledge on the chest)
        k = K.smoothstep(-0.3, 0.7, max(uz, ux * side) / max(r2 ** 0.5, 1e-6))
        f = (1.0 - r2) ** (p_lo + (p_hi - p_lo) * k)
        if f > best:
            best = f
            bdx = side * b.get("out", 0.0) * f * K.clamp01(ux * side * 2.0)
    return b["amp"] * best, b["amp"] * bdx


def build_trunk(name, mat, P):
    """The trunk: rings every P["trunk_step"] through P["trunk"] [(z, half-width, front y, back y, n front, n back)]
    (pchip per column), capped at both ends; then the belly and the bust (front vertices pushed forward)."""
    tab = P["trunk"]
    sx, sy = P.get("trunk_scale", (1.0, 1.0))
    z0, z1 = tab[0][0], tab[-1][0]
    step = P.get("trunk_step", 0.02)
    nz = max(2, int(round((z1 - z0) / step)))
    rings = []
    for i in range(nz + 1):
        z = z0 + (z1 - z0) * i / nz
        rx, yf, yb = (pchip(_col(tab, j), z) for j in (1, 2, 3))
        nf, nb = pchip(_col(tab, 4), z), pchip(_col(tab, 5), z)
        cy = (yf + yb) / 2.0
        rings.append((z, rx * sx, cy + (yf - cy) * sy, cy + (yb - cy) * sy, nf, nb))
    bm = bmesh.new()
    loft(bm, rings, P.get("trunk_segs", 32), cap_bottom=True, cap_top=True)
    belly, bust = P.get("belly"), P.get("bust")
    for v in bm.verts:
        p = v.co
        if p.y >= 0.0:
            continue
        front = K.clamp01(-p.y / 0.06)
        d = 0.0
        if belly and belly[0]:
            amp, bz, szz, sxx = belly
            d += amp * gauss(p.z - bz, szz) * gauss(p.x, sxx)
        dx = 0.0
        if isinstance(bust, dict):
            d_b, dx = bust_dome(p, bust)
            d += d_b
        elif bust and bust[0]:
            amp, bx, bz, sig_up, sig_down = bust
            g = 0.0
            for side in (1.0, -1.0):
                sg = sig_up if p.z > bz else sig_down          # fuller and longer above, a tighter fold below
                g += gauss(p.x - side * bx, sig_up) * gauss(p.z - bz, sg)
            d += amp * min(1.0, g)
        p.y -= d * front
        p.x += dx * front
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(name, bm, mat, _trunk_w())


def build_neutral_neck(name, mat, P):
    bm = bmesh.new()
    loft(bm, [(z, rx, yf, yb, 2.0, 2.0) for z, rx, yf, yb in P["neck"]], 16, cap_bottom=True, cap_top=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(name, bm, mat, _neck_w())


HEAD_PIVOT_SRC = Vector((0.0, -0.050, 1.580))     # REAL-1's head bone head: the analytic head's own frame


def build_neutral_head(name, mat, P):
    """The analytic head (REAL-1's frame) with P["head"]'s face params, the jaw narrowed, scaled about REAL-1's head
    pivot (scale; width x on top) and set on the open rig's head bone."""
    h = P.get("head", {})
    ob = build_head(name, mat, face=h)
    sc, wd, jaw = h.get("scale", 1.0), h.get("width", 1.0), h.get("jaw", 0.0)
    dst = K.H("head")
    for v in ob.data.vertices:
        p = v.co.copy()
        if jaw:
            p.x *= 1.0 - jaw * K.smoothstep(1.71, 1.61, p.z)
        q = p - HEAD_PIVOT_SRC
        v.co = dst + Vector((q.x * sc * wd, q.y * sc, q.z * sc))
    ob.data.update()
    return ob


def build_limb_arm(name, mat, s, P):
    """One tube from inside the shoulder to the wrist: P["upperarm"] [(t along the upper arm, r up, r front-back)] and
    P["forearm"] [(t along the forearm, ...)] (the T-pose rest: palm down, so the wrist is wider front-back)."""
    S, E, W = arm_frame(s)
    du, dl = (E - S), (W - E)
    pts, rads = [], []
    for t, ru, rd in P["upperarm"]:
        pts.append(S + du * t)
        rads.append((ru, rd))
    for t, ru, rd in P["forearm"]:
        pts.append(E + dl * t)
        rads.append((ru, rd))
    bm = bmesh.new()
    params, _ = tube(bm, pts, rads, P.get("limb_sides", 14), up=up_z, cap0=True, cap1=True)
    return finish(name, bm, mat, _arm_w(s))


def build_limb_leg(name, mat, s, P):
    """One tube down the leg's bone line: P["leg"] [(z, r front-back, r across, y offset (+ back: the calf))], top
    (inside the trunk) to the ankle (inside the boot)."""
    hip, knee, ank = K.H("upperleg." + s), K.T("upperleg." + s), K.T("lowerleg." + s)

    def at(z):
        if z >= knee.z:
            return hip.lerp(knee, (hip.z - z) / (hip.z - knee.z))
        return knee.lerp(ank, (knee.z - z) / (knee.z - ank.z))
    pts = [at(z) + Vector((0.0, dy, 0.0)) for z, rf, rs, dy in P["leg"]]
    rads = [(rf, rs) for z, rf, rs, dy in P["leg"]]
    bm = bmesh.new()
    params, _ = tube(bm, pts, rads, P.get("limb_sides", 14), up=lambda p, d: Vector((0, -1, 0)), cap0=True, cap1=True)
    return finish(name, bm, mat, _leg_w(s))


def build_neutral(P):
    """Base_Body, the neutral mannequin on the OPEN rig (chain step 3): P is a chain's "body" (real_chain). Never
    exported; the sit re-fit, the foot report and the arm pass measure it."""
    K.setup()
    K.remove(["Base_Body"])
    m = K.mat("AN_BaseSkin", P.get("skin", "C4A084"))
    parts = [build_neutral_head("RB_Head", m, P), build_neutral_neck("RB_Neck", m, P), build_trunk("RB_Trunk", m, P)]
    for s in ("l", "r"):
        parts += [build_limb_arm("RB_Arm_" + s, m, s, P), build_hand("RB_Hand_" + s, m, s, scale=P.get("hand", 1.0)),
                  build_limb_leg("RB_Leg_" + s, m, s, P), build_boot("RB_Boot_" + s, m, s, P.get("boot"))]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = body.data.name = "Base_Body"
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("Base_Body (%s): %d tris, top %.3f, soles %.3f" % (P.get("name", "?"), tris, max(v.co.z for v in body.data.vertices),
                                                          min(v.co.z for v in body.data.vertices)))
    return body
