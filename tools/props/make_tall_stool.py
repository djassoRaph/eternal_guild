# make_tall_stool.py - Story 25.31 S2.0 (AC 10b, R-5): the bar stool at bar height, as a NEW asset
# (assets/environment/custom/b2_bar_stool_tall.gltf + .bin; the 25.6 b2_bar_stool.gltf is untouched).
# Pure Python (numpy): the 25.6 stool's design (b2_builder.build_stool: an octagonal seat 0.045 thick, four splayed
# legs from r 0.12 under the seat to r 0.20 on the floor, a ring of stretchers) raised to SEAT, the stretcher ring at
# the foot height FOOT = SEAT - 0.45 (the realistic sit clips are fitted to a 0.45 m chair: a seated patron's soles sit
# 0.45 under the seat), plus a footrest under the sitter's feet: two rails from the front legs forward to a crossbar at
# FOOT_FWD in front of the seat centre (+Z, the sitter's facing), its top at FOOT. The floor footprint is the 25.6
# stool's (legs at r 0.20). Same atlas cells and material as the 25.6 stool (kaykit_atlas_mat, hexagons_medieval.png).
import json
import math
import os
import struct
import sys

import numpy as np

OUT_DIR = "F:/GAME I AM MAKING/shiningsun/assets/environment/custom/"
NAME = "b2_bar_stool_tall"
SEAT = 0.72          # the seat_point (m): seated elbows at the counter top (REAL-1 0.39, REAL-2 0.36 above the seat; top 1.10)
FOOT = SEAT - 0.45   # the foot ring / footrest top: the sit clip's soles
FOOT_FWD = 0.38      # the footrest crossbar's centre in front of the seat centre (soles 0.27-0.62 ahead of the hips)
WOOD_LIGHT = (0.6875, 0.0635)
WOOD_DARK = (0.8125, 0.1625)
TRI_BUDGET = 150

tris = []            # (p0, p1, p2, uv)


def quad(a, b, c, d, uv):
    tris.append((a, b, c, uv))
    tris.append((a, c, d, uv))


def V(*a):
    return np.array(a, dtype=float)


def beam(p0, p1, w, h, up, uv, cap0=True, cap1=True):
    """A box beam from p0 to p1, cross-section w (across) x h (along `up` projected off the axis)."""
    d = p1 - p0
    d = d / np.linalg.norm(d)
    u = up - d * np.dot(up, d)
    u = u / np.linalg.norm(u)
    v = np.cross(d, u)
    corners = [(+1, +1), (-1, +1), (-1, -1), (+1, -1)]
    r0 = [p0 + v * (sx * w / 2) + u * (sy * h / 2) for sx, sy in corners]
    r1 = [p1 + v * (sx * w / 2) + u * (sy * h / 2) for sx, sy in corners]
    for k in range(4):
        a, b = k, (k + 1) % 4
        quad(r0[a], r1[a], r1[b], r0[b], uv)
    if cap0:
        quad(r0[0], r0[1], r0[2], r0[3], uv)
    if cap1:
        quad(r1[3], r1[2], r1[1], r1[0], uv)


def seat():
    n, rot = 8, math.radians(22.5)
    y0, y1 = SEAT - 0.045, SEAT
    bot = [V(0.19 * math.cos(rot + 2 * math.pi * k / n), y0, 0.19 * math.sin(rot + 2 * math.pi * k / n)) for k in range(n)]
    top = [V(0.20 * math.cos(rot + 2 * math.pi * k / n), y1, 0.20 * math.sin(rot + 2 * math.pi * k / n)) for k in range(n)]
    for k in range(n):
        j = (k + 1) % n
        quad(bot[k], top[k], top[j], bot[j], WOOD_LIGHT)
    for k in range(1, n - 1):
        tris.append((top[0], top[k + 1], top[k], WOOD_LIGHT))
        tris.append((bot[0], bot[k], bot[k + 1], WOOD_LIGHT))


def leg_point(a, y):
    """The leg at heading a (radians) at height y: r 0.20 on the floor to 0.12 under the seat."""
    t = y / (SEAT - 0.045)
    r = 0.20 + (0.12 - 0.20) * t
    return V(r * math.cos(a), y, r * math.sin(a))


