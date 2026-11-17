#!/usr/bin/env python3
"""Check the moving quay wall in a fixed-step, 60 fps --sea-preview recording."""
import argparse
import subprocess

import numpy as np


parser = argparse.ArgumentParser()
parser.add_argument("video", help="Recording from --sea-preview at 60 fps")
args = parser.parse_args()
result = subprocess.run(
    ["ffmpeg", "-v", "error", "-i", args.video, "-vf",
     r"select=between(n\,165\,319),scale=1280:720,crop=740:244:172:210,format=gray",
     "-fps_mode", "passthrough", "-f", "rawvideo", "-pix_fmt", "gray", "-"],
    check=True, capture_output=True,
)
frames = np.frombuffer(result.stdout, dtype=np.uint8)
if frames.size != 155 * 244 * 740:
    raise SystemExit("Expected 155 frames from the quay camera path")
frames = frames.reshape(155, 244, 740)
tan_half_fov = np.tan(np.deg2rad(74) / 2)


def camera(frame):
    position = np.array([34., 2., 6. - (frame - 160) / 160 * 3])
    forward = np.array([30., -1.6, 3.]) - position
    forward /= np.linalg.norm(forward)
    right = np.cross(forward, [0, 1, 0])
    right /= np.linalg.norm(right)
    return position, forward, right, np.cross(right, forward)


def world_point(x, y):
    position, forward, right, up = camera(180)
    ray = forward + right * ((2 * x / 1280 - 1) * tan_half_fov * 1280 / 720) + up * ((1 - 2 * y / 720) * tan_half_fov)
    return position + ray * ((30 - position[0]) / ray[0])


regions = {
    'near_upper': [world_point(x, y) for x, y in ((200, 379), (400, 323), (400, 348), (200, 404))],
    'near_lower': [world_point(x, y) for x, y in ((200, 419), (400, 363), (400, 388), (200, 444))],
    'far_upper': [world_point(x, y) for x, y in ((600, 267), (800, 211), (800, 236), (600, 292))],
    'far_lower': [world_point(x, y) for x, y in ((600, 307), (800, 251), (800, 276), (600, 332))],
}
y, x = np.indices((244, 740))
x, y = x + 172, y + 210
values = {name: [] for name in regions}
for number, image in enumerate(frames, 165):
    position, forward, right, up = camera(number)
    for name, corners in regions.items():
        polygon = []
        for point in corners:
            delta = point - position
            depth = delta @ forward
            polygon.append((640 * (1 + (delta @ right) / depth / (tan_half_fov * 1280 / 720)),
                            360 * (1 - (delta @ up) / depth / tan_half_fov)))
        edges = []
        for a, b in zip(polygon, polygon[1:] + polygon[:1]):
            edges.append((b[0] - a[0]) * (y - a[1]) - (b[1] - a[1]) * (x - a[0]))
        mask = np.all(np.asarray(edges) >= 0, axis=0) | np.all(np.asarray(edges) <= 0, axis=0)
        if mask.sum() < 1000:
            raise SystemExit(f"Quay {name} region left the expected camera view")
        values[name].append(float(image[mask].mean()))
passed = True
for name, samples in values.items():
    jumps = np.abs(np.diff(samples))
    mean_jump, max_jump = float(jumps.mean()), float(jumps.max())
    region_passed = mean_jump < 5 and max_jump < 15
    passed &= region_passed
    print(f"Quay {name}, frames 165–319: mean/max brightness jump {mean_jump:.2f}/{max_jump:.2f}; {'PASS' if region_passed else 'FAIL'}")
raise SystemExit(0 if passed else 1)
