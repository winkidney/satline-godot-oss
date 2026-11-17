#!/usr/bin/env python3
"""Diagnostic float32 arithmetic oracle; never replaces the original Three fixture."""
import json
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
F = np.float32


def add(a, b):
    return F(F(a) + F(b))


def mul(a, b):
    return F(F(a) * F(b))


def stages(cell):
    a = mul(cell, .3183099)
    b = add(a, [.71, .113, .419])
    f = F(b - np.floor(b))
    p = mul(f, 17)
    xy = mul(p[0], p[1])
    xyz = mul(xy, p[2])
    sx = add(p[0], p[1])
    total = add(sx, p[2])
    product = mul(xyz, total)
    h = F(product - np.floor(product))
    return F([*a, *b, *f, *p, xy, xyz, sx, total, product, h])


def noise(point):
    base = np.floor(F(point))
    fraction = F(F(point) - base)
    weight = mul(mul(fraction, fraction), F(F(3) - mul(2, fraction)))
    h = [stages(add(base, [x, y, z]))[-1] for z in range(2) for y in range(2) for x in range(2)]
    def mix(a, b, t):
        return add(mul(a, F(F(1)-t)), mul(b, t))
    n = mix(mix(mix(h[0],h[1],weight[0]), mix(h[2],h[3],weight[0]),weight[1]),
            mix(mix(h[4],h[5],weight[0]), mix(h[6],h[7],weight[0]),weight[1]),weight[2])
    return {'point': list(map(float, point)), 'expected_bits': int(n.view(np.uint32)),
            'expected': float(n), 'hashes': F(h).view(np.uint32).tolist()}


def main():
    cells = {(22., 92., 1.)}
    noise_points = []
    fixture = json.loads((ROOT / 'assets/export/fixtures/wet-reference.json').read_text())
    for sample in fixture['cases']:
        p = F(sample['vectors']['uPos'])
        mp = mul(p, sample['macro'][2])
        sc = add(p[0], p[2])
        coordinates = [mp, add(mul(mp, 3.7), 11.3), mul(p, 170), add(mul(p, 410), 5)]
        coordinates += [F([mul(sc, 9), mul(p[1], .55), add(mul(sc, .7), 3)]),
                        F([mul(sc, 29), mul(p[1], 1.1), 7]),
                        F([mul(sc, 1.1), mul(p[1], .25), 1.7])]
        for point in coordinates:
            noise_points.append(noise(point))
            base = np.floor(point)
            for z in range(2):
                for y in range(2):
                    for x in range(2):
                        cells.add(tuple(map(float, add(base, [x, y, z]))))
    ordered = [(22., 92., 1.)] + sorted(cells - {(22., 92., 1.)})
    names = [f'{s}.{c}' for s in ['multiply', 'affine', 'fract', 'scaled'] for c in 'xyz']
    names += ['xy', 'xyz', 'sum_xy', 'sum_xyz', 'product', 'hash']
    report = {'scope': 'CPU separated float32 diagnostic, not original GPU authority',
              'numpy': np.__version__, 'stages': names,
              'cases': [{'cell': cell, 'expected_bits': stages(cell).view(np.uint32).tolist()} for cell in ordered],
              'noise_points': noise_points}
    output = ROOT / 'evidence/wet-hash-diagnostic-input.json'
    output.write_text(json.dumps(report, separators=(',', ':')) + '\n')
    print(json.dumps({'cells': len(ordered), 'output': str(output), 'corner_hash': float(stages(ordered[0])[-1])}))


if __name__ == '__main__':
    main()
