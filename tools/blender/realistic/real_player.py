# real_player.py - the player on route RL (Story 25.31 S1, AC 5, catalogue G1): one man for the demo (AH-1), a
# weathered retired adventurer from Raphael's pick (eternal_guild_art/picked/C_G1_player.png): short messy dark hair
# greying at the temple, a short grey-shot beard, a long worn brown coat worn open (wide collar, lapels, turned cuffs,
# a back vent), a dark leather vest over a grey laced shirt, a belt, worn dark trousers with patched knees, cuffed
# boots, and a sheathed sword at his left hip (R-9: nothing in his hands; the worn sword is a prop on `hips`).
# One call per step (README's runner):
#   open_base_as_player()  realistic_base.blend (REAL-1) saved as g1_player_real.blend (a file load: own call)
#   build()                his parts on the REAL-1 rig, joined into Player_Body (2 surfaces: the head projection + the
#                          body atlas) + the Player_Sword prop on hips; the merge report
#   paint_head()           the painted head pass (real_bake: the views blended by the normal, no seam)
#   build_clips()          Idle (straightened, his arms by his coat) and Running_A (his arms kept outside the coat)
#   rate()                 Running_A's ground speed on his body: player.json's run_ground_speed (V9)
#   export()               Rig + body + prop to assets/characters/custom/g1_player_real.glb
# The head is the Bartender's analytic head (real_body.build_head) narrowed (x 0.88) and lowered 0.02 m under the hair,
# projected from HIS sheet (real_layout.PLAYER, side view flipped: it shows his right side); the hair is a shell over it
# projected the same way, so the drawing's hair, brows, scar and beard are the pick's own.
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

ART = C.ART
CFG = {
    "role": "player",
    "blend": C.BLEND + "g1_player_real.blend",
    "head_png": ART + "textures/realistic/g1_player_real_head.png",              # the projection's source crops
    "head_paint_png": ART + "textures/realistic/g1_player_real_headpaint.png",       # the painted pass (shipped)
    "body_png": ART + "textures/realistic/g1_player_real_body.png",
    "glb": "F:/GAME I AM MAKING/shiningsun/assets/characters/custom/g1_player_real.glb",
    "body": "Player_Body",
    "props": ["Player_Sword"],
}
SHEET = L.PLAYER
TRI_BUDGET = 10000
HEAD_X, HEAD_DZ = 0.88, -0.020     # the Bartender's head narrowed and lowered (his eyes 1.710, the hair's top 1.86)


def head_shape(p):
    return Vector((p.x * HEAD_X, p.y, p.z + HEAD_DZ))


def open_base_as_player(overwrite_ok=False):
    return RC.open_base_as(CFG["blend"], overwrite_ok=overwrite_ok)


def _materials():
    head = K.mat("RT_Player_Head", "BE9078", CFG["head_png"])
    body = K.mat("RT_Player_Body", "58463A", CFG["body_png"])
    for m, name in ((head, "player_head"), (body, "player_body")):
        im = next(n for n in m.node_tree.nodes if n.type == "TEX_IMAGE").image
        im.name = name
        im.reload()
    return head, body


# ------------------------------------------------------------------ the hair: a shell over the (unshaped) head

def _hair_low(th):
    """The hair's lower edge (unshaped head z) at column angle th: the hairline, the temples, over the ears, the nape."""
    a = abs(math.degrees(th))
    return RB._interp([(0, 1.812), (25, 1.808), (45, 1.795), (62, 1.776), (78, 1.762), (100, 1.758), (125, 1.735),
                       (150, 1.700), (180, 1.688)], a)


def _hair_t(th):
    a = abs(math.degrees(th))
    return RB._interp([(0, 0.020), (40, 0.018), (70, 0.012), (100, 0.012), (140, 0.018), (180, 0.020)], a)


