#!/usr/bin/env python3
"""Inspect actual world HDR material diagnostics with explicit channel/row metadata."""
import argparse
import json
from pathlib import Path
import numpy as np
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("mode",choices=["grain","noise"])
parser.add_argument("--projection",action="store_true")
args=parser.parse_args()
suffix="-projection" if args.projection else ""
root=Path(__file__).resolve().parents[1]/"evidence"
s=json.loads((root/f"weapon-studio-rifle-side-source-{args.mode}.json").read_text())["hdr"]
n=json.loads((root/f"weapon-studio-rifle-side-{args.mode}{suffix}.json").read_text())["hdr"]
assert n["format"]==14 and s["row_order"]=="bottom-to-top" and n["row_order"]=="top-to-bottom"
a=np.fromfile(root/s["file"],dtype="<f2").reshape(s["height"],s["width"],4)[::-1,:,:3].astype(float)
b=np.fromfile(root/Path(n["file"]).name,dtype="<f2").reshape(n["height"],n["width"],3).astype(float)
assert a.shape==b.shape
report={"channels":["dGr+.5","dNear","dDrop"] if args.mode=="grain" else ["dLo","dMid","dRun"],
 "xy":[660,359],"source":a[359,660].tolist(),"native":b[359,660].tolist(),
 "target_exact_match":bool(np.array_equal(a[359,660],b[359,660])),
 "quad_roi":[659,358,663,362],"source_quad":a[358:362,659:663].tolist(),"native_quad":b[358:362,659:663].tolist(),
 "quad_max_error":np.abs(a[358:362,659:663]-b[358:362,659:663]).max(axis=(0,1)).tolist(),
 "scope":"Actual linear world HDR, original RGBA16F bottom rows flipped/native RGBH14; retains MSAA resolve. Descriptive diagnostic, no global passing claim."}
(root/f"weapon-studio-{args.mode}{suffix}-hdr-comparison.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps({k:v for k,v in report.items() if k not in ["source_quad","native_quad"]}))

if args.projection:
    assert report["target_exact_match"], "Projection diagnostic target differs from original HDR"