def build():
    seat()
    up = V(0, 1, 0)
    heads = [math.radians(45 + 90 * k) for k in range(4)]
    for a in heads:
        beam(leg_point(a, 0.0), leg_point(a, SEAT - 0.045), 0.04, 0.04, V(math.cos(a), 0, math.sin(a)), WOOD_DARK, cap0=False, cap1=False)
    # the foot ring: stretchers between the legs, their tops at FOOT
    ring = [leg_point(a, FOOT - 0.0125) for a in heads]
    for k in range(4):
        beam(ring[k], ring[(k + 1) % 4], 0.025, 0.025, up, WOOD_DARK, cap0=False, cap1=False)
    # the footrest: rails from the two front legs (+Z: headings 45 and 135 degrees) forward to the crossbar
    front = [ring[0], ring[1]]
    bar_y = FOOT - 0.015
    ends = [V(p[0] * 1.15, bar_y, FOOT_FWD) for p in front]
    for p, e in zip(front, ends):
        beam(V(p[0], bar_y, p[2]), e, 0.025, 0.025, up, WOOD_DARK, cap0=False, cap1=True)
    beam(ends[0] + V(0.02, 0, 0), ends[1] - V(0.02, 0, 0), 0.04, 0.03, up, WOOD_DARK)


def write():
    pos, nor, uvs = [], [], []
    for a, b, c, uv in tris:
        n = np.cross(b - a, c - a)
        n = n / np.linalg.norm(n)
        for p in (a, b, c):
            pos.append(p)
            nor.append(n)
            uvs.append(uv)
    # glTF winding is counter-clockwise for the front face: check every face points away from its part's centre later
    pos = np.array(pos, dtype=np.float32)
    nor = np.array(nor, dtype=np.float32)
    uvs = np.array(uvs, dtype=np.float32)
    idx = np.arange(len(pos), dtype=np.uint16)
    blobs = [pos.tobytes(), nor.tobytes(), uvs.tobytes(), idx.tobytes()]
    pad = [(-len(b)) % 4 for b in blobs]
    data = b"".join(b + b"\0" * p for b, p in zip(blobs, pad))
    offs = np.cumsum([0] + [len(b) + p for b, p in zip(blobs, pad)])[:-1]
    src = json.load(open(OUT_DIR + "b2_bar_stool.gltf", encoding="utf-8"))
    g = {
        "asset": {"generator": "Eternal Guild make_tall_stool.py (Story 25.31 S2.0)", "version": "2.0"},
        "scene": 0,
        "scenes": [{"name": "Scene", "nodes": [2]}],
        "nodes": [{"mesh": 0, "name": "bar_stool"}, {"name": "seat_point", "translation": [0, SEAT, 0]},
                  {"children": [0, 1], "name": NAME}],
        "materials": src["materials"],
        "meshes": [{"name": "bar_stool", "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                                                          "indices": 3, "material": 0}]}],
        "textures": src["textures"], "images": src["images"], "samplers": src["samplers"],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(pos), "type": "VEC3",
             "min": pos.min(0).tolist(), "max": pos.max(0).tolist()},
            {"bufferView": 1, "componentType": 5126, "count": len(pos), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": len(pos), "type": "VEC2"},
            {"bufferView": 3, "componentType": 5123, "count": len(idx), "type": "SCALAR"}],
        "bufferViews": [{"buffer": 0, "byteOffset": int(offs[i]), "byteLength": len(blobs[i]),
                         "target": 34963 if i == 3 else 34962} for i in range(4)],
        "buffers": [{"byteLength": len(data), "uri": NAME + ".bin"}],
    }
    for ext in (".gltf", ".bin"):
        if os.path.exists(OUT_DIR + NAME + ext) and "--overwrite" not in sys.argv:
            sys.exit("%s exists (--overwrite to rewrite this new asset)" % (OUT_DIR + NAME + ext))
    with open(OUT_DIR + NAME + ".bin", "wb") as f:
        f.write(data)
    with open(OUT_DIR + NAME + ".gltf", "w", encoding="utf-8", newline="\n") as f:
        json.dump(g, f, indent=1)
    print("TRIS bar_stool_tall %d / %d %s" % (len(tris), TRI_BUDGET, "OK" if len(tris) <= TRI_BUDGET else "OVER"))
    print("seat_point %.3f, foot ring / footrest top %.3f, footrest %.2f ahead; bounds %s %s" % (
        SEAT, FOOT, FOOT_FWD, np.round(pos.min(0), 3), np.round(pos.max(0), 3)))


def outward_check():
    """Every face's normal points away from its own part (no inverted faces): for convex parts the face centre minus
    the part's centre dotted with the normal is > 0. Parts: consecutive tris of one beam / the seat."""
    bad = 0
    for a, b, c, uv in tris:
        n = np.cross(b - a, c - a)
        if np.linalg.norm(n) < 1e-12:
            bad += 1
    return bad


if __name__ == "__main__":
    build()
    print("degenerate faces", outward_check())
    write()
