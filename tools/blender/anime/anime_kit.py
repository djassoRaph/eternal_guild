# anime_kit.py - route AN (Story 25.30): the mesh, skinning and material helpers every AN character is built with,
# and build_base_body(): Base_Body, the neutral unclothed SD body on the stretched rig (the reference body of the
# foot report, the sit re-fit and the seated-room report; never exported).
#
# Generalised from the approved anime test (eternal_guild_art/anime_test/scripts/anime_body.py). The test's heights
# were absolute; here every height goes through Z(), a piecewise-linear map from the test rig's landmarks (ankle,
# hip joint, shoulder) to the current rig's, so a part drawn for the test lands on any AN rig built by anime_rig.py.
# Horizontal sizes are the test's. Build in the REST pose. Blender frame: front -Y, her left +X, up +Z.
import math

import bmesh
import bpy
from mathutils import Vector

import anime_common as C

TEST_LM = (0.0, 0.149, 0.923, 1.36)     # the approved test's floor, ankle, hip joint (upperleg head), shoulder
HR = Vector((0.245, 0.235, 0.29))        # the head's half sizes (the test's)
S = {}                                  # set by setup(): the rig's bones and landmarks


def setup(arm=None):
    arm = arm or C.rig()
    S["rig"] = arm
    S["bone"] = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}
    S["lm"] = (0.0, S["bone"]["foot.l"][0].z, S["bone"]["upperleg.l"][0].z, S["bone"]["upperarm.l"][0].z)
    S["hc"] = Vector((0.0, 0.0, Z(1.80)))
    return S


def Z(z):
    """The test's height z on this rig."""
    a, b = TEST_LM, S["lm"]
    if z >= a[-1]:
        return z + (b[-1] - a[-1])
    for i in range(len(a) - 1):
        if z <= a[i + 1]:
            t = (z - a[i]) / (a[i + 1] - a[i])
            return b[i] + t * (b[i + 1] - b[i])
    return z


def H(n):
    return S["bone"][n][0].copy()


def T(n):
    return S["bone"][n][1].copy()


def HC():
    return S["hc"].copy()


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def clamp01(x):
    return max(0.0, min(1.0, x))


# ------------------------------------------------------------------ materials (flat colours; the face takes an image)

