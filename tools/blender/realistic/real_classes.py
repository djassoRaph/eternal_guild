# real_classes.py - the six class bodies on route RL (Story 25.31 S3, AC 8; catalogue G2-G7), from Raphael's picks
# (eternal_guild_art/picked/C_G<n>_<class>.png): the Fighter, the Mage and the Barbarian on REAL-1 (the player's head,
# projected from each pick), the Rogue, the Healer and the Ranger on REAL-2 (REAL-2's head). One module, ONE .blend and
# ONE GLB per class (V13: actions are file-global): <art>/blender/g<n>_<class>_real.blend ->
# assets/characters/custom/g<n>_<class>_real.glb. The townsfolk kit's garments (real_townsfolk) are reused.
# R-9 (refined, decision log 2026-10-04): the bodies are EMPTY-HANDED. Every carried item is a SEPARATE prop on its slot,
# HIDDEN by the game by default (RealisticPatron.dress_body hides the hand-slot props): the Fighter's sword (handslot.r)
# and round shield (handslot.l), the Mage's staff (handslot.r), the Healer's crystal staff (handslot.r; AH-3: the
# crystal is its own emissive material, roughness 0, no outline), the Barbarian's axe (handslot.r), the Ranger's bow
# (handslot.l). WORN gear is visible: the Rogue's sheathed daggers (a prop on hips), the Ranger's quiver (a prop on
# chest), satchels and straps (on the body).
# One call per step (README's runner), for a class id V:
#   open_base_as(V)      the base (REAL-1 / REAL-2) saved as g<n>_<V>_real.blend (a file load: own call)
#   build(V)             its parts joined into <Role>_Body (the head projection + the body atlas) + its props
#   build_clips(V)       Idle (hands by the clothes), Walking_A (its own stride), Running_A (a jog), arms kept outside
#                        the clothes in Running_A, the sits, Cheer and Interact (real_player.arms_out)
#   build(V, props_only=True)   the hand props again, aimed from the re-posed Idle
#   paint_head(V)        the painted head pass (real_bake)
#   measure(V)           ground speeds, tops, the seat (V13), widths; robes(V) the thighs-vs-robe check (b)
#   export(V)            Rig + body + props to assets/characters/custom/g<n>_<V>_real.glb
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
import real_dealer as RD
import real_layout as L
import real_player as RP
import real_townsfolk as T

ART = C.ART
TRI_BUDGET = 10000
GLB_DIR = T.GLB_DIR
IDS = ("fighter", "rogue", "mage", "healer", "barbarian", "ranger")
G = {"fighter": "g2", "rogue": "g3", "mage": "g4", "healer": "g5", "barbarian": "g6", "ranger": "g7"}
ROLE = {"fighter": "Fighter", "rogue": "Rogue", "mage": "Mage", "healer": "Healer", "barbarian": "Barbarian",
        "ranger": "Ranger"}
WOMEN = ("rogue", "healer", "ranger")
# props: (name, bone, carried): carried props hang from a hand slot and the game hides them; worn ones stay visible
PROPS = {"fighter": [("Fighter_Sword", "handslot.r", True), ("Fighter_Shield", "handslot.l", True)],
         "rogue": [("Rogue_Daggers", "hips", False)],
         "mage": [("Mage_Staff", "handslot.r", True)],
         "healer": [("Healer_Staff", "handslot.r", True)],
         "barbarian": [("Barbarian_Axe", "handslot.r", True)],
         "ranger": [("Ranger_Bow", "handslot.l", True), ("Ranger_Quiver", "chest", False)]}
W = RC.WOMAN


def cfg(v):
    r, g = ROLE[v], G[v]
    return {
        "id": v, "role": r,
        "blend": C.BLEND + "%s_%s_real.blend" % (g, v),
        "head_png": ART + "textures/realistic/%s_%s_real_head.png" % (g, v),
        "head_paint_png": ART + "textures/realistic/%s_%s_real_headpaint.png" % (g, v),
        "body_png": ART + "textures/realistic/%s_%s_real_body.png" % (g, v),
        "glb": GLB_DIR + "%s_%s_real.glb" % (g, v),
        "body": r + "_Body",
        "props": [p[0] for p in PROPS[v]],
        "chain": RC.REAL_2 if v in WOMEN else RC.REAL_1,
        "sheet": L.CLASS_SHEETS[v],
    }


# ------------------------------------------------------------------ heads

HEAD_X = {"fighter": 0.90, "mage": 0.89, "barbarian": 0.97}
DZ = -0.020
WHEAD = {"rogue": dict(W["head"], width=0.90, jaw=0.14), "healer": dict(W["head"], width=0.90, jaw=0.15),
         "ranger": dict(W["head"], width=0.89, jaw=0.15)}


def shape_of(v):
    if v in WOMEN:
        h = WHEAD[v]

        def sh(p):
            q = p.copy()
            q.x *= 1.0 - h["jaw"] * K.smoothstep(1.71, 1.61, p.z)
            q = q - RB.HEAD_PIVOT_SRC
            return K.H("head") + Vector((q.x * h["scale"] * h["width"], q.y * h["scale"], q.z * h["scale"]))
        return sh
    hx = HEAD_X[v]
    return lambda p: Vector((p.x * hx, p.y, p.z + DZ))


def unshape_z(v, z):
    if v in WOMEN:
        return (z - K.H("head").z) / WHEAD[v]["scale"] + RB.HEAD_PIVOT_SRC.z
    return z - DZ


def head_ring_at(v, z):
    """(half-width, front y, back y, centre y) of class v's shaped head at rest height z (no nose)."""
    zu = unshape_z(v, z)
    w, yf, yb = RB.head_ring(zu)
    sh = shape_of(v)
    pw = sh(Vector((w, (yf + yb) / 2, zu)))
    pf = sh(Vector((0.0, yf, zu)))
    pb = sh(Vector((0.0, yb, zu)))
    return pw.x, pf.y, pb.y, (pf.y + pb.y) / 2


def _project_or_paint(bm, v, region, params, name):
    """The head material: projected from the pick (region None); else the body atlas region (the Ranger's hair: her
    pick draws it under a hood in two views)."""
    if region is None:
        print("%s views" % name, RB.projection_uvs(bm, sheet=cfg(v)["sheet"]))
    else:
        RB.param_uvs(bm, params, region, wrap_u=True)


def hair_shell(name, mat, v, low, top=1.852, apex=1.881, thick=None, mess=1.0, cols=34, rows=8, part=None, region=None):
    """real_townsfolk.hair_shell on class v's head (part: the parting's column angle in degrees, or None)."""
    thick = thick or (lambda a: RB._interp([(0, 0.020), (40, 0.018), (70, 0.012), (100, 0.012), (140, 0.018), (180, 0.020)], a))
    bm = bmesh.new()
    ths = [RB.head_theta(k, cols) for k in range(cols)]
    grid, params = [], {}
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
            if part is not None:
                t *= 1.0 - 0.5 * RB.gauss(math.degrees(th) - part, 6.0) * s
            vv = bm.verts.new(p + n * t)
            params[vv] = (k / cols, s)
            row.append(vv)
        grid.append(row)
    for a_, b_ in zip(grid[:-1], grid[1:]):
        for k in range(cols):
            bm.faces.new((a_[k], a_[(k + 1) % cols], b_[(k + 1) % cols], b_[k]))
    tip = bm.verts.new((0.0, -0.075, apex))
    params[tip] = (0.5, 1.0)
    for k in range(cols):
        bm.faces.new((grid[-1][k], grid[-1][(k + 1) % cols], tip))
    RB._reshape(bm, shape_of(v))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    f0 = max(bm.faces, key=lambda f: f.calc_center_median().z)
    if f0.normal.z < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    _project_or_paint(bm, v, region, params, name)
    return RB.finish(name, bm, mat, RB.head_w)


def _low(table):
    return lambda a: RB._interp(table, a)


HAIRLINE = T.HAIRLINE


def head_parts(v, head, P):
    """Head, ears, neck (head material, projected)."""
    sh = shape_of(v)
    sheet = cfg(v)["sheet"]
    if v in WOMEN:
        nb = bmesh.new()
        RB.loft(nb, [(z, w, f, b, 2.0, 2.0) for z, w, f, b in W["neck"]], 14)
        bmesh.ops.recalc_face_normals(nb, faces=nb.faces)
        print("neck views", RB.projection_uvs(nb, sheet=sheet))
        return [RB.build_head(P + "Head", head, sheet=sheet, face=WHEAD[v], shape=sh), RB.finish(P + "Neck", nb, head, RB._neck_w()),
                RB.build_ears(P + "Ears", head, sheet=sheet, shape=sh)]
    hx = HEAD_X[v]
    g = 1.18 if v == "barbarian" else 1.0
    neck = [(1.47, 0.068 * g, -0.112, 0.040, 2.2, 2.2), (1.54, 0.064 * g, -0.106, 0.028 * g, 2.2, 2.2),
            (1.60, 0.061 * g, -0.102, 0.022, 2.2, 2.2), (1.67, 0.060, -0.096, 0.018, 2.2, 2.2)]
    return [RB.build_head(P + "Head", head, sheet=sheet, shape=sh), RB.build_ears(P + "Ears", head, sheet=sheet, shape=sh),
            RB.build_neck(P + "Neck", head, sheet=sheet, rings=[(z, w / hx, f, b, n1, n2) for z, w, f, b, n1, n2 in neck], shape=sh)]


# ------------------------------------------------------------------ generic garments (any ring function, any base)

def man_ring(z, grow=0.0):
    return T.man_ring(z, grow)


def woman_ring(z, grow=0.0):
    return T.woman_ring(z, grow)


BURLY = (1.13, 1.10)                       # the Barbarian's trunk x / y (AH-5: burly within the base)
BELLY = (0.030, 1.08, 0.10, 0.11)          # amp, z, sigma z, sigma x


def burly_ring(z, grow=0.0):
    w, yf, yb = RP._man_trunk(z)
    cy = (yf + yb) / 2
    return w * BURLY[0] + grow, cy + (yf - cy) * BURLY[1] - grow, cy + (yb - cy) * BURLY[1] + grow


def _belly(p):
    amp, bz, sz, sx = BELLY
    return amp * RB.gauss(p.z - bz, sz) * RB.gauss(p.x, sx)


def bust_push(bm, k=0.92, rx=1.08, zmin=1.08):
    """REAL-2's bust under the cloth (real_body.bust_dome, a little softened)."""
    bust = dict(W["bust"], amp=W["bust"]["amp"] * k, rx=W["bust"]["rx"] * rx)
    for vv in bm.verts:
        p = vv.co
        if p.y >= 0 or p.z < zmin:
            continue
        d, dx = RB.bust_dome(Vector((p.x, p.y, p.z)), bust)
        f = K.clamp01(-p.y / 0.06)
        p.y -= d * f
        p.x += dx * f


