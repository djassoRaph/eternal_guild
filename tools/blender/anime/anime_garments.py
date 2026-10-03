# anime_garments.py - route AN (Story 25.31, AC 3): the garments every anime character is dressed with, on the
# anime_kit primitives. Each builder makes ONE skinned, smooth-shaded part in the caller's material (the palette atlas:
# the caller paints it with anime_atlas.paint_part) and returns the object(s); the caller joins the parts into its
# <Role>_Body (anime_merge.join). Heights are the approved test's, through K.Z(); horizontal sizes in metres.
# Build in the REST pose, after K.setup(). Blender frame: front -Y, the character's left +X, up +Z.
#
# Lifted from the Quest Dealer (25.30; their defaults ARE her values, so her rebuild is unchanged): elf ears, circlet,
# collar, trims (placket, buttons, belt), skirt/robe (+ its weights), mantles, cuffs.
# New for the cast (25.31): skirt slit, trousers, belt, apron, tabard, cape, shawl, hood / headscarf, hats fitted with
# K.head_radius_at (straw hat, cloth cap, morion (AH-9: the guard's, not a kettle brim), beret), pack, purse, human ears,
# beards. Headwear has ~0.11-0.14 m above the 2.110 head top under the 2.25 cap: build_hat() prints its top.
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import anime_kit as K


# ------------------------------------------------------------------ helpers

def slab(bm, grid, thick, inward):
    """A closed thin slab from a grid of outer points [row][col] (rows top to bottom): the outer sheet, a copy moved
    `thick` along inward(p), and the four edge strips. Smooth-shaded by new_obj (a sheet with no thickness inks badly)."""
    outer = [[bm.verts.new(p) for p in row] for row in grid]
    inner = [[bm.verts.new(p + inward(p) * thick) for p in row] for row in grid]
    R, Cn = len(grid), len(grid[0])
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


def hips_legs_w(top_z, hem_z, front_follow=0.35, back_rigid=True, legs=0.9):
    """A hanging garment's weights (the skirt's recipe): hips at the waist, the upper legs toward the hem; the front
    follows the thighs higher up (h^front_follow), the back stays with the hips (seated: it hangs behind the seat)."""
    def fn(co):
        h = K.clamp01((top_z - co.z) / (top_z - hem_z))
        s = K.clamp01(0.5 + co.x / 0.26)
        front = K.clamp01(0.5 - co.y / 0.2) if back_rigid else 1.0
        wl = legs * h ** front_follow * (0.1 + 0.9 * front)
        return {"hips": 1 - wl, "upperleg.l": wl * s, "upperleg.r": wl * (1 - s)}
    return fn


def back_w(co):
    """A back-hung piece (cape, pack): chest above the shoulder blades, blending to spine and hips down the back."""
    Z = K.Z
    if co.z > Z(1.20):
        return {"chest": 1.0}
    if co.z > Z(1.00):
        return K.blend("spine", "chest", (co.z - Z(1.00)) / (Z(1.20) - Z(1.00)))
    return K.blend("hips", "spine", K.clamp01((co.z - Z(0.80)) / (Z(1.00) - Z(0.80))))


# ------------------------------------------------------------------ ears

def build_ears(name, mat, length=0.26, root_r=0.058, direction=(0.86, 0.24, 0.45), flat=0.28, n=9, sides=8):
    """Long elf ears (the Quest Dealer's)."""
    hc = K.HC()
    bm = bmesh.new()
    for sx in (1, -1):
        base = hc + Vector((0.212 * sx, 0.025, -0.025))
        d = Vector((direction[0] * sx, direction[1], direction[2])).normalized()
        pts = [base + d * (length * i / (n - 1)) for i in range(n)]
        radii = [root_r * (1 - i / (n - 1)) ** 0.85 + 0.002 for i in range(n)]
        K.strand(bm, pts, radii, sides=sides, flat=flat, up_of=lambda p: Vector((0, 0.25, 1)), pole_tip=True)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.head_w)
    return ob


def build_human_ears(name, mat, size=1.0, seg=8, rings=6):
    """Small round human ears at the sides of the head (most of the cast: no elf ears outside the dealer)."""
    hc = K.HC()
    bm = bmesh.new()
    for sx in (1, -1):
        c = hc + Vector(((K.HR.x - 0.012) * sx, 0.03, -0.035))
        vs = K.ellipsoid(bm, c, 0.024 * size, 0.040 * size, 0.056 * size, seg, rings)
        for v in vs:                                          # tilted back a little, the top leaning out
            v.co = c + Matrix.Rotation(math.radians(-12 * sx), 3, "Y") @ (v.co - c)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.head_w)
    return ob


