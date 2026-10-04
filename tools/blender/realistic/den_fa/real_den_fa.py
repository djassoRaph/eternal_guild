# real_den_fa.py - Story 25.32 (catalogue G9): Den Fa on route RL, restyled realistic from his pick
# (<art>/picked/C_G9_den_fa.png) WITHOUT the bone wings (R-8). He keeps his own 25.10 rig (DC-1), minus the 12 wing bones
# (DC-2): 30 d_ bones whose rest is 25.10's (DC-3; real_den_fa_anims.compare proves it against the recorded 25.10 file).
# The body is new: route RL's geometry and UV helpers (real_body.loft / tube / grid_slab / param_uvs, anime_kit's
# new_obj / skin / ellipsoid) with his OWN weight functions (his bones are d_, not KayKit's), one body atlas painted by
# real_den_fa_paint.py over real_layout.REG, and the featureless mirror mask as its own material den_fa_mask (DC-5,
# unchanged from 25.10: metallic 1.0, roughness 0.10, #d8dde3). One mesh DenFa_Body, 2 surfaces, 1 texture.
#
# The atlas regions (real_layout.REG boxes, his garments in them):
#   shirt (wraps)   the coat's body (the side placket, two collar buttons)   apron     the coat's skirt halves (frayed hem)
#   bib             the high stand collar                                   sleeve    the coat sleeves (wrap)
#   roll            the dark turned-back cuffs (wrap)                       hand      the dark grey gloves
#   trousers        dark trousers (wrap)                                    boots     knee-high brown leather (wrap)
#   forearm         his dark grey skin: the skull and the neck              seat      the bat ears (mauve, darker inside)
#
# The coat (DC-7: it adapts to his clips): the skirt is two halves split at the front AND at the back (a vent). Below
# the top band (hips) both halves follow the thighs fully, front and back, and below the knee they hand over to the
# shins: seated on the hearth bench only 0.17 m separate his thigh axis from the bench top, so the back of the coat
# stays within 0.15 m of the thighs (the bench check, AC 5) and never hangs from the hips (it would go through the
# bench).
#
# One call per step (the README's runner, with tools/blender/realistic/den_fa on sys.path):
#   new_file()        an empty file saved as <art>/blender/g9_den_fa_real.blend (refuses an existing file)
#   build_rig()       DenFa_Rig, the 30 bones
#   build_clips()     the six clips (real_den_fa_anims), stashed; compare() against the 25.10 record
#   build()           DenFa_Body (the parts joined) and check()
#   export()          DenFa_Rig + DenFa_Body -> assets/characters/custom/g9_den_fa_real.glb (then reverts the file)
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

import anime_common as C
import anime_kit as K
import anime_merge as MG
import real_body as RB
import real_den_fa_anims as DA

ART = C.ART
BLEND = C.BLEND + "g9_den_fa_real.blend"
OLD_BLEND = C.BLEND + "g9_den_fa.blend"
RECORD = C.BLEND + "g9_den_fa_25_10_record.json"
BODY_PNG = ART + "textures/realistic/g9_den_fa_real_body.png"
GLB = "F:/GAME I AM MAKING/shiningsun/assets/characters/custom/g9_den_fa_real.glb"
RIG = "DenFa_Rig"
BODY = "DenFa_Body"
BODY_MAT = "RT_DenFa_Body"
MASK_MAT = "den_fa_mask"
IMAGE = "g9_den_fa_real_body"
TRI_BUDGET = 10000          # RL_TRI_BUDGET
SURFACE_CAP = 3             # RL_BODY_SURFACES (the mask included)
TOP = 2.91                  # his ear tips (canon, R-3)
P = "DF_"                   # the parts' prefix before the join

