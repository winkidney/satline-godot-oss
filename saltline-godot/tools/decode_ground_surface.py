#!/usr/bin/env python3
"""Decode the saved Playwright collector result and bind its source manifest."""
from pathlib import Path
import base64,hashlib,json,struct,math
project=Path(__file__).resolve().parents[1]
study=project.parent/"artifact-rendering-study/output/playwright"
raw=(study/"ground-observed-cli.txt").read_text()
encoded=raw.split("### Result\n",1)[1].split("\n### Ran Playwright code",1)[0].strip()
data=json.loads(base64.b64decode(json.loads(encoded)))
manifest=json.loads((study/"ground-instrumentation.json").read_text())
assert data["ready"] and data["fatal"] is None and data["errors"]==[]
assert data["instrumented_response_sha256"]==manifest["instrumented_sha256"]
assert data["quality"]["name"]=="high" and data["time"]["frame"]==3
for key,value in {"q":"high","shot":"1","noaudio":"1","step":"1","dt":"0.016666667"}.items():assert data["params"].get(key)==value
source_root=project.parent/"artifact-rendering-study"
for file,key in [(source_root/"source/extracted/bundle-1.js","source_sha256"),(source_root/"source/saltline.original.html","original_html_sha256"),(study/"ground-instrumented.js","instrumented_sha256")]:assert hashlib.sha256(file.read_bytes()).hexdigest()==manifest[key]
for row in data["rows"]:
 row["x_f64"]=struct.pack("<d",row["x"]).hex();row["z_f64"]=struct.pack("<d",row["z"]).hex()
data["rects_f64"]=[[struct.pack("<d",v).hex() for v in r] for r in data["rects"]]
data["source_sha256"]=manifest["source_sha256"];data["instrumentation"]=manifest
blob=json.dumps(data,ensure_ascii=False,separators=(",",":")).encode()
out=project/"assets/export";scene=json.loads((out/"scenes/main.json").read_text())
assert data["player_start"]==scene["modules"]["level"]["playerStart"]
effective_seed=float(data["params"].get("seed") or 4207)
assert math.isfinite(effective_seed) and (int(effective_seed)&0xffffffff)==int(scene["seed"])
(out/"fixtures/ground-metal-observed.json").write_bytes(blob)
meta={key:data[key] for key in ["source_sha256","instrumented_response_sha256","rects","rects_f64","params","quality","player_start"]}
meta["source_seed"]=scene["seed"];meta["observed_sha256"]=hashlib.sha256(blob).hexdigest()
(out/"ground-metal-rects.json").write_text(json.dumps(meta,indent=2))
print(json.dumps({"rects":len(data["rects"]),"probes":len(data["rows"]),"observed_sha256":meta["observed_sha256"]}))