def srgb_to_lin(hexrgb):
    r, g, b = (int(hexrgb[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in (r, g, b)]


def mat(name, hexrgb, image=None):
    """A Principled material, opaque by construction: its Alpha input unlinked at 1.0 (the glTF 4.5 exporter reads
    alphaMode from that socket) and backface culling off (glTF doubleSided -> Godot CULL_DISABLED)."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = False
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    lin = srgb_to_lin(hexrgb)
    bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
    m.diffuse_color = (lin[0], lin[1], lin[2], 1.0)       # the viewport / Workbench colour
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Alpha"].default_value = 1.0
    if image:
        tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None) or nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(image, check_existing=True)
        tex.image.use_fake_user = True
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m


# ------------------------------------------------------------------ mesh helpers (the test's)

def new_obj(name, bm, material, uv=True):
    if uv and not bm.loops.layers.uv:
        bm.loops.layers.uv.new("UVMap")
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    if me.uv_layers and me.uv_layers[0].name != "UVMap":
        me.uv_layers[0].name = "UVMap"
    ob = bpy.data.objects.get(name)
    if ob is None:
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
    else:
        ob.data = me
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def ring_frame(d, up_hint):
    u = up_hint - d * up_hint.dot(d)
    if u.length < 1e-4:
        u = Vector((1, 0, 0)) - d * d.x
    u.normalize()
    return u, d.cross(u).normalized()


def strand(bm, pts, radii, sides=8, flat=1.0, up_of=None, cap0=True, pole_tip=False):
    """A tube along pts with a radius per point; its cross-section squashed by `flat` along w. pole_tip closes the
    last ring to a point."""
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u, w = ring_frame(d, up_of(p) if up_of else Vector((0, 0, 1)))
        r = radii[i]
        if pole_tip and i == len(pts) - 1:
            rings.append([bm.verts.new(p)])
            continue
        rings.append([bm.verts.new(p + (u * math.cos(2 * math.pi * k / sides) + w * flat * math.sin(2 * math.pi * k / sides)) * r)
                      for k in range(sides)])
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(sides):
            if len(b) == 1:
                bm.faces.new((a[k], a[(k + 1) % sides], b[0]))
            else:
                bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    if cap0:
        bm.faces.new(list(reversed(rings[0])))
    if len(rings[-1]) > 1:
        bm.faces.new(rings[-1])


def loop_tube(bm, pts, r, sides=6):
    rings = []
    n = len(pts)
    for i, p in enumerate(pts):
        d = (pts[(i + 1) % n] - pts[i - 1]).normalized()
        u, w = ring_frame(d, Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0)))
        rings.append([bm.verts.new(p + (u * math.cos(2 * math.pi * k / sides) + w * math.sin(2 * math.pi * k / sides)) * r) for k in range(sides)])
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % n]
        for k in range(sides):
            bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))


def lathe(bm, profile, segs=24, sy=1.0, cx=0.0, cy=0.0):
    """Revolve [(r, z), ...] round a vertical axis; sy squashes the depth; r ~ 0 makes a pole."""
    rings = []
    for r, z in profile:
        if r < 1e-4:
            rings.append([bm.verts.new((cx, cy, z))])
        else:
            rings.append([bm.verts.new((cx + r * math.sin(2 * math.pi * k / segs), cy - sy * r * math.cos(2 * math.pi * k / segs), z)) for k in range(segs)])
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(segs):
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                bm.faces.new((a[0], b[(k + 1) % segs], b[k]))
            elif len(b) == 1:
                bm.faces.new((a[k], a[(k + 1) % segs], b[0]))
            else:
                bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))


def ellipsoid(bm, c, sx, sy, sz, seg=16, rings=10):
    res = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in res["verts"]:
        v.co = Vector((c.x + v.co.x * sx, c.y + v.co.y * sy, c.z + v.co.z * sz))
    return res["verts"]


def catmull(ctrl, n):
    P = [ctrl[0]] + list(ctrl) + [ctrl[-1]]
    out = []
    segs = len(ctrl) - 1
    for i in range(n):
        s = i / (n - 1) * segs
        k = min(int(s), segs - 1)
        t = s - k
        p0, p1, p2, p3 = P[k], P[k + 1], P[k + 2], P[k + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return out


def head_radius_at(theta, z, grow=0.0):
    hc = HC()
    k = max(0.0, 1 - ((z - hc.z) / HR.z) ** 2) ** 0.5
    rx, ry = HR.x * k + grow, HR.y * k + grow
    return rx * math.sin(theta), -ry * math.cos(theta)


def radial(p):
    hc = HC()
    v = Vector((p.x - hc.x, p.y - hc.y, 0))
    return v.normalized() if v.length > 1e-5 else Vector((0, -1, 0))


# ------------------------------------------------------------------ skinning (weights: <= 4 influences, normalised)

def skin(ob, fn):
    groups = {}
    for v in ob.data.vertices:
        ws = {b: w for b, w in fn(v.co).items() if w > 1e-4}
        ws = dict(sorted(ws.items(), key=lambda kv: -kv[1])[:4])
        tot = sum(ws.values()) or 1.0
        for bone, w in ws.items():
            if bone not in groups:
                groups[bone] = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
            groups[bone].add([v.index], w / tot, "REPLACE")
    ob.parent = S["rig"]
    arm = ob.modifiers.get("Armature") or ob.modifiers.new("Armature", "ARMATURE")
    arm.object = S["rig"]


def blend(a, b, t):
    t = clamp01(t)
    return {a: 1 - t, b: t} if a != b else {a: 1.0}


def chain(bones, blend_m=0.05):
    def fn(co):
        best, bi, bt = 1e9, 0, 0.0
        for i, n in enumerate(bones):
            a, b = H(n), T(n)
            ab = b - a
            t = clamp01((co - a).dot(ab) / ab.length_squared)
            dd = (a + ab * t - co).length
            if dd < best:
                best, bi, bt = dd, i, t
        n = bones[bi]
        L = (T(n) - H(n)).length
        if bi + 1 < len(bones) and (1 - bt) * L < blend_m:
            return blend(n, bones[bi + 1], 0.5 - (1 - bt) * L / (2 * blend_m))
        if bi > 0 and bt * L < blend_m:
            return blend(bones[bi - 1], n, 0.5 + bt * L / (2 * blend_m))
        return {n: 1.0}
    return fn


def torso_w(co):
    z = co.z
    if z < Z(0.99):
        return {"hips": 1.0}
    if z < Z(1.07):
        return blend("hips", "spine", (z - Z(0.99)) / (Z(1.07) - Z(0.99)))
    if z < Z(1.20):
        return {"spine": 1.0}
    if z < Z(1.28):
        return blend("spine", "chest", (z - Z(1.20)) / (Z(1.28) - Z(1.20)))
    return {"chest": 1.0}


def neck_w(co):
    return blend("chest", "head", (co.z - Z(1.46)) / 0.08)


def head_w(co):
    return {"head": 1.0}


def shoulder_w(s):
    """The shoulder blend (the test's mantles were rigid 35/65): chest near the collar, the upper arm outward."""
    def fn(co):
        k = clamp01((abs(co.x) - 0.13) / 0.14)
        return {"chest": 1 - 0.75 * k, "upperarm." + s: 0.75 * k}
    return fn


# ------------------------------------------------------------------ body parts (skin or clothed by the caller's material)

TORSO = [(0.0, 0.905), (0.132, 0.91), (0.143, 0.96), (0.118, 1.07), (0.121, 1.14), (0.146, 1.23), (0.150, 1.30),
         (0.140, 1.36), (0.108, 1.415), (0.060, 1.45), (0.0, 1.455)]
TORSO_SY = 0.72


def torso_r(z_test, girth=1.0):
    """The torso lathe's radius at the test's height z_test (times the body's torso girth)."""
    for (r0, z0), (r1, z1) in zip(TORSO[1:-2], TORSO[2:-1]):
        if z0 <= z_test <= z1:
            return (r0 + (r1 - r0) * (z_test - z0) / (z1 - z0)) * girth
    return 0.12 * girth


FACE_SKIN_V = 0.02          # a face-texture row with nothing painted on it (anime_face: the chin is v 0.0, the mouth ~0.15)


def build_head(name, material, face_uv=True, useg=36, vseg=26):
    hc = HC()
    bm = bmesh.new()
    res = bmesh.ops.create_uvsphere(bm, u_segments=useg, v_segments=vseg, radius=1.0)
    for v in res["verts"]:
        x, y, z = v.co.x * HR.x, v.co.y * HR.y, v.co.z * HR.z
        if z < 0:                                           # the anime jaw: narrow, a soft point at the chin
            t = -z / HR.z
            x *= 1 - 0.42 * t ** 1.6
            y *= (1 - 0.48 * t ** 1.5) if y > 0 else (1 - 0.12 * t ** 2)
            y -= 0.028 * t ** 3
        if z > 0 and y > 0:
            y *= 1.06                                       # a rounder back of the skull
        v.co = hc + Vector((x, y, z))
    lay = bm.loops.layers.uv.new("UVMap")
    chin = hc.z - HR.z
    for f in bm.faces:
        c = f.calc_center_median()
        # decided per FACE (25.31; per corner, a face straddling the cut mixed projected and fallback corners and
        # smeared eye / blush / lip texels across her left cheek): the front faces take the face texture's projection,
        # u = 0.5 + x / 0.5, v = (z - chin) / (crown - chin); the others one texel at that side's edge (u 0.02 / 0.98)
        # on a row with nothing painted on it (FACE_SKIN_V), so a seam face's neighbour samples skin
        front = face_uv and c.y < 0.03
        fallback = (0.98 if c.x > 0 else 0.02, FACE_SKIN_V)
        for l in f.loops:
            p = l.vert.co
            l[lay].uv = (0.5 + p.x / 0.5, (p.z - chin) / (2 * HR.z)) if front else fallback
    ob = new_obj(name, bm, material)
    skin(ob, head_w)
    return ob


def build_neck(name, material):
    bm = bmesh.new()
    strand(bm, [Vector((0, 0.005, Z(1.40))), Vector((0, 0.01, Z(1.50))), Vector((0, 0.012, Z(1.58)))], [0.052, 0.050, 0.050], sides=12)
    ob = new_obj(name, bm, material)
    skin(ob, neck_w)
    return ob


def build_torso(name, material, bust=0.0, girth=1.0, belly=0.0):
    """girth scales the radii (burly bodies, AH-5); belly pushes the front of the lower torso forward (m)."""
    bm = bmesh.new()
    lathe(bm, [(r * girth, Z(z)) for r, z in TORSO], segs=28, sy=TORSO_SY)
    if belly:
        for v in bm.verts:
            if v.co.y < 0:
                v.co.y -= belly * math.exp(-((v.co.z - Z(1.05)) / 0.11) ** 2) * math.exp(-(v.co.x / 0.11) ** 2)
    if bust:
        for v in bm.verts:
            if v.co.y < 0:
                v.co.y -= bust * math.exp(-((v.co.z - Z(1.255)) / 0.045) ** 2) * math.exp(-((abs(v.co.x) - 0.06) / 0.06) ** 2)
    ob = new_obj(name, bm, material)
    skin(ob, torso_w)
    return ob


def arm_pts(s):
    sx = 1 if s == "l" else -1
    sh = Vector((0.13 * sx, 0, H("upperarm." + s).z))
    el, wr = H("lowerarm." + s), H("wrist." + s)
    return sh, el, wr


def build_arm(name, material, s, radii=None, sides=12, rings=12, girth=1.0):
    sh, el, wr = arm_pts(s)
    pts = catmull([sh, el, wr + (wr - el).normalized() * 0.02], rings)
    radii = radii or [(0.049 - 0.009 * (i / (rings - 1)) ** 0.7 + (0.006 if i == rings - 1 else 0.0)) * girth for i in range(rings)]
    bm = bmesh.new()
    strand(bm, pts, radii, sides=sides)
    arm_fn = chain(["upperarm." + s, "lowerarm." + s, "wrist." + s, "hand." + s])

    def fn(co):
        w = arm_fn(co)
        k = clamp01((0.21 - abs(co.x)) / 0.07)
        if k > 0:
            w = {b: v * (1 - k) for b, v in w.items()}
            w["chest"] = w.get("chest", 0) + k
        return w
    ob = new_obj(name, bm, material)
    skin(ob, fn)
    return ob


def build_hand(name, material, s, lod=1.0, scale=1.0):
    """The hand, built round the re-seated handslot (N6), reaching back inside the cuff. scale: bigger hands for burly
    bodies (the palm stays on the slot)."""
    sh, el, wr = arm_pts(s)
    d = (wr - el).normalized()
    c = H("handslot." + s)                                  # the palm's centre (anime_rig re-seats the slot there)
    q = lambda n: max(4, int(round(n * lod)))
    k = scale
    bm = bmesh.new()
    ellipsoid(bm, c, 0.066 * k, 0.042 * k, 0.025 * k, q(12), q(8))
    ellipsoid(bm, wr + d * 0.055 + Vector((0, -0.036, 0.004)) * k, 0.026 * k, 0.014 * k, 0.014 * k, q(8), q(6))    # the thumb
    ellipsoid(bm, wr + d * 0.005, 0.034 * k, 0.030 * k, 0.024 * k, q(10), q(6))                                  # the wrist, into the cuff
    ob = new_obj(name, bm, material)
    skin(ob, chain(["wrist." + s, "hand." + s], 0.02))
    return ob


def build_leg(name, material, s, sides=12, rings=14, girth=1.0, radii=None):
    """A leg (or a trouser leg: anime_garments.build_trousers passes its radii). girth scales the default radii."""
    sx = 1 if s == "l" else -1
    hip, knee, ank = Vector((0.105 * sx, 0, H("upperleg." + s).z + 0.007)), T("upperleg." + s), T("lowerleg." + s)
    bm = bmesh.new()
    top = hip + (knee - hip) * 0.14
    pts = catmull([top, knee, ank], rings)
    radii = radii or [(0.070 - 0.027 * (i / (rings - 1))) * girth for i in range(rings)]
    # a near-vertical tube takes the front as its ring axis (an up hint along the tube flips the rings: the knee pinch)
    strand(bm, pts, radii, sides=sides, up_of=lambda p: Vector((0, -1, 0)))
    leg_fn = chain(["upperleg." + s, "lowerleg." + s, "foot." + s], 0.06)
    zb = Z(0.86)

    def fn(co):
        w = leg_fn(co)
        k = clamp01((co.z - zb) / 0.07)
        if k > 0:
            w = {b: v * (1 - k) for b, v in w.items()}
            w["hips"] = w.get("hips", 0) + k
        return w
    ob = new_obj(name, bm, material)
    skin(ob, fn)
    return ob


def build_foot(name, material, s, boot_top=None, sides=12):
    """A foot (or a knee-high boot when boot_top is given, 0..1 down the shin) with a flat sole on the floor."""
    sx = 1 if s == "l" else -1
    knee, ank = T("upperleg." + s), T("lowerleg." + s)
    bm = bmesh.new()
    if boot_top is not None:
        top = knee + (ank - knee) * boot_top
        strand(bm, catmull([top, ank + Vector((0, 0.005, 0.02))], 8), [0.062, 0.061, 0.059, 0.057, 0.055, 0.053, 0.052, 0.052], sides=sides,
               up_of=lambda p: Vector((0, -1, 0)))
        loop_tube(bm, [top + Vector((0.066 * math.cos(2 * math.pi * k / 14), 0.066 * math.sin(2 * math.pi * k / 14), 0.0)) for k in range(14)], 0.010, sides=4)
    foot = [Vector((0.105 * sx, 0.055, 0.075)), Vector((0.105 * sx, 0.0, 0.07)), Vector((0.105 * sx, -0.09, 0.052)), Vector((0.105 * sx, -0.19, 0.038))]
    strand(bm, catmull(foot, 8), [0.052, 0.054, 0.052, 0.048, 0.044, 0.038, 0.030, 0.012], sides=sides)
    for v in bm.verts:
        if v.co.z < 0.004:
            v.co.z = 0.004                                  # a flat sole on the floor
    ob = new_obj(name, bm, material)
    skin(ob, chain(["lowerleg." + s, "foot." + s, "toes." + s], 0.04))
    return ob


def build_pelvis(name, material, girth=1.0):
    """The hips and the tops of the thighs, closing the gap between the torso and the legs (hips-weighted)."""
    bm = bmesh.new()
    lathe(bm, [(r * girth, z) for r, z in [(0.128, Z(0.93)), (0.136, Z(0.89)), (0.132, Z(0.85)), (0.112, Z(0.815)), (0.0, Z(0.80))]],
          segs=28, sy=TORSO_SY + 0.06)
    ob = new_obj(name, bm, material)
    skin(ob, lambda co: {"hips": 1.0})
    return ob


def remove(names):
    for n in names:
        o = bpy.data.objects.get(n)
        if o:
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if isinstance(me, bpy.types.Mesh) and me.users == 0:
                bpy.data.meshes.remove(me)


# A body's params (F6; AH-5: variety from girth, not from new rigs). The defaults are Base_Body's: x 1.0 is exact, so
# build_base_body() with no arguments yields the identical joined Base_Body (4,872 tris; 25.31 V17).
BODY = {"skin": "F7DECF", "torso_girth": 1.0, "belly": 0.0, "bust": 0.0, "arm_girth": 1.0, "leg_girth": 1.0,
        "hand_scale": 1.0, "pelvis_girth": 1.0, "head_seg": (36, 26), "arm_seg": (12, 12), "leg_seg": (12, 14), "hand_lod": 1.0,
        "foot_sides": 12, "boot_top": None}
PARTS = ("head", "neck", "torso", "pelvis", "arm_l", "arm_r", "hand_l", "hand_r", "leg_l", "leg_r", "foot_l", "foot_r")
BASE_PARTS = ["Base_" + k[0].upper() + k[1:] for k in PARTS]       # Base_Head ... Base_Foot_r


def body_params(params=None):
    """BODY with the caller's overrides (an unknown key refuses: a typo would silently build the default)."""
    params = dict(params or {})
    unknown = sorted(set(params) - set(BODY))
    assert not unknown, "unknown body params %s (known: %s)" % (unknown, sorted(BODY))
    out = dict(BODY)
    out.update(params)
    return out


def build_base_body(params=None, join=True, prefix="Base_", material=None, face=None):
    """The skin parts of a body from params (body_params: skin colour, torso girth and belly, bust, arm and leg girth,
    hand scale, pelvis girth, segment counts, boots).
    join=True (chain step 3): one object `Base_Body`, one skin material: the neutral reference body (never exported).
    join=False: a character's parts unjoined, {part: object} for PARTS, named prefix + Head ... Foot_r, in `material`
    (default: a skin material) with the head in `face` (face-projected UVs) when given; the caller paints them, adds
    its garments and joins (anime_merge.join). Code review F6."""
    p = body_params(params)
    setup()
    names = {k: prefix + k[0].upper() + k[1:] for k in PARTS}
    remove(list(names.values()) + (["Base_Body"] if join else []))
    m = material or mat("AN_BaseSkin" if join else prefix + "Skin", p["skin"])
    hu, hv = p["head_seg"]
    asd, ari = p["arm_seg"]
    lsd, lri = p["leg_seg"]
    parts = {"head": build_head(names["head"], face or m, face_uv=face is not None, useg=hu, vseg=hv),
             "neck": build_neck(names["neck"], m),
             "torso": build_torso(names["torso"], m, bust=p["bust"], girth=p["torso_girth"], belly=p["belly"]),
             "pelvis": build_pelvis(names["pelvis"], m, girth=p["pelvis_girth"])}
    for s in ("l", "r"):
        parts["arm_" + s] = build_arm(names["arm_" + s], m, s, sides=asd, rings=ari, girth=p["arm_girth"])
    for s in ("l", "r"):
        parts["hand_" + s] = build_hand(names["hand_" + s], m, s, lod=p["hand_lod"], scale=p["hand_scale"])
    for s in ("l", "r"):
        parts["leg_" + s] = build_leg(names["leg_" + s], m, s, sides=lsd, rings=lri, girth=p["leg_girth"])
    for s in ("l", "r"):
        parts["foot_" + s] = build_foot(names["foot_" + s], m, s, boot_top=p["boot_top"], sides=p["foot_sides"])
    if not join:
        return parts
    objs = [parts[k] for k in PARTS]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "Base_Body"
    body.data.name = "Base_Body"
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    top = max(v.co.z for v in body.data.vertices)
    print("Base_Body: %d tris, rest top %.3f" % (tris, top))
    return body