# ------------------------------------------------------------------ head jewellery

def build_circlet(name, gem_name, mat, z=1.884, gem_z=1.874, dip=0.075, tube=0.0065):
    Z = K.Z
    bm = bmesh.new()
    pts = []
    for i in range(36):
        th = 2 * math.pi * i / 36
        zz = Z(z) + dip * (1 - math.cos(th)) / 2
        x, y = K.head_radius_at(th, zz, grow=0.010)
        pts.append(Vector((x, y, zz)))
    K.loop_tube(bm, pts, tube, sides=4)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.head_w)
    bm = bmesh.new()
    gy = K.head_radius_at(0.0, Z(gem_z), grow=0.0)[1]
    K.ellipsoid(bm, Vector((0, gy - 0.014, Z(gem_z))), 0.020, 0.012, 0.026, 10, 6)
    gem = K.new_obj(gem_name, bm, mat)
    K.skin(gem, K.head_w)
    return ob, gem


# ------------------------------------------------------------------ neck and torso dressing

COLLAR = [(0.060, 1.425), (0.068, 1.47), (0.077, 1.52), (0.084, 1.556)]


def build_collar(name, trim_name, mat, profile=COLLAR, segs=20, sy=0.9, trim_r=0.085, trim_tube=0.008):
    """A high stand collar (profile [(r, test z)]) and its rim trim (trim_name None: no trim)."""
    Z = K.Z
    bm = bmesh.new()
    K.lathe(bm, [(r, Z(z)) for r, z in profile], segs=segs, sy=sy)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.neck_w)
    if trim_name is None:
        return ob, None
    zt = Z(profile[-1][1])
    bm = bmesh.new()
    K.loop_tube(bm, [Vector((trim_r * math.sin(a), -trim_r * sy * math.cos(a), zt)) for a in [2 * math.pi * i / 20 for i in range(20)]], trim_tube, sides=4)
    ob2 = K.new_obj(trim_name, bm, mat)
    K.skin(ob2, K.neck_w)
    return ob, ob2


def build_trims(name, mat, placket=True, buttons=(1.33, 1.18), belt_z=1.06, belt_r=0.126, belt_tube=0.013, girth=1.0):
    """A coat's front placket (1.43 down to 1.04, with a step out over the belt), buttons and a belt ring (belt_z None:
    no belt), as one part."""
    Z, tr = K.Z, lambda z: K.torso_r(z, girth)
    bm = bmesh.new()
    if placket:
        zs = [1.43 - 0.03 * i for i in range(14)]
        front = [Vector((0, -K.TORSO_SY * tr(z) - 0.006 - (0.02 if 1.22 < z < 1.29 else 0.0), Z(z))) for z in zs]
        K.strand(bm, front, [0.010] * len(front), sides=4, flat=0.5, up_of=lambda p: Vector((0, -1, 0)))
    for zb in buttons:
        K.ellipsoid(bm, Vector((0, -K.TORSO_SY * tr(zb) - 0.018, Z(zb))), 0.02, 0.012, 0.016, 8, 5)
    if belt_z is not None:
        r = belt_r * girth
        belt = [Vector((r * math.sin(a), -r * K.TORSO_SY * math.cos(a), Z(belt_z))) for a in [2 * math.pi * i / 24 for i in range(24)]]
        K.loop_tube(bm, belt, belt_tube, sides=4)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.torso_w)
    return ob


def build_belt(name, mat, z=1.06, r=0.126, tube=0.013, girth=1.0, buckle=True, segs=24):
    """A belt ring at test height z (over a coat or trousers' waist), with an optional front buckle."""
    Z = K.Z
    r = r * girth
    bm = bmesh.new()
    K.loop_tube(bm, [Vector((r * math.sin(a), -r * K.TORSO_SY * math.cos(a), Z(z))) for a in [2 * math.pi * i / segs for i in range(segs)]], tube, sides=4)
    if buckle:
        K.ellipsoid(bm, Vector((0, -r * K.TORSO_SY - tube, Z(z))), 0.028, 0.010, 0.022, 8, 4)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.torso_w)
    return ob