def tunic(name, mat, ring, rows_below, grow=0.014, top=1.575, region="shirt", legs=0.85, front_follow=0.55, back=0.60,
          jag=0.010, n=2.4, segs=28, belt_z=1.03, step=0.045, woman=False, belly=False, trunk_w=None):
    """real_townsfolk.tunic on any trunk ring (ring(z, grow) -> (half-width, front y, back y)): the trunk + grow from
    top down to belt_z, then rows_below [(z, half-width, front y, back y)] flaring to the hem. woman: the bust pushed
    out under the cloth; belly: the Barbarian's belly."""
    zs = []
    z = top
    while z > belt_z + 1e-6:
        zs.append(z)
        z -= step
    rings = [(z, ) + ring(z, grow) + (n, n) for z in zs]
    rings += [(r[0], r[1], r[2], r[3], n, n) for r in rows_below]
    rings.sort(key=lambda r: r[0])
    bm = bmesh.new()
    rv, params = RB.loft(bm, rings, segs)
    if woman:
        bust_push(bm)
    if belly:
        for vv in bm.verts:
            if vv.co.y < 0:
                vv.co.y -= _belly(vv.co) * K.clamp01(-vv.co.y / 0.06)
    if jag:
        for k, vv in enumerate(rv[0]):
            vv.co.z += jag * ((k * 5) % 3 - 1)
    RB.param_uvs(bm, params, region, wrap_u=True)
    hem = rings[0][0]
    sk = RB.skirt_w(belt_z, hem, front_follow, legs, back=back)
    tw = trunk_w or (RB._trunk_w() if woman else RB.torso_w)
    return RB.finish(name, bm, mat, lambda co: tw(co) if co.z >= belt_z else sk(co))


def robe_w(top_z, hem_z, front_follow, legs, back, shin):
    """real_body.skirt_w with a shin share: below the knee the leg's share goes over to the lower leg (shin 1: all of
    it 0.15 m under the knee), so a long robe hangs along the shins when seated and never stands out like a board."""
    kz = K.T("upperleg.l").z

    def fn(co):
        h = K.clamp01((top_z - co.z) / (top_z - hem_z))
        sd = K.clamp01(0.5 + co.x / 0.24)
        front = K.clamp01(0.5 - co.y / 0.20)
        wl = legs * h ** front_follow * (back + (1.0 - back) * front)
        k = shin * K.smoothstep(kz + 0.05, kz - 0.15, co.z)
        return {"hips": 1 - wl, "upperleg.l": wl * sd * (1 - k), "upperleg.r": wl * (1 - sd) * (1 - k),
                "lowerleg.l": wl * sd * k, "lowerleg.r": wl * (1 - sd) * k}
    return fn


def split_skirt(name, mat, side, ring, top, hem, gap, region="apron", cols=10, rows=10, legs=0.85, front_follow=0.45,
                back=0.6, jag=0.008, thick=0.007, ripple=0.007, shin=0.0):
    """One half of a skirt split at the front (real_player.build_coat_skirt on any ring(z) and gap(z) = half the
    opening, m): side "l" from the opening round to the back seam. back 0.6 (the dealer's): seated, the back lies over
    the seat instead of hanging through it; legs / front_follow: the front follows the thighs (Running_A)."""
    sx = 1.0 if side == "l" else -1.0
    grid = []
    for j in range(rows + 1):
        z = top + (hem - top) * j / rows
        rg = ring(z)
        g = math.asin(min(0.99, (gap(z) / rg[0]) ** (2.4 / 2.0)))
        row = []
        for i in range(cols + 1):
            th = g + (math.pi - g) * i / cols
            p = RP._contour(rg, th)
            t = j / rows
            rip = ripple * math.sin(th * 6.0 + 0.4 * sx) * t ** 0.8
            cy = (rg[1] + rg[2]) / 2
            rr = math.hypot(p.x, p.y - cy) or 1.0
            x = p.x + p.x / rr * rip
            y = p.y + (p.y - cy) / rr * rip
            z2 = z + (jag * ((i * 5) % 3 - 1) if j == rows else 0.0)
            row.append(Vector((x * sx, y, z2)))
        grid.append(row)
    if sx < 0:
        grid = [list(reversed(r)) for r in grid]
    bm = bmesh.new()
    params = RB.grid_slab(bm, grid, thick, lambda p: Vector((-p.x, -p.y, 0)).normalized())
    RB.param_uvs(bm, params, region)
    if shin:
        return RB.finish(name, bm, mat, robe_w(top, hem, front_follow, legs, back, shin))
    return RB.finish(name, bm, mat, RB.skirt_w(top, hem, front_follow, legs, back=back))


def rows_ring(rows):
    return lambda z: tuple(RB._interp([(r[0], r[i]) for r in rows], z) for i in (1, 2, 3))


def mantle(name, mat, rows, region="bib", n=2.4, segs=28, scallop=0.006, woman=False, arm_from=0.17, arm_k=0.45,
           shag=0.0, trunk_w=None):
    """A short closed shoulder piece round the neck (real_townsfolk.mantle on any rows, either base); shag: a fur's
    jagged lower edge and tufts."""
    bm = bmesh.new()
    rv, params = RB.loft(bm, [(z, w, yf, yb, n, n) for z, w, yf, yb in rows], segs)
    for k, vv in enumerate(rv[-1]):
        vv.co.z += scallop * ((k * 5) % 3 - 1)
        if shag:
            vv.co.z -= shag * (0.5 + 0.5 * math.sin(k * 2.9)) ** 2
    if shag:
        for j, ring in enumerate(rv[1:-1]):
            for k, vv in enumerate(ring):
                c = Vector((0.0, (rows[j + 1][2] + rows[j + 1][3]) / 2, vv.co.z))
                d = Vector((vv.co.x - c.x, vv.co.y - c.y, 0.0))
                if d.length > 1e-5:
                    vv.co += d.normalized() * (shag * 0.35 * math.sin(k * 1.7 + j * 2.3))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    RB.param_uvs(bm, params, region, wrap_u=True)
    tw = trunk_w or (RB._trunk_w() if woman else RB.torso_w)
    zlim = rows[1][0]

    def w(co):
        ww = tw(co)
        if abs(co.x) > arm_from and co.z < zlim:
            s = "l" if co.x > 0 else "r"
            k = arm_k * K.clamp01((abs(co.x) - arm_from) / 0.07)
            ww = {b: x * (1 - k) for b, x in ww.items()}
            ww["upperarm." + s] = ww.get("upperarm." + s, 0.0) + k
        return ww
    return RB.finish(name, bm, mat, w)


def cape(name, mat, rows, hem, open_half, region="apron", cols=16, nrows=9, thick=0.008, jag=0.012, woman=False,
         skirt_top=1.05):
    """real_townsfolk.cape on rows [(z, half-width, front y, back y)] (either base): open at the front by
    open_half(z); the shoulders ride the chest (and the upper arms near them), the rest hangs (hips + thighs)."""
    grid = []
    for j in range(nrows + 1):
        z = rows[0][0] + (hem - rows[0][0]) * j / nrows
        ring = rows_ring(rows)(z)
        g = math.asin(min(0.99, (open_half(z) / ring[0]) ** (2.4 / 2.0)))
        row = []
        for i in range(cols + 1):
            th = g + (2 * math.pi - 2 * g) * i / cols
            p = RP._contour(ring, th)
            q = Vector((p.x, p.y, z))
            t = j / nrows
            q.x += 0.006 * math.sin(th * 7.0) * t
            q.y += 0.006 * math.cos(th * 7.0) * t
            if j == nrows:
                q.z += jag * ((i * 5) % 3 - 1)
            row.append(q)
        grid.append(row)
    bm = bmesh.new()
    params = RB.grid_slab(bm, grid, thick, lambda p: Vector((-p.x, -p.y, 0)).normalized())
    RB.param_uvs(bm, params, region)
    sk = RB.skirt_w(skirt_top, hem, 0.6, 0.55, back=0.20) if hem < skirt_top else None
    tw = RB._trunk_w() if woman else RB.torso_w
    zs = K.H("upperarm.l").z - 0.18

    def w(co):
        if sk is None or co.z >= skirt_top:
            ww = tw(co)
            if co.z > zs and abs(co.x) > 0.15:
                s = "l" if co.x > 0 else "r"
                k = 0.35 * K.clamp01((abs(co.x) - 0.15) / 0.08) * K.clamp01((co.z - zs) / 0.10)
                ww = {b: x * (1 - k) for b, x in ww.items()}
                ww["upperarm." + s] = ww.get("upperarm." + s, 0.0) + k
            return ww
        return sk(co)
    return RB.finish(name, bm, mat, w)


def bare_arm(name, mat, s, P, k=(1.0, 1.0), woman=False, region="forearm"):
    """A bare arm (skin, the forearm region): the base's limb tube (P["upperarm"] / P["forearm"]) with radii x k."""
    S, E, Wr = RB.arm_frame(s)
    du, dl = (E - S), (Wr - E)
    pts, rads = [], []
    for t, ru, rd in P["upperarm"]:
        pts.append(S + du * t)
        rads.append((ru * k[0], rd * k[0]))
    for t, ru, rd in P["forearm"]:
        pts.append(E + dl * t)
        rads.append((ru * k[1], rd * k[1]))
    bm = bmesh.new()
    params, _ = RB.tube(bm, pts, rads, 14, up=RB.up_z, cap0=True, cap1=True)
    RB.param_uvs(bm, params, region, wrap_u=True)
    return RB.finish(name, bm, mat, RB._arm_w(s) if woman else RB.arm_w(s))


def bracer(name, mat, s, r=(0.062, 0.066), span=(0.16, 0.015), region="roll", woman=False, laces=False):
    S, E, Wr = RB.arm_frame(s)
    dl = (Wr - E).normalized()
    pts = [Wr - dl * span[0], Wr - dl * (span[0] + span[1]) / 2, Wr - dl * span[1]]
    bm = bmesh.new()
    params, _ = RB.tube(bm, pts, [r, (r[0] * 0.97, r[1] * 0.97), (r[0] * 0.94, r[1] * 0.94)], 12, up=RB.up_z, cap0=False, cap1=False)
    RB.param_uvs(bm, params, region, wrap_u=True)
    return RB.finish(name, bm, mat, RB._arm_w(s) if woman else RB.arm_w(s))