def build_hair(name, mat, cols=34, rows=8):
    bm = bmesh.new()
    ths = [RB.head_theta(k, cols) for k in range(cols)]
    grid = []
    for j in range(rows + 1):
        s = j / rows                                           # 0 at the lower edge, 1 near the crown
        row = []
        for k, th in enumerate(ths):
            zb = _hair_low(th)
            z = zb + (1.852 - zb) * s ** 0.85
            p = RB.head_point(th, z)
            c = Vector((0.0, (RB.head_ring(z)[1] + RB.head_ring(z)[2]) / 2.0, z))
            d = Vector((p.x - c.x, p.y - c.y, 0.0))
            d = d.normalized() if d.length > 1e-6 else Vector((0, 1, 0))
            up = Vector((0, 0, 1)) * K.smoothstep(0.55, 1.0, s)
            n = (d * (1.0 - 0.6 * K.smoothstep(0.55, 1.0, s)) + up).normalized()
            t = _hair_t(th) * (0.25 + 0.75 * K.smoothstep(0.0, 0.35, s)) + 0.004 * K.smoothstep(0.6, 1.0, s)
            # messy: tufts along the top and the sides (a few mm in and out, more toward the crown)
            t += (0.003 + 0.005 * s * (1.0 - s)) * math.sin(k * 2.7 + j * 1.3) * (0.5 + 0.5 * math.sin(k * 0.9))
            row.append(bm.verts.new(p + n * t))
        grid.append(row)
    for a, b in zip(grid[:-1], grid[1:]):
        for k in range(cols):
            bm.faces.new((a[k], a[(k + 1) % cols], b[(k + 1) % cols], b[k]))
    top = bm.verts.new((0.0, -0.075, 1.861 + 0.020))    # shaped: 1.861, the pick's hair top (1.86)
    for k in range(cols):
        bm.faces.new((grid[-1][k], grid[-1][(k + 1) % cols], top))
    RB._reshape(bm, head_shape)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    f0 = max(bm.faces, key=lambda f: f.calc_center_median().z)
    if f0.normal.z < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    print("hair views", RB.projection_uvs(bm, sheet=SHEET))
    return RB.finish(name, bm, mat, RB.head_w)


# ------------------------------------------------------------------ the coat, the vest, the belt

# REAL-1's neutral trunk (real_chain.MAN) + the cloth: the vest 0.012 out, the coat 0.032 out over the chest and
# flaring over the hips to its hem (z, half-width, front y, back y)
COAT = [(0.375, 0.270, -0.165, 0.190), (0.55, 0.258, -0.158, 0.180), (0.72, 0.245, -0.150, 0.172),
        (0.88, 0.228, -0.143, 0.165), (0.95, 0.214, -0.140, 0.162), (1.04, 0.202, -0.142, 0.142),
        (1.10, 0.192, -0.144, 0.129), (1.16, 0.193, -0.146, 0.129), (1.22, 0.199, -0.154, 0.135),
        (1.28, 0.207, -0.164, 0.143), (1.34, 0.213, -0.171, 0.147), (1.40, 0.218, -0.168, 0.147),
        (1.45, 0.218, -0.158, 0.140), (1.495, 0.204, -0.142, 0.128), (1.53, 0.175, -0.129, 0.114),
        (1.56, 0.135, -0.120, 0.096)]
COAT_N = 2.4


def _man_trunk(z):
    rows = RC.MAN["trunk"]
    return tuple(RB._interp([(r[0], r[i]) for r in rows], z) for i in (1, 2, 3))


def vest_ring(z, grow=0.012):
    w, yf, yb = _man_trunk(z)
    return w + grow, yf - grow, yb + grow


def coat_ring(z):
    return tuple(RB._interp([(r[0], r[i]) for r in COAT], z) for i in (1, 2, 3))


def _contour(ring, th, n=COAT_N, grow=0.0):
    w, yf, yb = ring
    cy, d = (yf + yb) / 2.0, (yb - yf) / 2.0
    return Vector(((w + grow) * RB.se(math.sin(th), n), cy - (d + grow) * RB.se(math.cos(th), n), 0.0))


def _gap_half(z):
    """The coat's front opening: half of its width (m) at z (the vest shows between its edges)."""
    return RB._interp([(0.375, 0.120), (0.75, 0.100), (1.00, 0.080), (1.12, 0.080), (1.30, 0.110), (1.45, 0.125),
                       (1.56, 0.085)], z)


def _gap_theta(z, ring, n=COAT_N):
    w = ring[0]
    return math.asin(min(0.99, (_gap_half(z) / w) ** (n / 2.0)))


