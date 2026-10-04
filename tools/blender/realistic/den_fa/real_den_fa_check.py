# real_den_fa_check.py - Story 25.32 T5 (AC 5): Den Fa's checks on the realistic body, from Story 25.10's den_sitcheck.py
# (<art>/pipeline_ref/25_10/): every clip against the hearth's real geometry (the bench box, the wall face, the chimney
# face), the wood store's line of sight with 10 logs, the self-clip checks (a) hands and forearms vs the coat front,
# (b) thighs vs the coat, (c) the glove inside the cuff; and the runtime numbers (MASK_SEATED, MASK_STANDING,
# BUBBLE_SEATED). Each check is first shown to report a hit on a deliberately bad pose (proofs()) before a zero is
# trusted (mistakes-log, Den Fa). Godot (x, y, z) = Blender (x, -z, y) here (the tavern's world, the rig moved to
# seat_root and turned to the SitPoint's facing); rays are cast in the OBJECT's space (matrix_world.inverted()).
# Also the renders (shots) for T4 / T9.
import math
import os

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector
from mathutils.bvhtree import BVHTree

import anime_common as C
import real_den_fa as DF
import real_den_fa_anims as DA

SIT_POINT = Vector((-4.540, 0.550, -7.680))          # Godot world (Hearth/SitPoint composed, T0)
FWD = Vector((0.906308, 0.0, -0.422618))
YAW = math.atan2(FWD.x, FWD.z)
RIGHT = Vector((-FWD.z, 0.0, FWD.x))                 # his right, the room side
ROOT_G = SIT_POINT + FWD * DA.HIP_BACK + RIGHT * DA.SEAT_SIDE
ROOT_G.y = SIT_POINT.y - DA.SEAT_UP
BENCH = ((-4.87, -4.13), (0.10, 0.55), (-8.05, -7.27))
WALL_X = -4.83
CHIMNEY_Z, CHIMNEY_Y, CHIMNEY_X = -7.97, 0.68, -3.40
LOGS_G = [Vector((-4.49, y, -7.445 - 0.115 * i)) for i in range(5) for y in (0.16, 0.265)]   # 10 slots (WoodStore)
CAM_DIR_G = Vector((0.612, 0.5, 0.612)).normalized()     # from the scene toward the tavern camera
TIMES = (0.0, 0.25, 0.5, 0.75, 1.0)


def g2b(g):
    return Vector((g.x, -g.z, g.y))


def b2g(b):
    return Vector((b.x, b.z, -b.y))


def _rig_body():
    return DF.rig(), bpy.data.objects[DF.BODY]


def place(arm, at_seat=True):
    if at_seat:
        arm.location = g2b(ROOT_G)
        arm.rotation_euler = Euler((0, 0, YAW), 'XYZ')
    else:
        arm.location = (0, 0, 0)
        arm.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()


def restore():
    arm = DF.rig()
    place(arm, False)
    DF.rest(arm)


def _clip_at(arm, clip, t):
    """The clip's KEYS at t (0..1), through its action (what the GLB carries)."""
    act = bpy.data.actions[clip]
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    f0, f1 = act.frame_range
    bpy.context.scene.frame_set(int(round(f0 + (f1 - f0) * t)))
    bpy.context.view_layer.update()


