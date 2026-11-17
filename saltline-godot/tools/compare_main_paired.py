#!/usr/bin/env python3
"""Describe matched-camera RGB8 differences without inventing an acceptance gate."""
import argparse, hashlib, json
from pathlib import Path
import numpy as np
from PIL import Image
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--case",default="")
args=parser.parse_args()
if args.case and not all(c.isascii() and (c.islower() or c.isdigit() or c=="-") for c in args.case):parser.error("Invalid case")
root=Path(__file__).resolve().parents[1]/"evidence"
tag="high"+("-"+args.case if args.case else "")
a_path=root/f"main-paired-{tag}-source.png";b_path=root/f"main-paired-{tag}-native.png"
a=np.asarray(Image.open(a_path).convert("RGB"),dtype=float);b=np.asarray(Image.open(b_path).convert("RGB"),dtype=float)
if a.shape!=b.shape:raise ValueError("Image dimensions differ")
d=np.abs(a-b);h,w=a.shape[:2]
regions={"full":[0,0,w,h]}
if not args.case:regions.update({"sky":[140,0,550,160],"crane":[560,24,740,350],"left_containers":[130,240,460,560],"right_container":[820,260,1240,650],"wet_ground":[320,510,810,720]})
rows={}
for name,(x0,y0,x1,y1) in regions.items():
 x=d[y0:y1,x0:x1]
 rows[name]={"rect":[x0,y0,x1,y1],"mae_rgb8":float(x.mean()),"p50":float(np.percentile(x,50)),"p95":float(np.percentile(x,95)),"p99":float(np.percentile(x,99)),"max":float(x.max()),"signed_bias_rgb8":np.mean(b[y0:y1,x0:x1]-a[y0:y1,x0:x1],axis=(0,1)).tolist()}
report={"regions":rows,"source_png_sha256":hashlib.sha256(a_path.read_bytes()).hexdigest(),"native_png_sha256":hashlib.sha256(b_path.read_bytes()).hexdigest(),"scope":"Descriptive display RGB8 comparison at identical source camera/time and manual exposure1. No acceptance threshold or whole-render parity claim; dynamic grain, rasterization, rain and texture details may differ."}
(root/f"main-paired-{tag}-comparison.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps(report))