def build_vest(name, mat):
    bm = bmesh.new()
    zs = [0.94, 1.00, 1.06, 1.12, 1.18, 1.24, 1.30, 1.36, 1.42, 1.47, 1.51, 1.545, 1.575]
    rings = [(z,) + vest_ring(z) + (2.4, 2.4) for z in zs]
    rv, params = RB.loft(bm, [(r[0], r[1], r[2], r[3], r[4], r[5]) for r in rings], 24)
    # the loft's u 0.5 is his front (loft: u = th / 2pi + 0.5): the painter draws the V there, the seam is at his back
    RB.param_uvs(bm, params, "shirt", wrap_u=True)
    return RB.finish(name, bm, mat, RB.torso_w)


def build_coat_body(name, mat, cols=26):
    zs = [1.56, 1.53, 1.495, 1.45, 1.40, 1.34, 1.28, 1.22, 1.16, 1.10, 1.04, 0.98]
    grid = []
    for z in zs:
        ring = coat_ring(z)
        g = _gap_theta(z, ring)
        row = []
        for i in range(cols + 1):
            th = g + (2 * math.pi - 2 * g) * i / cols
            p = _contour(ring, th)
            row.append(Vector((p.x, p.y, z)))
        grid.append(row)
    bm = bmesh.new()
    params = RB.grid_slab(bm, grid, 0.010, lambda p: Vector((-p.x, -(p.y - 0.0), 0)).normalized())
    RB.param_uvs(bm, params, "bib")
    return RB.finish(name, bm, mat, RB.torso_w)


def build_coat_skirt(name, mat, side, cols=10, rows=10, legs=0.85, front_follow=0.55):
    """One half of the coat's skirt (side "l": his left, from the front opening round to the back seam), z 1.02 to the
    hem; the two halves meet at the back (the seam), and below the vent's top hang free of each other."""
    sx = 1.0 if side == "l" else -1.0
    top, hem = 1.02, 0.375
    grid = []
    for j in range(rows + 1):
        z = top + (hem - top) * j / rows
        ring = coat_ring(z)
        g = _gap_theta(z, ring)
        row = []
        for i in range(cols + 1):
            th = g + (math.pi - g) * i / cols                   # the front edge to the back (his left: + x)
            p = _contour(ring, th)
            t = j / rows
            rip = 0.008 * math.sin(th * 6.0 + 0.4 * sx) * t ** 0.8         # hanging folds
            rr = math.hypot(p.x, p.y - (ring[1] + ring[2]) / 2) or 1.0
            x = p.x + p.x / rr * rip
            y = p.y + (p.y - (ring[1] + ring[2]) / 2) / rr * rip
            if i == cols and z < 0.72:                          # the vent: the halves part a little below its top
                y += 0.004 * (0.72 - z) / 0.35
            z2 = z + (0.008 * ((i * 5) % 3 - 1) if j == rows else 0.0)
            row.append(Vector((x * sx, y, z2)))
        grid.append(row)
    if sx < 0:
        grid = [list(reversed(r)) for r in grid]
    bm = bmesh.new()
    params = RB.grid_slab(bm, grid, 0.008, lambda p: Vector((-p.x, -p.y, 0)).normalized())
    RB.param_uvs(bm, params, "apron")
    return RB.finish(name, bm, mat, RB.skirt_w(top, hem, front_follow, legs))


def build_lapels(name, mat):
    """The lapels: a flap folded back over the coat's front along each edge of the opening (z 1.22-1.53)."""
    bm = bmesh.new()
    params = {}
    for sx in (1.0, -1.0):
        grid = []
        zs = [1.53, 1.48, 1.42, 1.36, 1.30, 1.24]
        for z in zs:
            ring = coat_ring(z)
            g = _gap_theta(z, ring)
            w = RB._interp([(1.24, 0.004), (1.32, 0.045), (1.42, 0.075), (1.48, 0.070), (1.53, 0.040)], z)
            row = []
            for k in range(3):
                # from the edge outward over the coat (k 0 the fold, 2 the lapel's outer edge)
                dth = (w / ring[0]) * (k / 2.0) * 1.2
                p = _contour(ring, g + dth, grow=0.006 + 0.003 * k)
                row.append(Vector((p.x * sx, p.y, z - 0.01 * k * (z - 1.24))))
            grid.append(row if sx > 0 else list(reversed(row)))
        params.update(RB.grid_slab(bm, grid, 0.005, lambda p: Vector((-p.x, -p.y, 0)).normalized()))
    RB.param_uvs(bm, params, "straps")
    return RB.finish(name, bm, mat, RB.torso_w)


