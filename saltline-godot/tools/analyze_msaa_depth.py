#!/usr/bin/env python3
"""Keep algorithm-capture checks separate from cross-backend raster differences."""
import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=root/'evidence'
source=json.loads((root/'assets/export/fixtures/msaa-depth-reference.json').read_text())
native=json.loads((base/'msaa-raster-device.json').read_text())
report={'source_backend':source['renderer'],'source_samples':source['samples'],'source_subpixel_bits':source['subpixelBits'],'source_multisampled_render_to_texture':source['multisampledRenderToTexture'],'native':native,'variants':{}}
for name,file in [('native','depth-samples-verification.json'),('mirrored','depth-samples-mirrored-verification.json'),('mirrored_quantized4','depth-samples-mirrored-quantized-verification.json')]:
    raw=(base/file).read_bytes();data=json.loads(raw);rows=data['cases']
    report['variants'][name]={'capture_failures':data['failures'],'cases':len(rows),'partial_pixels':data['partial_pixels'],'coverage_mismatches':sum(abs(c['native_coverage']-c['original_coverage'])>1e-4 for c in rows),'sample_depth_mismatches':[sum(abs(c['combined'][s]-c['original_depth'])>1e-5 for c in rows) for s in range(4)],'GPU_combined_vs_original_mismatches':sum(abs(c['gpu_combined_selected']-c['original_depth'])>1e-5 for c in rows),'sha256':hashlib.sha256(raw).hexdigest()}
(base/'msaa-depth-analysis.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report['variants'],indent=2))
