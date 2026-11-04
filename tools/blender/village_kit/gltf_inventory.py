"""Inventory a folder of .gltf files: bounds (world, node transforms applied), tris, materials, textures.
Usage: python -I gltf_inventory.py <gltf_dir> <out_json>
"""
import json
import struct
import sys
import os
import math

COMP = {5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}
NCOMP = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def node_matrix(n):
    if 'matrix' in n:
        m = n['matrix']
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = n.get('translation', [0, 0, 0])
    q = n.get('rotation', [0, 0, 0, 1])
    s = n.get('scale', [1, 1, 1])
    x, y, z, w = q
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    m = [[r[i][j] * s[j] for j in range(3)] + [t[i]] for i in range(3)]
    m.append([0, 0, 0, 1])
    return m


def read_positions(g, buf, acc_i):
    acc = g['accessors'][acc_i]
    bv = g['bufferViews'][acc['bufferView']]
    fmt, size = COMP[acc['componentType']]
    n = NCOMP[acc['type']]
    stride = bv.get('byteStride', size * n)
    off = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
    out = []
    for i in range(acc['count']):
        out.append(struct.unpack_from('<' + fmt * n, buf, off + i * stride))
    return out


def inventory(path):
    g = json.load(open(path, encoding='utf-8'))
    d = os.path.dirname(path)
    buf = open(os.path.join(d, g['buffers'][0]['uri']), 'rb').read()
    mats = [m.get('name', '?') for m in g.get('materials', [])]
    tex_of_mat = {}
    imgs = [im.get('uri', im.get('name', '?')) for im in g.get('images', [])]
    texs = g.get('textures', [])
    for m in g.get('materials', []):
        used = []
        pbr = m.get('pbrMetallicRoughness', {})
        for key in ('baseColorTexture', 'metallicRoughnessTexture'):
            if key in pbr:
                used.append(imgs[texs[pbr[key]['index']]['source']])
        for key in ('normalTexture', 'occlusionTexture', 'emissiveTexture'):
            if key in m:
                used.append(imgs[texs[m[key]['index']]['source']])
        bc = pbr.get('baseColorFactor')
        tex_of_mat[m.get('name', '?')] = {'tex': used, 'factor': bc, 'alpha': m.get('alphaMode', 'OPAQUE'), 'double': m.get('doubleSided', False)}
    lo = [math.inf] * 3
    hi = [-math.inf] * 3
    tris = 0
    used_mats = set()
    scene = g['scenes'][g.get('scene', 0)]
    stack = [(i, [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]) for i in scene['nodes']]
    nodes_named = []
    while stack:
        ni, parent = stack.pop()
        n = g['nodes'][ni]
        m = mat_mul(parent, node_matrix(n))
        nodes_named.append(n.get('name', '?'))
        if 'mesh' in n:
            for p in g['meshes'][n['mesh']]['primitives']:
                pos = read_positions(g, buf, p['attributes']['POSITION'])
                if 'indices' in p:
                    tris += g['accessors'][p['indices']]['count'] // 3
                else:
                    tris += len(pos) // 3
                if 'material' in p:
                    used_mats.add(mats[p['material']])
                for v in pos:
                    w = [sum(m[i][k] * (list(v) + [1])[k] for k in range(4)) for i in range(3)]
                    for i in range(3):
                        lo[i] = min(lo[i], w[i])
                        hi[i] = max(hi[i], w[i])
        for c in n.get('children', []):
            stack.append((c, m))
    return {
        'min': [round(x, 3) for x in lo], 'max': [round(x, 3) for x in hi],
        'size': [round(hi[i] - lo[i], 3) for i in range(3)],
        'tris': tris, 'materials': sorted(used_mats), 'mat_detail': tex_of_mat,
        'nodes': nodes_named[:6], 'skins': len(g.get('skins', [])), 'anims': len(g.get('animations', [])),
    }


def main():
    src, out = sys.argv[1], sys.argv[2]
    res = {}
    for f in sorted(os.listdir(src)):
        if f.endswith('.gltf'):
            try:
                res[f[:-5]] = inventory(os.path.join(src, f))
            except Exception as e:  # report, never swallow
                res[f[:-5]] = {'error': repr(e)}
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(res, fh, indent=1)
    errs = [k for k, v in res.items() if 'error' in v]
    print('models', len(res), 'errors', len(errs), errs[:5])


if __name__ == '__main__':
    main()