def dome(bm, c, pole, rx, ry, rz, phi_max, cols=14, rows=5, lames=0.0):
    """A dome's grid (rows from the pole out to phi_max, closed columns): c + pole*cos(phi)*rz + the cross axes *
    sin(phi)*(rx, ry); lames: a step down at each row (plate lames)."""
    a = Vector(pole).normalized()
    e1 = Vector((0, 0, 1)).cross(a)
    if e1.length < 1e-4:
        e1 = Vector((1, 0, 0))
    e1.normalize()
    e2 = a.cross(e1).normalized()
    grid = []
    for j in range(rows + 1):
        ph = max(1e-3, phi_max * j / rows)
        row = []
        for i in range(cols + 1):
            th = 2 * math.pi * i / cols
            p = c + a * math.cos(ph) * rz + (e1 * math.cos(th) * rx + e2 * math.sin(th) * ry) * math.sin(ph)
            p -= a * lames * j
            row.append(p)
        grid.append(row)
    return grid


def shell(name, mat, grid, thick, region, weights, c=None):
    bm = bmesh.new()
    cc = c if c is not None else sum((p for r in grid for p in r), Vector()) / sum(len(r) for r in grid)
    params = RB.grid_slab(bm, grid, thick, lambda p: (cc - p).normalized())
    RB.param_uvs(bm, params, region)
    return RB.finish(name, bm, mat, weights)


def satchel(bm, c, size, flap=True):
    """A leather satchel (a box with a flap) at c (rest)."""
    T.box(bm, c, size)
    if flap:
        T.box(bm, c + Vector((0, -size[1] / 2 - 0.004, size[2] * 0.22)), (size[0] * 1.04, 0.008, size[2] * 0.6))


def strap(bm, pts, w=0.022, t=0.006):
    RB.tube(bm, pts, [(t, w)] * len(pts), 4, up=lambda p, d: Vector((p.x, p.y, 0)).normalized() if Vector((p.x, p.y, 0)).length > 1e-4 else Vector((0, -1, 0)),
            cap0=True, cap1=True)


def _join_bm(dst, src):
    tmp = bpy.data.meshes.new("_j")
    src.to_mesh(tmp)
    src.free()
    dst.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)


def worn(name, mat, build_fn, uv, weights):
    """A worn piece on the body (a satchel, straps): flat UVs on a misc cell (or a region via params)."""
    bm = bmesh.new()
    build_fn(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    RB.flat_uvs(bm, L.misc_uv(uv))
    return RB.finish(name, bm, mat, weights)


# ------------------------------------------------------------------ props (rest frame, aimed from Idle's first frame)

def slot_frame(slot, clip="Idle"):
    """(grip in rest, R): R maps a direction in the posed Idle frame 0 (world) back to the rest frame, so a prop
    built in rest along R @ want points along `want` in Idle (the bone carries it)."""
    arm = C.rig()
    act = bpy.data.actions[clip]
    m = C.fk(arm, C.Curves(act), act.frame_range[0], [slot])[slot]
    rest = arm.data.bones[slot].matrix_local
    Rp = m.to_3x3() @ rest.to_3x3().inverted()
    grip = arm.matrix_world @ arm.data.bones[slot].head_local
    return grip, Rp.inverted()


def _bone_prop(ob, bone):
    return T._bone_prop(ob, bone)


def _prop_obj(name, bm, mats, bone):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = K.new_obj(name, bm, mats[0])
    for m in mats[1:]:
        ob.data.materials.append(m)
    return _bone_prop(ob, bone)


def _place(bm, grip, R, start=0):
    """Verts built in a local frame (x across, y forward, z up as seen in Idle) -> rest."""
    for vv in list(bm.verts)[start:]:
        vv.co = grip + R @ vv.co


def _posed_axes(slot, up, fwd):
    """A hand-held prop's local frame in Idle: z along `up`, y along `fwd` (made orthogonal)."""
    z = Vector(up).normalized()
    y = Vector(fwd) - z * Vector(fwd).dot(z)
    y.normalize()
    x = y.cross(z)
    return Matrix((x, y, z)).transposed()


def _built(bm, fn, uv=None, region=None):
    """Run fn(sub bmesh), give its faces flat misc-cell UVs (uv) or leave them, and merge into bm."""
    sub = bmesh.new()
    params = fn(sub)
    if uv:
        RB.flat_uvs(sub, L.misc_uv(uv))
    elif region:
        RB.param_uvs(sub, params, region)
    _join_bm(bm, sub)


def prop_sword(name, mat):
    """The Fighter's arming sword in his right hand, point down and a little forward (hidden by the game)."""
    grip, R = slot_frame("handslot.r")
    F = _posed_axes("handslot.r", (0.0, 0.30, 0.95), (0.0, -1.0, 0.0))      # local z: up the grip (the pommel up)
    bm = bmesh.new()
    _built(bm, lambda b: RB.tube(b, [Vector((0, 0, -0.06)), Vector((0, 0, 0.10))], [(0.014, 0.014), (0.013, 0.013)], 6,
                                 up=lambda p, d: Vector((1, 0, 0)))[0], uv="laces")
    _built(bm, lambda b: (RB.tube(b, [Vector((-0.10, 0, -0.07)), Vector((0.10, 0, -0.07))], [(0.010, 0.012)] * 2, 6,
                                  up=lambda p, d: Vector((0, 0, 1))), K.ellipsoid(b, Vector((0, 0, 0.12)), 0.022, 0.022, 0.024, 8, 5))[0],
           uv="buckle")
    blade = [Vector((0, 0, -0.08 - 0.82 * t)) for t in (0.0, 0.5, 0.92, 1.0)]
    _built(bm, lambda b: RB.tube(b, blade, [(0.024, 0.005), (0.021, 0.005), (0.012, 0.004), (0.002, 0.002)], 4,
                                 up=lambda p, d: Vector((1, 0, 0)))[0], uv="metal_dark")
    for vv in bm.verts:
        vv.co = grip + R @ (F @ vv.co)
    return _prop_obj(name, bm, [mat], "handslot.r")


def prop_shield(name, mat):
    """The Fighter's round shield on his left forearm (hidden by the game): wood planks, a red star, a steel rim and
    boss (the apron region painted as its face)."""
    grip, R = slot_frame("handslot.l")
    bm = bmesh.new()
    rad, segs = 0.30, 20
    c = Vector((0.07, 0.0, 0.16))                   # Idle: out from the arm, up the forearm
    nrm = Vector((1.0, -0.25, 0.0)).normalized()     # the face looks out and a little forward
    e1 = Vector((0, 0, 1))
    e2 = nrm.cross(e1).normalized()
    e1 = e2.cross(nrm).normalized()
    params = {}
    front, backr = [], []
    ctr_f = bm.verts.new(c + nrm * 0.035)
    ctr_b = bm.verts.new(c - nrm * 0.005)
    params[ctr_f] = (0.5, 0.5)
    params[ctr_b] = (0.5, 0.5)
    for i in range(segs):
        a = 2 * math.pi * i / segs
        q = e1 * math.cos(a) + e2 * math.sin(a)
        f = bm.verts.new(c + q * rad + nrm * 0.012)
        b = bm.verts.new(c + q * rad - nrm * 0.008)
        params[f] = (0.5 + 0.5 * math.cos(a), 0.5 + 0.5 * math.sin(a))
        params[b] = params[f]
        front.append(f)
        backr.append(b)
    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new((ctr_f, front[i], front[j]))
        bm.faces.new((ctr_b, backr[j], backr[i]))
        bm.faces.new((front[i], backr[i], backr[j], front[j]))
    RB.param_uvs(bm, params, "apron")
    _built(bm, lambda b: K.ellipsoid(b, c + nrm * 0.040, 0.055, 0.055, 0.055, 10, 5), uv="metal_dark")   # the boss
    for vv in bm.verts:
        vv.co = grip + R @ vv.co
    return _prop_obj(name, bm, [mat], "handslot.l")


def prop_staff(name, mats, slot="handslot.r", below=0.80, above=0.92, crystal=False):
    """A gnarled walking staff, upright in Idle (the Mage's; the Healer's with a forked top holding the green
    crystal: AH-3, its own emissive material)."""
    grip, R = slot_frame(slot)
    bm = bmesh.new()
    pts, rads = [], []
    n = 9
    for i in range(n + 1):
        t = i / n
        z = -below + (below + above) * t
        wob = Vector((0.012 * math.sin(t * 9.0), 0.010 * math.cos(t * 7.0), 0.0))
        pts.append(Vector((0.0, 0.0, z)) + wob)
        rads.append(0.017 + 0.004 * math.sin(t * 13.0) - 0.003 * t)
    _built(bm, lambda b: RB.tube(b, pts, rads, 6, up=lambda p, d: Vector((1, 0, 0)))[0], uv="metal_dark")
    top = pts[-1]
    if crystal:
        for sx in (1.0, -1.0):                      # the fork's two prongs round the crystal
            prong = [top, top + Vector((0.035 * sx, 0.0, 0.05)), top + Vector((0.040 * sx, 0.005, 0.12)), top + Vector((0.022 * sx, 0.0, 0.18))]
            _built(bm, lambda b, pr=prong: RB.tube(b, pr, [0.012, 0.010, 0.008, 0.004], 5, up=lambda p, d: Vector((0, 1, 0)))[0],
                   uv="metal_dark")
    n_wood = len(bm.faces)
    if crystal:
        cb = bmesh.new()
        c0 = top + Vector((0.0, 0.0, 0.035))
        ring = []
        for i in range(6):
            a = 2 * math.pi * i / 6
            ring.append(cb.verts.new(c0 + Vector((0.032 * math.cos(a), 0.032 * math.sin(a), 0.06))))
        lo = cb.verts.new(c0)
        hi = cb.verts.new(c0 + Vector((0.0, 0.0, 0.17)))
        for i in range(6):
            j = (i + 1) % 6
            cb.faces.new((lo, ring[j], ring[i]))
            cb.faces.new((hi, ring[i], ring[j]))
        RB.flat_uvs(cb, L.misc_uv("skin"))
        tmp = bpy.data.meshes.new("_cr")
        cb.to_mesh(tmp)
        cb.free()
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
        for f in list(bm.faces)[n_wood:]:
            f.material_index = 1
    F = _posed_axes(slot, (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))
    for vv in bm.verts:
        vv.co = grip + R @ (F @ vv.co)
    return _prop_obj(name, bm, mats, slot)


def prop_axe(name, mat):
    """The Barbarian's bearded axe in his right hand, held near the haft's end, the head down by his boot (hidden)."""
    grip, R = slot_frame("handslot.r")
    F = _posed_axes("handslot.r", (0.0, 0.25, 0.97), (0.0, -1.0, 0.0))      # local z: up the haft (the head at -z)
    bm = bmesh.new()
    haft = [Vector((0.0, 0.0, 0.12)), Vector((0.0, 0.0, -0.30)), Vector((0.0, 0.0, -0.70)), Vector((0.0, 0.0, -0.80))]
    _built(bm, lambda b: RB.tube(b, haft, [0.018, 0.020, 0.021, 0.019], 6, up=lambda p, d: Vector((1, 0, 0)))[0], uv="strap_dark")
    # the head: a flat slab, the bearded blade toward his front (local -y), a short poll behind
    hb = bmesh.new()
    prof = [(0.03, -0.60), (0.03, -0.80), (-0.03, -0.80), (-0.18, -0.86), (-0.22, -0.74), (-0.20, -0.58), (-0.10, -0.62), (-0.03, -0.62)]
    up_, dn_ = [], []
    for y, z in prof:
        up_.append(hb.verts.new((0.012, y, z)))
        dn_.append(hb.verts.new((-0.012, y, z)))
    hb.faces.new(up_)
    hb.faces.new(list(reversed(dn_)))
    for i in range(len(prof)):
        j = (i + 1) % len(prof)
        hb.faces.new((up_[i], dn_[i], dn_[j], up_[j]))
    for vv in hb.verts:                            # thin to an edge at the blade
        if vv.co.y < -0.15:
            vv.co.x *= 0.25
    RB.flat_uvs(hb, L.misc_uv("metal_dark"))
    _join_bm(bm, hb)
    for vv in bm.verts:
        vv.co = grip + R @ (F @ vv.co)
    return _prop_obj(name, bm, [mat], "handslot.r")


def prop_bow(name, mat):
    """The Ranger's longbow in her left hand, upright, its belly forward, the string behind (hidden by the game)."""
    grip, R = slot_frame("handslot.l")
    F = _posed_axes("handslot.l", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))
    bm = bmesh.new()
    pts, rads = [], []
    for i in range(13):
        t = -1.0 + 2.0 * i / 12
        z = 0.66 * t
        y = -0.10 * (1 - t * t) + 0.035 * abs(t) ** 3 - 0.02          # the belly forward, recurved tips
        pts.append(Vector((0.0, y, z)))
        rads.append((0.016 if abs(t) < 0.12 else 0.012 - 0.006 * abs(t), 0.010 if abs(t) < 0.12 else 0.007 - 0.003 * abs(t)))
    _built(bm, lambda b: RB.tube(b, pts, rads, 5, up=lambda p, d: Vector((0, 1, 0)))[0], uv="metal_dark")
    _built(bm, lambda b: RB.tube(b, [pts[0], pts[-1]], [0.0025, 0.0025], 3, up=lambda p, d: Vector((1, 0, 0)))[0], uv="laces")
    _built(bm, lambda b: RB.tube(b, [Vector((0, -0.12, -0.07)), Vector((0, -0.12, 0.07))], [0.019, 0.019], 6,
                                 up=lambda p, d: Vector((1, 0, 0)))[0], uv="strap_dark")            # the grip wrap
    for vv in bm.verts:
        vv.co = grip + R @ (F @ vv.co)
    return _prop_obj(name, bm, [mat], "handslot.l")