# ------------------------------------------------------------------ skirts and robes

SKIRT = [(0.123, 1.07), (0.138, 1.00), (0.185, 0.88), (0.232, 0.76), (0.262, 0.66)]


def skirt_shape(v, top_z, hem_z, back_full=0.35, back_lift=0.08, front_ease=0.13):
    """The back half fuller (depth x(1 + back_full) at the hem) and higher (+back_lift at the hem: a coat cut longer in
    front), so the seated back hem stays behind the stool's seat (the hips-rigid back sinks with the hips); front_ease
    gives the thighs' stride room."""
    h = K.clamp01((top_z - v.z) / (top_z - hem_z))
    if v.y < 0:
        v.y *= 1.0 + front_ease * h
    if v.y > 0:
        k = min(1.0, v.y / 0.12)
        v.y *= 1.0 + back_full * h * k
        v.z += back_lift * h * k


def skirt_w_fn(top_z, hem_z, front_follow=0.35):
    """The skirt's weights (the dealer's): see hips_legs_w."""
    return hips_legs_w(top_z, hem_z, front_follow=front_follow)


def build_skirt(name, trim_name, mat, profile=SKIRT, segs=24, sy=0.84, back_full=0.35, back_lift=0.08, front_ease=0.13,
                slit=None, hem_trim_r=0.266, hem_tube=0.012, front_follow=0.35, girth=1.0):
    """A skirt or robe: profile [(r, test z)] waist to hem (a long robe: a lower last z), revolved with denser rings (the
    hem deforms over the thighs). slit: (half-angle in degrees, test z of its top): the front opened below that height
    (a robe's walking slit; its hem trim then stops at the slit). trim_name None: no hem trim."""
    Z = K.Z
    prof = []
    for (r0, z0), (r1, z1) in zip(profile[:-1], profile[1:]):
        for t in (0.0, 1 / 3, 2 / 3):
            prof.append(((r0 + (r1 - r0) * t) * girth, Z(z0 + (z1 - z0) * t)))
    prof.append((profile[-1][0] * girth, Z(profile[-1][1])))
    top_z, hem_z = prof[0][1], prof[-1][1]
    shape = dict(back_full=back_full, back_lift=back_lift, front_ease=front_ease)
    bm = bmesh.new()
    K.lathe(bm, prof, segs=segs, sy=sy)
    for v in bm.verts:
        skirt_shape(v.co, top_z, hem_z, **shape)
    if slit:
        half, sz = math.radians(slit[0]), Z(slit[1])
        doomed = [f for f in bm.faces if f.calc_center_median().z < sz
                  and abs(math.atan2(f.calc_center_median().x, -f.calc_center_median().y)) < half]
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
    ob = K.new_obj(name, bm, mat)
    wfn = skirt_w_fn(top_z, hem_z, front_follow=front_follow)
    K.skin(ob, wfn)
    if trim_name is None:
        return ob, None
    bm = bmesh.new()
    hr = hem_trim_r * girth
    if slit:
        half = math.radians(slit[0])
        hem = []
        for k in range(29):
            a = half + (2 * math.pi - 2 * half) * k / 28
            p = Vector((hr * math.sin(a), -hr * sy * math.cos(a), hem_z + 0.002))
            skirt_shape(p, top_z, hem_z, **shape)
            hem.append(p)
        K.strand(bm, hem, [hem_tube] * len(hem), sides=4)
    else:
        hem = []
        for a in [2 * math.pi * i / 28 for i in range(28)]:
            p = Vector((hr * math.sin(a), -hr * sy * math.cos(a), hem_z + 0.002))
            skirt_shape(p, top_z, hem_z, **shape)
            hem.append(p)
        K.loop_tube(bm, hem, hem_tube, sides=4)
    ob2 = K.new_obj(trim_name, bm, mat)
    K.skin(ob2, wfn)
    return ob, ob2


# ------------------------------------------------------------------ trousers

def build_trousers(name, mat, s, girth=1.0, flare=0.0, top_r=0.078, ankle_r=0.056, sides=10, rings=12):
    """One trouser leg on the leg's own path and weights (K.build_leg with wider radii): top_r at the thigh, ankle_r
    at the ankle, + flare x t^2 toward the hem (t 0 thigh .. 1 ankle). Boots go over the hem (K.build_foot)."""
    radii = [(top_r - (top_r - ankle_r) * (i / (rings - 1))) * girth + flare * (i / (rings - 1)) ** 2 for i in range(rings)]
    return K.build_leg(name, mat, s, sides=sides, rings=rings, radii=radii)