# ------------------------------------------------------------------ the skeleton (25.10's, without the wings)
BONES = [  # name, head, tail, parent
    ('d_root', (0, 0, 0), (0, 0, 0.25), None),
    ('d_hips', (0, 0, 1.18), (0, 0, 1.40), 'd_root'),
    ('d_spine', (0, 0, 1.40), (0, 0, 1.62), 'd_hips'),
    ('d_chest', (0, 0, 1.62), (0, 0, 1.97), 'd_spine'),
    ('d_collar', (0, 0, 1.97), (0, 0, 2.20), 'd_chest'),
    ('d_neck', (0, -0.01, 1.97), (0, -0.02, 2.22), 'd_chest'),
    ('d_head', (0, -0.02, 2.22), (0, -0.02, 2.58), 'd_neck'),
    ('d_mask', (0, -0.10, 2.40), (0, -0.22, 2.40), 'd_head'),
]
for _s, _sx in (('L', 1), ('R', -1)):
    BONES += [
        ('d_ear1.%s' % _s, (_sx * 0.09, 0.0, 2.52), (_sx * 0.14, 0.02, 2.70), 'd_head'),
        ('d_ear2.%s' % _s, (_sx * 0.14, 0.02, 2.70), (_sx * 0.19, 0.04, 2.90), 'd_ear1.%s' % _s),
        ('d_shoulder.%s' % _s, (_sx * 0.05, 0.0, 1.95), (_sx * 0.21, 0.0, 1.99), 'd_chest'),
        ('d_upperarm.%s' % _s, (_sx * 0.23, 0.0, 1.99), (_sx * 0.28, 0.0, 1.50), 'd_shoulder.%s' % _s),
        ('d_forearm.%s' % _s, (_sx * 0.28, 0.0, 1.50), (_sx * 0.31, -0.02, 1.06), 'd_upperarm.%s' % _s),
        ('d_hand.%s' % _s, (_sx * 0.31, -0.02, 1.06), (_sx * 0.32, -0.03, 0.93), 'd_forearm.%s' % _s),
        ('d_index.%s' % _s, (_sx * 0.32, -0.05, 0.93), (_sx * 0.32, -0.06, 0.83), 'd_hand.%s' % _s),
        ('d_thumb.%s' % _s, (_sx * 0.29, -0.06, 1.02), (_sx * 0.28, -0.09, 0.95), 'd_hand.%s' % _s),
        ('d_thigh.%s' % _s, (_sx * 0.11, 0.0, 1.20), (_sx * 0.12, 0.0, 0.64), 'd_hips'),
        ('d_shin.%s' % _s, (_sx * 0.12, 0.0, 0.64), (_sx * 0.12, 0.02, 0.12), 'd_thigh.%s' % _s),
        ('d_foot.%s' % _s, (_sx * 0.12, 0.02, 0.12), (_sx * 0.12, -0.17, 0.03), 'd_shin.%s' % _s),
    ]
BONE_NAMES = [b[0] for b in BONES]
assert len(BONE_NAMES) == 30 and not any(n.startswith("d_wing") for n in BONE_NAMES)
HEAD = {b[0]: Vector(b[1]) for b in BONES}
TAIL = {b[0]: Vector(b[2]) for b in BONES}
SIDES = (('L', 1.0), ('R', -1.0))


def rig():
    return bpy.data.objects[RIG]


def rest(arm=None):
    """The rig in rest: no action, every pose bone's matrix_basis the identity (build and parent only in rest)."""
    arm = arm or rig()
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()


def new_file():
    """An empty file saved as BLEND (one armature per .blend: actions are file-global). Refuses an existing file."""
    assert not os.path.exists(BLEND), "%s exists: open it instead" % BLEND
    assert not bpy.data.is_dirty, "the open file has unsaved changes: %r" % bpy.data.filepath
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    return bpy.data.filepath


def build_rig():
    assert C.is_open(BLEND), "not g9_den_fa_real.blend: %r" % bpy.data.filepath
    assert RIG not in bpy.data.objects, "DenFa_Rig exists: the rig is built once (its clips and the body bind to it)"
    arm = bpy.data.armatures.new(RIG)
    ob = bpy.data.objects.new(RIG, arm)
    bpy.context.scene.collection.objects.link(ob)
    for o in bpy.context.selected_objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name, h, t, par in BONES:
        eb = arm.edit_bones.new(name)
        eb.head = Vector(h)
        eb.tail = Vector(t)
        eb.roll = 0.0
        if par:
            eb.parent = arm.edit_bones[par]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    for pb in ob.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    bpy.ops.wm.save_mainfile()
    return len(arm.bones)


def build_clips():
    assert C.is_open(BLEND)
    names = DA.build_actions(rig())
    out = DA.compare(RECORD, rig())
    bpy.ops.wm.save_mainfile()
    return names, out


# ------------------------------------------------------------------ weights (his bones)

def clamp01(x):
    return max(0.0, min(1.0, x))


def blend(a, b, t):
    t = clamp01(t)
    return {a: 1.0 - t, b: t} if a != b else {a: 1.0}


def chain(bones, blend_m=0.08):
    """By projection on the nearest bone of the chain, blended across each joint over +-blend_m."""
    def fn(co):
        best, bi, bt = 1e9, 0, 0.0
        for i, n in enumerate(bones):
            a, b = HEAD[n], TAIL[n]
            ab = b - a
            t = clamp01((co - a).dot(ab) / ab.length_squared)
            d = (a + ab * t - co).length
            if d < best:
                best, bi, bt = d, i, t
        n = bones[bi]
        L = (TAIL[n] - HEAD[n]).length
        if bi + 1 < len(bones) and (1 - bt) * L < blend_m:
            return blend(n, bones[bi + 1], 0.5 - (1 - bt) * L / (2 * blend_m))
        if bi > 0 and bt * L < blend_m:
            return blend(bones[bi - 1], n, 0.5 + bt * L / (2 * blend_m))
        return {n: 1.0}
    return fn


def fixed(bone):
    return lambda co: {bone: 1.0}


def torso_w(co):
    z = co.z
    if z < 1.30:
        w = {'d_hips': 1.0}
    elif z < 1.46:
        w = blend('d_hips', 'd_spine', (z - 1.30) / 0.16)
    elif z < 1.62:
        w = blend('d_spine', 'd_chest', (z - 1.46) / 0.16)
    else:
        w = {'d_chest': 1.0}
    if z > 1.80 and abs(co.x) > 0.15:          # the shoulder caps follow the arms a little (Point lifts the arm 95 deg)
        s = 'L' if co.x > 0 else 'R'
        k = clamp01((abs(co.x) - 0.15) / 0.08) * clamp01((z - 1.80) / 0.10)
        w = {b: v * (1 - 0.6 * k) for b, v in w.items()}
        w['d_upperarm.' + s] = w.get('d_upperarm.' + s, 0.0) + 0.6 * k
    return w