def _world_verts(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    polys = [tuple(p.vertices) for p in me.polygons]
    M = np.array(ev.matrix_world)
    ev.to_mesh_clear()
    w = co @ M[:3, :3].T + M[:3, 3]
    return co, w, polys


def world_hits(w):
    """Blender world verts (n, 3) -> counts in the bench box, behind the wall face, past the chimney face (Godot)."""
    gx, gy, gz = w[:, 0], w[:, 2], -w[:, 1]
    bench = (gx > BENCH[0][0]) & (gx < BENCH[0][1]) & (gy > BENCH[1][0]) & (gy < BENCH[1][1]) & (gz > BENCH[2][0]) & (gz < BENCH[2][1])
    wall = gx < WALL_X
    chim = (gz < CHIMNEY_Z) & (gy > CHIMNEY_Y) & (gx < CHIMNEY_X)
    worst = {"bench": float(np.max(BENCH[1][1] - gy[bench])) if bench.any() else 0.0,
             "wall": float(np.max(WALL_X - gx[wall])) if wall.any() else 0.0,
             "chimney": float(np.max(CHIMNEY_Z - gz[chim])) if chim.any() else 0.0}
    return {"bench": int(bench.sum()), "wall": int(wall.sum()), "chimney": int(chim.sum())}, worst, bench | wall | chim


def _groups_of(ob, mask):
    gname = {g.index: g.name for g in ob.vertex_groups}
    out = {}
    for i in np.nonzero(mask)[0]:
        v = ob.data.vertices[int(i)]
        g = max(v.groups, key=lambda x: x.weight).group if v.groups else -1
        n = gname.get(g, "-")
        out[n] = out.get(n, 0) + 1
    return out


def clearance():
    """AC 5 world clearance: every clip at t 0, 0.25, 0.5, 0.75, 1 with the rig at seat_root. {clip: {t: counts}}."""
    arm, ob = _rig_body()
    place(arm, True)
    rep, total = {}, 0
    try:
        for clip in DA.CLIPS:
            rep[clip] = {}
            for t in TIMES:
                _clip_at(arm, clip, t)
                _, w, _ = _world_verts(ob)
                n, worst, bad = world_hits(w)
                if sum(n.values()):
                    rep[clip][t] = (n, {k: round(v, 3) for k, v in worst.items()}, _groups_of(ob, bad))
                total += sum(n.values())
    finally:
        restore()
    print("world clearance: %d vertices in the bench / wall / chimney %s  %s" % (total, rep, "OK" if total == 0 else "OVER"))
    return total, rep


ROUTE_1 = Vector((-3.3, 0.1, -7.8))     # bar_route's second point: his walk leaves the seat root toward it (and returns)
WALK_SPEED = 1.1


def walk_route_clearance(step=2):
    """Walk as the game plays it near the hearth: the root moving at WALK_SPEED from seat_root toward bar_route's next
    point (the first 1.5 cycles), and back to seat_root from it (the last 1.5 cycles, facing the bench), every key
    frame. (Walk held in place AT seat_root is what clearance() samples: a pose he never holds there.)"""
    arm, ob = _rig_body()
    act = bpy.data.actions["Walk"]
    f0, f1 = (int(x) for x in act.frame_range)
    cyc = (f1 - f0) / DA.FPS
    root = Vector((ROOT_G.x, 0.0, ROOT_G.z))
    tgt = Vector((ROUTE_1.x, 0.0, ROUTE_1.z))
    d = (tgt - root).normalized()
    total, rep = 0, {}
    try:
        arm.animation_data.action = act
        for leg, sgn in (("leave", 1.0), ("return", -1.0)):
            frames = range(0, int(1.5 * (f1 - f0)) + 1, step)
            for k in frames:
                s = k / DA.FPS * WALK_SPEED                          # metres walked
                if leg == "leave":
                    pos, face = root + d * s, d
                else:
                    pos, face = root + d * (1.5 * cyc * WALK_SPEED - s), -d
                arm.location = g2b(Vector((pos.x, ROOT_G.y, pos.z)))
                arm.rotation_euler = Euler((0, 0, math.atan2(face.x, face.z)), 'XYZ')
                bpy.context.scene.frame_set(f0 + k % (f1 - f0))
                bpy.context.view_layer.update()
                _, w, _ = _world_verts(ob)
                n, worst, bad = world_hits(w)
                if sum(n.values()):
                    rep[(leg, k)] = (n, _groups_of(ob, bad))
                total += sum(n.values())
    finally:
        restore()
    print("walk on the route: %d vertices in the bench / wall / chimney %s  %s" % (total, rep, "OK" if total == 0 else "OVER"))
    return total, rep


def log_hits(clip="Sit", t=0.0, pose=None):
    """How many of the 10 log slots have their line of sight to the camera blocked by his mesh (rays in object space)."""
    arm, ob = _rig_body()
    place(arm, True)
    try:
        if pose is None:
            _clip_at(arm, clip, t)
        else:
            arm.animation_data.action = None
            DA.apply_pose(arm, pose)
            bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        ev = ob.evaluated_get(dg)
        tree = BVHTree.FromObject(ev, dg)            # in the OBJECT's local space: move the rays there
        inv = ev.matrix_world.inverted()
        d = (inv.to_3x3() @ g2b(CAM_DIR_G)).normalized()
        blocked = []
        for i, lg in enumerate(LOGS_G):
            o = inv @ g2b(lg)
            loc, nrm, idx, dist = tree.ray_cast(o, d, 20.0)
            if loc is not None:
                blocked.append(i)
    finally:
        restore()
    return blocked


def _region_verts(ob, regions):
    """The vertices of the body-atlas faces whose UV centroid lies strictly inside one of the real_layout.REG regions
    (the parts are told apart by their regions; regions share edges, so a corner test would leak; the mask's faces are
    never in a region)."""
    import real_layout as L
    me = ob.data
    uv = me.uv_layers[0].data
    out = set()
    boxes = [L.REG[r] for r in regions]
    for p in me.polygons:
        if me.materials[p.material_index].name == DF.MASK_MAT:
            continue
        u = sum(uv[li].uv[0] for li in p.loop_indices) / p.loop_total
        v = sum(uv[li].uv[1] for li in p.loop_indices) / p.loop_total
        if any(b[0] < u < b[2] and b[1] < v < b[3] for b in boxes):
            out.update(p.vertices)
    return out


def _polys_in(ob, verts):
    return [i for i, p in enumerate(ob.data.polygons) if all(v in verts for v in p.vertices)]


def _sel():
    arm, ob = _rig_body()
    DF.rest(arm)
    rest = np.array([v.co[:] for v in ob.data.vertices])
    coat = _region_verts(ob, ("shirt", "apron", "sleeve", "bib"))
    coat_front = _region_verts(ob, ("shirt", "apron"))
    skirt = _region_verts(ob, ("apron",))
    legs = np.array(sorted(_region_verts(ob, ("trousers",))))
    gloves = np.array(sorted(_region_verts(ob, ("hand",))))
    sleeves = np.array(sorted(_region_verts(ob, ("sleeve",))))
    gname = {g.index: g.name for g in ob.vertex_groups}
    side = {}
    for i in legs:
        v = ob.data.vertices[int(i)]
        ws = [(g.weight, gname[g.group]) for g in v.groups]
        if ws and max(ws)[1].startswith("d_thigh."):
            side[int(i)] = max(ws)[1][-1]
    thighs = np.array([i for i in legs if int(i) in side])
    band = thighs[(rest[thighs][:, 2] > 0.70) & (rest[thighs][:, 2] < 1.10)]
    return {"arm": arm, "ob": ob, "rest": rest, "coat_polys": _polys_in(ob, coat_front), "skirt_polys": _polys_in(ob, skirt),
            "band": band, "side": side, "gloves": gloves, "sleeves": sleeves,
            "cuffs": {s: np.array(sorted(i for i in _region_verts(ob, ("roll",)) if (rest[i][0] > 0) == (s == "L"))) for s in "LR"},
            "hands": {s: np.array([i for i in gloves if (rest[i][0] > 0) == (s == "L")]) for s in "LR"}}


def _eval(ob):
    co, _, polys = _world_verts(ob)          # the rig at the origin here: object space = armature space
    return co, polys


def _check_a(co, polys, sel):
    """(a) glove and sleeve-forearm vertices inside the coat's closed body front: a ray from the vertex toward the
    body's axis (x 0, y 0 at its height) that meets the coat surface is outside; one that doesn't is inside or behind
    it. Counted only in front of the body's axis and within 0.40 m of it."""
    bvh = BVHTree.FromPolygons([Vector(c) for c in co], [polys[i] for i in sel["coat_polys"]])
    idx = np.concatenate([sel["gloves"], sel["sleeves"][sel["rest"][sel["sleeves"]][:, 2] < 1.45]])
    n = 0
    for i in idx:
        p = Vector(co[int(i)])
        axis = Vector((0.0, 0.0, p.z))
        d = axis - p
        d.z = 0.0
        if p.y > -0.02 or d.length > 0.40 or d.length < 1e-6 or p.z > 2.0 or p.z < 0.5:
            continue
        hit = bvh.ray_cast(p, d.normalized(), d.length)
        if hit[0] is None:
            n += 1                       # no coat between it and the axis: inside the coat
    return n


def _check_b(co, polys, sel):
    """(b) for every covered thigh vertex, the ray from the thigh's axis through it must hit the skirt at or beyond the
    vertex (a hit before: a poke; none: open, unless the ray points more than ~12 deg down: under the hem)."""
    arm = sel["arm"]
    bvh = BVHTree.FromPolygons([Vector(c) for c in co], [polys[i] for i in sel["skirt_polys"]])
    pokes, opened, deep = 0, 0, 0.0
    for i in sel["covered"]:
        p = Vector(co[int(i)])
        pb = arm.pose.bones["d_thigh." + sel["side"][int(i)]]
        a, b = pb.head, pb.tail
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
        ax = a + ab * t
        d = p - ax
        if d.length < 1e-6:
            continue
        hit = bvh.ray_cast(ax, d.normalized(), 3.0)
        if hit[0] is None:
            if d.normalized().z >= -0.2:
                opened += 1
        elif hit[3] < d.length - 1e-4:
            pokes += 1
            deep = max(deep, d.length - hit[3])
    return pokes, opened, round(deep, 4)


def _check_c(co, sel):
    """(c) per side, the glove's vertices inside the cuff's axial span must stay within its inner radius."""
    n, worst = 0, 0.0
    for s in "LR":
        cv = co[sel["cuffs"][s]]
        c = cv.mean(axis=0)
        axis = np.linalg.svd(cv - c)[2][-1]
        rel = cv - c
        ax = rel @ axis
        inner = float(np.min(np.linalg.norm(rel - np.outer(ax, axis), axis=1)))
        lo, hi = float(np.min(ax)), float(np.max(ax))
        hr = co[sel["hands"][s]] - c
        hax = hr @ axis
        m = (hax >= lo) & (hax <= hi)
        if np.any(m):
            rad = np.linalg.norm(hr[m] - np.outer(hax[m], axis), axis=1)
            ex = rad - inner
            n += int(np.sum(ex > 0))
            worst = max(worst, float(np.max(ex)))
    return n, round(worst, 4)


def _covered(sel):
    """The band's thigh vertices the skirt covers at rest (a clip must keep them covered)."""
    arm, ob = sel["arm"], sel["ob"]
    DF.rest(arm)
    co, polys = _eval(ob)
    sel["covered"] = sel["band"]
    keep = []
    bvh = BVHTree.FromPolygons([Vector(c) for c in co], [polys[i] for i in sel["skirt_polys"]])
    for i in sel["band"]:
        p = Vector(co[int(i)])
        pb = arm.pose.bones["d_thigh." + sel["side"][int(i)]]
        a, b = pb.head, pb.tail
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
        d = p - (a + ab * t)
        hit = bvh.ray_cast(a + ab * t, d.normalized(), 3.0)
        if hit[0] is not None and hit[3] >= d.length - 1e-4:
            keep.append(int(i))
    sel["covered"] = np.array(keep)
    return len(sel["band"]), len(keep)


A_CLIPS = ("Idle", "Point", "Sit")
B_CLIPS = ("Walk", "Sit", "StandUp", "SitDown")


def self_clips(step=2):
    """(a) in Idle, Point and Sit; (b) in Walk, Sit, StandUp, SitDown; (c) every clip; every key frame (step)."""
    sel = _sel()
    band, cov = _covered(sel)
    arm, ob = sel["arm"], sel["ob"]
    place(arm, False)
    rep = {"a": {}, "b": {}, "c": {}, "band": (band, cov)}
    try:
        for clip in DA.CLIPS:
            act = bpy.data.actions[clip]
            arm.animation_data.action = act
            f0, f1 = (int(x) for x in act.frame_range)
            for f in range(f0, f1 + 1, step):
                bpy.context.scene.frame_set(f)
                co, polys = _eval(ob)
                if clip in A_CLIPS:
                    n = _check_a(co, polys, sel)
                    if n > rep["a"].get(clip, (0, None))[0]:
                        rep["a"][clip] = (n, f)
                if clip in B_CLIPS:
                    pk, op, dp = _check_b(co, polys, sel)
                    if pk + op > sum(rep["b"].get(clip, (0, 0, 0.0, None))[:2]):
                        rep["b"][clip] = (pk, op, dp, f)
                n, ex = _check_c(co, sel)
                if n > rep["c"].get(clip, (0, 0.0, None))[0]:
                    rep["c"][clip] = (n, ex, f)
    finally:
        restore()
    total = sum(v[0] for v in rep["a"].values()) + sum(v[0] + v[1] for v in rep["b"].values()) + sum(v[0] for v in rep["c"].values())
    print("self-clips (a) hands/forearms in the coat %s  (b) thighs vs coat (pokes, open, deepest, frame) %s  (c) glove out of the cuff %s"
          "  thigh band %s covered at rest  %s" % (rep["a"], rep["b"], rep["c"], rep["band"], "OK" if total == 0 else "OVER"))
    return total, rep


def proofs():
    """Every check reports on a deliberately bad pose (else its zero proves nothing): world (the rig sunk 0.3 m into
    the bench in Sit), logs (a pose with both legs straight out over the store), (a) the left hand pushed into the
    coat's belly, (b) the left thigh swung out and up through the skirt, (c) the left hand pushed 9 cm back up into its cuff and 6 cm sideways (through its wall)."""
    out = {}
    arm, ob = _rig_body()
    place(arm, True)
    try:
        _clip_at(arm, "Sit", 0.0)
        arm.location.z -= 0.30
        bpy.context.view_layer.update()
        _, w, _ = _world_verts(ob)
        out["world"] = sum(world_hits(w)[0].values())
    finally:
        restore()
    bad = DA.sit_pose(0.0)
    for s in ("L", "R"):
        bad['d_thigh.%s' % s] = {'r': [('X', -60), ('Z', -45)]}
        bad['d_shin.%s' % s] = {'r': [('X', 0)]}
    out["logs"] = len(log_hits(pose=bad))
    sel = _sel()
    _covered(sel)
    arm = sel["arm"]
    place(arm, False)
    try:
        DA.apply_pose(arm, DA.idle_pose(0.0))
        bpy.context.view_layer.update()
        pb = arm.pose.bones["d_hand.L"]
        head = pb.matrix.to_translation()                    # the hand moved into the coat's belly (armature space)
        pb.matrix = Matrix.Translation(Vector((0.05, -0.04, head.z)) - head) @ pb.matrix
        bpy.context.view_layer.update()
        co, polys = _eval(sel["ob"])
        out["a"] = _check_a(co, polys, sel)
        DA.apply_pose(arm, DA.idle_pose(0.0))
        arm.pose.bones["d_thigh.L"].rotation_quaternion = DA.local_quat(arm, "d_thigh.L", [('Y', -75), ('X', -60)])
        bpy.context.view_layer.update()
        co, polys = _eval(sel["ob"])
        out["b"] = _check_b(co, polys, sel)
        DA.apply_pose(arm, DA.idle_pose(0.0))
        arm.pose.bones["d_hand.L"].location = Vector((0.06, -0.09, 0.0))   # bone axes: back up into the cuff and sideways
        bpy.context.view_layer.update()
        co, polys = _eval(sel["ob"])
        out["c"] = _check_c(co, sel)
    finally:
        restore()
    print("proofs (deliberately bad poses; every count must be > 0): %s" % out)
    counts = {"world": out["world"], "logs": out["logs"], "a": out["a"], "b": out["b"][0] + out["b"][1], "c": out["c"][0]}
    assert all(v > 0 for v in counts.values()), "a check never reports on its bad pose: its zero proves nothing %s" % counts
    return out


def numbers():
    """den_fa.gd's MASK_SEATED / MASK_STANDING (the mask surface's centre from his root, Godot axes: x his left, y up,
    z forward) in Sit and Idle at t 0, BUBBLE_SEATED (the seated head top + 0.1) and the tops."""
    arm, ob = _rig_body()
    place(arm, False)
    out = {}
    try:
        mask_idx = [p.vertices for p in ob.data.polygons if ob.data.materials[p.material_index].name == DF.MASK_MAT]
        mask_v = sorted({i for vs in mask_idx for i in vs})
        for clip, key in (("Sit", "MASK_SEATED"), ("Idle", "MASK_STANDING")):
            _clip_at(arm, clip, 0.0)
            co, _ = _eval(ob)
            m = co[mask_v]
            # the outer surface's centre: the mask vertex farthest along the posed d_mask bone (its front pole)
            pb = arm.pose.bones["d_mask"]
            h, d = np.array(pb.head), np.array((pb.tail - pb.head).normalized())
            c = m[int(np.argmax((m - h) @ d))]
            out[key] = (round(float(c[0]), 3), round(float(c[2]), 3), round(float(-c[1]), 3))
            out[key + "_top"] = round(float(co[:, 2].max()), 3)
        out["BUBBLE_SEATED"] = round(out["MASK_SEATED_top"] + 0.1, 2)
    finally:
        restore()
    print("numbers:", out)
    return out


# ------------------------------------------------------------------ renders

def _marker(name, h, x, colour):
    ob = bpy.data.objects.get(name)
    if ob is None:
        me = bpy.data.meshes.new(name)
        import bmesh
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * 0.14, v.co.y * 0.14, (v.co.z + 0.5) * h))
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        m = bpy.data.materials.new(name)
        m.diffuse_color = colour
        me.materials.append(m)
    ob.location = (x, 0.0, 0.0)
    return ob


