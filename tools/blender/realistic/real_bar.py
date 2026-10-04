# real_bar.py - route RL (Story 25.31 S1): the Bartender's clearance against the round bar and his body block, the
# 25.13 method (pipeline_ref/25_13/staff_clearcheck.py's bar_hits / bartender_report) on anime_clearcheck's skinned,
# densified clouds (Godot axes: x his left, y up, z forward). Every radius is a parameter (his staff.json body block:
# serve_r, restock_r, ring_r, keg_r, gap_r), so a body's numbers are measured, not assumed.
#   halves(cfg)                Walk_Bar's half-widths per height band: walk_bar_half_low (0.26-0.49, the kegs), _shelf
#                              (0.3-0.6, the shelf's lowest tier), _mid (0.6-1.12, up to the counter top)
#   report(cfg, nums, tank)    hits of every clip at its stations (the arcs both ways, the flap leg, Wipe / Serve / Idle
#                              and the turns at the serve stands, Pour / Restock and the turn at the restock station)
#                              against the counter, the shelf, the kegs, the keg rack and the flap leaves
#   proof(cfg, nums)           the check reports hits for a body placed 0.35 m too far in (r - 0.35)
#   ring_ok(nums, halves)      Test 19's ring rules for these numbers (r - shelf >= 1.28, r - low >= 1.49 by the kegs,
#                              r + mid <= 2.355 off the flap gap)
# Leaves the rig in rest (anime_clearcheck's clouds do the posing).
import math

import bpy
import numpy as np

import anime_clearcheck as CC

C = np.array([7.740, 0.100, -8.215])            # the ring centre (world)
SERVE_DEG = [0.0, 60.0, 120.0, 240.0, 300.0]
KEG_HALF, RAMP, GAP_HALF, GAP_RAMP_TO = 30.0, 12.0, 6.0, 12.0


def ring_radius_at(phi_deg, n):
    d = abs(((phi_deg - 180.0 + 180.0) % 360.0) - 180.0)
    if d <= GAP_HALF:
        return n["gap_r"]
    if d <= GAP_RAMP_TO:
        t = (d - GAP_HALF) / (GAP_RAMP_TO - GAP_HALF)
        return n["gap_r"] + (n["keg_r"] - n["gap_r"]) * 0.5 * (1 - math.cos(math.pi * t))
    if d <= KEG_HALF:
        return n["keg_r"]
    if d >= KEG_HALF + RAMP:
        return n["ring_r"]
    t = (d - KEG_HALF) / RAMP
    return n["keg_r"] + (n["ring_r"] - n["keg_r"]) * 0.5 * (1 - math.cos(math.pi * t))


def ring_pos(phi_deg, r):
    p = math.radians(phi_deg)
    return C + np.array([r * math.sin(p), 0.0, r * math.cos(p)])


def bar_hits(w):
    """staff_clearcheck.bar_hits: hit counts and depths of world points against the bar (ring-local shapes)."""
    lx, ly, lz = w[:, 0] - C[0], w[:, 1] - C[1], w[:, 2] - C[2]
    r = np.hypot(lx, lz)
    phi = np.degrees(np.arctan2(lx, lz)) % 360.0
    off180 = np.abs(phi - 180.0)
    shelf_r = np.select([ly < 0.3, ly < 0.6, ly < 0.9, ly < 1.2, ly <= 1.29], [1.25, 1.28, 1.165, 1.02, 0.914], default=0.77)
    masks = {
        "counter": (r >= 2.35) & (r <= 3.10) & (ly >= 0.0) & (ly <= 1.12) & (off180 >= 16.8),
        "shelf": (ly >= 0.0) & (r < shelf_r),
        "kegs": (r <= 1.49) & (ly <= 0.492) & (ly >= 0.0) & (off180 <= 17.0),
        "rack": (np.abs(lx) <= 0.43) & (lz >= -1.55) & (lz <= -0.94) & (ly >= 0.06) & (ly <= 0.26),
        "flap": (np.abs(lx) >= 0.9) & (np.abs(lx) <= 1.15) & (lz >= -3.64) & (lz <= -2.85) & (ly >= 0.08) & (ly <= 0.93),
    }
    hits = {k: int(np.sum(m)) for k, m in masks.items() if np.any(m)}
    depth = {}
    if "counter" in hits:
        depth["counter"] = float(np.max(r[masks["counter"]] - 2.35))
    if "shelf" in hits:
        m = masks["shelf"]
        depth["shelf"] = float(np.max(shelf_r[m] - r[m]))
    if "kegs" in hits:
        depth["kegs"] = float(np.max(1.49 - r[masks["kegs"]]))
    if "rack" in hits:
        m = masks["rack"]
        depth["rack"] = float(np.max(np.minimum(np.minimum(0.43 - np.abs(lx[m]), lz[m] + 1.55), -0.94 - lz[m])))
    if "flap" in hits:
        depth["flap"] = 0.0
    return hits, depth