QUIVER = (Vector((0.115, 0.205, 1.43)), Vector((-0.085, 0.215, 1.07)))       # top (behind her left shoulder), bottom


def prop_quiver(name, mat):
    """The Ranger's quiver, WORN on her back over the cape (visible): a leather tube from behind her left shoulder to
    her right hip, five red-fletched arrows out of its top (a prop on chest)."""
    top, bot = QUIVER
    d = (top - bot).normalized()
    bm = bmesh.new()
    _built(bm, lambda b: RB.tube(b, [bot, bot.lerp(top, 0.5), top], [(0.042, 0.050), (0.044, 0.052), (0.047, 0.054)], 8,
                                 up=lambda p, dd: Vector((0, 1, 0)), cap0=True, cap1=False)[0], uv="knot")
    _built(bm, lambda b: RB.tube(b, [top - d * 0.02, top + d * 0.01], [(0.050, 0.057)] * 2, 8, up=lambda p, dd: Vector((0, 1, 0)))[0],
           uv="strap_dark")
    side = d.cross(Vector((0, 1, 0))).normalized()
    for k in range(5):
        off = side * (0.022 * (k - 2)) + Vector((0, 0.012 * ((k % 2) * 2 - 1), 0))
        a0 = top + off - d * 0.05
        a1 = top + off + d * (0.17 + 0.015 * (k % 3))
        _built(bm, lambda b, a0=a0, a1=a1: RB.tube(b, [a0, a1], [0.004, 0.004], 3, up=lambda p, dd: Vector((0, 1, 0)))[0], uv="laces")
        for sg in (1, -1):                            # the red fletching: two little vanes
            fb = bmesh.new()
            base = a1 - d * 0.09
            n_ = side * sg * 0.018
            vs = [fb.verts.new(base), fb.verts.new(base + d * 0.08), fb.verts.new(base + d * 0.075 + n_), fb.verts.new(base + d * 0.01 + n_)]
            fb.faces.new(vs)
            RB.flat_uvs(fb, L.misc_uv("stitch"))
            _join_bm(bm, fb)
    return _prop_obj(name, bm, [mat], "chest")


def prop_daggers(name, mat):
    """The Rogue's two sheathed daggers, WORN (visible): at her left hip in front, at her right hip behind, hilts up
    (a prop on hips)."""
    bm = bmesh.new()
    for hilt, dv in ((Vector((0.155, -0.075, 1.000)), Vector((0.30, -0.42, -0.86))),
                     (Vector((-0.150, 0.080, 1.000)), Vector((-0.30, 0.40, -0.87)))):
        d = dv.normalized()
        flat = Vector((0.0, -1.0, 0.0)) if hilt.y < 0 else Vector((0.0, 1.0, 0.0))
        flat = (flat - d * flat.dot(d)).normalized()
        up = d.cross(flat).normalized()
        _built(bm, lambda b, h=hilt, d=d, up=up: RB.tube(b, [h + d * 0.01, h + d * 0.16, h + d * 0.27],
                                                        [(0.009, 0.020), (0.008, 0.017), (0.005, 0.006)], 6, up=lambda p, dd, u=up: u)[0], uv="knot")
        _built(bm, lambda b, h=hilt, d=d: RB.tube(b, [h - d * 0.10, h], [0.011, 0.011], 6, up=lambda p, dd: Vector((1, 0, 0)))[0], uv="laces")
        _built(bm, lambda b, h=hilt, d=d, up=up: (RB.tube(b, [h - up * 0.040, h + up * 0.040], [0.007, 0.007], 5, up=lambda p, dd: d),
                                                  K.ellipsoid(b, h - d * 0.11, 0.013, 0.013, 0.013, 6, 4))[0], uv="metal_dark")
    return _prop_obj(name, bm, [mat], "hips")