def _clear_markers():
    for n in ("REF_Knight_2315", "REF_REAL1_1860", "REF_Bench_045"):
        o = bpy.data.objects.get(n)
        if o:
            me, mats = o.data, list(o.data.materials)
            bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.meshes.remove(me)
            for m in mats:
                if m and m.users == 0:
                    bpy.data.materials.remove(m)


def shots(folder, prefix="25-32_denfa", clip=None, t=0.0, views=((0, 0, "front"), (35, 0, "q3"), (90, 0, "side"),
                                                                   (180, 0, "back"), (35, 35, "gamecam")),
          markers=True, ortho=3.4, res=(900, 1100), light="STUDIO", color="TEXTURE"):
    """Renders through a camera (never the viewport): his rest or a clip at t, beside a 2.315 m Knight marker and a
    1.86 m REAL-1 marker. The file is reverted by the caller's next open; markers are removed here."""
    arm, ob = _rig_body()
    place(arm, False)
    DF.rest(arm)
    if clip:
        _clip_at(arm, clip, t)
    if markers:
        _marker("REF_Knight_2315", 2.315, 1.0, (0.55, 0.55, 0.6, 1))
        _marker("REF_REAL1_1860", 1.86, -1.0, (0.6, 0.45, 0.35, 1))
    out = []
    try:
        for yaw, elev, name in views:
            p = os.path.join(folder, "%s_%s%s.png" % (prefix, (clip or "rest").lower(), "_" + name))
            C.shot(p, (0.0, 0.0, 1.45 if elev < 20 else 1.2), yaw, elev, ortho, res)
            sh = bpy.context.scene.display.shading
            if light != "FLAT" or color != "TEXTURE":
                sh.light = light
                sh.color_type = color
                bpy.ops.render.render(write_still=True)
            out.append(p)
    finally:
        _clear_markers()
        restore()
    return out