def build_collar(name, mat, cols=20):
    """The coat's wide collar: up the back of the neck and turned down over the shoulders, open at the front."""
    rows = [(1.52, 0.000, 0.000), (1.56, 0.006, 0.000), (1.595, 0.014, 0.004), (1.615, 0.024, 0.002), (1.59, 0.034, -0.006),
            (1.55, 0.040, -0.012)]                              # (z, outward, extra back) from the neck line: up, then over
    grid = []
    for z0, out, back in rows:
        row = []
        for i in range(cols + 1):
            th = math.radians(38.0) + (2 * math.pi - math.radians(76.0)) * i / cols
            base = _contour(vest_ring(min(1.575, z0)), th, n=2.2, grow=0.012 + out)
            row.append(Vector((base.x, base.y + back * max(0.0, -math.cos(th)), z0)))
        grid.append(row)
    bm = bmesh.new()
    params = RB.grid_slab(bm, grid, 0.006, lambda p: Vector((-p.x, -p.y, 0)).normalized())
    RB.param_uvs(bm, params, "straps")
    return RB.finish(name, bm, mat, lambda co: K.blend("chest", "head", 0.10 * K.clamp01((co.z - 1.58) / 0.06)))


def build_coat_sleeve(name, mat, s):
    S, E, W = RB.arm_frame(s)
    du, dl = (E - S).normalized(), (W - E).normalized()
    pts = [S - du * 0.075, S - du * 0.015, S + du * 0.070, S + du * 0.160, E - du * 0.020, E + dl * 0.040, E + dl * 0.130,
           W - dl * 0.050, W + dl * 0.006]
    rads = [(0.078, 0.084), (0.080, 0.088), (0.074, 0.080), (0.068, 0.072), (0.064, 0.068), (0.062, 0.064), (0.058, 0.060),
            (0.054, 0.056), (0.053, 0.055)]
    bm = bmesh.new()
    params, rings = RB.tube(bm, pts, rads, 12, up=RB.up_z, cap0=True, cap1=False)
    RB.param_uvs(bm, params, "sleeve", wrap_u=True)
    return RB.finish(name, bm, mat, RB.arm_w(s))