def tankard_points(clip, frame, scale):
    """The held H1 tankard (x scale, upright, about its grip on handslot.r) as sample points in his frame."""
    arm = bpy.data.objects["Rig"]
    CC._pose(clip, frame)
    g = arm.matrix_world @ arm.pose.bones["handslot.r"].head
    gp = np.array([g.x, g.z, -g.y])
    rad = 0.056 * scale
    ring = [(rad * math.cos(a), rad * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 12, endpoint=False)]
    return np.array([gp + np.array([dx, dy, dz]) for dx, dz in ring for dy in (-0.085 * scale, 0.0, 0.105 * scale)])


def halves(cfg, clip="Walk_Bar"):
    bands = {"walk_bar_half_low": (0.26, 0.49), "walk_bar_half_shelf": (0.3, 0.6), "walk_bar_half_mid": (0.6, 1.12)}
    out = {}
    for k, (y0, y1) in bands.items():
        out[k] = round(max(float(np.max(np.abs(CC.band(CC.cloud(clip, f, with_props=True, cfg=cfg), y0, y1)[:, 0])))
                           for f in CC.frames_of(clip, 1)), 3)
    CC._rest()
    return out


def ring_ok(n, h):
    why = []
    for deg in range(360):
        r = ring_radius_at(float(deg), n)
        if r - h["walk_bar_half_shelf"] < 1.28:
            why.append("shelf %d" % deg)
        if abs(deg - 180.0) <= 30.0 and r - h["walk_bar_half_low"] < 1.49:
            why.append("kegs %d" % deg)
        if abs(deg - 180.0) > 16.8 and r + h["walk_bar_half_mid"] > 2.355:
            why.append("counter %d" % deg)
    return why


