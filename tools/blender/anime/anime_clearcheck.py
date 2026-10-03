# anime_clearcheck.py - route AN (Story 25.30, T5): the Quest Dealer's body numbers and clearance, the 25.13 method
# (staff_clearcheck.py): each (clip, frame) is evaluated once as a skinned point cloud in her own frame (Godot axes:
# x = her left, y up, z = forward), DENSIFIED along the edges (the anime rings are 5-6 cm apart), then placed at the
# desk's stations (world = Godot tavern coordinates) and tested against the story's geometry table.
#   measure()      idle_front, walk_half_at_desk, seated_front, bubble_seated, the stool pull, hall / bar speed
#   desk_report()  0 hits on the slab, the front and side panels; the stool exemption (below the seat top, behind her
#                  root; the max depth per clip; seated <= 0.048 m)
#   self_clips()   hair vs the arms, thighs vs the skirt, hands vs the cuffs
#   proof()        each check first shown to report a hit (a deliberately bad placement)
# Each entry point leaves the rig in rest with no active action (the export must not depend on which ran last). The
# clouds are cached per (clip, frame): anime_anims.build_clips, anime_retarget.refit_sit and anime_dealer.build drop
# the cache (C.drop_cached_clouds).
import math

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

import anime_atlas as A
import anime_common as C
import anime_dealer as D

DESK = np.array([11.600, 0.100, -4.300])
WORK_POINT = np.array([11.600, 0.540, -5.080])
SLAB_BACK = -4.776
STOOL_BOX = (np.array([11.397, 0.094, -5.302]), np.array([11.803, 0.540, -4.905]))
STOOL_CENTRE = np.array([11.600, 0.540, -5.1035])
APPROACH = np.array([11.0, 0.100, -5.50])
BODY = "Dealer_Body"
PALETTE_KEYS = list(D.PALETTE)               # the atlas's cell order (anime_atlas.build fills cells in dict order)
_cache = {}


def clear_cache():
    _cache.clear()