# ------------------------------------------------------------------ shoulders and sleeves

MANTLE = [(0.0, 0.085), (0.05, 0.08), (0.085, 0.058), (0.102, 0.025), (0.108, 0.0)]


def build_mantle(name, trim_name, mat, s, profile=MANTLE, x=0.205, z=1.345, tilt=(0.62, 0.78), segs=16, trim_tube=0.008):
    """A shoulder cap (the dealer's mantles; a pauldron with a wider profile), blended chest to upper arm."""
    sx = 1 if s == "l" else -1
    Z = K.Z
    bm = bmesh.new()
    K.lathe(bm, profile, segs=segs)
    R = Vector((0, 0, 1)).rotation_difference(Vector((tilt[0] * sx, 0, tilt[1])).normalized()).to_matrix()
    c = Vector((x * sx, 0.0, Z(z)))
    for v in bm.verts:
        v.co = R @ v.co + c
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.shoulder_w(s))
    if trim_name is None:
        return ob, None
    rr = profile[-1][0]
    bm = bmesh.new()
    rim = [R @ Vector((rr * math.cos(2 * math.pi * k / segs), rr * math.sin(2 * math.pi * k / segs), 0.0)) + c for k in range(segs)]
    K.loop_tube(bm, rim, trim_tube, sides=4)
    ob2 = K.new_obj(trim_name, bm, mat)
    K.skin(ob2, K.shoulder_w(s))
    return ob, ob2


def build_cuff(name, mat, s, r=0.043, tube=0.009, offset=0.012, segs=12):
    """A cuff ring round the sleeve end (inner radius r - tube: anime_clearcheck's cuff check reads it)."""
    sh, el, wr = K.arm_pts(s)
    d = (wr - el).normalized()
    u, w = K.ring_frame(d, Vector((0, 0, 1)))
    bm = bmesh.new()
    K.loop_tube(bm, [wr + d * offset + (u * math.cos(2 * math.pi * k / segs) + w * math.sin(2 * math.pi * k / segs)) * r for k in range(segs)], tube, sides=4)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.chain(["upperarm." + s, "lowerarm." + s, "wrist." + s, "hand." + s]))
    return ob


# ------------------------------------------------------------------ apron, tabard, cape, shawl

def _front_grid(z_top, z_bot, half_w, rows, cols, gap, girth=1.0, hem_spread=0.0, back=False):
    """A grid hugging the torso / pelvis front (or back) at test heights z_top..z_bot, gap off the body; below the
    pelvis it hangs straight on (the hips' depth). half_w (m) widens by hem_spread toward the hem."""
    Z = K.Z
    sgn = 1 if back else -1
    grid = []
    for j in range(rows + 1):
        zt = z_top + (z_bot - z_top) * j / rows
        hw = half_w + hem_spread * j / rows
        depth = K.TORSO_SY * K.torso_r(max(zt, 0.92), girth)
        row = []
        for i in range(cols + 1):
            x = -hw + 2 * hw * i / cols
            r = K.torso_r(max(zt, 0.92), girth)
            k = math.sqrt(max(0.0, 1 - (x / (r + 0.03)) ** 2)) if abs(x) < r + 0.03 else 0.0
            y = sgn * (depth * max(k, 0.55) + gap)
            row.append(Vector((x, y, Z(zt))))
        grid.append(row)
    return grid


def build_apron(name, mat, z_top=1.07, z_bot=0.52, half_w=0.15, rows=8, cols=6, gap=0.02, thick=0.010, girth=1.0, hem_spread=0.03):
    """A front apron from the waist (z_top) to below the knee (z_bot: 0.52 test = knee-length, the Bartender's),
    hanging off the belly; weighted like a skirt's front (it follows the thighs when he walks or squats)."""
    grid = _front_grid(z_top, z_bot, half_w, rows, cols, gap, girth, hem_spread)
    bm = bmesh.new()
    slab(bm, grid, thick, lambda p: Vector((0, 1, 0)))
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, hips_legs_w(grid[0][0].z, grid[-1][0].z, front_follow=0.5, back_rigid=False))
    return ob


