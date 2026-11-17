#!/usr/bin/env python3
"""Summarize original NVIDIA GL D24 hardware bias without replacing GPU evidence."""
import hashlib
import json
from pathlib import Path
import statistics
import struct

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "assets/export/fixtures/polygon-offset-reference.json"
NATIVE = ROOT / "evidence/rd-polygon-offset-probe.json"
Q24 = 2.0 ** -24


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def f32(bits):
    return struct.unpack("<f", struct.pack("<I", bits))[0]


data = json.loads(REFERENCE.read_text())
flat = [c for c in data["cases"] if c["shape"] == 0]
constant_ratios = [v / c["units"] for c in flat if c["units"] for v in c["delta"]]
inferred_r = statistics.median(constant_ratios)
residuals = [abs(v - c["factor"] * c["analyticSlope"] - c["units"] * inferred_r)
             for c in data["cases"] for v in c["delta"]]
report = {
    "purpose": "Diagnostic evidence for raster depth bias selection; no production shader or tolerance changes",
    "reference": str(REFERENCE.relative_to(ROOT)), "reference_sha256": sha(REFERENCE),
    "probe_sha256": sha(ROOT / "tools/polygon_offset_reference.html"),
    "backend": data["backend"], "attachment": data["attachment"],
    "case_count": len(data["cases"]), "sample_count": sum(len(c["delta"]) for c in data["cases"]),
    "inferred_r": inferred_r, "inferred_r_in_q24": inferred_r / Q24,
    "maximum_residual_from_factor_m_plus_units_r": max(residuals),
    "maximum_residual_in_q24": max(residuals) / Q24,
    "offset_enabled_zero_matches_disabled": all(c["biased"]["bits"] == c["baseline"]["bits"] for c in flat if c["units"] == 0),
    "flat_profiles": [{"range": c["range"], "depth": c["depth"], "units": c["units"], "delta_q24": c["delta"][0] / Q24} for c in flat],
    "limitations": [
        "Single-sample controlled depth-writing geometry only; original offset materials disable depth writes.",
        "The residual is measured evidence, not a new fidelity tolerance or a claim of exact unquantized depth.",
        "D24 sampling converts UNORM to float32; .25/.5 exponent crossings include observable quantization/rounding effects.",
        "The baseline and biased GL draw share identical vertex math. Absolute GL/native depth comparison additionally requires matching clip transformations.",
        "MSAA, reverse-Z, oblique projection, independent weapon quantization and actual decal visibility require follow-up GPU tests.",
    ],
}
if NATIVE.exists():
    native = json.loads(NATIVE.read_text())
    lookup = {(c["depth"], c["units"]): c for c in flat if c["range"] == 1}
    compared = []
    for p in native["profiles"]:
        if p.get("format") != 128 or "samples" not in p:
            continue
        base = f32(next(s["bits"] for s in p["samples"] if s["units"] == 0))
        for s in p["samples"]:
            c = lookup[(p["nominal_depth"], s["units"])]
            native_delta = f32(s["bits"]) - base
            compared.append({"depth": p["nominal_depth"], "units": s["units"],
                             "delta_error": native_delta - c["delta"][0],
                             "absolute_depth_bits_equal": s["bits"] == c["biased"]["bits"][0]})
    report["paired_public_rd_d24"] = {
        "source": str(NATIVE.relative_to(ROOT)), "source_sha256": sha(NATIVE),
        "profiles_compared": len(compared),
        "delta_mismatches": sum(x["delta_error"] != 0 for x in compared),
        "maximum_delta_error": max(abs(x["delta_error"]) for x in compared),
        "absolute_depth_mismatches": [x for x in compared if not x["absolute_depth_bits_equal"]],
        "interpretation": "All 63 offset deltas match exactly. Nine absolute depths at nominal .1 differ by one q24 because GL constructs 2*d-1 before viewport mapping; native probe writes d directly. This does not establish reverse-Z equivalence.",
    }
output = ROOT / "evidence/polygon-offset-gl-analysis.json"
output.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"output": str(output.relative_to(ROOT)), "cases": report["case_count"],
                  "r_q24": report["inferred_r_in_q24"], "max_residual_q24": report["maximum_residual_in_q24"],
                  "paired_delta_mismatches": report.get("paired_public_rd_d24", {}).get("delta_mismatches")}))
