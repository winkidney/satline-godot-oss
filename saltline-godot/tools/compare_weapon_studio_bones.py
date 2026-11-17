#!/usr/bin/env python3
"""Compare actual source/native studio bone locals; source is never native-derived."""
import json
import math
from pathlib import Path
root = Path(__file__).resolve().parents[1] / "evidence"
a = json.loads((root / "weapon-studio-rifle-side-source.json").read_text())
b = json.loads((root / "weapon-studio-rifle-side.json").read_text())
source = {(r["side"], r["name"]): r for r in a["bones"]}
native = {(r["side"], r["name"]): r for r in b["bones"]}
rows = []
for key in source.keys() & native.keys():
    r, t = source[key], native[key]
    qa = [x / math.sqrt(sum(v*v for v in r["q"])) for x in r["q"]]
    qb = [x / math.sqrt(sum(v*v for v in t["q"])) for x in t["q"]]
    rows.append({"side": key[0], "name": key[1], "position_m": math.dist(r["p"], t["p"]),
                 "quaternion_component_l2": min(math.dist(qa, qb), math.dist(qa, [-x for x in qb]))})
report = {"source_count": len(source), "native_count": len(native),
          "missing": sorted(source.keys()-native.keys()), "extra": sorted(native.keys()-source.keys()),
          "max_position_m": max(r["position_m"] for r in rows),
          "max_quaternion_component_l2": max(r["quaternion_component_l2"] for r in rows),
          "position_tolerance_m": 1e-6, "quaternion_component_tolerance": 2e-6,
          "rows": sorted(rows, key=lambda r:(r["side"], r["name"])),
          "scope": "Actual source and native source-node local transforms at rifle side initial .016 plus 3 fixed steps. Quaternion sign normalized; not full skin vertex or arbitrary pose proof."}
report["passed"] = (len(source)==len(native)==70 and not report["missing"] and not report["extra"]
                    and report["max_position_m"]<1e-6 and report["max_quaternion_component_l2"]<2e-6)
(root / "weapon-studio-bones-comparison.json").write_text(json.dumps(report, indent=2)+"\n")
print(json.dumps({k:v for k,v in report.items() if k!="rows"}))
raise SystemExit(0 if report["passed"] else 1)