def build_tabard(name, mat, z_top=1.40, z_bot=0.62, half_w=0.13, rows=10, cols=6, gap=0.022, thick=0.010, girth=1.0, back=True):
    """A tabard: a front panel (and a back one) from the shoulders to below the hips; torso weights above the waist,
    hips/upper legs below (the guard's livery, the Healer's)."""
    Z = K.Z
    bm = bmesh.new()
    for b in ((False, True) if back else (False,)):
        grid = _front_grid(z_top, z_bot, half_w, rows, cols, gap, girth, 0.02, back=b)
        slab(bm, grid, thick, (lambda p: Vector((0, -1, 0))) if b else (lambda p: Vector((0, 1, 0))))
    ob = K.new_obj(name, bm, mat)
    waist = Z(1.00)
    legs = hips_legs_w(waist, Z(z_bot), front_follow=0.5, back_rigid=False)
    K.skin(ob, lambda co: K.torso_w(co) if co.z > waist else legs(co))
    return ob


def build_cape(name, mat, z_top=1.43, z_bot=0.55, half_top=0.17, half_bot=0.30, rows=10, cols=8, thick=0.012, girth=1.0, flare=0.10):
    """A cape hung from the shoulders down the back to z_bot, flaring out behind toward the hem (clear of the legs'
    stride and of the seat: its back stays with the spine/hips, back_w)."""
    Z = K.Z
    grid = []
    for j in range(rows + 1):
        t = j / rows
        zt = z_top + (z_bot - z_top) * t
        hw = half_top + (half_bot - half_top) * t
        base = K.TORSO_SY * K.torso_r(max(zt, 0.92), girth) + 0.03
        row = []
        for i in range(cols + 1):
            u = -1 + 2 * i / cols
            x = hw * u
            y = base + flare * t ** 1.5 - 0.06 * u * u * (1 - 0.5 * t)       # wraps a little round the sides
            row.append(Vector((x, y, Z(zt))))
        grid.append(row)
    bm = bmesh.new()
    slab(bm, grid, thick, lambda p: Vector((0, -1, 0)))
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, back_w)
    return ob


SHAWL = [(0.090, 1.455), (0.150, 1.43), (0.215, 1.38), (0.245, 1.31), (0.240, 1.24), (0.228, 1.22),
         (0.225, 1.30), (0.200, 1.37), (0.140, 1.41), (0.085, 1.43)]


def build_shawl(name, mat, profile=SHAWL, segs=24, sy=0.80, girth=1.0):
    """A shawl draped close round the neck and over the shoulders (a closed lathe ring: outer surface, hem, inner);
    blended chest to upper arm like the mantles."""
    Z = K.Z
    bm = bmesh.new()
    rings = [[bm.verts.new((r * girth * math.sin(2 * math.pi * k / segs), -sy * r * girth * math.cos(2 * math.pi * k / segs), Z(z)))
              for k in range(segs)] for r, z in profile]
    n = len(rings)
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % n]
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    ob = K.new_obj(name, bm, mat)

    def fn(co):
        k = K.clamp01((abs(co.x) - 0.13) / 0.14)
        s = "l" if co.x > 0 else "r"
        return {"chest": 1 - 0.6 * k, "upperarm." + s: 0.6 * k}
    K.skin(ob, fn)
    return ob


# ------------------------------------------------------------------ hoods and headscarves

