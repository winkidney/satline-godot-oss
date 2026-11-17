#!/usr/bin/env python3
"""Fit the observed inline hash error; diagnostic arithmetic, not a replacement noise."""
import hashlib
import json
import numpy as np
from wet_hash_precision_reference import ROOT, F, add, mul, noise


def distributed_noise(point):
    base = np.floor(F(point))
    fraction = F(F(point) - base)
    weight = mul(mul(fraction, fraction), F(F(3) - mul(2, fraction)))
    hashes = []
    for z in range(2):
        for y in range(2):
            for x in range(2):
                # Deliberate alternate evaluation, unlike original (base+corner)*c.
                a = add(mul(base, .3183099), mul([x, y, z], .3183099))
                a = add(a, [.71, .113, .419])
                p = mul(F(a - np.floor(a)), 17)
                product = mul(mul(mul(p[0], p[1]), p[2]), add(add(p[0], p[1]), p[2]))
                hashes.append(F(product - np.floor(product)))
    def mix(a, b, t):
        return add(mul(a, F(F(1)-t)), mul(b, t))
    h, w = hashes, weight
    return mix(mix(mix(h[0],h[1],w[0]),mix(h[2],h[3],w[0]),w[1]),
               mix(mix(h[4],h[5],w[0]),mix(h[6],h[7],w[0]),w[1]),w[2])


def main():
    inputs_path = ROOT / 'evidence/wet-hash-diagnostic-input.json'
    observed_path = ROOT / 'evidence/wet-canvas-noise-verification.json'
    inputs = json.loads(inputs_path.read_text())['noise_points']
    observed = json.loads(observed_path.read_text())['reports']
    bits = next(r['bits'] for r in observed if r['mode'] == 'full_guard')
    gpu = np.asarray(bits, dtype=np.uint32).view(F)
    report = {'scope': 'CPU arithmetic fit to measured full_guard without input barrier; not a driver disassembly',
              'numpy': np.__version__, 'samples': len(inputs),
              'sources': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in [inputs_path, observed_path]},
              'models': []}
    for name, values in [('original_parenthesized', [noise(x['point'])['expected'] for x in inputs]),
                         ('distributed_base_product', [distributed_noise(x['point']) for x in inputs])]:
        errors = np.abs(F(values)-gpu)
        report['models'].append({'name': name, 'max_abs': float(errors.max()),
                                 'differences_above_1e_6': int((errors>1e-6).sum())})
    path = ROOT / 'evidence/wet-hash-distribution-analysis.json'
    path.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report['models']))


if __name__ == '__main__':
    main()