def build_cuff(name, mat, s):
    """The coat's turned-back cuff: a broad band round the wrist end of the sleeve."""
    S, E, W = RB.arm_frame(s)
    dl = (W - E).normalized()
    c = W - dl * 0.040
    u = Vector((0, 0, 1))
    u = (u - dl * u.dot(dl)).normalized()
    w = dl.cross(u).normalized()
    R, ta, tr = 0.058, 0.036, 0.011
    bm = bmesh.new()
    nu, nv = 12, 6
    vs, params = [], {}
    for i in range(nu):
        a = 2 * math.pi * i / nu
        radial = u * math.cos(a) + w * math.sin(a)
        row = []
        for j in range(nv):
            b = 2 * math.pi * j / nv
            p = c + radial * (R + tr * math.cos(b)) + dl * (ta * math.sin(b))
            v = bm.verts.new(p)
            params[v] = (i / nu, j / nv)
            row.append(v)
        vs.append(row)
    for i in range(nu):
        for j in range(nv):
            bm.faces.new((vs[i][j], vs[(i + 1) % nu][j], vs[(i + 1) % nu][(j + 1) % nv], vs[i][(j + 1) % nv]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    RB.param_uvs(bm, params, "roll", wrap_u=True, wrap_v=True)
    return RB.finish(name, bm, mat, RB.arm_w(s))


PELVIS = [(0.80, 0.100, -0.060, 0.070, 2.2, 2.2), (0.86, 0.165, -0.100, 0.115, 2.2, 2.3), (0.92, 0.180, -0.112, 0.128, 2.2, 2.3),
          (0.99, 0.178, -0.110, 0.123, 2.2, 2.3), (1.06, 0.170, -0.110, 0.112, 2.2, 2.3)]


def build_pelvis(name, mat):
    bm = bmesh.new()
    rv, params = RB.loft(bm, PELVIS, 20, cap_bottom=True)
    RB.param_uvs(bm, params, "seat", wrap_u=True)
    return RB.finish(name, bm, mat, lambda co: {"hips": 1.0})


def build_belt(name, mat, z=1.085, h=0.042, segs=24):
    bm = bmesh.new()
    params = {}
    layers = [(z - h / 2, 0.010), (z + h / 2, 0.010), (z + h / 2, 0.002), (z - h / 2, 0.002)]
    rings = []
    for li, (zz, g) in enumerate(layers):
        ring = []
        for k in range(segs):
            th = 2 * math.pi * k / segs
            p = _contour(vest_ring(z), th, n=2.4, grow=g)
            v = bm.verts.new((p.x, p.y, zz))
            params[v] = (k / segs, li / 4.0)
            ring.append(v)
        rings.append(ring)
    for a, b in zip(rings, rings[1:] + rings[:1]):
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    RB.param_uvs(bm, params, "belt", wrap_u=True, wrap_v=True)
    y = _contour(vest_ring(z), 0.0, grow=0.014).y
    bk = bmesh.new()
    c = Vector((0.0, y - 0.003, z))
    for v in K.ellipsoid(bk, c, 0.026, 0.007, 0.024, 8, 4):
        q = v.co - c
        v.co = c + Vector((RB.se(q.x / 0.026, 3.5) * 0.026, q.y, RB.se(q.z / 0.024, 3.5) * 0.024))
    RB.flat_uvs(bk, L.misc_uv("buckle"))
    tmp = bpy.data.meshes.new("_bk")
    bk.to_mesh(tmp)
    bk.free()
    bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    return RB.finish(name, bm, mat, RB.torso_w)


# ------------------------------------------------------------------ the sword (a prop on hips, sheathed: R-9)

SWORD_HILT = Vector((0.205, -0.045, 1.035))           # the scabbard's throat at his left hip, a little forward
SWORD_DIR = Vector((0.27, 0.20, -0.94)).normalized()  # out, back and down (the pick's front and back views)
SWORD_LEN = 0.86


def build_sword(name, mat):
    bm = bmesh.new()
    params = {}
    d = SWORD_DIR
    flat = Vector((0.0, -1.0, 0.0))                     # the scabbard's broad side faces out (its width front-back)
    flat = (flat - d * flat.dot(d)).normalized()
    pts = [SWORD_HILT + d * (SWORD_LEN * k / 6.0) for k in range(7)]
    rads = [(0.011, 0.024), (0.011, 0.024), (0.011, 0.023), (0.010, 0.022), (0.010, 0.020), (0.009, 0.017), (0.007, 0.010)]
    pp, _ = RB.tube(bm, pts, rads, 6, up=lambda p, dd: d.cross(flat).normalized(), cap0=True, cap1=True)
    params.update({v: (u, 1.0 - v_) for v, (u, v_) in pp.items()})            # v 1 the throat, 0 the tip
    sub = bmesh.new()                                   # the grip (its leather wrap: the laces cell)
    grip_end = SWORD_HILT - d * 0.17
    RB.tube(sub, [SWORD_HILT - d * 0.020, grip_end], [(0.014, 0.014), (0.012, 0.012)], 6, up=lambda p, dd: flat,
            cap0=True, cap1=True)
    RB.flat_uvs(sub, L.misc_uv("laces"))
    pom = bmesh.new()                                   # the cross-guard and the pommel (steel)
    RB.tube(pom, [SWORD_HILT - flat * 0.075 - d * 0.012, SWORD_HILT + flat * 0.075 - d * 0.012], [(0.010, 0.012)] * 2, 6,
            up=lambda p, dd: d, cap0=True, cap1=True)
    K.ellipsoid(pom, grip_end - d * 0.012, 0.021, 0.021, 0.021, 8, 5)
    RB.flat_uvs(pom, L.misc_uv("metal_dark"))
    RB.param_uvs(bm, params, "cloth")
    for extra in (sub, pom):
        tmp = bpy.data.meshes.new("_sw")
        extra.to_mesh(tmp)
        extra.free()
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    ob = K.new_obj(name, bm, mat)
    arm = C.rig()
    mw = ob.matrix_world.copy()
    ob.parent = arm
    ob.parent_type = "BONE"
    ob.parent_bone = "hips"
    ob.matrix_world = mw
    return ob


# ------------------------------------------------------------------ build

COAT_LEGS, COAT_FOLLOW = 0.85, 0.45      # the skirt halves follow their thighs (the coat is open at the front)


def build():
    assert C.is_open(CFG["blend"]), "open_base_as_player() first (%r)" % bpy.data.filepath
    RT.rest_pose()
    K.remove(["Base_Body"])
    m = bpy.data.materials.get("AN_BaseSkin")
    if m and m.users == 0:
        bpy.data.materials.remove(m)
    K.setup()
    old = [o.name for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(("RB_", "RP_", "Player_"))]
    K.remove(old)
    head, body = _materials()
    neck = [(1.47, 0.068, -0.112, 0.040, 2.2, 2.2), (1.54, 0.064, -0.106, 0.028, 2.2, 2.2), (1.60, 0.061, -0.102, 0.022, 2.2, 2.2),
            (1.67, 0.060, -0.096, 0.018, 2.2, 2.2)]
    parts = [RB.build_head("RP_Head", head, sheet=SHEET, shape=head_shape), build_hair("RP_Hair", head),
             RB.build_ears("RP_Ears", head, sheet=SHEET, shape=head_shape),
             RB.build_neck("RP_Neck", head, sheet=SHEET, rings=[(z, w / HEAD_X, f, b, n1, n2) for z, w, f, b, n1, n2 in neck],
                           shape=head_shape),
             build_vest("RP_Vest", body), build_coat_body("RP_Coat", body), build_lapels("RP_Lapels", body),
             build_collar("RP_Collar", body), build_belt("RP_Belt", body), build_pelvis("RP_Seat", body)]
    for s in ("l", "r"):
        parts += [build_coat_skirt("RP_Skirt_" + s, body, s, legs=COAT_LEGS, front_follow=COAT_FOLLOW),
                  build_coat_sleeve("RP_Sleeve_" + s, body, s), build_cuff("RP_Cuff_" + s, body, s),
                  RB.build_hand_real("RP_Hand_" + s, body, s, scale=1.0),
                  RB.build_trouser_leg("RP_Leg_" + s, body, s, girth=0.90), RB.build_boot("RP_Boot_" + s, body, s)]
    counts = {p.name: sum(len(f.vertices) - 2 for f in p.data.polygons) for p in parts}
    props = [build_sword("Player_Sword", body)]
    out = MG.join(CFG["body"], parts)
    C.drop_cached_clouds()
    ok, stats = MG.check(out, props=props, tri_budget=TRI_BUDGET)
    print("parts (tris):", sorted(counts.items(), key=lambda kv: -kv[1]))
    return ok, stats


def paint_head():
    import real_bake as BK
    out = BK.bake_head(CFG["body"], "RT_Player_Head", SHEET, CFG["head_paint_png"])
    ok, stats = MG.check(bpy.data.objects[CFG["body"]], props=[bpy.data.objects[n] for n in CFG["props"]], tri_budget=TRI_BUDGET)
    return ok, stats, out


# ------------------------------------------------------------------ his clips: Idle and Running_A (the two he plays)

IDLE_HAND = (0.330, -0.020, 0.885)       # by his coat (the coat's hips 0.21 + the sleeve): the pick's relaxed A-stance
IDLE_POLE = (0.75, 0.45, 1.20)


def _use_his_soles():
    RBT._SOLES["pts"] = C.sole_points(C.rig(), [bpy.data.objects[CFG["body"]]])


def pose_idle(t):
    AN.base_pose(RBT.SRC["Idle"], t)
    RBT.stand_tall()
    for s, sx in (("l", 1), ("r", -1)):
        RBT.reach(s, AN.in_frame_of("chest", (IDLE_HAND[0] * sx, IDLE_HAND[1], IDLE_HAND[2])),
                  AN.in_frame_of("chest", (IDLE_POLE[0] * sx, IDLE_POLE[1], IDLE_POLE[2])), (-sx, 0.15, 0.0))


ARM_GAP = 0.025                         # Running_A's forearms and hands kept this far outside his coat


def arms_out(clip, body_name=None, gap=ARM_GAP, max_deg=30.0):
    """Running_A on REAL-1 keeps the base's arm pass (fitted to the neutral man); his coat is ~0.03 m wider, so each
    key frame's upper arm turns AWAY from the body (about the chest's front-back axis, the arm pass's own measure,
    real_arms.clearance) just enough to keep `gap`. Rewrites the upperarm rotation channels only."""
    import real_arms as RA
    act = bpy.data.actions[clip]
    body = bpy.data.objects[body_name or CFG["body"]]
    dom = RA._dominant(body)
    arm = C.rig()
    p = dict(RC.ARM_PASS, gap=gap)
    poses, turns = [], []
    keys = RA._keys(act)
    for f in keys:
        RT.pose_from(act, f)
        co = RA._frame_points(body, dom)
        R = RA._chest_frame()
        Rinv = R.inverted()
        axis = R @ Vector((0.0, 1.0, 0.0))
        row = {}
        for s, sx in RA.SIDES:
            S = arm.pose.bones["upperarm." + s].head
            A, B = RA._arm_points(co, RA._sets(dom, s), S, Rinv)
            mid = RA._midline(p, S, Rinv, sx)

            def clear(g):
                return RA.clearance(RA._rot(A, -g, sx) if g else A, B, sx, p["window"], mid)
            g = 0.0
            if clear(0.0) < gap:
                lo, hi = 0.0, math.radians(max_deg)
                for _ in range(16):
                    m_ = (lo + hi) / 2
                    if clear(m_) >= gap:
                        hi = m_
                    else:
                        lo = m_
                g = hi
            row[s] = g
        turns.append(row)
    for k, f in enumerate(keys):
        RT.pose_from(act, f)
        R = RA._chest_frame()
        axis = R @ Vector((0.0, 1.0, 0.0))
        for s, sx in RA.SIDES:
            g = turns[k][s]
            if g:
                RT.rotate_about("upperarm." + s, Matrix.Rotation(-g * sx, 3, axis), pivot=arm.pose.bones["upperarm." + s].head.copy())
        poses.append((f, {"upperarm." + s: {"rotation_quaternion": arm.pose.bones["upperarm." + s].rotation_quaternion.copy()}
                          for s, _ in RA.SIDES}))
    RT._rekey(act, [("upperarm.l", "rotation_quaternion"), ("upperarm.r", "rotation_quaternion")], poses)
    act["real_player_arms_out"] = gap
    RT.rest_pose()
    C.drop_cached_clouds()
    out = {s: round(math.degrees(max(t[s] for t in turns)), 1) for s, _ in RA.SIDES}
    print("arms out %s: max turn deg %s" % (clip, out))
    return out


def build_clips():
    assert C.is_open(CFG["blend"])
    RBT.ensure_sources()
    _use_his_soles()
    out = AN.build_clips([("Idle", AN.IDLE_S, pose_idle, True)])
    bpy.data.actions["Idle"].use_fake_user = True
    out.append(("Running_A arms out", arms_out("Running_A")))
    print("clips", out)
    return out


def rate(clip="Running_A"):
    import anime_clearcheck as CC
    v = CC.ground_speed(clip, {"body": CFG["body"], "props": CFG["props"]})
    CC._rest()
    print("%s ground speed on his body: %.3f m/s (playback rate at 5.0 m/s: %.3f)" % (clip, v, 5.0 / v))
    return round(v, 3)


# ------------------------------------------------------------------ export

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
    os.makedirs(os.path.dirname(CFG["glb"]), exist_ok=True)
    bpy.ops.wm.save_mainfile()
    for src in RBT.SRC.values():
        if src in bpy.data.actions:
            bpy.data.actions.remove(bpy.data.actions[src])
    bpy.ops.export_scene.gltf(filepath=CFG["glb"], use_selection=True, export_apply=False, export_skins=True,
                              export_animations=True, export_yup=True)
    print("exported", CFG["glb"], os.path.getsize(CFG["glb"]))
    bpy.ops.wm.revert_mainfile()
    return CFG["glb"]