def cell_uv(key):
    i = PALETTE_KEYS.index(key)
    return ((i % A.GRID + 0.5) / A.GRID, (i // A.GRID + 0.5) / A.GRID)


def verts_of(key):
    """The vertices of her flat parts painted `key`: palette-material faces whose UVs sit on that cell's centre (a
    face-material polygon is never counted, whatever its UV)."""
    me = bpy.data.objects[BODY].data
    pal = [i for i, m in enumerate(me.materials) if m is not None and m.name == D.PALETTE_MAT]
    if len(pal) != 1:
        raise RuntimeError("verts_of(%s): %s has %d '%s' material slots, not 1" % (key, BODY, len(pal), D.PALETTE_MAT))
    lay = me.uv_layers[0].data
    u0, v0 = cell_uv(key)
    out = set()
    for p in me.polygons:
        if p.material_index != pal[0]:
            continue
        u, v = lay[p.loop_indices[0]].uv
        if abs(u - u0) < 1e-3 and abs(v - v0) < 1e-3:
            out.update(p.vertices)
    return out


def _pose(clip, frame):
    arm = C.rig()
    arm.animation_data.action = bpy.data.actions[clip] if clip else None
    if not clip:
        for pb in arm.pose.bones:
            pb.matrix_basis.identity()
    bpy.context.scene.frame_set(int(math.floor(frame)), subframe=frame - math.floor(frame))
    bpy.context.view_layer.update()


def _rest():
    """The rig back in rest, no active action."""
    arm = C.rig()
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def cloud(clip, frame, with_quill=False):
    """Her evaluated surface at (clip, frame) in her frame (Godot axes), vertices plus points at 1/3 and 2/3 of every edge."""
    key = (clip, frame, with_quill)
    if key in _cache:
        return _cache[key]
    _pose(clip, frame)
    dg = bpy.context.evaluated_depsgraph_get()
    chunks = []
    for n in [BODY] + (["Dealer_Quill"] if with_quill else []):
        ob = bpy.data.objects[n]
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        ed = np.empty(len(me.edges) * 2, dtype=np.int64)
        me.edges.foreach_get("vertices", ed)
        ed = ed.reshape(-1, 2)
        a, b = co[ed[:, 0]], co[ed[:, 1]]
        co = np.concatenate([co, a + (b - a) / 3, a + 2 * (b - a) / 3])
        M = np.array(ev.matrix_world)
        w = co @ M[:3, :3].T + M[:3, 3]
        chunks.append(np.stack([w[:, 0], w[:, 2], -w[:, 1]], axis=1))
        ev.to_mesh_clear()
    pts = np.concatenate(chunks)
    _cache[key] = pts
    return pts


def place(pts, pos, yaw):
    c, s = math.cos(yaw), math.sin(yaw)
    x = pos[0] + pts[:, 0] * c + pts[:, 2] * s
    z = pos[2] - pts[:, 0] * s + pts[:, 2] * c
    return np.stack([x, pos[1] + pts[:, 1], z], axis=1)


def desk_hits(w):
    lx, ly, lz = w[:, 0] - DESK[0], w[:, 1] - DESK[1], w[:, 2] - DESK[2]
    masks = {
        "slab": (np.abs(lx) <= 1.03) & (lz >= -0.476) & (lz <= 0.476) & (ly >= 0.78) & (ly <= 0.85),
        "front": (np.abs(lx) <= 1.03) & (lz >= 0.40) & (lz <= 0.48) & (ly >= 0.0) & (ly <= 0.78),
        "sides": (np.abs(lx) >= 0.96) & (np.abs(lx) <= 1.03) & (lz >= -0.476) & (lz <= 0.476) & (ly >= 0.0) & (ly <= 0.78),
    }
    return {k: int(np.sum(m)) for k, m in masks.items() if np.any(m)}


def stool_depth(w, root_z, stool_dz=0.0):
    """Points inside the stool's box (moved back by stool_dz): (count outside the exemption, the max depth inside)."""
    lo, hi = STOOL_BOX[0] + np.array([0, 0, -stool_dz]), STOOL_BOX[1] + np.array([0, 0, -stool_dz])
    m = np.all((w >= lo) & (w <= hi), axis=1)
    if not np.any(m):
        return 0, 0.0
    p = w[m]
    depth = np.min(np.stack([p[:, 0] - lo[0], hi[0] - p[:, 0], p[:, 1] - lo[1], hi[1] - p[:, 1], p[:, 2] - lo[2], hi[2] - p[:, 2]], axis=1), axis=1)
    bad = int(np.sum(~((p[:, 1] <= hi[1]) & (p[:, 2] < root_z))))
    return bad, float(np.max(depth))


def frames_of(clip, step):
    a, b = bpy.data.actions[clip].frame_range
    return list(range(int(a), int(b) + 1, step))


# ------------------------------------------------------------------ her numbers

def band(pts, y0=0.78, y1=0.95, what="?"):
    out = pts[(pts[:, 1] >= y0) & (pts[:, 1] <= y1)]
    if not len(out):
        raise RuntimeError("no point of %s in the %.2f-%.2f m band at %s" % (BODY, y0, y1, what))
    return out


def ground_speed(clip):
    """Stance length / stance time, both feet (the 25.13 method): while a foot's sole is down, it slides back
    relative to her root at the walking speed."""
    arm = C.rig()
    body = bpy.data.objects[BODY]
    pts = C.sole_points(arm, [body])
    act = bpy.data.actions[clip]
    fr = frames_of(clip, 1)
    speeds = []
    for s in ("l", "r"):
        if not pts[s]:
            raise RuntimeError("ground_speed(%s): no sole points on %s's .%s foot" % (clip, BODY, s))
        bones = sorted({b for b, _ in pts[s]})
        track = []
        for f in fr:
            m = C.fk(arm, C.Curves(act), f, bones)
            low = min((m[b] @ p).z for b, p in pts[s])
            y = sum((m[b] @ p).y for b, p in pts[s]) / len(pts[s])
            track.append((f, low, y))
        down = [t for t in track if t[1] <= 0.012]
        runs, cur = [], [down[0]] if down else []
        for t in down[1:]:
            if t[0] == cur[-1][0] + 1:
                cur.append(t)
            else:
                runs.append(cur)
                cur = [t]
        if cur:
            runs.append(cur)
        run = max(runs, key=len) if runs else []
        if len(run) >= 3:
            speeds.append(abs(run[-1][2] - run[0][2]) / ((run[-1][0] - run[0][0]) / 24.0))
    if not speeds:
        raise RuntimeError("ground_speed(%s): no stance run (>= 3 frames with a sole <= 0.012 m) on either foot" % clip)
    return sum(speeds) / len(speeds)


def measure(hip_back=0.397):
    try:
        return _measure(hip_back)
    finally:
        _rest()


def _measure(hip_back):
    def front(clip, f):
        return float(np.max(band(cloud(clip, f), what="%s frame %s" % (clip, f))[:, 2]))

    idle_front = max(front("Idle", f) for f in frames_of("Idle", 2))
    walk_half = max(float(np.max(np.abs(band(cloud("Walk_Bar", f), what="Walk_Bar frame %s" % f)[:, 0]))) for f in frames_of("Walk_Bar", 1))
    seated_front = max(front("Sit_Chair_Idle", f) for f in frames_of("Sit_Chair_Idle", 8))
    seated_top = max(float(np.max(cloud(c, f)[:, 1])) for c in ("Sit_Chair_Idle", "Write", "Brief") for f in frames_of(c, 8))
    seated_z = WORK_POINT[2] + hip_back
    pull = max(0.45, math.ceil((seated_z - SLAB_BACK + max(idle_front, walk_half) + 0.02) * 100) / 100)
    out = {"hip_back": hip_back, "stool_pull": pull, "seated_front": round(seated_front, 3), "walk_half_at_desk": round(walk_half, 3),
           "idle_front": round(idle_front, 3), "bubble_seated": round(seated_top + 0.10, 2),
           "hall_speed": round(ground_speed("Walking_A"), 2), "bar_speed": round(ground_speed("Walk_Bar"), 2)}
    print("her numbers: %s (seated top %.3f)" % (out, seated_top))
    return out


# ------------------------------------------------------------------ the desk and the stool

def desk_report(nums):
    try:
        return _desk_report(nums)
    finally:
        _rest()


def _desk_report(nums):
    hb, pull = nums["hip_back"], nums["stool_pull"]
    seated = np.array([11.600, 0.100, WORK_POINT[2] + hb])
    standing = seated - np.array([0.0, 0.0, pull])
    rep = {}

    def add(tag, hits, stool=None):
        cur = rep.setdefault(tag, {"n": 0, "stool_bad": 0, "stool_depth": 0.0})
        cur["n"] += sum(hits.values())
        if stool:
            cur["stool_bad"] += stool[0]
            cur["stool_depth"] = round(max(cur["stool_depth"], stool[1]), 3)
    for clip, step in (("Write", 4), ("Brief", 4), ("Sit_Chair_Idle", 8)):
        for f in frames_of(clip, step):
            w = place(cloud(clip, f, with_quill=True), seated, 0.0)
            add("%s seated" % clip, desk_hits(w), stool_depth(w, seated[2]))
    for clip, step in (("Sit_Chair_Down", 2), ("Sit_Chair_StandUp", 2)):
        for f in frames_of(clip, step):
            w = place(cloud(clip, f), standing, 0.0)
            add("%s at the standing root" % clip, desk_hits(w), stool_depth(w, standing[2], stool_dz=pull))
    for k in range(6):                                              # the shuffle in and out (seated, sliding)
        pos = standing + (seated - standing) * (k / 5)
        w = place(cloud("Sit_Chair_Idle", 0), pos, 0.0)
        add("shuffle", desk_hits(w), stool_depth(w, pos[2], stool_dz=pull * (1 - k / 5)))
    d = STOOL_CENTRE - APPROACH
    face_stool = math.atan2(d[0], d[2])
    for f in frames_of("Interact", 3):                              # pulling / pushing the stool at the approach
        add("Interact at the approach", desk_hits(place(cloud("Interact", f), APPROACH, face_stool)))
    for k in range(7):                                              # the turn at the approach (Idle in place)
        for f in frames_of("Walk_Bar", 3):
            add("turn at the approach", desk_hits(place(cloud("Walk_Bar", f), APPROACH, math.pi / 2 + (face_stool - math.pi / 2) * k / 6)))
    dd = standing - APPROACH
    head = math.atan2(dd[0], dd[2])
    for k in range(7):
        for f in frames_of("Walk_Bar", 2):
            add("walk to the standing root", desk_hits(place(cloud("Walk_Bar", f), APPROACH + dd * (k / 6), head)))
    for k in range(7):
        for f in frames_of("Walk_Bar", 2):
            add("turn at the standing root", desk_hits(place(cloud("Walk_Bar", f), standing, head * (1 - k / 6))))
    for zq in np.linspace(-3.4, APPROACH[2], 8):                    # the route's last legs (x 9.85, then east)
        for f in frames_of("Walk_Bar", 2):
            add("route leg south", desk_hits(place(cloud("Walk_Bar", f), np.array([9.85, 0.1, zq]), math.pi)))
    for xq in np.linspace(9.85, APPROACH[0], 6):
        for f in frames_of("Walk_Bar", 2):
            add("route leg east", desk_hits(place(cloud("Walk_Bar", f), np.array([xq, 0.1, APPROACH[2]]), math.pi / 2)))
    hits = {k: v for k, v in rep.items() if v["n"] or v["stool_bad"]}
    print("desk report: hits %s" % (hits or "none"))
    print("stool depth per clip: %s" % {k: v["stool_depth"] for k, v in rep.items() if v["stool_depth"] > 0})
    return rep


def proof(nums):
    """A deliberately bad placement must report hits (else a zero proves nothing)."""
    try:
        return _proof(nums)
    finally:
        _rest()


def _proof(nums):
    seated = np.array([11.600, 0.100, WORK_POINT[2] + nums["hip_back"] + 0.45])      # 0.45 m too far in: into the desk
    h = desk_hits(place(cloud("Write", 0), seated, 0.0))
    s = stool_depth(place(cloud("Sit_Chair_Idle", 0), np.array([11.600, 0.100, -5.08]), 0.0), -5.08)
    print("proof: the desk check reports %s for her 0.45 m too far in; the stool check depth %.3f with her root on the WorkPoint" % (h, s[1]))
    return bool(h) and s[1] > 0.0


# ------------------------------------------------------------------ self-clips (in Blender armature space)

def _eval_co(clip, frame):
    _pose(clip, frame)
    dg = bpy.context.evaluated_depsgraph_get()
    ob = bpy.data.objects[BODY]
    ev = ob.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    polys = [tuple(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    return co, polys


def _seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
    return np.linalg.norm(p - (a + np.outer(t, ab)), axis=1)


def _skirt_island(me, coat, below):
    """The skirt's faces: the connected coat island reaching below `below` at rest (the torso's bottom cap and the
    sleeves are other islands)."""
    faces = [p for p in me.polygons if all(v in coat for v in p.vertices)]
    by_vert = {}
    for p in faces:
        for v in p.vertices:
            by_vert.setdefault(v, []).append(p.index)
    seen, out = set(), []
    for p in faces:
        if p.index in seen:
            continue
        comp, stack = [], [p.index]
        seen.add(p.index)
        while stack:
            i = stack.pop()
            comp.append(i)
            for v in me.polygons[i].vertices:
                for j in by_vert[v]:
                    if j not in seen:
                        seen.add(j)
                        stack.append(j)
        if min(me.vertices[v].co.z for i in comp for v in me.polygons[i].vertices) < below:
            out += comp
    return out


def _need(sel, what):
    if len(sel) == 0:
        raise RuntimeError("self_clips: no %s on %s (an empty selection proves nothing)" % (what, BODY))
    return sel


def self_clips():
    try:
        return _self_clips()
    finally:
        _rest()


def _self_clips():
    arm = C.rig()
    me = bpy.data.objects[BODY].data
    rest = np.array([v.co[:] for v in me.vertices])
    hair = _need(np.array(sorted(verts_of("hair"))), "hair vertices")
    dark = _need(np.array(sorted(verts_of("dark"))), "dark (leggings) vertices")
    coat = _need(verts_of("coat"), "coat vertices")
    skin = _need(np.array(sorted(verts_of("skin"))), "skin vertices")
    gold = _need(np.array(sorted(verts_of("gold"))), "gold vertices")
    from anime_kit import Z, setup
    setup(arm)
    belt_z, hem_z = Z(1.07), Z(0.66) - 0.01
    skirt_polys = _need(_skirt_island(me, coat, Z(0.70)), "skirt faces (a coat island reaching below the thighs' top)")
    covered = _need(dark[(rest[dark][:, 2] > Z(0.66) + 0.02) & (rest[dark][:, 2] < Z(0.95))], "thigh vertices under the skirt")
    arm_r = {"upperarm": 0.06, "lowerarm": 0.055, "hand": 0.06}
    rep = {"hair_vs_arms": {}, "thighs_vs_skirt": {}, "hands_vs_cuffs": {}}
    for clip in ("Idle", "Walking_A", "Walk_Bar", "Interact", "Write", "Brief"):
        worst = (0, None)
        for f in frames_of(clip, 2):
            co, _ = _eval_co(clip, f)
            n = 0
            for s in ("l", "r"):
                for b, r in arm_r.items():
                    pb = arm.pose.bones["%s.%s" % (b, s)]
                    n += int(np.sum(_seg_dist(co[hair], np.array(pb.head), np.array(pb.tail)) < r))
            if n > worst[0]:
                worst = (n, f)
        rep["hair_vs_arms"][clip] = worst
    for clip in ("Idle", "Walking_A", "Walk_Bar", "Sit_Chair_Down", "Sit_Chair_Idle"):
        worst = (0, 0.0, None)
        for f in frames_of(clip, 2):
            co, polys = _eval_co(clip, f)
            bvh = BVHTree.FromPolygons([Vector(c) for c in co], [polys[i] for i in skirt_polys])
            pokes, deep = 0, 0.0
            for i in covered:
                p = Vector(co[i])
                side = "l" if rest[i][0] > 0 else "r"
                pb = arm.pose.bones["upperleg." + side]
                a, b = pb.head, pb.tail
                ab = b - a
                t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
                axis = a + ab * t
                d = p - axis
                if d.length < 1e-6:
                    continue
                hit = bvh.ray_cast(axis, d.normalized(), d.length)
                if hit[0] is not None:
                    pokes += 1
                    deep = max(deep, d.length - hit[3])
            if pokes > worst[0] or deep > worst[1]:
                worst = (max(pokes, worst[0]), max(deep, worst[1]), f)
        rep["thighs_vs_skirt"][clip] = (worst[0], round(worst[1], 4), worst[2])
    wrist_x = abs(arm.data.bones["wrist.l"].head_local.x)
    hand_v = skin[np.abs(rest[skin][:, 0]) > wrist_x - 0.02]
    cuff_v = gold[np.abs(np.abs(rest[gold][:, 0]) - (wrist_x + 0.012)) < 0.03]
    for clip in ("Idle", "Walking_A", "Walk_Bar", "Interact", "Write", "Brief"):
        worst = 0.0
        for f in frames_of(clip, 2):
            co, _ = _eval_co(clip, f)
            for s, sx in (("l", 1), ("r", -1)):
                at = "at %s frame %s" % (clip, f)
                hv = co[_need(hand_v[np.sign(rest[hand_v][:, 0]) == sx], "hand.%s vertices %s" % (s, at))]
                cv = co[_need(cuff_v[np.sign(rest[cuff_v][:, 0]) == sx], "cuff.%s vertices %s" % (s, at))]
                gap = min(float(np.min(np.linalg.norm(hv - c, axis=1))) for c in cv)
                worst = max(worst, gap)
        rep["hands_vs_cuffs"][clip] = round(worst, 4)
    print("self-clips: %s" % rep)
    return rep