def build_hood(name, mat, grow=0.035, open_half=60.0, drape_z=1.42, drape_r=0.17, useg=24, vseg=12, thick=0.012):
    """A hood (or, tighter, a headscarf) shelled over the head with K.head_radius_at: the crown, sides and back, the
    face left open (|angle from the front| < open_half degrees), and a drape round the neck down to drape_z.
    Head-weighted above the jaw, chest-blended on the drape."""
    Z = K.Z
    hc, HR = K.HC(), K.HR
    top = hc.z + HR.z + grow
    zs = [top - (top - Z(drape_z)) * (j / vseg) ** 1.15 for j in range(vseg + 1)]
    half = math.radians(open_half)

    def shell(th, z):
        """The head's ellipsoid inflated by grow on every axis (as the hair cap is: a horizontal grow alone pinches
        to a spike over the crown and the cap shows through)."""
        k = math.sqrt(max(0.0, 1 - ((z - hc.z) / (HR.z + grow)) ** 2))
        return (HR.x + grow) * k * math.sin(th), -(HR.y + grow) * k * math.cos(th)
    grid = []
    for j, z in enumerate(zs):
        row = []
        for i in range(useg + 1):
            th = half + (2 * math.pi - 2 * half) * i / useg
            if z >= hc.z - HR.z * 0.6:
                x, y = shell(th, z)
            else:
                t = K.clamp01((hc.z - HR.z * 0.6 - z) / (hc.z - HR.z * 0.6 - Z(drape_z)))
                x0, y0 = shell(th, hc.z - HR.z * 0.6)
                x1, y1 = drape_r * math.sin(th), -drape_r * 0.9 * math.cos(th)
                x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            row.append(Vector((x, y * (1.06 if y > 0 else 1.0), z)))
        grid.append(row)
    # the crown closes: the top row is pulled to the centre
    grid[0] = [Vector((hc.x, hc.y, top)) + (p - Vector((hc.x, hc.y, top))) * 0.15 for p in grid[0]]
    bm = bmesh.new()
    slab(bm, grid, thick, lambda p: (Vector((hc.x, hc.y, p.z)) - p).normalized() if (Vector((hc.x, hc.y, p.z)) - p).length > 1e-4 else Vector((0, 0, -1)))
    ob = K.new_obj(name, bm, mat)
    jaw = hc.z - HR.z * 0.6

    def fn(co):
        if co.z >= jaw:
            return {"head": 1.0}
        return K.blend("chest", "head", K.clamp01((co.z - Z(drape_z)) / (jaw - Z(drape_z))))
    K.skin(ob, fn)
    return ob


def build_headscarf(name, mat):
    """The old woman's headscarf: a hood worn close (over any hair cap: their grow is <= 0.02), the face open wider,
    down to the nape."""
    return build_hood(name, mat, grow=0.032, open_half=70.0, drape_z=1.50, drape_r=0.14, thick=0.010)


# ------------------------------------------------------------------ hats and helmets (fitted with K.head_radius_at)

def _band_r(z, grow):
    """The head's band radii (rx, ry) at height z, plus grow."""
    x, _ = K.head_radius_at(math.pi / 2, z, grow=grow)
    _, y = K.head_radius_at(0.0, z, grow=grow)
    return abs(x), abs(y)


def _hat_lathe(bm, prof, segs, band_z, ry_over_rx):
    """Revolve [(r, z)] round the head's centre with the head's own depth/width ratio."""
    hc = K.HC()
    K.lathe(bm, prof, segs=segs, sy=ry_over_rx, cx=hc.x, cy=hc.y)


def _tilt(bm, pivot, axis, deg):
    R = Matrix.Rotation(math.radians(deg), 3, axis)
    for v in bm.verts:
        v.co = R @ (v.co - pivot) + pivot


