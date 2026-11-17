#!/usr/bin/env python3
"""Summarize exact GL/Vulkan float32 evidence; never rewrite source fixtures."""
from collections import Counter
from hashlib import sha256
from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
exported = root.parent / "artifact-rendering-study/evidence/runtime/weapon-hash-gl-diagnostic.json"
canonical = root / "evidence/weapon-hash-gl-diagnostic.json"
canonical.write_bytes(exported.read_bytes())
native = root / "evidence/weapon-hash-native-diagnostic.json"
gl_data, vk_data = (json.loads(p.read_text()) for p in (canonical, native))
gl = {(r["case"], r["mode"]): r for r in gl_data["cases"]}
vk = {(r["case"], r["mode"]): r for r in vk_data["cases"]}
different = [key for key in gl if gl[key]["bits"] != vk[key]["bits"]]
comparisons = []
for source_mode, candidate_mode in (
    ("dot_literal", "dot_fma_xyz"),
    ("sin_literal_dot", "sin_fma_xyz"),
    ("hash_literal", "hash_fma_xyz"),
):
    for key, source in gl.items():
        if key[1] != source_mode:
            continue
        candidate = vk[key[0], candidate_mode]
        comparisons.append({"case": key[0], "source_mode": source_mode,
                            "native_mode": candidate_mode,
                            "source_bits": source["bits"], "native_bits": candidate["bits"],
                            "equal": source["bits"] == candidate["bits"]})
uniform_keys = [key for key in gl if key[1] == "sin_uniform"]
case2 = []
for mode in ("dot_literal", "sin_literal_dot", "product_literal", "hash_literal"):
    a, b = gl["case2_grain", mode], vk["case2_grain", mode]
    case2.append({"mode": mode, "gl": a, "vulkan_literal": b})
surface_path = root / "evidence/weapon-detail-fma-diagnostic.json"
surface = json.loads(surface_path.read_text())
helpers_path = root / "assets/export/fixtures/weapon-detail-helpers-original.glsl"
body_path = root / "assets/export/fixtures/weapon-detail-body-original.glsl"
bundle = (root.parent / "artifact-rendering-study/source/extracted/bundle-1.js").read_text()
start = bundle.index("float dh3(vec3 p)")
helpers_match = bundle[start:].startswith(helpers_path.read_text().strip())
start = bundle.index("vec3 dP = vObjP;", start)
end_marker = "float dOcc = 1.0 - 0.80 * dCav;"
body_match = bundle[start:bundle.index(end_marker, start)+len(end_marker)].strip() == body_path.read_text().strip()
paths = [canonical, native, root / "tools/weapon_hash_diagnostic.json", helpers_path, body_path,
         root / "assets/export/fixtures/weapon-detail-reference.json", surface_path]
report = {
    "schema": 1, "source_backend": gl_data["backend"], "native_backend": vk_data["backend"],
    "original_extraction_matches_bundle": {"helpers": helpers_match, "body": body_match},
    "common_operations": len(gl), "literal_bit_mismatches": len(different),
    "literal_mismatches_by_mode": dict(Counter(key[1] for key in different)),
    "same_uniform_angle_sine": {"cases": len(uniform_keys), "bit_mismatches": sum(gl[k]["bits"] != vk[k]["bits"] for k in uniform_keys)},
    "explicit_fma": {"comparisons": comparisons, "total": len(comparisons), "bit_mismatches": sum(not c["equal"] for c in comparisons)},
    "case2_trace": case2,
    "surface_diagnostic": {"cases": len(surface["cases"]), "channels": surface["channels"],
                           "failures": surface["failures"], "maximum_absolute_error": max(c["maximum_error"] for c in surface["cases"])},
    "sha256": {str(p.relative_to(root)): sha256(p.read_bytes()).hexdigest() for p in paths},
    "scope": "Diagnostic-only evidence. Source literal dot contracts x multiplication, then y FMA, then z FMA. Explicit native FMA matches sampled source bits. Uniform-angle sine equality is established for these 15 controls, not every float32 angle. Original material fixture and tolerance unchanged; no claim about arbitrary GPU vendors or complete surface integration.",
}
destination = root / "evidence/weapon-hash-analysis.json"
destination.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"report": str(destination), "literal_bit_mismatches": len(different),
                  "fma_bit_mismatches": report["explicit_fma"]["bit_mismatches"],
                  "surface_failures": len(surface["failures"])}))