def crystal_mat(name):
    """AH-3 / V5: the Healer's crystal glows: its own material (never the body's), emissive green on a dark green base,
    roughness 0 (the edge shader leaves it un-inked), no metal."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = False
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.05, 0.30, 0.10, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.0
    bsdf.inputs["Alpha"].default_value = 1.0
    bsdf.inputs["Emission Color"].default_value = (0.20, 1.00, 0.35, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 1.6
    m.diffuse_color = (0.2, 0.9, 0.35, 1.0)
    return m


def build_props(v, body_mat):
    c = cfg(v)
    K.remove([n for n in c["props"] if n in bpy.data.objects])
    out = []
    for name, bone, carried in PROPS[v]:
        if name == "Fighter_Sword":
            out.append(prop_sword(name, body_mat))
        elif name == "Fighter_Shield":
            out.append(prop_shield(name, body_mat))
        elif name == "Mage_Staff":
            out.append(prop_staff(name, [body_mat], below=0.84, above=0.98))
        elif name == "Healer_Staff":
            out.append(prop_staff(name, [body_mat, crystal_mat("RT_Healer_Crystal")], below=0.78, above=0.74, crystal=True))
        elif name == "Barbarian_Axe":
            out.append(prop_axe(name, body_mat))
        elif name == "Ranger_Bow":
            out.append(prop_bow(name, body_mat))
        elif name == "Ranger_Quiver":
            out.append(prop_quiver(name, body_mat))
        elif name == "Rogue_Daggers":
            out.append(prop_daggers(name, body_mat))
    return out


# ------------------------------------------------------------------ the classes

def _materials(c):
    head = K.mat("RT_%s_Head" % c["role"], "C29A7C", c["head_png"])
    body = K.mat("RT_%s_Body" % c["role"], "6A5A4C", c["body_png"])
    for m, name in ((head, "%s_head" % c["id"]), (body, "%s_body" % c["id"])):
        im = next(n for n in m.node_tree.nodes if n.type == "TEX_IMAGE").image
        im.name = name
        im.reload()
    return head, body


def _men_legs(P, body, top, girth=0.90):
    parts = [T.pelvis(P + "Seat", body)]
    for s in ("l", "r"):
        parts += [T.trouser_leg(P + "Leg_" + s, body, s, girth=girth, bottom=min(0.335, top["top"] - 0.025)),
                  RB.build_boot(P + "Boot_" + s, body, s, top)]
    return parts


def _women_legs(P, body, boot):
    parts = [RD.build_pelvis(P + "Seat", body)]
    for s in ("l", "r"):
        parts += [RD.build_leg(P + "Leg_" + s, body, s), RB.build_boot(P + "Boot_" + s, body, s, boot)]
    return parts


def fighter(v, head, body, P):
    parts = head_parts(v, head, P)
    parts.append(hair_shell(P + "Hair", head, v, _low(HAIRLINE), top=1.838, apex=1.858))
    tab = [(1.00, 0.212, -0.140, 0.150), (0.90, 0.228, -0.146, 0.158), (0.80, 0.240, -0.150, 0.164), (0.775, 0.242, -0.150, 0.165)]
    parts += [tunic(P + "Tabard", body, man_ring, tab, grow=0.030, top=1.545, jag=0.008, belt_z=1.06),
              tunic(P + "MailSkirt", body, man_ring, [(0.86, 0.214, -0.132, 0.150), (0.70, 0.226, -0.136, 0.152)], grow=0.022,
                    top=0.905, belt_z=0.90, region="bib", jag=0.004, step=0.01),
              T.roll_ring(P + "MailCollar", body, [(1.49, 0.150, -0.118, 0.110, 2.3), (1.53, 0.112, -0.114, 0.082, 2.2),
                                                   (1.575, 0.090, -0.112, 0.060, 2.1), (1.615, 0.082, -0.108, 0.050, 2.0)], "bib"),
              T.band(P + "Belt", body, lambda z: man_ring(z, 0.034), 1.060, 0.044)]
    for s, sx in (("l", 1), ("r", -1)):
        S = K.H("upperarm." + s)
        parts += [T.sleeve(P + "Sleeve_" + s, body, s, k=1.04),
                  shell(P + "Pauldron_" + s, body, dome(None, S + Vector((0.030 * sx, 0.0, 0.020)), (0.55 * sx, 0.0, 0.84),
                                                          0.105, 0.120, 0.090, math.radians(100), cols=14, rows=5, lames=0.008),
                        0.008, "cloth", _pauldron_w(s), c=S + Vector((0.0, 0.0, 0.0))),
                  bracer(P + "Vambrace_" + s, body, s, r=(0.064, 0.070), span=(0.215, 0.012)),
                  RB.build_hand_real(P + "Hand_" + s, body, s, scale=1.0)]
        kn = K.T("upperleg." + s)
        parts.append(shell(P + "Poleyn_" + s, body, dome(None, kn + Vector((0.004 * sx, -0.050, 0.0)), (0.0, -1.0, 0.12),
                                                           0.072, 0.088, 0.030, math.radians(82), cols=12, rows=3),
                           0.006, "cloth", lambda co, s=s: K.blend("upperleg." + s, "lowerleg." + s, 0.5), c=kn))
    parts += _men_legs(P, body, {"top": 0.27, "cuff": False})
    return parts


def _pauldron_w(s):
    def w(co):
        k = K.clamp01((abs(co.x) - 0.13) / 0.12)
        return {"chest": 1.0 - 0.75 * k, "upperarm." + s: 0.75 * k}
    return w


def rogue(v, head, body, P):
    parts = head_parts(v, head, P)
    low = _low([(0, 1.800), (30, 1.792), (55, 1.770), (75, 1.742), (95, 1.712), (130, 1.690), (180, 1.680)])
    parts.append(hair_shell(P + "Hair", head, v, low, top=1.852, apex=1.874, thick=lambda a: 0.014, mess=0.6, part=-25.0))
    parts.append(ponytail(P + "Ponytail", head, v))
    rows = [(0.94, 0.172, -0.104, 0.130), (0.86, 0.190, -0.118, 0.142), (0.83, 0.193, -0.120, 0.144)]
    parts += [tunic(P + "Tunic", body, woman_ring, rows, grow=0.014, top=1.415, jag=0.012, belt_z=1.00, step=0.03, woman=True,
                    n=2.3, segs=32),
              cowl(P + "Cowl", body, woman=True),
              scarf(P + "Scarf", body),
              T.band(P + "Belt", body, lambda z: woman_ring(z, 0.022), 1.000, 0.032, n=2.3, weights=RB._trunk_w())]
    for s in ("l", "r"):
        parts += [bare_arm(P + "Arm_" + s, body, s, W, woman=True),
                  bracer(P + "Bracer_" + s, body, s, r=(0.040, 0.046), span=(0.15, 0.015), woman=True),
                  RB.build_hand_real(P + "Hand_" + s, body, s, scale=0.84)]
    parts += _women_legs(P, body, {"length": 0.84, "width": 0.86, "height": 0.88, "girth": 0.84, "top": 0.36, "cuff": True})
    return parts


def ponytail(name, mat, v):
    """The Rogue's ponytail: tied at the back of her head, hanging down her back outside the cowl (head material,
    projected from her pick's side and back views)."""
    zt = 1.635
    _, _, yb, _ = head_ring_at(v, zt)
    pts = [Vector((0.0, yb - 0.010, zt)), Vector((0.0, yb + 0.030, zt - 0.010)), Vector((0.0, yb + 0.062, zt - 0.060)),
           Vector((0.0, yb + 0.080, zt - 0.140)), Vector((0.0, yb + 0.086, zt - 0.220)), Vector((0.0, yb + 0.082, zt - 0.290)),
           Vector((0.0, yb + 0.074, zt - 0.330))]
    rads = [(0.026, 0.024), (0.022, 0.022), (0.036, 0.030), (0.042, 0.032), (0.036, 0.028), (0.022, 0.018), (0.006, 0.006)]
    bm = bmesh.new()
    RB.tube(bm, pts, rads, 10, up=lambda p, d: Vector((1, 0, 0)), cap0=True, cap1=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print("%s views" % name, RB.projection_uvs(bm, sheet=cfg(v)["sheet"]))
    zh = K.H("head").z
    return RB.finish(name, bm, mat, lambda co: K.blend("chest", "head", K.clamp01((co.z - (zh + 0.04)) / 0.12)))


def cowl(name, mat, woman=False, rows=None, region="apron", back_bag=True):
    """A hood worn DOWN: a thick roll round the neck and the shoulders' tops, the hood's bag lying on the upper back."""
    rows = rows or ([(1.465, 0.072, -0.084, 0.050), (1.445, 0.125, -0.112, 0.090), (1.415, 0.180, -0.128, 0.126),
                     (1.375, 0.205, -0.138, 0.140), (1.335, 0.208, -0.142, 0.142), (1.300, 0.200, -0.140, 0.140)] if woman else
                    [(1.600, 0.090, -0.104, 0.062), (1.565, 0.150, -0.124, 0.105), (1.525, 0.215, -0.146, 0.140),
                     (1.475, 0.250, -0.158, 0.156), (1.425, 0.258, -0.164, 0.162), (1.380, 0.250, -0.165, 0.160)])
    ob = mantle(name, mat, rows, region=region, n=2.1, woman=woman, scallop=0.008)
    if back_bag:
        bm = bmesh.new()
        z0, w0, f0, b0 = rows[2]
        c = Vector((0.0, b0 + 0.010, z0 - 0.020))
        K.ellipsoid(bm, c, w0 * 0.55, 0.040, 0.085, 12, 6)
        for vv in bm.verts:
            if vv.co.y < c.y:
                vv.co.y = c.y - (c.y - vv.co.y) * 0.3
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        params = {vv: (0.5 + (vv.co.x - c.x) / (2.2 * w0), 0.5 + (vv.co.z - c.z) / 0.2) for vv in bm.verts}
        RB.param_uvs(bm, params, region)
        bag = RB.finish(name + "Bag", bm, mat, lambda co: {"chest": 1.0})
        return [ob, bag]
    return [ob]


def scarf(name, mat):
    """The Rogue's small green scarf (V6: her class accent): a roll at the throat over the cowl's neck, a knot in front
    and two short ends (the straps region, green)."""
    # Stage D 1: over the cowl's neck (the first sat inside it and only its knot showed), the ends to her chest
    ring = T.roll_ring(name, mat, [(1.430, 0.104, -0.128, 0.078, 2.2), (1.452, 0.094, -0.118, 0.064, 2.1),
                                   (1.478, 0.080, -0.106, 0.052, 2.0)], "straps",
                       weights=lambda co: K.blend("chest", "head", 0.15 * K.clamp01((co.z - 1.45) / 0.04)))
    bm = bmesh.new()
    knot = Vector((0.012, -0.136, 1.420))
    K.ellipsoid(bm, knot, 0.024, 0.016, 0.022, 8, 5)
    for dx, ln in ((-0.008, 0.165), (0.024, 0.130)):
        pts = [knot + Vector((dx, -0.004, -0.012)), knot + Vector((dx * 1.4, -0.016, -ln * 0.5)), knot + Vector((dx * 1.8, -0.030, -ln))]
        RB.tube(bm, pts, [(0.005, 0.022), (0.005, 0.021), (0.005, 0.017)], 4, up=lambda p, d: Vector((0, -1, 0)), cap0=True, cap1=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    params = {vv: (0.5 + vv.co.x * 4, (vv.co.z - 1.28) / 0.16) for vv in bm.verts}
    RB.param_uvs(bm, params, "straps")
    ends = RB.finish(name + "Ends", bm, mat, lambda co: {"chest": 1.0})
    return [ring, ends]


def mage(v, head, body, P):
    parts = head_parts(v, head, P)
    hl = [(0, 1.800), (25, 1.796), (45, 1.786), (62, 1.770), (78, 1.752), (100, 1.746), (125, 1.722), (150, 1.692), (180, 1.680)]
    parts.append(hair_shell(P + "Hair", head, v, _low(hl), top=1.830, apex=1.850, mess=1.2))
    parts.append(floppy_hat(P + "Hat", body, v))
    robe_top = [(1.02, 0.206, -0.138, 0.148), (0.96, 0.214, -0.142, 0.154)]
    parts += [tunic(P + "Robe", body, man_ring, robe_top, grow=0.020, top=1.560, jag=0.0, belt_z=1.06),
              mantle(P + "Cowl", body, [(1.600, 0.092, -0.106, 0.064), (1.565, 0.152, -0.126, 0.106), (1.525, 0.214, -0.148, 0.140),
                                        (1.480, 0.244, -0.160, 0.152), (1.430, 0.244, -0.168, 0.156), (1.385, 0.236, -0.170, 0.154)],
                     region="bib", n=2.1, scallop=0.008),
              T.band(P + "Belt", body, lambda z: man_ring(z, 0.030), 1.060, 0.044),
              worn(P + "Satchel", body, _mage_satchel, "knot", lambda co: {"hips": 1.0}),
              worn(P + "SatchelStrap", body, _mage_strap, "strap_dark", _strap_w)]
    for s in ("l", "r"):
        parts += [split_skirt(P + "Skirt_" + s, body, s, rows_ring(MAGE_ROBE), 1.04, 0.205, _mage_gap, **MAGE_SKIRT),
                  T.sleeve(P + "Sleeve_" + s, body, s, k=1.10),
                  bracer(P + "Cuff_" + s, body, s, r=(0.068, 0.072), span=(0.075, 0.0)),
                  RB.build_hand_real(P + "Hand_" + s, body, s, scale=1.0)]
    parts += _men_legs(P, body, {"top": 0.30, "cuff": False})
    return parts


MAGE_ROBE = [(0.205, 0.300, -0.220, 0.215), (0.40, 0.288, -0.212, 0.205), (0.60, 0.274, -0.202, 0.194),
             (0.80, 0.254, -0.186, 0.180), (0.92, 0.234, -0.162, 0.170), (1.04, 0.212, -0.146, 0.152)]
# the robe's halves (clearance check (b), Stage D 1: at legs 0.85 / h^0.40 the thighs poked through 0.046 m walking,
# 0.079 m seated): the front follows the thighs higher up and fully, with more ease in front
MAGE_SKIRT = {"legs": 1.0, "front_follow": 0.22, "back": 0.6, "rows": 12, "shin": 1.0}


def _mage_gap(z):
    return RB._interp([(0.205, 0.060), (0.60, 0.040), (0.95, 0.012), (1.04, 0.004)], z)


def _mage_satchel(bm):
    satchel(bm, Vector((0.200, -0.110, 0.92)), (0.065, 0.135, 0.150))


def _mage_strap(bm):
    strap(bm, [Vector((-0.120, -0.150, 1.47)), Vector((-0.040, -0.172, 1.36)), Vector((0.080, -0.180, 1.20)),
               Vector((0.175, -0.170, 1.05)), Vector((0.200, -0.150, 0.99))])


def _strap_w(co):
    return RB.torso_w(co)


def floppy_hat(name, mat, v):
    """The Mage's wide floppy felt hat (V18: headwear under the 2.25 top): a soft round crown and a broad brim that
    droops at the sides and back, frayed; its front stays higher so his eyes show from the game camera."""
    zb = 1.770
    w, yf, yb, cy = head_ring_at(v, zb + 0.015)
    rx0, ry0 = w + 0.026, (yb - yf) / 2 + 0.026
    n = 24
    parts = []
    b = bmesh.new()
    rings = []
    for dz, k, g, dy in [(0.0, 1.0, 0.0, 0.0), (0.035, 1.04, 0.006, 0.004), (0.085, 1.00, 0.004, 0.010),
                         (0.125, 0.82, 0.0, 0.016), (0.150, 0.46, 0.0, 0.020)]:
        rings.append(T._ring_pts(0.0, cy + dy, rx0 * k + g, ry0 * k + g, zb + dz, n))
    params, vs = T._loft_rings(b, rings, n)
    c = sum((x.co for x in vs[-1]), Vector()) / n + Vector((0, 0.004, 0.008))
    tv = b.verts.new(c)
    params[tv] = (0.5, 1.0)
    for i in range(n):
        b.faces.new((vs[-1][i], vs[-1][(i + 1) % n], tv))
    b.faces.new(list(reversed(vs[0])))
    RB.param_uvs(b, params, "cloth", wrap_u=True)
    grid = []
    rows = 4
    for j in range(rows + 1):
        t = j / rows
        row = []
        for i in range(n + 1):
            th = 2 * math.pi * i / n
            ext = (0.165 + 0.055 * (1 - math.cos(th)) / 2) * t
            p = Vector((rx0 * RB.se(math.sin(th), 2.2), cy - ry0 * RB.se(math.cos(th), 2.2), zb))
            d = Vector((p.x, p.y - cy, 0.0)).normalized()
            q = p + d * ext
            side = abs(math.sin(th))
            q.z += -(0.020 + 0.055 * side + 0.030 * max(0.0, -math.cos(th))) * t * t + 0.022 * t * max(0.0, math.cos(th))
            if j == rows:
                q += d * 0.010 * ((i * 7) % 3 - 1)
                q.z += 0.006 * ((i * 5) % 3 - 1)
            row.append(q)
        grid.append(row)
    bb = bmesh.new()
    pp = RB.grid_slab(bb, grid, 0.009, lambda p: Vector((0, 0, 1)))
    RB.param_uvs(bb, pp, "cloth")
    _join_bm(b, bb)
    bmesh.ops.recalc_face_normals(b, faces=b.faces)
    return RB.finish(name, b, mat, RB.head_w)


def healer(v, head, body, P):
    parts = head_parts(v, head, P)
    low = _low([(0, 1.796), (30, 1.790), (55, 1.766), (75, 1.735), (95, 1.700), (130, 1.660), (180, 1.640)])
    parts.append(hair_shell(P + "Hair", head, v, low, top=1.850, apex=1.870, thick=lambda a: 0.012, mess=0.4, part=0.0))
    parts.append(hood(P + "Hood", head, v))
    # Stage D 1: shorter (to z 1.30): at 1.235 it hid the green cross on her chest (her pick's capelet ends above it)
    capelet = [(1.448, 0.110, -0.098, 0.082), (1.425, 0.160, -0.122, 0.110), (1.395, 0.205, -0.140, 0.132),
               (1.360, 0.232, -0.160, 0.146), (1.325, 0.244, -0.178, 0.152), (1.300, 0.248, -0.188, 0.155)]
    rows = [(0.96, 0.170, -0.112, 0.128)]
    parts += [tunic(P + "Robe", body, woman_ring, rows, grow=0.018, top=1.420, jag=0.0, belt_z=0.98, step=0.03, woman=True,
                    n=2.3, segs=32),
              mantle(P + "Capelet", body, capelet, region="bib", n=2.2, scallop=0.006, woman=True, arm_from=0.16, arm_k=0.5),
              T.band(P + "Belt", body, lambda z: woman_ring(z, 0.028), 0.990, 0.032, n=2.3, weights=RB._trunk_w()),
              worn(P + "Satchel", body, _healer_satchel, "knot", lambda co: {"hips": 1.0})]
    for s in ("l", "r"):
        parts += [split_skirt(P + "Skirt_" + s, body, s, rows_ring(HEALER_ROBE), 0.98, 0.410, _healer_gap, **HEALER_SKIRT),
                  bell_sleeve(P + "Sleeve_" + s, body, s),
                  RB.build_hand_real(P + "Hand_" + s, body, s, scale=0.84)]
    parts += _women_legs(P, body, {"length": 0.84, "width": 0.86, "height": 0.88, "girth": 0.84, "top": 0.37, "cuff": True})
    return parts


HEALER_ROBE = [(0.410, 0.262, -0.192, 0.196), (0.55, 0.248, -0.184, 0.186), (0.70, 0.232, -0.170, 0.174),
               (0.84, 0.210, -0.148, 0.158), (0.92, 0.192, -0.130, 0.146), (0.98, 0.172, -0.114, 0.130)]
HEALER_SKIRT = {"legs": 1.0, "front_follow": 0.22, "back": 0.6, "rows": 10, "shin": 1.0}     # the Mage's lesson


def _healer_gap(z):
    return RB._interp([(0.410, 0.045), (0.60, 0.030), (0.90, 0.010), (0.98, 0.004)], z)


def _healer_satchel(bm):
    satchel(bm, Vector((-0.205, -0.075, 0.905)), (0.060, 0.120, 0.135))


def bell_sleeve(name, mat, s):
    """The Healer's wide sleeve, flaring to the wrist (a gold-trimmed cuff: the roll region at its end)."""
    S, E, Wr = RB.arm_frame(s)
    du, dl = (E - S).normalized(), (Wr - E).normalized()
    pts = [S - du * 0.065, S - du * 0.012, S + du * 0.060, S + du * 0.140, E - du * 0.018, E + dl * 0.036, E + dl * 0.120,
           Wr - dl * 0.060, Wr - dl * 0.030, Wr + dl * 0.012]
    rads = [(0.062, 0.068), (0.064, 0.070), (0.058, 0.062), (0.054, 0.057), (0.052, 0.054), (0.054, 0.056), (0.060, 0.062),
            (0.068, 0.070), (0.072, 0.074), (0.074, 0.076)]
    bm = bmesh.new()
    params, _ = RB.tube(bm, pts, rads, 12, up=RB.up_z, cap0=True, cap1=False)
    RB.param_uvs(bm, params, "sleeve", wrap_u=True)
    return RB.finish(name, bm, mat, RB._arm_w(s))


def hood(name, mat, v):
    """The Healer's hood, UP (head material, projected from her pick: its gold-trimmed edge and folds are the drawing's):
    a shell round her head, open over the face, closing under the chin and lying on the neck and shoulders' tops; a
    soft point at the back of the crown."""
    zh = K.H("head").z
    # Stage D 1: roomier (grow 0.042), its crown closed at a soft point behind the top (the first had an open ring there)
    zs = [1.796, 1.785, 1.768, 1.745, 1.715, 1.680, 1.640, 1.600, 1.560, 1.520, 1.485, 1.455]
    top_z = 1.800
    cols = 26
    grid = []
    for z in zs:
        if z > 1.690:
            w, yf, yb, cy = head_ring_at(v, 1.690)
            t = (z - 1.690) / (top_z - 1.690)
            k = max(0.04, (1 - t * t) ** 0.5)
            w, yf, yb = w * k, cy + (yf - cy) * k + 0.030 * t, cy + (yb - cy) * k + 0.040 * t
        elif z >= 1.53:
            w, yf, yb, cy = head_ring_at(v, z)
        else:
            w0, yf0, yb0, cy0 = head_ring_at(v, 1.53)
            t = (1.53 - z) / (1.53 - 1.455)
            w, yf, yb = w0 + (0.150 - w0) * t, yf0 + (-0.112 - yf0) * t, yb0 + (0.110 - yb0) * t
        g = 0.042 * min(1.0, (top_z - z) / 0.03) if z > 1.53 else 0.042 + 0.010 * (1.53 - z) / 0.08
        op = math.radians(RB._interp([(1.455, 0.0), (1.485, 26.0), (1.520, 52.0), (1.560, 62.0), (1.600, 64.0), (1.640, 62.0),
                                      (1.680, 50.0), (1.715, 28.0), (1.745, 0.0), (1.80, 0.0)], z))
        row = []
        for i in range(cols + 1):
            th = op + (2 * math.pi - 2 * op) * i / cols
            p = RP._contour((w, yf, yb), th, n=2.1, grow=g)
            row.append(Vector((p.x, p.y, z)))
        grid.append(row)
    c0 = sum(grid[0], Vector()) / len(grid[0])
    grid[0] = [c0 + (p - c0) * 0.08 for p in grid[0]]          # the crown's point: the first ring pulled shut
    bm = bmesh.new()
    cen = Vector((0.0, K.H("head").y + 0.01, 1.60))
    RB.grid_slab(bm, grid, 0.008, lambda p: Vector((cen.x - p.x, cen.y - p.y, 0)).normalized())
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print("%s views" % name, RB.projection_uvs(bm, sheet=cfg(v)["sheet"]))
    return RB.finish(name, bm, mat, lambda co: K.blend("chest", "head", K.clamp01((co.z - (zh + 0.02)) / 0.10)))


def barbarian(v, head, body, P):
    parts = head_parts(v, head, P)
    hl = [(0, 1.814), (25, 1.810), (45, 1.795), (62, 1.776), (78, 1.740), (100, 1.700), (125, 1.680), (150, 1.660), (180, 1.650)]
    parts += [hair_shell(P + "Hair", head, v, _low(hl), top=1.840, apex=1.866, mess=1.2),
              hair_fall(P + "HairFall", head, v), beard(P + "Beard", head, v), beard_fall(P + "BeardFall", head, v)]
    rows = [(1.00, 0.222, -0.170, 0.160), (0.88, 0.240, -0.168, 0.172), (0.76, 0.252, -0.170, 0.180), (0.725, 0.254, -0.170, 0.181)]
    parts += [tunic(P + "Jerkin", body, burly_ring, rows, grow=0.014, top=1.545, jag=0.018, belt_z=1.06, belly=True),
              # Stage D 1: longer, to z 1.26 (his pick's fur covers the shoulders and the upper back)
              mantle(P + "Fur", body, [(1.600, 0.118, -0.122, 0.090), (1.575, 0.180, -0.150, 0.130), (1.535, 0.262, -0.176, 0.170),
                                       (1.480, 0.300, -0.190, 0.190), (1.420, 0.308, -0.198, 0.200), (1.360, 0.304, -0.200, 0.204),
                                       (1.300, 0.296, -0.200, 0.204), (1.260, 0.290, -0.198, 0.202)],
                     region="bib", n=2.1, scallop=0.014, shag=0.030, arm_from=0.18, arm_k=0.55),
              worn(P + "Straps", body, _barb_straps, "strap_dark", RB.torso_w),
              T.band(P + "Belt", body, lambda z: burly_ring(z, 0.034 + _belly(Vector((0, -0.2, z)))), 1.060, 0.060)]
    for s in ("l", "r"):
        parts += [bare_arm(P + "Arm_" + s, body, s, RC.MAN, k=(1.32, 1.22)),
                  bracer(P + "Bracer_" + s, body, s, r=(0.058, 0.064), span=(0.17, 0.02)),
                  RB.build_hand_real(P + "Hand_" + s, body, s, scale=1.08)]
    parts += _men_legs(P, body, {"top": 0.40, "cuff": True, "girth": 1.04}, girth=0.98)
    return parts


def _barb_straps(bm):
    for sx in (1, -1):
        pts = []
        for t in (0.0, 0.25, 0.5, 0.75, 1.0):
            z = 1.48 - 0.36 * t
            x = sx * (0.16 - 0.30 * t)
            w, yf, yb = burly_ring(z, 0.022)
            pts.append(Vector((x, RP._contour((w, yf, yb), math.asin(max(-0.99, min(0.99, x / w)))).y - 0.006, z)))
        strap(bm, pts, w=0.026, t=0.007)


def hair_fall(name, mat, v):
    """The Barbarian's long hair behind his ears and down his back to under the fur (head material, projected)."""
    zh = K.H("head").z
    cols, nrows = 16, 8
    top, tip = 1.740, 1.380
    grid = []
    for j in range(nrows + 1):
        t = j / nrows
        z = top + (tip - top) * t
        row = []
        for i in range(cols + 1):
            u = i / cols
            th = math.radians(84.0 + (360.0 - 168.0) * u)
            if z >= 1.62:
                w, yf, yb, cy = head_ring_at(v, z)
                ring, grow = (w, yf, yb), 0.020 + 0.012 * t
            else:
                w0, yf0, yb0, cy0 = head_ring_at(v, 1.62)
                k = K.clamp01((1.62 - z) / 0.20)
                ring = (w0 + (0.190 - w0) * k, yf0 + (-0.080 - yf0) * k, yb0 + (0.222 - yb0) * k)   # over the fur
                grow = 0.030
            p = RP._contour(ring, th, n=2.2, grow=grow)
            p.y += 0.006 * math.sin(i * 1.9) * t
            zz = z + (0.014 * ((i * 7) % 3 - 1) if j == nrows else 0.0)
            row.append(Vector((p.x * (1 + 0.06 * t), p.y, zz)))
        grid.append(row)
    bm = bmesh.new()
    hy = K.H("head").y
    RB.grid_slab(bm, grid, 0.012, lambda p: Vector((-p.x, -(p.y - hy), 0)).normalized())
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print("%s views" % name, RB.projection_uvs(bm, sheet=cfg(v)["sheet"]))
    return RB.finish(name, bm, mat, lambda co: K.blend("chest", "head", K.clamp01((co.z - (zh + 0.02)) / 0.12)))


def beard(name, mat, v, cols=40, rows=9):
    """The Bartender's full beard (real_body.beard_point) on the Barbarian's head (shaped), projected from his pick."""
    bm = bmesh.new()
    ths = [RB.head_theta(k, cols) for k in range(cols)]
    grid = []
    for j in range(rows):
        s = j / (rows - 1)
        row = []
        for k, th in enumerate(ths):
            zt, zb = RB.beard_top(th), RB.beard_bot(th, k) - 0.02
            row.append(bm.verts.new(RB.beard_point(th, zt + (zb - zt) * (s ** 0.9), s)))
        grid.append(row)
    for a, b in zip(grid[:-1], grid[1:]):
        for k in range(cols):
            bm.faces.new((a[k], b[k], b[(k + 1) % cols], a[(k + 1) % cols]))
    cz = sum(x.co.z for x in grid[-1]) / cols
    tip = bm.verts.new((0.0, RB.BEARD_YC - 0.03, cz - 0.004))
    for k in range(cols):
        bm.faces.new((tip, grid[-1][(k + 1) % cols], grid[-1][k]))
    RB._reshape(bm, shape_of(v))
    for vv in bm.verts:                 # a broader beard than the Bartender's
        vv.co.x *= 1.06
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    f0 = max(bm.faces, key=lambda f: -f.calc_center_median().y)
    if f0.normal.y > 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    print("%s views" % name, RB.projection_uvs(bm, sheet=cfg(v)["sheet"]))
    return RB.finish(name, bm, mat, RB.head_w)


def beard_fall(name, mat, v):
    """The long beard hanging from under his chin over his chest (outside the jerkin and the fur's front), tapering
    to a braided tip with a ring (head material, projected)."""
    zh = K.H("head").z
    zs = [1.585, 1.540, 1.490, 1.440, 1.390, 1.340, 1.290, 1.250, 1.215]
    hw = [0.094, 0.098, 0.094, 0.086, 0.074, 0.060, 0.044, 0.030, 0.018]
    cols = 10
    grid = []
    for z, w in zip(zs, hw):
        # Stage D 1: in front of the fur's front (y ~-0.20 plus its shag), where the first hung hidden
        if z > 1.52:
            yfr = -0.172 - 0.064 * (1.585 - z) / 0.065
        else:
            ww, yf, yb = burly_ring(z, 0.030 + 0.012)
            yfr = min(-0.238, yf - 0.012 - _belly(Vector((0, -0.2, z))))
        row = []
        for i in range(cols + 1):
            x = -w + 2 * w * i / cols
            y = yfr + 0.030 * (x / max(w, 1e-3)) ** 2
            row.append(Vector((x, y, z)))
        grid.append(row)
    bm = bmesh.new()
    RB.grid_slab(bm, grid, 0.028, lambda p: Vector((0, 1, 0)))
    for k in range(3):                   # the braid's knots and the ring
        K.ellipsoid(bm, Vector((0.0, zs[-1] * 0 + grid[-1][cols // 2].y + 0.012, 1.200 - 0.030 * k)), 0.016, 0.014, 0.018, 8, 5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print("%s views" % name, RB.projection_uvs(bm, sheet=cfg(v)["sheet"]))
    return RB.finish(name, bm, mat, lambda co: K.blend("chest", "head", K.clamp01((co.z - (zh + 0.05)) / 0.10)))


def ranger(v, head, body, P):
    parts = head_parts(v, head, P)
    # Stage D 1: the hair frames her face down to the jaw (her pick), parted at the centre (the first read as a cap)
    low = _low([(0, 1.796), (22, 1.786), (40, 1.770), (50, 1.752), (62, 1.712), (75, 1.668), (92, 1.650), (130, 1.655),
                (180, 1.660)])
    parts += [hair_shell(P + "Hair", body, v, low, top=1.852, apex=1.874,
                         thick=lambda a: RB._interp([(0, 0.013), (50, 0.016), (80, 0.020), (180, 0.016)], a), mess=0.9,
                         part=0.0, region="cloth"),
              braid(P + "Braid", body, v)]
    rows = [(0.96, 0.172, -0.106, 0.130), (0.88, 0.188, -0.116, 0.140), (0.84, 0.192, -0.118, 0.142)]
    parts += [tunic(P + "Jerkin", body, woman_ring, rows, grow=0.016, top=1.425, jag=0.006, belt_z=1.00, step=0.03, woman=True,
                    n=2.3, segs=32)]
    # Stage D 1: the hood-down cowl a roll on the shoulders (to z 1.385; the first reached 1.30 and read as a brown bib)
    # and the short cape behind the shoulders, its front edges wide apart (her green jerkin shows, as in her pick)
    parts += cowl(P + "Cowl", body, woman=True, region="bib",
                  rows=[(1.465, 0.075, -0.086, 0.052), (1.445, 0.128, -0.112, 0.092), (1.415, 0.180, -0.126, 0.128),
                        (1.385, 0.200, -0.132, 0.140)])
    parts += [cape(P + "Cape", body, [(1.445, 0.118, -0.090, 0.090), (1.405, 0.200, -0.122, 0.132), (1.340, 0.236, -0.138, 0.150),
                                      (1.250, 0.244, -0.146, 0.162), (1.150, 0.238, -0.146, 0.166), (1.020, 0.242, -0.150, 0.172)],
                   1.020, lambda z: RB._interp([(1.445, 0.100), (1.30, 0.175), (1.02, 0.200)], z), region="apron", woman=True,
                   skirt_top=1.10, nrows=8),
              T.band(P + "Belt", body, lambda z: woman_ring(z, 0.026), 1.000, 0.032, n=2.3, weights=RB._trunk_w()),
              worn(P + "Pouches", body, _ranger_pouches, "strap_dark", lambda co: {"hips": 1.0})]
    for s in ("l", "r"):
        parts += [T.sleeve(P + "Sleeve_" + s, body, s, k=1.0, woman=True),
                  bracer(P + "Bracer_" + s, body, s, r=(0.046, 0.050), span=(0.16, 0.02), woman=True),
                  RB.build_hand_real(P + "Hand_" + s, body, s, scale=0.84)]
    parts += _women_legs(P, body, {"length": 0.84, "width": 0.86, "height": 0.88, "girth": 0.84, "top": 0.37, "cuff": True})
    return parts


def _ranger_pouches(bm):
    for x in (0.135, -0.135):
        w, yf, yb = woman_ring(1.00, 0.03)
        y = RP._contour((w, yf, yb), math.asin(min(0.99, abs(x) / w)), n=2.3).y
        T.box(bm, Vector((x, y - 0.012, 0.955)), (0.070, 0.034, 0.075))
        T.box(bm, Vector((x, y - 0.031, 0.985)), (0.074, 0.006, 0.030))


def braid(name, mat, v):
    """The Ranger's braid: from behind her left ear round the neck, over her left shoulder and down her front (body
    atlas hair; lobes alternate like plaits); a tie at its end."""
    ctrl = [Vector((0.040, 0.045, 1.600)), Vector((0.085, 0.020, 1.530)), Vector((0.118, -0.050, 1.465)),
            Vector((0.110, -0.125, 1.405)), Vector((0.098, -0.168, 1.330)), Vector((0.094, -0.185, 1.270)),
            Vector((0.092, -0.188, 1.235))]
    pts = K.catmull(ctrl, 22)
    rads = []
    for i, p in enumerate(pts):
        t = i / (len(pts) - 1)
        r = 0.017 - 0.006 * t                         # Stage D 1: a slimmer plait (0.026 read as a scarf)
        lobe = 1.0 + 0.18 * math.sin(i * math.pi * 0.9)
        rads.append((r * lobe, r * (2.0 - lobe) * 0.9))
    bm = bmesh.new()
    params, _ = RB.tube(bm, pts, rads, 8, up=lambda p, d: Vector((0, -1, 0)), cap0=True, cap1=True)
    RB.param_uvs(bm, params, "cloth", wrap_u=True)
    K.ellipsoid(bm, pts[-1] + Vector((0, 0, -0.012)), 0.012, 0.012, 0.016, 6, 4)
    for vv in bm.verts:
        if vv not in params:
            params[vv] = (0.5, 0.0)
    RB.param_uvs(bm, params, "cloth", wrap_u=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    zh = K.H("head").z
    return RB.finish(name, bm, mat, lambda co: K.blend("chest", "head", K.clamp01((co.z - (zh + 0.10)) / 0.08)))


RECIPES = {"fighter": fighter, "rogue": rogue, "mage": mage, "healer": healer, "barbarian": barbarian, "ranger": ranger}


def _flatten(parts):
    out = []
    for p in parts:
        out += p if isinstance(p, list) else [p]
    return out


def build(v, props_only=False):
    c = cfg(v)
    assert C.is_open(c["blend"]), "open_base_as(%r) first (%r)" % (v, bpy.data.filepath)
    RT.rest_pose()
    K.setup()
    if props_only:
        body_mat = bpy.data.materials["RT_%s_Body" % c["role"]]
        props = build_props(v, body_mat)
        ok, stats = MG.check(bpy.data.objects[c["body"]], props=props, tri_budget=TRI_BUDGET)
        return ok, stats
    K.remove(["Base_Body"])
    m = bpy.data.materials.get("AN_BaseSkin")
    if m and m.users == 0:
        bpy.data.materials.remove(m)
    P = "RT_"
    old = [o.name for o in bpy.data.objects if o.type == "MESH" and (o.name.startswith(P) or o.name.startswith(c["role"] + "_"))]
    K.remove(old)
    head, body = _materials(c)
    parts = _flatten(RECIPES[v](v, head, body, P))
    counts = {p.name: sum(len(f.vertices) - 2 for f in p.data.polygons) for p in parts}
    out = MG.join(c["body"], parts)
    C.drop_cached_clouds()
    props = build_props(v, body)
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

# (hand in the chest's frame, chest stoop deg): the hands by the clothes (the townsfolk's Stage D lesson: close in)
IDLE = {"fighter": ((0.315, -0.030, 0.880), 0.0), "rogue": ((0.250, -0.030, 0.800), 0.0),
        "mage": ((0.315, -0.040, 0.880), 0.0), "healer": ((0.265, -0.040, 0.800), 0.0),
        "barbarian": ((0.360, -0.030, 0.880), 0.0), "ranger": ((0.258, -0.030, 0.800), 0.0)}
IDLE_POLE = T.IDLE_POLE
WALK_STRIDE = {"fighter": 0.66, "rogue": 0.70, "mage": 0.58, "healer": 0.60, "barbarian": 0.64, "ranger": 0.70}
JOG_STRIDE = {"fighter": 0.48, "rogue": 0.50, "mage": 0.40, "healer": 0.40, "barbarian": 0.46, "ranger": 0.50}
ARMS_MAX = {"barbarian": 10.0}


def _c():
    for v in IDS:
        if C.is_open(cfg(v)["blend"]):
            return cfg(v)
    raise AssertionError("not a class file: %r" % bpy.data.filepath)


def build_clips(v):
    """real_townsfolk.build_clips with the class's own numbers (every rewritten clip from its recorded SRC_* copy)."""
    c = cfg(v)
    assert C.is_open(c["blend"])
    keep = (dict(T.IDLE), dict(T.WALK_STRIDE), dict(T.JOG_STRIDE))
    T.IDLE[v], T.WALK_STRIDE[v], T.JOG_STRIDE[v] = IDLE[v], WALK_STRIDE[v], JOG_STRIDE[v]
    try:
        T._ensure_run_src()
        RBT._SOLES["pts"] = C.sole_points(C.rig(), [bpy.data.objects[c["body"]]])
        src = bpy.data.actions[T.SRC_RUN]
        run_s = (src.frame_range[1] - src.frame_range[0]) / AN.FPS
        out = AN.build_clips([("Idle", AN.IDLE_S, T.pose_idle_of(v), True), ("Walking_A", AN.WALKING_A_S, T.pose_walk_of(v), True),
                              ("Running_A", run_s, T.pose_jog_of(v), True)])
        for n in ("Idle", "Walking_A", "Running_A"):
            bpy.data.actions[n].use_fake_user = True
        for clip in T.ARMS_OUT:
            if clip != "Running_A":
                a = bpy.data.actions[clip]
                srca = bpy.data.actions[T.SRC_OF[clip]]
                a.fcurves.clear()
                for fc in srca.fcurves:
                    n = a.fcurves.new(fc.data_path, index=fc.array_index, action_group=fc.group.name if fc.group else "")
                    n.keyframe_points.add(len(fc.keyframe_points))
                    for k, kp in zip(n.keyframe_points, fc.keyframe_points):
                        k.co, k.interpolation = kp.co, kp.interpolation
                        k.handle_left, k.handle_right = kp.handle_left, kp.handle_right
                    n.update()
            out.append((clip + " arms out", RP.arms_out(clip, body_name=c["body"], gap=0.02, max_deg=ARMS_MAX.get(v, 6.0))))
    finally:
        T.IDLE.clear()
        T.IDLE.update(keep[0])
        T.WALK_STRIDE.clear()
        T.WALK_STRIDE.update(keep[1])
        T.JOG_STRIDE.clear()
        T.JOG_STRIDE.update(keep[2])
    print("clips", out)
    return out


def _region_verts(body, regions):
    return T._region_verts(body, regions)


def measure(v):
    """Ground speeds (Walking_A, Running_A), tops, the seat (V13: the body's own seat vertices in Sit_Chair_Idle vs
    the 0.45 chair), the seated front and half-width."""
    import anime_clearcheck as CC
    c = cfg(v)
    body = bpy.data.objects[c["body"]]
    nums = {}
    for clip in ("Walking_A", "Running_A"):
        nums[clip] = round(CC.ground_speed(clip, {"body": c["body"], "props": c["props"]}), 3)
    CC._rest()
    arm = C.rig()
    nums["top_rest"] = round(max((body.matrix_world @ vv.co).z for vv in body.data.vertices), 3)
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
            idx = _region_verts(body, ("seat", "trousers"))
            sb = [co[i] for i in idx if (Vector((co[i].x, co[i].y)) - Vector((hips.x, hips.y))).length < 0.20 and co[i].z < hips.z]
            nums["seat_low"] = round(min(p.z for p in sb), 4) if sb else None
            nums["sit_hips_y"] = round(hips.z, 4)
            nums["sit_front"] = round(-min(p.y for p in co), 3)
    arm.animation_data.action = None
    RT.rest_pose()
    print(v, nums)
    return nums


def robe_check(v, clips=("Idle", "Walking_A", "Running_A", "Sit_Chair_Down", "Sit_Chair_Idle", "Sit_Chair_StandUp")):
    """Clearance check (b) on the robed classes (Mage, Healer: AC 8, robes survive Running_A and the sits): anime_
    clearcheck's thighs-vs-skirt ray test with route RL's selections (the body atlas REGIONS instead of route AN's
    palette cells: legs = the trousers' region, the skirt = the robe halves' region "apron"); proved on a bad pose
    first."""
    import anime_clearcheck as CC
    c = cfg(v)
    body = bpy.data.objects[c["body"]]
    regions = {"legs": ("trousers",), "skirt": ("apron",)}
    keep, keep_z = CC.verts_of, K.Z
    CC.verts_of = lambda key, cfg_=None: set(_region_verts(body, regions[key]))
    K.Z = lambda z: z                  # the bands are route RL's own heights (K.Z maps route AN's test heights)
    try:
        ck = {"keys": {"legs": "legs", "skirt": "skirt"}, "thigh_band": (0.62, 0.84), "thigh_pad": 0.0,
              "skirt_below": 0.90, "thigh_clips": list(clips), "hair_clips": [], "cuff_clips": []}
        conf = {"body": c["body"], "props": c["props"], "check": ck, "role": v}
        proof = CC.proof_self_clips(conf)          # raises when a check reports 0 on the bad pose (or none ran)
        if "thighs_vs_skirt" not in proof:
            raise RuntimeError("robe_check(%s): check (b) did not run (no covered thighs selected): its report proves nothing" % v)
        rep = CC.self_clips(conf)
    finally:
        CC.verts_of, K.Z = keep, keep_z
    print("robe check", v, "proof", proof, "report", rep)
    return proof, rep


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
    for src in list(RBT.SRC.values()) + [T.SRC_RUN] + list(T.SRC_OF.values()):
        if src in bpy.data.actions:
            bpy.data.actions.remove(bpy.data.actions[src])
    if os.path.exists(c["glb"]):
        print("re-exporting (a new asset of this story):", c["glb"])
    bpy.ops.export_scene.gltf(filepath=c["glb"], use_selection=True, export_apply=False, export_skins=True,
                              export_animations=True, export_yup=True)
    print("exported", c["glb"], os.path.getsize(c["glb"]))
    bpy.ops.wm.revert_mainfile()
    return c["glb"]