def build_hat(name, mat, kind, band_test_z=1.93, grow=0.02, segs=24, tilt=None):
    """A hat or helmet worn on the head (head-weighted). kind: "straw" (the farmer's wide straw hat), "cap" (the local's
    cloth cap with a peak), "morion" (the guard's: a crested dome with a brim up-swept front and back, AH-9: no kettle
    brim shared with the farmer), "beret" (the merchant's floppy slanted beret). Prints its top (cap 2.25)."""
    hc = K.HC()
    zb = K.Z(band_test_z)
    rx, ry = _band_r(zb, grow)
    sy = ry / rx
    crown = hc.z + K.HR.z + grow              # the head top + grow
    bm = bmesh.new()
    if kind == "straw":
        prof = [(0.0, crown + 0.07), (rx * 0.75, crown + 0.065), (rx * 0.98, crown + 0.02), (rx, zb + 0.03),
                (rx + 0.02, zb - 0.005), (rx + 0.105, zb - 0.025), (rx + 0.12, zb - 0.038), (rx + 0.105, zb - 0.034),
                (rx + 0.01, zb - 0.02), (rx - 0.012, zb + 0.02), (rx * 0.9, crown + 0.03), (0.0, crown + 0.04)]
        _hat_lathe(bm, prof, segs, zb, sy)
        # pushed back: the brim lifts in front (a wider brim hid the whole face from the game camera, 25.14's lesson)
        _tilt(bm, Vector((hc.x, hc.y, zb)), "X", tilt if tilt is not None else -12.0)
    elif kind == "cap":
        prof = [(0.0, crown + 0.05), (rx * 0.8, crown + 0.045), (rx + 0.03, crown - 0.03), (rx + 0.025, zb + 0.03),
                (rx + 0.012, zb - 0.01), (rx - 0.004, zb - 0.008), (rx * 0.9, crown - 0.01), (0.0, crown + 0.02)]
        _hat_lathe(bm, prof, segs, zb, sy)
        n = 8                                                       # the peak over the brow
        top_v, bot_v = [], []
        for i in range(n + 1):
            a = math.radians(-55 + 110 * i / n)
            for r in (0.0, 1.0):
                rr = rx + 0.01 + r * 0.075
                p = Vector((hc.x + rr * math.sin(a), hc.y - rr * sy * math.cos(a), zb - 0.004 - 0.018 * r))
                top_v.append(bm.verts.new(p))
                bot_v.append(bm.verts.new(p - Vector((0, 0, 0.012))))
        for i in range(n):
            a, b, c, d = 2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2
            bm.faces.new((top_v[a], top_v[b], top_v[c], top_v[d]))
            bm.faces.new((bot_v[a], bot_v[d], bot_v[c], bot_v[b]))
            bm.faces.new((top_v[b], bot_v[b], bot_v[c], top_v[c]))
            bm.faces.new((top_v[a], top_v[d], bot_v[d], bot_v[a]))
        bm.faces.new((top_v[0], bot_v[0], bot_v[1], top_v[1]))
        bm.faces.new((top_v[-2], top_v[-1], bot_v[-1], bot_v[-2]))
        _tilt(bm, Vector((hc.x, hc.y, zb)), "X", tilt if tilt is not None else 4.0)
    elif kind == "morion":
        dome = crown + 0.025                                        # a low dome: the comb crest is the tell (cap 2.25)
        prof = [(0.0, dome)]
        for k in range(1, 6):
            a = math.radians(90 - 90 * k / 6)
            prof.append((rx * math.cos(a) + 0.008, zb + 0.02 + (dome - zb - 0.02) * math.sin(a)))
        prof += [(rx + 0.012, zb + 0.005), (rx + 0.09, zb - 0.015), (rx + 0.10, zb - 0.028), (rx + 0.005, zb - 0.01),
                 (rx * 0.92, crown - 0.02), (0.0, crown + 0.03)]
        _hat_lathe(bm, prof, segs, zb, sy)
        for v in bm.verts:                                          # the brim sweeps up at the front and back (boat shape)
            d = Vector((v.co.x - hc.x, v.co.y - hc.y, 0))
            if d.length > rx + 0.02:
                fb = abs(d.y) / max(d.length, 1e-6)
                v.co.z += 0.075 * fb ** 2 * K.clamp01((d.length - rx - 0.02) / 0.08)
        h = dome - zb - 0.02                                        # the comb crest, front to back over the dome
        crest = [Vector((hc.x, hc.y - ry * 0.95 * math.sin(a), zb + 0.02 + h * math.cos(a) + 0.012 * math.cos(a) ** 2))
                 for a in [math.radians(-75 + 150 * k / 10) for k in range(11)]]
        K.strand(bm, crest, [0.012 + 0.010 * math.cos(math.radians(-75 + 150 * k / 10)) for k in range(11)], sides=6, flat=2.6,
                 up_of=lambda p: Vector((1, 0, 0)))
        _tilt(bm, Vector((hc.x, hc.y, zb)), "X", tilt if tilt is not None else -6.0)
    elif kind == "beret":
        prof = [(0.0, crown + 0.06), (rx * 0.7, crown + 0.055), (rx + 0.10, crown + 0.01), (rx + 0.11, crown - 0.03),
                (rx + 0.06, zb + 0.05), (rx + 0.012, zb + 0.02), (rx + 0.008, zb - 0.01), (rx - 0.01, zb - 0.008),
                (rx * 0.9, crown - 0.03), (0.0, crown + 0.02)]
        _hat_lathe(bm, prof, segs, zb, sy)
        _tilt(bm, Vector((hc.x, hc.y, zb)), "Y", tilt if tilt is not None else 12.0)      # worn at a slant
    else:
        raise ValueError("build_hat: unknown kind %r" % kind)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.head_w)
    top = max(v.co.z for v in ob.data.vertices)
    print("%s (%s): top %.3f (cap 2.25: %s)" % (name, kind, top, "OK" if top <= 2.25 else "OVER"))
    return ob