SKIRT_TOP, SKIRT_FULL, KNEE = 1.32, 1.04, 0.64


def skirt_w(sx):
    """A skirt half (sx +1: his left half). Its share of the legs rises from 0 at SKIRT_TOP to 1 at SKIRT_FULL, front
    AND back (the bench: nothing may hang from the hips below 1.03 m); the own leg dominates its half, the other leg
    takes a little near the seams; below the knee the share hands over to the shins (the Mage's robe lesson, 25.31)."""
    own, oth = ('L', 'R') if sx > 0 else ('R', 'L')

    def fn(co):
        wl = K.smoothstep(SKIRT_TOP, SKIRT_FULL, co.z)
        mine = clamp01(0.5 + sx * co.x / 0.10)
        k = K.smoothstep(KNEE + 0.05, KNEE - 0.15, co.z)
        out = {'d_hips': 1.0 - wl}
        for side, share in ((own, mine), (oth, 1.0 - mine)):
            out['d_thigh.' + side] = out.get('d_thigh.' + side, 0.0) + wl * share * (1 - k)
            out['d_shin.' + side] = out.get('d_shin.' + side, 0.0) + wl * share * k
        return out
    return fn


def leg_w(s):
    f = chain(['d_thigh.' + s, 'd_shin.' + s, 'd_foot.' + s], 0.08)

    def fn(co):
        w = f(co)
        k = clamp01((co.z - 1.10) / 0.10)
        if k > 0:
            w = {b: v * (1 - k) for b, v in w.items()}
            w['d_hips'] = w.get('d_hips', 0.0) + k
        return w
    return fn


def arm_w(s):
    f = chain(['d_upperarm.' + s, 'd_forearm.' + s, 'd_hand.' + s], 0.08)

    def fn(co):
        w = f(co)
        k = clamp01((0.24 - abs(co.x)) / 0.06) * clamp01((co.z - 1.85) / 0.08)    # the sleeve's head into the shoulder
        if k > 0:
            w = {b: v * (1 - 0.5 * k) for b, v in w.items()}
            w['d_chest'] = w.get('d_chest', 0.0) + 0.5 * k
        return w
    return fn


# ------------------------------------------------------------------ shapes

