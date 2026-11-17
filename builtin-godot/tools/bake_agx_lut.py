#!/usr/bin/env python3
"""Approximate the source ACES/AgX blend with a native, post-tonemap 3D LUT."""
from pathlib import Path
import numpy as np

size = 128
axis = (np.arange(size, dtype=np.float64) + .5) / size
axis[0], axis[-1] = 0, 1
red, green = np.meshgrid(axis, axis)
M = np.array([[.59719, .35458, .04823], [.07600, .90834, .01566], [.02840, .13383, .83777]])
O = np.array([[1.60475, -.53108, -.07367], [-.10208, 1.10813, -.00605], [-.00327, -.07276, 1.07602]])
S = np.array([[.6274, .3293, .0433], [.0691, .9195, .0113], [.0164, .0880, .8956]])
R = np.array([[1.6605, -.5876, -.0728], [-.1246, 1.1329, -.0083], [-.0182, -.1006, 1.1187]])
inset = np.array([[.856627153315983, .0951212405381588, .0482516061458583],
                  [.137318972929847, .761241990602591, .101439036467562],
                  [.11189821299995, .0767994186031903, .811302368396859]])
outset = np.array([[1.1271005818144368, -.11060664309660323, -.016493938717834573],
                   [-.1413297634984383, 1.157823702216272, -.016493938717834257],
                   [-.14132976349843826, -.11060664309660294, 1.2519364065950405]])
inverse_m, inverse_o = np.linalg.inv(M), np.linalg.inv(O)


def curve(value):
    return (value * (value + .0245786) - .000090537) / (value * (.983729 * value + .4329510) + .238081)


def encode(value):
    value = np.clip(value, 0, 1)
    return np.where(value <= .0031308, value * 12.92, 1.055 * value ** (1 / 2.4) - .055)


def grade(color):
    luminance = color @ np.array([.2126, .7152, .0722])
    t = np.clip((luminance - .03) / .52, 0, 1)
    t = t * t * (3 - 2 * t)
    shadow, highlight = np.array([.8, 1.01, 1.13]), np.array([1.07, 1, .9])
    color = color * (shadow + (highlight - shadow) * t[..., None])
    color = .78 * color + .22 * color * color * (3 - 2 * color)
    return np.clip(color * .988 + np.array([.006, .0085, .011]), 0, 1)


def agx(hdr):
    color = (hdr @ S.T) @ inset.T
    color = np.clip((np.log2(np.maximum(color, 1e-10)) + 12.47393) / 16.5, 0, 1)
    x2, x4 = color * color, color * color * color * color
    color = 15.5*x4*x2 - 40.14*x4*color + 31.96*x4 - 6.868*x2*color + .4298*x2 + .1191*color - .00232
    luminance = color @ np.array([.2126, .7152, .0722])
    color = luminance[..., None] + (np.maximum(color, 0) ** 1.18 - luminance[..., None]) * 1.22
    color = np.maximum(color @ outset.T, 0) ** 2.2
    return np.clip(color @ R.T, 0, 1)


white = curve(1.8 * 14.26024)
layers = []
for blue in axis:
    srgb = np.stack((red, green, np.full_like(red, blue)), axis=-1)
    y = np.where(srgb <= .04045, srgb / 12.92, ((srgb + .055) / 1.055) ** 2.4)
    q = np.clip((white * y) @ inverse_o.T, 0, 1 / .983729 - .0001)
    a, b, k = 1 - .983729*q, .0245786 - .4329510*q, .000090537 + .238081*q
    discriminant = np.sqrt(np.maximum(b*b + 4*a*k, 0))
    root = np.where(b >= 0, 2*k / np.maximum(b + discriminant, 1e-12), (-b + discriminant) / np.maximum(2*a, 1e-12))
    hdr = np.clip((root @ inverse_m.T) / 1.3, 0, 64)
    reconstructed = encode(np.clip((curve((hdr * 1.3) @ M.T) @ O.T) / white, 0, 1))
    residual = np.max(np.abs(reconstructed - srgb), axis=-1)
    weight = np.clip((residual - .08) / .17, 0, 1)
    weight = 1 - weight * weight * (3 - 2 * weight)
    mixed = y + .25 * weight[..., None] * (agx(hdr) - y)
    mixed[np.max(srgb, axis=-1) == 0] = 0
    result = encode(grade(np.clip(mixed, 0, 1)))
    layers.append(np.concatenate((result, np.ones((*result.shape[:2], 1))), axis=-1).astype('<f2').tobytes())
target = Path(__file__).resolve().parents[1] / 'assets/source-grade-agx-128.rgba16f'
target.write_bytes(b''.join(layers))
print('Wrote', target.name, 'with', size, 'slices; clipped or invalid colors use a smooth fallback.')
