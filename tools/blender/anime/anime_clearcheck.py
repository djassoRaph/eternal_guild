# anime_clearcheck.py - route AN (Story 25.30 T5; generic since 25.31): a role's body numbers and clearance, the 25.13
# method (staff_clearcheck.py): each (clip, frame) is evaluated once as a skinned point cloud in the character's own
# frame (Godot axes: x = its left, y up, z = forward), DENSIFIED along the edges (the anime rings are 5-6 cm apart),
# then placed at its stations (world = Godot tavern coordinates) and tested against the geometry table.
# Every entry point takes the role's config (`cfg`, e.g. anime_dealer.config(): body, props, palette material and keys,
# the check's palette keys, Z bands, clip lists and geometry); cfg=None is the shipped Quest Dealer's.
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

_cache = {}


def _cfg(cfg):
    return cfg or D.DEALER


def clear_cache():
    _cache.clear()


def cell_uv(key, cfg=None):
    keys = list(_cfg(cfg)["palette"])        # the atlas's cell order (anime_atlas.build fills cells in dict order)
    i = keys.index(key)
    return ((i % A.GRID + 0.5) / A.GRID, (i // A.GRID + 0.5) / A.GRID)


def verts_of(key, cfg=None):
    """The vertices of the body's flat parts painted `key`: palette-material faces whose UVs sit on that cell's centre
    (a face-material polygon is never counted, whatever its UV)."""
    cfg = _cfg(cfg)
    BODY, pm = cfg["body"], cfg["palette_mat"]
    me = bpy.data.objects[BODY].data
    pal = [i for i, m in enumerate(me.materials) if m is not None and m.name == pm]
    if len(pal) != 1:
        raise RuntimeError("verts_of(%s): %s has %d '%s' material slots, not 1" % (key, BODY, len(pal), pm))
    lay = me.uv_layers[0].data
    u0, v0 = cell_uv(key, cfg)
    out = set()
    for p in me.polygons:
        if p.material_index != pal[0]:
            continue
        u, v = lay[p.loop_indices[0]].uv
        if abs(u - u0) < 1e-3 and abs(v - v0) < 1e-3:
            out.update(p.vertices)
    return out


def seat_verts(cfg=None):
    """The vertex indices refit_sit may sit on: the config's seat_keys (skin, leggings, pelvis; never a robe's hem)."""
    cfg = _cfg(cfg)
    out = set()
    for k in cfg["check"]["seat_keys"]:
        out |= verts_of(k, cfg)
    return sorted(out)


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


def cloud(clip, frame, with_props=False, cfg=None):
    """The body's evaluated surface at (clip, frame) in its frame (Godot axes), vertices plus points at 1/3 and 2/3 of
    every edge; with_props adds the role's props (the dealer's quill)."""
    cfg = _cfg(cfg)
    key = (cfg["body"], clip, frame, with_props)
    if key in _cache:
        return _cache[key]
    _pose(clip, frame)
    dg = bpy.context.evaluated_depsgraph_get()
    chunks = []
    for n in [cfg["body"]] + (list(cfg["props"]) if with_props else []):
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


def desk_hits(w, geo):
    DESK = geo["desk"]
    lx, ly, lz = w[:, 0] - DESK[0], w[:, 1] - DESK[1], w[:, 2] - DESK[2]
    masks = {
        "slab": (np.abs(lx) <= 1.03) & (lz >= -0.476) & (lz <= 0.476) & (ly >= 0.78) & (ly <= 0.85),
        "front": (np.abs(lx) <= 1.03) & (lz >= 0.40) & (lz <= 0.48) & (ly >= 0.0) & (ly <= 0.78),
        "sides": (np.abs(lx) >= 0.96) & (np.abs(lx) <= 1.03) & (lz >= -0.476) & (lz <= 0.476) & (ly >= 0.0) & (ly <= 0.78),
    }
    return {k: int(np.sum(m)) for k, m in masks.items() if np.any(m)}


def stool_depth(w, root_z, geo, stool_dz=0.0):
    """Points inside the stool's box (moved back by stool_dz): (count outside the exemption, the max depth inside)."""
    box = geo["stool_box"]
    lo, hi = box[0] + np.array([0, 0, -stool_dz]), box[1] + np.array([0, 0, -stool_dz])
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
        raise RuntimeError("no point of the body in the %.2f-%.2f m band at %s" % (y0, y1, what))
    return out


def ground_speed(clip, cfg=None):
    """Stance length / stance time, both feet (the 25.13 method): while a foot's sole is down, it slides back
    relative to the root at the walking speed."""
    BODY = _cfg(cfg)["body"]
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


def measure(hip_back=None, cfg=None):
    """A desk role's numbers (the dealer's body block): hip_back (default: the config's), stool_pull, seated_front,
    walk_half_at_desk, idle_front, bubble_seated, hall_speed, bar_speed."""
    cfg = _cfg(cfg)
    try:
        return _measure(cfg["check"]["hip_back"] if hip_back is None else hip_back, cfg)
    finally:
        _rest()


def _measure(hip_back, cfg):
    ck, geo = cfg["check"], cfg["check"]["geometry"]
    walk = ck["walk_clip"]

    def front(clip, f):
        return float(np.max(band(cloud(clip, f, cfg=cfg), what="%s frame %s" % (clip, f))[:, 2]))

    idle_front = max(front("Idle", f) for f in frames_of("Idle", 2))
    walk_half = max(float(np.max(np.abs(band(cloud(walk, f, cfg=cfg), what="%s frame %s" % (walk, f))[:, 0]))) for f in frames_of(walk, 1))
    seated_front = max(front("Sit_Chair_Idle", f) for f in frames_of("Sit_Chair_Idle", 8))
    seated_top = max(float(np.max(cloud(c, f, cfg=cfg)[:, 1])) for c in ck["seated_clips"] for f in frames_of(c, 8))
    seated_z = geo["work_point"][2] + hip_back
    pull = max(0.45, math.ceil((seated_z - geo["slab_back"] + max(idle_front, walk_half) + 0.02) * 100) / 100)
    out = {"hip_back": hip_back, "stool_pull": pull, "seated_front": round(seated_front, 3), "walk_half_at_desk": round(walk_half, 3),
           "idle_front": round(idle_front, 3), "bubble_seated": round(seated_top + 0.10, 2),
           "hall_speed": round(ground_speed(ck["hall_clip"], cfg), 2), "bar_speed": round(ground_speed(walk, cfg), 2)}
    print("%s numbers: %s (seated top %.3f)" % (cfg["role"], out, seated_top))
    return out


# ------------------------------------------------------------------ the desk and the stool

def desk_report(nums, cfg=None):
    cfg = _cfg(cfg)
    try:
        return _desk_report(nums, cfg)
    finally:
        _rest()


def _desk_report(nums, cfg):
    geo = cfg["check"]["geometry"]
    walk = cfg["check"]["walk_clip"]
    WORK_POINT, STOOL_CENTRE, APPROACH = geo["work_point"], geo["stool_centre"], geo["approach"]
    hb, pull = nums["hip_back"], nums["stool_pull"]
    seated = np.array([WORK_POINT[0], 0.100, WORK_POINT[2] + hb])
    standing = seated - np.array([0.0, 0.0, pull])
    rep = {}

    def add(tag, hits, stool=None):
        cur = rep.setdefault(tag, {"n": 0, "stool_bad": 0, "stool_depth": 0.0})
        cur["n"] += sum(hits.values())
        if stool:
            cur["stool_bad"] += stool[0]
            cur["stool_depth"] = round(max(cur["stool_depth"], stool[1]), 3)
    seated_clips = [(c, 8 if c == "Sit_Chair_Idle" else 4) for c in cfg["check"]["seated_clips"]]
    seated_clips = [x for x in seated_clips if x[0] != "Sit_Chair_Idle"] + [x for x in seated_clips if x[0] == "Sit_Chair_Idle"]
    for clip, step in seated_clips:
        for f in frames_of(clip, step):
            w = place(cloud(clip, f, with_props=True, cfg=cfg), seated, 0.0)
            add("%s seated" % clip, desk_hits(w, geo), stool_depth(w, seated[2], geo))
    for clip, step in (("Sit_Chair_Down", 2), ("Sit_Chair_StandUp", 2)):
        for f in frames_of(clip, step):
            w = place(cloud(clip, f, cfg=cfg), standing, 0.0)
            add("%s at the standing root" % clip, desk_hits(w, geo), stool_depth(w, standing[2], geo, stool_dz=pull))
    for k in range(6):                                              # the shuffle in and out (seated, sliding)
        pos = standing + (seated - standing) * (k / 5)
        w = place(cloud("Sit_Chair_Idle", 0, cfg=cfg), pos, 0.0)
        add("shuffle", desk_hits(w, geo), stool_depth(w, pos[2], geo, stool_dz=pull * (1 - k / 5)))
    d = STOOL_CENTRE - APPROACH
    face_stool = math.atan2(d[0], d[2])
    for f in frames_of("Interact", 3):                              # pulling / pushing the stool at the approach
        add("Interact at the approach", desk_hits(place(cloud("Interact", f, cfg=cfg), APPROACH, face_stool), geo))
    for k in range(7):                                              # the turn at the approach (Idle in place)
        for f in frames_of(walk, 3):
            add("turn at the approach", desk_hits(place(cloud(walk, f, cfg=cfg), APPROACH, math.pi / 2 + (face_stool - math.pi / 2) * k / 6), geo))
    dd = standing - APPROACH
    head = math.atan2(dd[0], dd[2])
    for k in range(7):
        for f in frames_of(walk, 2):
            add("walk to the standing root", desk_hits(place(cloud(walk, f, cfg=cfg), APPROACH + dd * (k / 6), head), geo))
    for k in range(7):
        for f in frames_of(walk, 2):
            add("turn at the standing root", desk_hits(place(cloud(walk, f, cfg=cfg), standing, head * (1 - k / 6)), geo))
    for zq in np.linspace(-3.4, APPROACH[2], 8):                    # the route's last legs (x 9.85, then east)
        for f in frames_of(walk, 2):
            add("route leg south", desk_hits(place(cloud(walk, f, cfg=cfg), np.array([9.85, 0.1, zq]), math.pi), geo))
    for xq in np.linspace(9.85, APPROACH[0], 6):
        for f in frames_of(walk, 2):
            add("route leg east", desk_hits(place(cloud(walk, f, cfg=cfg), np.array([xq, 0.1, APPROACH[2]]), math.pi / 2), geo))
    hits = {k: v for k, v in rep.items() if v["n"] or v["stool_bad"]}
    print("desk report: hits %s" % (hits or "none"))
    print("stool depth per clip: %s" % {k: v["stool_depth"] for k, v in rep.items() if v["stool_depth"] > 0})
    return rep


def proof(nums, cfg=None):
    """A deliberately bad placement must report hits (else a zero proves nothing)."""
    cfg = _cfg(cfg)
    try:
        return _proof(nums, cfg)
    finally:
        _rest()


def _proof(nums, cfg):
    geo = cfg["check"]["geometry"]
    wp = geo["work_point"]
    first_seated = [c for c in cfg["check"]["seated_clips"] if c != "Sit_Chair_Idle"][0]
    seated = np.array([wp[0], 0.100, wp[2] + nums["hip_back"] + 0.45])      # 0.45 m too far in: into the desk
    h = desk_hits(place(cloud(first_seated, 0, cfg=cfg), seated, 0.0), geo)
    s = stool_depth(place(cloud("Sit_Chair_Idle", 0, cfg=cfg), np.array([wp[0], 0.100, wp[2]]), 0.0), wp[2], geo)
    print("proof: the desk check reports %s for the root 0.45 m too far in; the stool check depth %.3f with the root on the WorkPoint" % (h, s[1]))
    return bool(h) and s[1] > 0.0


# ------------------------------------------------------------------ self-clips (in Blender armature space)

def _eval_co(clip, frame, body):
    _pose(clip, frame)
    dg = bpy.context.evaluated_depsgraph_get()
    ob = bpy.data.objects[body]
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


def _need(sel, what, body="the body"):
    if len(sel) == 0:
        raise RuntimeError("self_clips: no %s on %s (an empty selection proves nothing)" % (what, body))
    return sel


def _eval_now(body):
    """The body's evaluated vertices (armature space: Rig at the origin) in the CURRENT pose, and its polygons."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = bpy.data.objects[body].evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    polys = [tuple(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    return co, polys


ARM_R = {"upperarm": 0.06, "lowerarm": 0.055, "hand": 0.06}      # the sleeve radius + 0.01 (25.30)
DOWN = -0.2                 # check (b): a miss whose ray points more than ~12 degrees down leaves under the hem


def _selections(cfg):
    """What the self-clip checks look at, chosen at REST on the body (palette keys and Z bands from the config)."""
    ck, BODY = cfg["check"], cfg["body"]
    keys = ck["keys"]
    arm = C.rig()
    _rest()
    me = bpy.data.objects[BODY].data
    rest = np.array([v.co[:] for v in me.vertices])
    import anime_kit as K
    K.setup(arm)
    sel = {"arm": arm, "rest": rest, "body": BODY}
    sel["hair"] = _need(np.array(sorted(verts_of(keys["hair"], cfg))), "hair vertices", BODY) if keys.get("hair") else None
    if keys.get("skirt"):
        legs = _need(np.array(sorted(verts_of(keys["legs"], cfg))), "leg (leggings) vertices", BODY)
        coat = _need(verts_of(keys["skirt"], cfg), "skirt-colour vertices", BODY)
        t_lo, t_hi = ck["thigh_band"]
        sel["skirt_polys"] = _need(_skirt_island(me, coat, K.Z(ck["skirt_below"])), "skirt faces (a skirt-colour island reaching below the thighs' top)", BODY)
        # thighs by weight (the leggings' colour also paints the pelvis, which is hips-weighted): the dominant group is
        # an upper leg, and it names the axis's side
        ob = bpy.data.objects[BODY]
        gname = {g.index: g.name for g in ob.vertex_groups}
        side = {}
        for v in me.vertices:
            ws = [(g.weight, gname[g.group]) for g in v.groups if g.weight > 1e-5]
            if ws and max(ws)[1].startswith("upperleg."):
                side[v.index] = max(ws)[1][-1]
        sel["leg_side"] = side
        thighs = np.array([i for i in legs if i in side], dtype=np.int64)
        band = _need(thighs[(rest[thighs][:, 2] > K.Z(t_lo) + ck["thigh_pad"]) & (rest[thighs][:, 2] < K.Z(t_hi))], "thigh vertices in the band", BODY)
        # the band's vertices the skirt covers AT REST (a coat cut longer in front shows the backs of the thighs below
        # its lifted back hem by design): a clip must keep them covered
        sel["covered"] = band
        _, _, _, _, ok = _thigh_report(rest, [tuple(p.vertices) for p in me.polygons], sel, keep=True)
        sel["covered"] = _need(band[ok], "thigh vertices the skirt covers at rest", BODY)
        sel["band_shown_at_rest"] = int(len(band) - np.sum(ok))
    else:
        sel["skirt_polys"] = sel["covered"] = None
    cuff = ck.get("cuff")
    if cuff and keys.get("cuff"):
        skin = _need(np.array(sorted(verts_of(keys["skin"], cfg))), "skin vertices", BODY)
        gold = _need(np.array(sorted(verts_of(keys["cuff"], cfg))), "cuff-colour vertices", BODY)
        wrist_x = abs(arm.data.bones["wrist.l"].head_local.x)
        sel["cuff"] = {}
        for s, sx in (("l", 1), ("r", -1)):
            _, el, wr = K.arm_pts(s)
            c = np.array(wr + (wr - el).normalized() * cuff["offset"])
            ring = gold[np.linalg.norm(rest[gold] - c, axis=1) < cuff["r"] + cuff["tube"] + 0.01]
            hand = skin[(np.abs(rest[skin][:, 0]) > wrist_x - 0.02) & (np.sign(rest[skin][:, 0]) == sx)]
            sel["cuff"][s] = (_need(ring, "cuff.%s ring vertices" % s, BODY), _need(hand, "hand.%s skin vertices" % s, BODY))
    else:
        sel["cuff"] = None
    return sel


def _hair_hits(co, sel):
    """(a) hair vertices inside an arm capsule (upperarm / lowerarm / hand, sleeve radius + 0.01)."""
    arm, n = sel["arm"], 0
    for s in ("l", "r"):
        for b, r in ARM_R.items():
            pb = arm.pose.bones["%s.%s" % (b, s)]
            n += int(np.sum(_seg_dist(co[sel["hair"]], np.array(pb.head), np.array(pb.tail)) < r))
    return n


def _thigh_report(co, polys, sel, keep=False):
    """(b) for every thigh vertex the skirt should cover, the ray from the upper leg's axis through it must HIT the
    skirt at or beyond the vertex: a hit before it is a poke (the thigh through the cloth, `deep` = how far), no hit is
    uncovered. `down`: the uncovered whose ray points below the horizontal (d.z < DOWN): it leaves under the hem, so
    only a viewer below the vertex sees along it (the game camera looks down; a seat hides a seated thigh's underside);
    the rest are `open` (real exposure). Hits = pokes + open.
    keep=True also returns a mask over sel["covered"]: True where the vertex is covered (a hit at or beyond)."""
    arm, rest = sel["arm"], sel["rest"]
    bvh = BVHTree.FromPolygons([Vector(c) for c in co], [polys[i] for i in sel["skirt_polys"]])
    pokes, uncovered, under, deep = 0, 0, 0, 0.0
    ok = np.zeros(len(sel["covered"]), dtype=bool)
    for j, i in enumerate(sel["covered"]):
        p = Vector(co[i])
        pb = arm.pose.bones["upperleg." + sel["leg_side"][int(i)]]
        a, b = pb.head, pb.tail
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
        axis = a + ab * t
        d = p - axis
        if d.length < 1e-6:
            continue
        hit = bvh.ray_cast(axis, d.normalized(), 3.0)
        if hit[0] is None:
            uncovered += 1
            under += int(d.normalized().z < DOWN)
        elif hit[3] < d.length - 1e-4:
            pokes += 1
            deep = max(deep, d.length - hit[3])
        else:
            ok[j] = True
    if keep:
        return pokes, uncovered, under, deep, ok
    return pokes, uncovered, under, deep


def _cuff_report(co, sel):
    """(c) per side, the posed cuff ring's axis (its plane's normal), centre, inner radius (the ring vertices' least
    radial distance) and axial span; the hand's skin vertices inside that span must stay within the inner radius.
    Returns (vertices outside, the worst excess in m, the inner radius)."""
    n, worst, inner_min = 0, 0.0, 9.0
    for s, (ring, hand) in sel["cuff"].items():
        cv = co[ring]
        c = cv.mean(axis=0)
        axis = np.linalg.svd(cv - c)[2][-1]
        rel = cv - c
        ax = rel @ axis
        inner = float(np.min(np.linalg.norm(rel - np.outer(ax, axis), axis=1)))
        lo, hi = float(np.min(ax)), float(np.max(ax))
        hr = co[hand] - c
        hax = hr @ axis
        m = (hax >= lo) & (hax <= hi)
        if np.any(m):
            rad = np.linalg.norm(hr[m] - np.outer(hax[m], axis), axis=1)
            ex = rad - inner
            n += int(np.sum(ex > 0))
            worst = max(worst, float(np.max(ex)))
        inner_min = min(inner_min, inner)
    return n, worst, inner_min


def self_clips(cfg=None):
    cfg = _cfg(cfg)
    try:
        return _self_clips(cfg)
    finally:
        _rest()


def _self_clips(cfg):
    ck = cfg["check"]
    sel = _selections(cfg)
    BODY = sel["body"]
    rep = {}
    if sel["hair"] is not None:
        rep["hair_vs_arms"] = {}
        for clip in ck["hair_clips"]:
            worst = (0, None)
            for f in frames_of(clip, 2):
                co, _ = _eval_co(clip, f, BODY)
                n = _hair_hits(co, sel)
                if n > worst[0]:
                    worst = (n, f)
            rep["hair_vs_arms"][clip] = worst
    if sel["covered"] is not None:
        rep["thighs_vs_skirt"] = {}          # (pokes, open, down, deepest poke, worst frame); hits = pokes + open
        for clip in ck["thigh_clips"]:
            worst = (0, 0, 0, 0.0, None)
            for f in frames_of(clip, 2):
                co, polys = _eval_co(clip, f, BODY)
                pk, un, ud, dp = _thigh_report(co, polys, sel)
                if worst[4] is None or (pk + un - ud, un, dp) > (worst[0] + worst[1], worst[1] + worst[2], worst[3]):
                    worst = (pk, un - ud, ud, round(dp, 4), f)
            rep["thighs_vs_skirt"][clip] = worst
        rep["thigh_band"] = {"covered_at_rest": int(len(sel["covered"])), "shown_below_the_hem_at_rest": sel["band_shown_at_rest"]}
    if sel["cuff"] is not None:
        rep["wrists_vs_cuffs"] = {}          # (vertices outside the cuff's inner radius, worst excess, inner radius, frame)
        for clip in ck["cuff_clips"]:
            worst = (0, 0.0, None, None)
            for f in frames_of(clip, 2):
                co, _ = _eval_co(clip, f, BODY)
                n, ex, inner = _cuff_report(co, sel)
                if worst[3] is None or (n, ex) > (worst[0], worst[1]):
                    worst = (n, round(ex, 4), round(inner, 4), f)
            rep["wrists_vs_cuffs"][clip] = worst
    print("self-clips: %s" % rep)
    return rep


def proof_self_clips(cfg=None):
    """Each self-clip check shown to report a hit on a deliberately bad pose (else its zero proves nothing): (a) the
    left hand reaching into the back hair, (b) the left thigh swung out and up through the skirt, (c) the left wrist
    dislocated 5 cm forward out of its cuff. Returns {check: hits}; every value must be > 0."""
    cfg = _cfg(cfg)
    try:
        return _proof_self_clips(cfg)
    finally:
        _rest()


def _proof_self_clips(cfg):
    import anime_retarget as RT
    from mathutils import Matrix
    sel = _selections(cfg)
    BODY, rest = sel["body"], sel["rest"]
    out = {}

    def idle():
        RT.pose_from(bpy.data.actions["Idle"], 0)

    if sel["hair"] is not None:
        idle()
        h = rest[sel["hair"]]
        back = h[(h[:, 1] > 0.12) & (h[:, 2] > 1.15) & (h[:, 2] < 1.45)]
        target = Vector(_need(back, "back hair vertices behind the shoulders", BODY).mean(axis=0))
        RT.two_bone("upperarm.l", "lowerarm.l", "handslot.l", target, Vector((0.6, 0.5, 1.3)))
        co, _ = _eval_now(BODY)
        out["hair_vs_arms"] = _hair_hits(co, sel)
    if sel["covered"] is not None:
        idle()
        RT.rotate_about("upperleg.l", Matrix.Rotation(math.radians(-75), 3, "Y") @ Matrix.Rotation(math.radians(-60), 3, "X"))
        co, polys = _eval_now(BODY)
        pk, un, ud, dp = _thigh_report(co, polys, sel)
        out["thighs_vs_skirt"] = pk + un - ud
        out["thighs_vs_skirt_detail"] = (pk, un - ud, ud, round(dp, 4))
    if sel["cuff"] is not None:
        idle()
        RT.set_pm("wrist.l", Matrix.Translation(Vector((0.0, -0.05, 0.0))) @ RT.pm("wrist.l"))
        co, _ = _eval_now(BODY)
        n, ex, inner = _cuff_report(co, sel)
        out["wrists_vs_cuffs"] = n
        out["wrists_vs_cuffs_detail"] = (n, round(ex, 4), round(inner, 4))
    print("self-clip proof (deliberately bad poses; every count must be > 0): %s" % out)
    return out