def interp(table, z):
    """Linear in z over rows (z, a, b, ...) sorted any way; clamped at the ends."""
    rows = sorted(table, key=lambda r: r[0])
    if z <= rows[0][0]:
        return rows[0][1:]
    for a, b in zip(rows[:-1], rows[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(x + (y - x) * t for x, y in zip(a[1:], b[1:]))
    return rows[-1][1:]


def contour(rx, yf, yb, n, th):
    """A superellipse ring (front at th 0, his left at +pi/2): (x, y)."""
    cy, d = (yf + yb) / 2.0, (yb - yf) / 2.0
    return rx * RB.se(math.sin(th), n), cy - d * RB.se(math.cos(th), n)


# the coat's body (z, rx, y_front, y_back, n_front, n_back): broad in the chest, square shoulders (the pick), sylphlike
COAT_TORSO = [   # v4 (the coordinator's read of v3 vs the pick): a fitted waist, a fuller chest, sloped round shoulders
    (1.16, 0.140, -0.112, 0.108, 2.2, 2.2),
    (1.24, 0.166, -0.138, 0.126, 2.3, 2.3),
    (1.36, 0.162, -0.140, 0.124, 2.3, 2.3),
    (1.52, 0.178, -0.152, 0.130, 2.3, 2.3),
    (1.68, 0.210, -0.168, 0.142, 2.3, 2.3),
    (1.80, 0.228, -0.170, 0.146, 2.3, 2.3),
    (1.88, 0.234, -0.160, 0.142, 2.2, 2.2),
    (1.94, 0.218, -0.140, 0.128, 2.1, 2.1),
    (1.985, 0.186, -0.118, 0.110, 2.1, 2.1),
    (2.020, 0.130, -0.098, 0.092, 2.0, 2.0),
    (2.035, 0.085, -0.084, 0.078, 2.0, 2.0),
]
# the skirt (z, rx, y_front, y_back): an A-line flare from the fitted waist (hem ~1.9x the waist's half-width, the
# pick), the back within 0.15 m of the thigh axes (the bench)
SKIRT = [(1.32, 0.174, -0.150, 0.136), (1.20, 0.188, -0.156, 0.142), (1.00, 0.228, -0.178, 0.150),
         (0.80, 0.264, -0.200, 0.150), (0.62, 0.296, -0.220, 0.150), (0.46, 0.326, -0.238, 0.150)]
SKIRT_N = 2.4
HEM = 0.46


def skirt_gap(z, over):
    """Where a half's front edge stops (m from the midline; negative: past it). The right half laps OVER the left to
    0.035 m on his left (the side placket, the pick) down to the knee, the left half stops at the midline; below
    0.62 m both open into the split front hem (the pick). The lap keeps the thighs covered when the halves part in
    Walk (check (b))."""
    if over:
        return interp([(0.46, 0.080), (0.66, 0.0), (0.80, -0.035), (1.32, -0.035)], z)[0]
    return interp([(0.46, 0.080), (0.66, 0.0), (1.32, 0.0)], z)[0]


def build_torso(name, mat):
    bm = bmesh.new()
    rings, params = RB.loft(bm, COAT_TORSO, 28, cap_bottom=True, cap_top=True)
    RB.param_uvs(bm, params, "shirt", wrap_u=True)
    return RB.finish(name, bm, mat, torso_w)


def build_skirt_half(name, mat, sx, cols=12, rows=14, thick=0.010, jag=0.014):
    """One half of the skirt: from the front opening round to the back vent (a grid_slab), the frayed hem jagged."""
    grid = []
    over = sx < 0             # the right half laps over the left at the front, the left over the right at the back vent
    back_gap = -0.030 if not over else 0.0
    for j in range(rows + 1):
        z = SKIRT_TOP + (HEM - SKIRT_TOP) * j / rows
        rx0, yf0, yb0 = interp(SKIRT, z)
        g = math.asin(max(-0.99, min(0.99, skirt_gap(z, over) / rx0)))
        gb = math.asin(max(-0.99, min(0.99, back_gap / rx0)))
        row = []
        for i in range(cols + 1):
            th = g + (math.pi - gb - g) * i / cols
            f = clamp01(th / math.pi)
            k_in = (1.0 - 0.015 * f) if over else (0.985 + 0.015 * f)     # the under layer 1.5 % inside the lap
            rx, yf, yb = rx0 * k_in, yf0 * k_in, yb0 * k_in
            x, y = contour(rx, yf, yb, SKIRT_N, th)
            t = j / rows
            rip = 0.006 * math.sin(th * 6.0 + 0.4 * sx) * t ** 0.8
            r = math.hypot(x, y - (yf + yb) / 2) or 1.0
            x += x / r * rip
            y += (y - (yf + yb) / 2) / r * rip
            z2 = z + (jag * ((i * 5) % 3 - 1) if j == rows else 0.0)
            row.append(Vector((x * sx, y, z2)))
        grid.append(row)
    if sx < 0:
        grid = [list(reversed(r)) for r in grid]
    bm = bmesh.new()
    params = RB.grid_slab(bm, grid, thick, lambda p: Vector((-p.x, -p.y, 0)).normalized())
    RB.param_uvs(bm, params, "apron")
    return RB.finish(name, bm, mat, skirt_w(sx))


def build_collar(name, mat, segs=24):
    """The high stand collar: an outer wall up to the jaw of the mask (lower in front), a lip folding inside."""
    rows = [(1.930, 0.160, -0.118, 0.112, 2.3, 2.3), (2.060, 0.124, -0.112, 0.106, 2.2, 2.2),
            (2.250, 0.128, -0.124, 0.116, 2.2, 2.2), (2.240, 0.112, -0.108, 0.100, 2.2, 2.2),
            (2.080, 0.098, -0.094, 0.088, 2.2, 2.2)]
    bm = bmesh.new()
    rings, params = RB.loft(bm, rows, segs, cap_top=False, cap_bottom=False)
    for k in range(segs):                       # the top edge dips in front: 2.25 at the back, 2.21 under the chin
        th = 2 * math.pi * k / segs
        dip = 0.04 * max(0.0, math.cos(th)) ** 1.5         # v4: up to the mask's jaw in front too (the pick)
        for ri in (2, 3):
            rings[ri][k].co.z -= dip
    # close the lip's lower edge to the outer wall's foot so the collar is one closed shell
    for k in range(segs):
        bm.faces.new((rings[4][k], rings[4][(k + 1) % segs], rings[0][(k + 1) % segs], rings[0][k]))
    params = {v: (u, (v.co.z - 1.93) / 0.32) for v, (u, _) in params.items()}
    RB.param_uvs(bm, params, "bib", wrap_u=True)
    return RB.finish(name, bm, mat, lambda co: blend('d_chest', 'd_neck', (co.z - 2.02) / 0.30 * 0.6))


def build_sleeve(name, mat, s, sx):
    # v4: a round deltoid cap (the first ring small, inside the shoulder), wide at the shoulder, tapering to the cuff
    pts = [Vector((sx * 0.214, 0.0, 2.030)), Vector((sx * 0.226, 0.0, 2.008)), Vector((sx * 0.238, 0.0, 1.975)),
           Vector((sx * 0.246, 0.0, 1.925)), Vector((sx * 0.252, 0.0, 1.850)), Vector((sx * 0.262, 0.0, 1.700)),
           Vector((sx * 0.276, 0.0, 1.520)), Vector((sx * 0.290, -0.010, 1.330)), Vector((sx * 0.302, -0.015, 1.170))]
    # (front-back, lateral) radii: the cap's lateral reach kept off the chimney face in StandUp / SitDown (AC 5)
    rads = [(0.034, 0.030), (0.068, 0.058), (0.088, 0.075), (0.097, 0.083), (0.098, 0.086), (0.090, 0.082), (0.080, 0.077), 0.078, 0.078]
    bm = bmesh.new()
    params, rings = RB.tube(bm, pts, rads, 14, up=lambda p, d: Vector((0, -1, 0)), cap0=True, cap1=True)
    RB.param_uvs(bm, params, "sleeve", wrap_u=True)
    return RB.finish(name, bm, mat, arm_w(s))


def build_cuff(name, mat, s, sx):
    """The dark, wide, turned-back cuff (the pick: a thick band at the wrist)."""
    a = Vector((sx * 0.300, -0.013, 1.205))
    b = Vector((sx * 0.311, -0.021, 1.055))
    pts = [a, a.lerp(b, 0.5), b]
    bm = bmesh.new()
    params, rings = RB.tube(bm, pts, [0.104, 0.110, 0.113], 14, up=lambda p, d: Vector((0, -1, 0)), cap0=True, cap1=True)
    # the open end: the cap pushed inward into a shallow cup (the glove comes out of it)
    for v in rings[-1]:
        v.co = v.co.lerp(b, 0.25)
    RB.param_uvs(bm, params, "roll", wrap_u=True)
    return RB.finish(name, bm, mat, lambda co: {'d_forearm.' + s: 1.0})


GLOVE_SCALE = 1.10          # v4: larger gloves; 1.35, 1.22 and 1.15 put the seated right hand in a wood-store log's sightline


def build_glove(name, mat, s, sx):
    """A dark grey gloved hand, empty (R-9): the palm on d_hand, the index on d_index (Point), three fingers on d_hand,
    the thumb on d_thumb. Long fingers (the pick). Fingers are 25.10's exemption from the 0.10 m rule."""
    bm = bmesh.new()
    parts = []                                         # (verts, weight fn)
    w0 = Vector((sx * 0.310, -0.020, 1.090))           # the wrist inside the cuff
    w1 = Vector((sx * 0.322, -0.032, 0.930))           # the knuckles
    before = set(bm.verts)
    RB.tube(bm, [w0, w0.lerp(w1, 0.55), w1], [(0.040, 0.030), (0.048, 0.022), (0.046, 0.020)], 10,
            up=lambda p, d: Vector((0, -1, 0)), cap0=True, cap1=True)
    parts.append((set(bm.verts) - before, lambda co: blend('d_forearm.' + s, 'd_hand.' + s, (1.08 - co.z) / 0.04)))
    fingers = [(-0.054, 'd_index.' + s, 0.110), (-0.032, 'd_hand.' + s, 0.120), (-0.010, 'd_hand.' + s, 0.112),
               (0.011, 'd_hand.' + s, 0.090)]
    for dy, bone, ln in fingers:
        a = Vector((sx * 0.323, dy - 0.006, 0.945))
        b = a + Vector((sx * 0.004, -0.010, -ln))
        before = set(bm.verts)
        RB.tube(bm, [a, a.lerp(b, 0.5), b], [0.0125, 0.0115, 0.0100], 6, cap0=True, cap1=True)   # v4: a little thicker
        parts.append((set(bm.verts) - before, (lambda co, bone=bone: {bone: 1.0})))
    a = HEAD['d_thumb.' + s] + Vector((sx * 0.004, 0.006, 0.010))
    b = TAIL['d_thumb.' + s]
    before = set(bm.verts)
    RB.tube(bm, [a, a.lerp(b, 0.5), b], [0.0165, 0.015, 0.0125], 6, cap0=True, cap1=True)
    parts.append((set(bm.verts) - before, lambda co: {'d_thumb.' + s: 1.0}))
    for v in bm.verts:                       # v4: full-size gloves that read at the game camera (x GLOVE_SCALE, the wrist)
        v.co = w0 + (v.co - w0) * GLOVE_SCALE
    params = {}
    for v in bm.verts:
        params[v] = (clamp01(0.5 + sx * (v.co.y + 0.02) * 4.0), clamp01((v.co.z - 0.82) / 0.28))
    RB.param_uvs(bm, params, "hand")
    # the per-piece weights: by position (the pieces are disjoint), recorded before the bmesh is freed
    idx = {}
    for verts, fn in parts:
        for v in verts:
            idx[tuple(round(c, 6) for c in v.co)] = fn
    ob = RB.finish(name, bm, mat, lambda co: {'d_hand.' + s: 1.0})
    for g in list(ob.vertex_groups):
        ob.vertex_groups.remove(g)
    groups = {}
    for v in ob.data.vertices:
        fn = idx.get(tuple(round(c, 6) for c in v.co))
        ws = fn(v.co) if fn else {'d_hand.' + s: 1.0}
        tot = sum(ws.values()) or 1.0
        for bone, w in ws.items():
            if w <= 1e-4:
                continue
            g = groups.get(bone) or ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
            groups[bone] = g
            g.add([v.index], w / tot, "REPLACE")
    return ob


def build_leg(name, mat, s, sx):
    pts = [Vector((sx * 0.105, 0.0, 1.24)), Vector((sx * 0.108, 0.0, 1.12)), Vector((sx * 0.112, 0.0, 1.00)),
           Vector((sx * 0.116, 0.0, 0.88)), Vector((sx * 0.118, 0.0, 0.76)), Vector((sx * 0.120, 0.0, 0.66)),
           Vector((sx * 0.120, 0.012, 0.52))]
    bm = bmesh.new()
    params, rings = RB.tube(bm, pts, [0.090, 0.087, 0.084, 0.079, 0.074, 0.070, 0.064], 12, up=lambda p, d: Vector((0, -1, 0)))
    RB.param_uvs(bm, params, "trousers", wrap_u=True)
    return RB.finish(name, bm, mat, leg_w(s))


def build_boot(name, mat, s, sx):
    """A knee-high brown leather boot: the shaft (a slight flare at its top, under the knee) and the foot."""
    bm = bmesh.new()
    pts = [Vector((sx * 0.121, 0.004, 0.575)), Vector((sx * 0.121, 0.010, 0.45)), Vector((sx * 0.121, 0.018, 0.25)),
           Vector((sx * 0.121, 0.022, 0.12))]
    # v4: chunky, a little slouched at the top (the pick)
    p1, r1 = RB.tube(bm, pts, [(0.100, 0.098), 0.090, 0.078, 0.070], 12, up=lambda p, d: Vector((0, -1, 0)))
    shaft = set(bm.verts)
    # the foot: rings along y from the heel to the toe (z, half-width, height above the sole)
    foot = [(0.095, 0.046, 0.085), (0.068, 0.060, 0.150), (0.000, 0.063, 0.130), (-0.090, 0.064, 0.100),
            (-0.165, 0.060, 0.080), (-0.220, 0.048, 0.062), (-0.248, 0.026, 0.044)]
    segs = 12
    frings = []
    for y, hw, h in foot:
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            ca, sa = math.cos(a), math.sin(a)
            zc = h / 2.0
            ring.append(bm.verts.new((sx * 0.121 + hw * sa, y, max(0.0, zc + (h / 2.0) * RB.se(ca, 2.6)))))
        frings.append(ring)
    for a_, b_ in zip(frings[:-1], frings[1:]):
        for k in range(segs):
            bm.faces.new((a_[k], a_[(k + 1) % segs], b_[(k + 1) % segs], b_[k]))
    bm.faces.new(frings[0])
    bm.faces.new(list(reversed(frings[-1])))
    params = {}
    for v in bm.verts:
        params[v] = p1.get(v) if v in shaft else (((math.atan2(v.co.x - sx * 0.121, -v.co.y) / (2 * math.pi)) + 0.5) % 1.0,
                                                  0.02 + 0.30 * v.co.z / 0.14)
    RB.param_uvs(bm, params, "boots", wrap_u=True)

    def w(co):
        if co.z > 0.16:
            return {'d_shin.' + s: 1.0}
        return blend('d_shin.' + s, 'd_foot.' + s, (0.02 - co.y) / 0.08 + (0.12 - co.z) / 0.10)
    return RB.finish(name, bm, mat, w)


def build_neck(name, mat):
    bm = bmesh.new()
    pts = [Vector((0, -0.006, 1.95)), Vector((0, -0.014, 2.10)), Vector((0, -0.020, 2.30))]
    params, rings = RB.tube(bm, pts, [0.070, 0.064, 0.066], 12, up=lambda p, d: Vector((0, -1, 0)))
    params = {v: (u, 0.02 + 0.30 * vv) for v, (u, vv) in params.items()}
    RB.param_uvs(bm, params, "forearm", wrap_u=True)
    return RB.finish(name, bm, mat, chain(['d_neck', 'd_head'], 0.06))


SKULL_C, SKULL_R = Vector((0.0, 0.004, 2.405)), Vector((0.128, 0.150, 0.172))
MASK_C, MASK_R = Vector((0.0, -0.020, 2.395)), Vector((0.140, 0.172, 0.218))   # v4: taller than wide


def build_skull(name, mat):
    bm = bmesh.new()
    vs = K.ellipsoid(bm, SKULL_C, SKULL_R.x, SKULL_R.y, SKULL_R.z, 20, 12)
    params = {}
    for v in vs:
        d = v.co - SKULL_C
        params[v] = (((math.atan2(d.x, -d.y) / (2 * math.pi)) + 0.5) % 1.0, 0.36 + 0.60 * clamp01(0.5 + d.z / (2 * SKULL_R.z)))
    RB.param_uvs(bm, params, "forearm", wrap_u=True)
    return RB.finish(name, bm, mat, fixed('d_head'))


def mask_point(th, ph, grow=0.0):
    """The mask's shell: th round from the front (+ his left), ph the polar angle from the top. v4 (the pick): an
    elongated shell, the chin narrowed, a soft vertical ridge down the front (slightly pointed)."""
    z = MASK_C.z + (MASK_R.z + grow) * math.cos(ph)
    low = K.smoothstep(MASK_C.z + 0.02, MASK_C.z - 0.21, z)
    x = (MASK_R.x + grow) * math.sin(ph) * math.sin(th) * (1.0 - 0.32 * low)
    y = -(MASK_R.y + grow) * math.sin(ph) * math.cos(th) * (1.0 - 0.10 * low)
    if math.cos(th) > 0:
        y -= 0.014 * math.cos(th) ** 6 * math.sin(ph)
    return Vector((MASK_C.x + x, MASK_C.y + y, z))


def build_mask(name, mat, cols=18, rows=12, th_max=96.0, ph0=10.0, ph1=150.0, thick=0.016):
    """The featureless mirror mask (den_fa_mask): one smooth full-face dome from above the brow to under the chin, the
    sides stopping in front of the ears. Never a face: no features, nothing painted (DC-5)."""
    grid = []
    for j in range(rows + 1):
        ph = math.radians(ph0 + (ph1 - ph0) * j / rows)
        row = []
        for i in range(cols + 1):
            th = math.radians(-th_max + 2 * th_max * i / cols)
            row.append(mask_point(th, ph))
        grid.append(row)
    bm = bmesh.new()
    params = RB.grid_slab(bm, grid, thick, lambda p: (MASK_C - p).normalized())
    RB.flat_uvs(bm, (0.30, 0.10))          # a flat misc cell: the mask has no texture; never on a region's edge
    return RB.finish(name, bm, mat, fixed('d_mask'))


def build_ear(name, mat, s, sx):
    """A tall bat ear (muted mauve, the inner darker: painted on the front half of the ring), rising from the side of
    the skull above and behind the mask's edge to the 2.91 m tip."""
    # v4 (the pick): from the SIDE of the skull behind the mask's edge, angled ~21 deg outward; the tip at 2.91 (canon)
    base = Vector((sx * 0.112, 0.036, 2.455))
    mid = Vector((sx * 0.200, 0.044, 2.680))
    tip = Vector((sx * 0.290, 0.052, 2.910))
    pts = [base, base.lerp(mid, 0.5), mid, mid.lerp(tip, 0.45), mid.lerp(tip, 0.80), tip]
    rads = [(0.064, 0.034), (0.066, 0.030), (0.056, 0.024), (0.040, 0.019), (0.021, 0.012), (0.0, 0.0)]
    bm = bmesh.new()
    # up = +X on both sides, so the ring's u 0.75 is the front (the inner bowl) on both ears (the painter's rule)
    params, rings = RB.tube(bm, pts, rads, 10, up=lambda p, d: Vector((1.0, 0.0, 0.0)), cap0=True, pole_tip=True)
    for ring in rings[1:-1]:                    # the inner bowl: the front's middle pressed back
        c = sum((v.co for v in ring), Vector()) / len(ring)
        for v in ring:
            d = v.co - c
            if d.y < 0:
                v.co.y += 0.55 * (-d.y) * max(0.0, 1.0 - abs(d.x) / 0.06)
    RB.param_uvs(bm, params, "seat", wrap_u=True)
    return RB.finish(name, bm, mat, chain(['d_ear1.' + s, 'd_ear2.' + s], 0.05))


# ------------------------------------------------------------------ materials, the build and the contract

def materials():
    body = K.mat(BODY_MAT, "26587E", BODY_PNG if os.path.exists(BODY_PNG) else None)
    tex = next((n for n in body.node_tree.nodes if n.type == "TEX_IMAGE"), None)
    if tex and tex.image:
        tex.image.name = IMAGE
        tex.image.reload()
    mask = bpy.data.materials.get(MASK_MAT) or bpy.data.materials.new(MASK_MAT)
    mask.use_nodes = True
    mask.use_backface_culling = False
    bsdf = next(n for n in mask.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    lin = K.srgb_to_lin("D8DDE3")
    bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.10
    bsdf.inputs["Alpha"].default_value = 1.0
    bsdf.inputs["Emission Strength"].default_value = 0.0
    mask.diffuse_color = (lin[0], lin[1], lin[2], 1.0)
    mask.metallic, mask.roughness = 1.0, 0.10
    return body, mask


def parts_list():
    return [o.name for o in bpy.data.objects if o.type == "MESH" and (o.name.startswith(P) or o.name == BODY)]


def build():
    assert C.is_open(BLEND)
    arm = rig()
    rest(arm)
    K.S["rig"] = arm
    old = parts_list()
    K.remove(old)
    body, mask = materials()
    parts = [build_torso(P + "Coat", body), build_collar(P + "Collar", body), build_neck(P + "Neck", body),
             build_skull(P + "Skull", body), build_mask(P + "Mask", mask)]
    for s, sx in SIDES:
        parts += [build_skirt_half(P + "Skirt_" + s, body, sx), build_sleeve(P + "Sleeve_" + s, body, s, sx),
                  build_cuff(P + "Cuff_" + s, body, s, sx), build_glove(P + "Glove_" + s, body, s, sx),
                  build_leg(P + "Leg_" + s, body, s, sx), build_boot(P + "Boot_" + s, body, s, sx),
                  build_ear(P + "Ear_" + s, body, s, sx)]
    counts = {p.name: sum(len(f.vertices) - 2 for f in p.data.polygons) for p in parts}
    out = MG.join(BODY, parts)
    ok, stats = check(out)
    print("parts (tris):", sorted(counts.items(), key=lambda kv: -kv[1]))
    bpy.ops.wm.save_mainfile()
    return ok, stats


def check(body=None):
    """anime_merge.check's contract on his rig (DenFa_Rig at the origin, one Armature modifier, one UV layer, weights
    on real deform bones (<= 4, normalised), unsplit smooth normals, opaque, culling off, no emission) with route RL's
    budgets (<= 10,000 tris, <= 3 surfaces) and his one exception: metal ONLY on den_fa_mask (DC-4). Prints OK/OVER."""
    body = body or bpy.data.objects[BODY]
    arm = rig()
    off = max(abs(arm.matrix_world[i][j] - (1.0 if i == j else 0.0)) for i in range(4) for j in range(4))
    me = body.data
    rows = {}
    arms = [m for m in body.modifiers if m.type == "ARMATURE"]
    rows["STRUCTURE"] = off < 1e-6 and len(arms) == 1 and arms[0].object == arm and len(body.modifiers) == 1 \
        and body.parent == arm and tuple(body.scale) == (1.0, 1.0, 1.0)
    rows["UV"] = len(me.uv_layers) == 1 and me.uv_layers[0].name == "UVMap"
    deform = {b.name for b in arm.data.bones if b.use_deform}
    gname = {g.index: g.name for g in body.vertex_groups}
    bad_w = 0
    for v in me.vertices:
        ws = [(gname[g.group], g.weight) for g in v.groups if g.weight > 1e-5]
        if not ws or len(ws) > 4 or abs(sum(w for _, w in ws) - 1.0) > 1e-3 or any(n not in deform for n, _ in ws):
            bad_w += 1
    rows["WEIGHTS"] = bad_w == 0
    sharp = any(a.name in ("sharp_edge", "sharp_face") and any(d.value for d in a.data) for a in me.attributes)
    rows["NORMALS"] = me.normals_domain == "POINT" and not sharp and not me.has_custom_normals and all(p.use_smooth for p in me.polygons)
    mats_ok = True
    for m in me.materials:
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m and m.use_nodes else None
        if m is None or bsdf is None or bsdf.inputs["Alpha"].is_linked or abs(bsdf.inputs["Alpha"].default_value - 1.0) > 1e-6 \
                or m.use_backface_culling or bsdf.inputs["Emission Strength"].default_value > 0.0 \
                or bsdf.inputs["Roughness"].default_value <= 0.0 \
                or (bsdf.inputs["Metallic"].default_value > 0.0 and m.name != MASK_MAT):
            mats_ok = False
    rows["MATERIALS"] = mats_ok and [m.name for m in me.materials] == [BODY_MAT, MASK_MAT]
    images = {n.image.name: n.image.size[:] for m in me.materials for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image}
    rows["TEXTURES"] = 1 <= len(images) <= 2 and all(max(sz) <= 1024 for sz in images.values())
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    rows["TRIS"] = tris <= TRI_BUDGET
    rows["SURFACES"] = 1 <= len(me.materials) <= SURFACE_CAP
    top = max((body.matrix_world @ v.co).z for v in me.vertices)
    rows["TOP"] = abs(top - TOP) <= 0.05
    report = "  ".join("%s %s" % (k, "OK" if ok else "OVER") for k, ok in rows.items())
    print("%s: %d tris (budget %d), %d surfaces (cap %d) %s, textures %s, rest top %.3f (%.2f +- 0.05), bad weights %d\n%s"
          % (body.name, tris, TRI_BUDGET, len(me.materials), SURFACE_CAP, [m.name for m in me.materials], images, top, TOP,
             bad_w, report))
    return all(rows.values()), {"tris": tris, "surfaces": len(me.materials), "top": round(top, 3), "textures": images}


def export(overwrite_ok=False):
    """DenFa_Rig + DenFa_Body only, to a NEW file (N5): refuses an existing GLB unless overwrite_ok (this story's own
    re-export after a clip or body change). Saves first and reverts after, in a finally (nothing the export does
    stays). The clips are built from their pose functions, never rewritten from other clips (no SRC_* copies)."""
    assert C.is_open(BLEND)
    assert GLB.endswith("_real.glb"), "never the shipped g9_den_fa.glb"
    assert overwrite_ok or not os.path.exists(GLB), "%s exists: export(overwrite_ok=True) to re-export it" % GLB
    arm = rig()
    rest(arm)
    body = bpy.data.objects[BODY]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in (arm, body):
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.wm.save_mainfile()
    try:
        bpy.ops.export_scene.gltf(filepath=GLB, use_selection=True, export_apply=False, export_skins=True,
                                  export_animations=True, export_yup=True)
        size = os.path.getsize(GLB)
    finally:
        bpy.ops.wm.revert_mainfile()
    return GLB, size
