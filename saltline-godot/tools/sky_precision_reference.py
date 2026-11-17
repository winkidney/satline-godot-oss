#!/usr/bin/env python3
"""Diagnose sky filtering precision with NumPy; does not replace GPU acceptance.

Run from any directory. Dependency: numpy. Input texture is the original exported
RGBA byte buffer, in its original bottom-to-top row order. The exact model uses
float64 arithmetic and mathematical bilinear filtering. Quantized weight models
are sensitivity experiments, not measurements of any GPU's filtering algorithm.
"""

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]


def mix(a, b, t):
    return a * (1.0 - t) + b * t


def smoothstep(a, b, value):
    t = np.clip((value - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def normalize(value):
    return value / np.linalg.norm(value)


def evaluate_sky(row, uniforms, texture, weight_divisions=0):
    def v(*values):
        return np.array(values, dtype=np.float64)

    def n2(point):
        cell = np.floor(point).astype(np.int64)
        fraction = point - cell
        fraction = fraction * fraction * (3.0 - 2.0 * fraction)
        if weight_divisions:
            fraction = np.floor(fraction * weight_divisions + 0.5) / weight_divisions
        x, y = cell % 256
        right, upper = (cell + 1) % 256
        a, b = texture[y, x], texture[y, right]
        c, d = texture[upper, x], texture[upper, right]
        return mix(mix(a, b, fraction[0]), mix(c, d, fraction[0]), fraction[1])

    rotation = np.array([[1.6, -1.2], [1.2, 1.6]])

    def fbm(point, count):
        amplitude, total = 0.5, 0.0
        for _ in range(count):
            total += amplitude * n2(point)
            point = rotation @ point + 17.3
            amplitude *= 0.5
        return total / (1.0 - 2.0 ** (-count))

    sun = np.asarray(uniforms["uSunDir"], dtype=np.float64)
    horizon = np.asarray(uniforms["uHor"], dtype=np.float64)
    away = np.asarray(uniforms["uHorAway"], dtype=np.float64)
    sun_color = np.asarray(uniforms["uSunCol"], dtype=np.float64)
    flash_direction = np.asarray(uniforms["uFlashDir"], dtype=np.float64)
    direction = normalize(np.asarray(row["direction"], dtype=np.float64))
    height = max(direction[1], 0.0)
    mu = direction @ sun
    sun_dot = max(mu, 0.0)
    to_sun = np.clip(
        normalize(direction[[0, 2]] + 1e-5) @ normalize(sun[[0, 2]]) * 0.5 + 0.5,
        0.0,
        1.0,
    )
    hc = mix(away, away * 1.25 + v(0.05, 0.03, 0.02), smoothstep(0.2, 0.75, to_sun))
    hc = mix(hc, horizon * v(1.9, 1.55, 1.2), to_sun**6)
    hc = mix(hc, v(1.0, 0.60, 0.24) * 3.4, to_sun**34)
    mid = mix(v(0.15, 0.24, 0.36), v(0.72, 0.50, 0.34), to_sun**3)
    clear = mix(hc, mid, smoothstep(0.0, 0.17, height))
    clear = mix(clear, v(0.085, 0.145, 0.24), smoothstep(0.10, 0.5, height))
    clear += sun_color * v(1.0, 0.86, 0.68) * (
        sun_dot**8 * 0.14 + sun_dot**64 * 0.55
        + sun_dot**600 * 2.2 + sun_dot**6000 * 14.0
    )
    q = direction[[0, 2]] / (height + 0.10) * v(0.62, 0.95)
    q += v(-0.012, 0.004) * row["time"]
    warp = fbm(q * 0.45 + 7.1, 3)
    qq = q + (warp - 0.5) * 1.3
    density_fbm = fbm(qq, 5)
    ridge = 1.0 - abs(2.0 * fbm(qq * 3.1 + 5.0, 3) - 1.0)
    density = density_fbm * 0.86 + (ridge - 0.6) * 0.16 * smoothstep(0.03, 0.25, height)
    big = n2(q * 0.19 + 3.7)
    body = density * 0.74 + big * 0.36
    coverage = smoothstep(0.31, 0.50, body)
    edge = mix(0.030, 0.285, to_sun**1.7)
    rag = (n2(q * 0.9 + 11.0) - 0.5) * 0.16 + (density - 0.5) * 0.10
    deck = smoothstep(edge - 0.035, edge + 0.11, height + rag * (0.35 + to_sun))
    coverage *= deck
    hole = smoothstep(0.972, 0.9985, mu + (density - 0.5) * 0.012)
    coverage *= 1.0 - 0.93 * hole
    scud = smoothstep(0.55, 0.85, fbm(q * v(0.55, 1.9) + 31.0, 3))
    scud *= (1.0 - deck) * smoothstep(0.02, 0.10, height) * 0.55 * (1.0 - 0.8 * hole)
    density_sun = fbm(qq + normalize(sun[[0, 2]]) * 0.22, 5)
    relief = np.clip((density - density_sun) * 4.5 + 0.5, 0.0, 1.0)
    thick = smoothstep(0.40, 0.72, body)
    cool = mix(v(0.155, 0.195, 0.255), v(0.030, 0.042, 0.064), thick)
    cool *= 0.55 + 0.9 * relief * relief
    cool += v(0.07, 0.10, 0.15) * (1.0 - thick)**3
    near_sun = to_sun**5 * np.exp(-max(height - edge, 0.0) * 4.5) * 0.9 + sun_dot**7 * 0.9
    warm = horizon * v(1.30, 0.66, 0.40) * near_sun * (0.05 + 2.2 * relief**3) * 1.15
    rim = coverage * (1.0 - coverage) * 4.0
    warm += sun_color * rim * to_sun**4 * (0.5 + 1.6 * sun_dot**6) * (1.0 - 0.85 * hole)
    cloud = cool + warm
    flash = row["flash"] * max(direction @ flash_direction, 0.0)**5
    cloud += v(0.55, 0.68, 1.0) * flash * (0.4 + 2.2 * density * density)
    cloud = mix(cloud, hc * 0.55 + cloud * 0.45, np.exp(-height * 11.0))
    color = mix(clear, cloud, coverage * 0.985)
    scud_color = mix(v(0.10, 0.11, 0.14), horizon * 1.5, to_sun**3)
    scud_color += sun_color * sun_dot**24 * 2.0
    color = mix(color, scud_color, scud)
    veil = (1.0 - coverage * 0.92) * (1.0 - scud * 0.7)
    disk = smoothstep(0.999905, 0.999955, mu)
    color += v(1.0, 0.80, 0.52) * disk * 110.0 * veil * (1.0 - row["env"])
    if direction[1] < 0.0:
        t = np.clip(-direction[1] * 5.0, 0.0, 1.0)
        low = mix(away * 0.42, v(0.060, 0.064, 0.070), row["env"])
        low += horizon * 0.55 * to_sun**6 * np.exp(direction[1] * 7.0)
        color = mix(hc + sun_color * sun_dot**48 * 1.5, low, smoothstep(0.0, 1.0, t))
    color = mix(color, np.minimum(color, 6.0), row["env"])
    intermediates = {
        "warp": warp, "density_fbm": density_fbm, "density": density,
        "density_sun": density_sun, "relief": relief, "body": body, "coverage": coverage,
    }
    return np.maximum(color, 0.0), {key: float(value) for key, value in intermediates.items()}


def file_info(path):
    return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def error_metrics(actual, expected, case_indices=None):
    error = np.abs(actual - expected)
    case, channel = np.unravel_index(np.argmax(error), error.shape)
    tolerance = np.maximum(0.004, np.abs(expected) * 0.002)
    return {
        "mean_absolute_error": float(error.mean()),
        "maximum_absolute_error": float(error.max()),
        "compared_cases": len(actual),
        "maximum_case": int(case if case_indices is None else case_indices[case]),
        "maximum_channel": int(channel),
        "channels_above_gpu_acceptance_tolerance": int(np.count_nonzero(error > tolerance)),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-report", type=Path, default=ROOT / "evidence/sky-gpu-verification.json")
    parser.add_argument("--native-label", default="current native GPU report")
    parser.add_argument("--post-fix-report", type=Path)
    parser.add_argument("--webgl-backend", default="not recorded")
    parser.add_argument("--native-backend", default="not recorded")
    parser.add_argument("--output", type=Path, default=ROOT / "evidence/sky-precision-analysis.json")
    args = parser.parse_args()
    scene_path = ROOT / "assets/prepared/scene.json"
    reference_path = ROOT / "assets/export/fixtures/sky-gpu-reference.json"
    scene = json.loads(scene_path.read_text())
    material = next(item for item in scene["materials"] if item["name"] == "saltline-sky")
    uniforms = {key: item["value"] for key, item in material["uniforms"].items()}
    texture_record = next(item for item in scene["textures"] if item["id"] == uniforms["tNoise"]["$texture"])
    texture_path = ROOT / "assets/export" / texture_record["file"]
    texture = np.frombuffer(texture_path.read_bytes(), dtype=np.uint8).reshape(256, 256, 4)[:, :, 0] / 255.0
    reference = json.loads(reference_path.read_text())
    native = json.loads(args.native_report.read_text())
    post_fix = json.loads(args.post_fix_report.read_text()) if args.post_fix_report else None
    native_samples = sorted(native["samples"], key=lambda row: row["case"])
    cases = reference["cases"]
    native_case_indices = [row["case"] for row in native_samples]
    if (not native_case_indices or len(set(native_case_indices)) != len(native_case_indices)
            or min(native_case_indices) < 0 or max(native_case_indices) >= len(cases)):
        raise ValueError("Native observations must contain unique case numbers from the reference")
    expected = np.array([row["color"] for row in cases])
    native_values = np.array([row["actual"] for row in native_samples])
    post_fix_values = None
    if post_fix is not None:
        post_fix_samples = sorted(post_fix["samples"], key=lambda row: row["case"])
        if [row["case"] for row in post_fix_samples] != list(range(len(cases))):
            raise ValueError("Post-fix report must contain exactly the same numbered cases")
        post_fix_values = np.array([row["actual"] for row in post_fix_samples])
    models = []
    for divisions in (0, 128, 256, 65536):
        results = [evaluate_sky(row, uniforms, texture, divisions) for row in cases]
        values = np.array([result[0] for result in results])
        models.append({
            "model": "exact_bilinear_float64" if divisions == 0 else f"rounded_weights_1_over_{divisions}",
            "weight_divisions": divisions,
            "against_original_three_gpu": error_metrics(values, expected),
            "against_native_snapshot": error_metrics(values[native_case_indices], native_values, native_case_indices),
            "samples": [{"case": index, "color": value.tolist(), "intermediates": result[1]}
                        for index, (value, result) in enumerate(zip(values, results))],
        })
        if post_fix_values is not None:
            models[-1]["against_post_fix_native"] = error_metrics(values, post_fix_values)
    report = {
        "scope": "Diagnostic CPU float64 reconstruction of the original sky shader, not a replacement for original Three GPU reference or native GPU acceptance.",
        "numpy_version": np.__version__, "cases": len(cases), "channels": int(expected.size),
        "backends": {"original_three": args.webgl_backend, "native_godot": args.native_backend,
                     "source": "Runtime backend observations supplied through command-line arguments; see companion GPU backend metadata for original observation."},
        "provenance": {"scene": file_info(scene_path), "noise_rgba": file_info(texture_path),
                       "diagnostic_script": file_info(Path(__file__).resolve()),
                       "original_fragment_shader_sha256": hashlib.sha256(material["fragmentShader"].encode()).hexdigest(),
                       "three_gpu_reference": file_info(reference_path),
                       "native_snapshot": dict(file_info(args.native_report), label=args.native_label)},
        "limitations": [
            "CPU uses float64; original GPU math uses float32 and native readback uses RGBA16F.",
            "A partial native snapshot compares only its explicitly captured case indices, not all reference cases.",
            "Quantized weight models measure sensitivity and do not identify the actual GPU filter implementation.",
            "This calculation excludes sky cube geometry, camera interpolation, final tone mapping, and postprocessing.",
        ],
        "interpretation": "The exact bilinear result is very close to the original Three GPU. Perturbing only interpolation weights changes the failing cases, supporting a filtering-precision hypothesis. A native four-texelFetch bilinear experiment is needed to establish whether replacing hardware filtering resolves the discrepancy.",
        "native_snapshot": native,
        "models": models,
    }
    if post_fix is not None:
        report["provenance"]["post_fix_native"] = file_info(args.post_fix_report)
        report["post_fix_native"] = post_fix
        report["post_fix_against_original_three_gpu"] = error_metrics(post_fix_values, expected)
        passes = report["post_fix_against_original_three_gpu"]["channels_above_gpu_acceptance_tolerance"] == 0
        outcome = "passes" if passes else "does not pass"
        report["interpretation"] = (
            f"Recorded original Three backend: {args.webgl_backend}. Recorded native Godot backend: {args.native_backend}. "
            "The float64 exact-bilinear reconstruction closely matches the original Three GPU. "
            "Replacing native hardware texture filtering with four texelFetch calls and explicit bilinear mix "
            f"{outcome} the original GPU tolerance without changing the fixture. "
            "These experiments test filtering precision as the source of the prior amplified FBM discrepancy; "
            "they do not measure the exact hardware interpolation-weight format. Remaining HDR readback residuals include intermediate and "
            "final rendering precision and are not identified as a single float16 conversion."
        )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    print(json.dumps({"output": str(args.output), "cases": len(cases),
                      "models": [{key: value for key, value in model.items() if key != "samples"}
                                 for model in models]}, indent=2))


if __name__ == "__main__":
    main()