# ------------------------------------------------------------------ packs and purses

def build_pack(name, mat, bedroll=True, girth=1.0):
    """A traveller's pack on the back (a canvas box) with a bedroll across its top; back-weighted."""
    Z = K.Z
    yb = K.TORSO_SY * K.torso_r(1.15, girth)
    bm = bmesh.new()
    c = Vector((0.0, yb + 0.075, Z(1.12)))
    K.ellipsoid(bm, c, 0.15, 0.07, 0.15, 10, 6)                                  # the pack (a soft, rounded box)
    if bedroll:
        K.strand(bm, [Vector((-0.20, yb + 0.07, Z(1.30))), Vector((0.20, yb + 0.07, Z(1.30)))], [0.055, 0.055], sides=10)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, back_w)
    return ob


def build_purse(name, mat, side="r", z=0.98, girth=1.0):
    """A coin purse hung at the belt on one hip; hips-weighted."""
    Z = K.Z
    sx = 1 if side == "l" else -1
    r = K.torso_r(1.0, girth)
    c = Vector((0.10 * sx * girth, -K.TORSO_SY * r * 0.8 - 0.045, Z(z)))
    bm = bmesh.new()
    K.ellipsoid(bm, c, 0.050, 0.038, 0.055, 8, 6)
    K.strand(bm, [c + Vector((0, 0, 0.04)), c + Vector((0, 0, 0.075))], [0.022, 0.016], sides=6)     # the gathered neck
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, lambda co: {"hips": 1.0})
    return ob


# ------------------------------------------------------------------ beards

def head_point(th, zf):
    """A point of anime_kit.build_head's surface (its jaw narrowing included): th the angle from the front (+ to the
    character's left), zf the height from -1 (chin) to 1 (crown)."""
    hc, HR = K.HC(), K.HR
    r = math.sqrt(max(0.0, 1 - zf * zf))
    x, y, z = r * math.sin(th) * HR.x, -r * math.cos(th) * HR.y, zf * HR.z
    if z < 0:
        t = -z / HR.z
        x *= 1 - 0.42 * t ** 1.6
        y *= (1 - 0.48 * t ** 1.5) if y > 0 else (1 - 0.12 * t ** 2)
        y -= 0.028 * t ** 3
    if z > 0 and y > 0:
        y *= 1.06
    return hc + Vector((x, y, z))


def build_beard(name, mat, length=0.08, full=True, rows=9, cols=14, base=0.008, thick=0.010, moustache=True):
    """A beard shelled on the jaw (head_point): full = from the sideburns along the cheeks to the chin; else a chin
    beard. The mouth stays open (the front starts under the lower lip); it thickens toward the chin into a spade
    `length` deep. A moustache bar over the mouth. Head-weighted."""
    hc = K.HC()
    spread = 1.30 if full else 0.55
    bm = bmesh.new()
    grid = []
    for j in range(rows + 1):
        s_ = j / rows
        row = []
        for i in range(cols + 1):
            th = -spread + 2 * spread * i / cols
            zf_top = -0.78 + (0.48 if full else 0.0) * K.smoothstep(0.15, 0.7, abs(th))
            zf = zf_top + (-0.995 - zf_top) * s_
            p = head_point(th, zf)
            d = (p - hc).normalized()
            off = base + length * s_ ** 2 * (0.4 + 0.6 * math.cos(th) ** 2)
            row.append(p + d * off)
        grid.append(row)
    slab(bm, grid, thick, lambda q: (hc - q).normalized())
    if moustache:
        for sx in (1, -1):
            pts = [head_point(0.05 * sx, -0.64), head_point(0.30 * sx, -0.68), head_point(0.48 * sx, -0.78)]
            pts = [q + (q - hc).normalized() * 0.010 for q in pts]
            K.strand(bm, K.catmull(pts, 5), [0.015, 0.014, 0.012, 0.009, 0.005], sides=5, flat=0.6, up_of=lambda q: Vector((0, 0, 1)), pole_tip=True)
    ob = K.new_obj(name, bm, mat)
    K.skin(ob, K.head_w)
    return ob
