#!/usr/bin/env python3
"""Compare matching linear HDR component captures on board interiors."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]/"evidence"
MODES=["direct-diffuse","direct-specular","indirect-diffuse","indirect-specular"]
REGIONS={"concrete":[480,380,550,435],"metal":[610,385,670,435],"wood":[747,412,785,440]}
def read(backend,mode):
    metadata=ROOT/(f"fx-showcase-source-{mode}-manual.json" if backend=="source" else f"fx-showcase-native-{mode}.json")
    record=json.loads(metadata.read_text())
    state=record["state"] if backend=="source" else record
    info=state["hdr_world"]
    binary=ROOT/Path(info["file"]).name
    raw=binary.read_bytes()
    channels=len(raw)//(info["width"]*info["height"]*2)
    if channels not in [3,4]:raise ValueError("Expected half-float RGB/RGBA capture")
    pixels=np.frombuffer(raw,dtype="<f2").reshape(info["height"],info["width"],channels)[:,:,:3].astype(np.float32)
    if info["origin"]=="bottom-left":pixels=pixels[::-1]
    if not np.isfinite(pixels).all():raise ValueError("Nonfinite HDR capture")
    provenance={"metadata":metadata.name,"binary":binary.name,"sha256":hashlib.sha256(raw).hexdigest(),"channels":channels,"snapshot_draws":state["snapshot_draws"]}
    return pixels,provenance

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--inputs",action="store_true");args=parser.parse_args()
    modes=["hdr-"+mode for mode in ["albedo","normal","roughness","orm","normal-length","macro"]] if args.inputs else MODES
    result={"regions":REGIONS,"modes":{},"inputs":[],"scope":"Actual linear HDR world buffers, board interior rectangles. Not postprocess RGB or exact separated object masks. Shared tape and frozen age; local point lights and particle batches disabled."}
    images={"source":{},"native":{}}
    for mode in modes:
        for backend in images:
            pixels,provenance=read(backend,mode);images[backend][mode]=pixels;result["inputs"].append(provenance)
        metrics={}
        for name,(x0,y0,x1,y1) in REGIONS.items():
            source=images["source"][mode][y0:y1,x0:x1]
            native=images["native"][mode][y0:y1,x0:x1]
            delta=np.abs(source-native)
            metrics[name]={"source_mean_rgb":source.mean(axis=(0,1)).tolist(),"native_mean_rgb":native.mean(axis=(0,1)).tolist(),"mae":float(delta.mean()),"p95":float(np.quantile(delta,.95)),"max":float(delta.max()),"relative_energy_error":float((native.mean()-source.mean())/max(float(source.mean()),1e-8))}
            if mode=="hdr-normal":
                a=source*2-1;b=native*2-1
                a/=np.maximum(np.linalg.norm(a,axis=2,keepdims=True),1e-8);b/=np.maximum(np.linalg.norm(b,axis=2,keepdims=True),1e-8)
                angles=np.degrees(np.arccos(np.clip((a*b).sum(axis=2),-1,1)))
                metrics[name].update(angle_mean_degrees=float(angles.mean()),angle_p95_degrees=float(np.quantile(angles,.95)),angle_max_degrees=float(angles.max()))
        result["modes"][mode]=metrics
    if not args.inputs and (ROOT/"fx-showcase-source-beauty-manual.json").exists() and (ROOT/"fx-showcase-native-beauty.json").exists():
        result["reconstruction"]={}
        for backend in images:
            beauty,provenance=read(backend,"beauty");result["inputs"].append(provenance)
            total=sum(images[backend].values())
            result["reconstruction"][backend]={}
            for name,(x0,y0,x1,y1) in REGIONS.items():
                a=beauty[y0:y1,x0:x1];b=total[y0:y1,x0:x1];error=np.abs(a-b)
                result["reconstruction"][backend][name]={"mae":float(error.mean()),"max":float(error.max()),"beauty_mean":float(a.mean()),"sum_mean":float(b.mean())}
    output=ROOT/("fx-showcase-hdr-inputs.json" if args.inputs else "fx-showcase-hdr-components.json");output.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps({"metrics":result["modes"],"reconstruction":result.get("reconstruction")},indent=2))
if __name__=="__main__":main()