def report(cfg, n, tank_scale, release_k=0.6, inset=0.0):
    """Per (tag): hit count and depth per obstacle. inset: every station radius minus this (the proof)."""
    rep = {}

    def add(tag, hits, depth):
        if hits:
            cur = rep.setdefault(tag, {"n": 0, "depth": {}})
            cur["n"] += sum(hits.values())
            for k, v in depth.items():
                cur["depth"][k] = round(max(cur["depth"].get(k, 0.0), v), 3)

    def cl(clip, f, props=True):
        return CC.cloud(clip, f, with_props=props, cfg=cfg)

    wb = CC.frames_of("Walk_Bar", 2)
    for deg in range(0, 360, 5):                                   # the arcs, both directions
        for sgn in (1, -1):
            p = math.radians(deg)
            tang = np.array([math.cos(p), 0.0, -math.sin(p)]) * sgn
            yaw = math.atan2(tang[0], tang[2])
            for f in wb:
                add("arc", *bar_hits(CC.place(cl("Walk_Bar", f), ring_pos(deg, ring_radius_at(deg, n) - inset), yaw)))
    for r in np.linspace(3.7, n["gap_r"], 9):                      # the flap leg, facing in
        for f in wb:
            add("flap_leg", *bar_hits(CC.place(cl("Walk_Bar", f), ring_pos(180.0, r - inset), 0.0)))
    for deg in SERVE_DEG:                                          # the serve stands, facing the counter
        pos = ring_pos(deg, n["serve_r"] - inset)
        for clip, step in (("Wipe", 3), ("Serve", 2), ("Idle", 4)):
            last = CC.frames_of(clip, 1)[-1]
            for f in CC.frames_of(clip, step):
                pts = cl(clip, f)
                if clip == "Serve" and f <= release_k * last:
                    pts = np.concatenate([pts, tankard_points(clip, f, tank_scale)])
                add("%s@%d" % (clip, deg), *bar_hits(CC.place(pts, pos, math.radians(deg))))
        for k in range(7):                                         # turning at the stand (Walk_Bar in place)
            for f in wb:
                add("turn@%d" % deg, *bar_hits(CC.place(cl("Walk_Bar", f), pos, math.radians(deg + 90.0 * k / 6))))
        # the last leg: from the ring out to the stand, facing the counter (Walk_Bar)
        for r in np.linspace(ring_radius_at(deg, n), n["serve_r"], 4):
            for f in wb:
                add("in@%d" % deg, *bar_hits(CC.place(cl("Walk_Bar", f), ring_pos(deg, r - inset), math.radians(deg))))
    rpos = ring_pos(180.0, n["restock_r"] - inset)
    for clip, step in (("Pour", 3), ("Restock", 4)):               # the restock station, facing the island
        for f in CC.frames_of(clip, step):
            pts = cl(clip, f)
            if clip == "Pour":
                pts = np.concatenate([pts, tankard_points(clip, f, tank_scale)])
            add("%s@180" % clip, *bar_hits(CC.place(pts, rpos, 0.0)))
    for k in range(7):                                             # turning at the restock station
        for f in wb:
            add("turn@restock", *bar_hits(CC.place(cl("Walk_Bar", f), rpos, math.radians(90.0 * (1 - k / 6)))))
    CC._rest()
    return rep


def counter_top(cfg, clip, tank_scale=0.0, serve_r=None, release_k=0.6):
    """How deep anything of his (props, and the tankard while held) goes below the counter top (1.12) past its face,
    over the clip at a serve stand (serve_r): the hands, the cloth and the tankard ride ON the top."""
    worst = 0.0
    edge = 2.35 - serve_r
    last = CC.frames_of(clip, 1)[-1]
    for f in CC.frames_of(clip, 1):
        p = CC.cloud(clip, f, with_props=True, cfg=cfg)
        if tank_scale and f <= release_k * last:
            p = np.concatenate([p, tankard_points(clip, f, tank_scale)])
        q = p[(p[:, 2] > edge) & (p[:, 1] < 1.12)]
        if len(q):
            worst = max(worst, 1.12 - float(np.min(q[:, 1])))
    CC._rest()
    return round(worst, 4)


def reach_miss(clip, target_fn, side="r"):
    """The slot's worst distance to its target over a clip (two-bone IK stops short out of reach)."""
    import anime_common as AC
    arm = bpy.data.objects["Rig"]
    act = bpy.data.actions[clip]
    last = AC.frames(act)[-1]
    worst = 0.0
    for f in AC.frames(act):
        tgt = target_fn(f / last)
        if tgt is None:                                            # no target at this phase (a transition)
            continue
        m = AC.fk(arm, AC.Curves(act), f, ["handslot." + side])
        worst = max(worst, (m["handslot." + side].translation - tgt).length)
    return round(worst, 4)


def reach_radius(cfg, clip="Walk_Bar", y1=1.12):
    """The farthest any point of the clip (props in) reaches horizontally from his root below y1: what a turn in place
    sweeps (a serve stand must sit this far inside the counter's face)."""
    r = max(float(np.max(np.hypot(*CC.band(CC.cloud(clip, f, with_props=True, cfg=cfg), 0.0, y1)[:, [0, 2]].T)))
            for f in CC.frames_of(clip, 1))
    CC._rest()
    return round(r, 3)
