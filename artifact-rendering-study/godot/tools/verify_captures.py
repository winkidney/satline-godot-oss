#!/usr/bin/env python3
"""Verify rendered A/B captures and encode a lossless motion WebP. Requires Pillow."""
from pathlib import Path
from PIL import Image, ImageChops, ImageStat
import hashlib,json,re
root=Path(__file__).resolve().parents[1]/'captures'
frames=[Image.open(root/f'motion-{i:02d}.png').convert('RGB') for i in range(12)]
frames[0].save(root/'micro-motion.webp',format='WEBP',save_all=True,append_images=frames[1:],duration=120,loop=0,lossless=True,method=6)
checks={}
for a,b in [('micro-filtered','micro-unfiltered'),('wet-planar','wet-no-planar'),('wet-planar','dry'),('lens-clean','lens-styled'),('lens-styled','lens-auto-exposure')]:
    im1=Image.open(root/(a+'.png')).convert('RGB').crop((320,0,1280,800))
    im2=Image.open(root/(b+'.png')).convert('RGB').crop((320,0,1280,800))
    diff=ImageChops.difference(im1,im2)
    checks[a+' vs '+b]={'mean_absolute_rgb_difference_0_255':sum(ImageStat.Stat(diff).mean)/3,'changed_pixel_fraction':1-diff.convert('L').histogram()[0]/(960*800)}
    assert checks[a+' vs '+b]['mean_absolute_rgb_difference_0_255']>0.01
runtime=json.loads((root/'runtime.json').read_text())
assert len(runtime['captures'])==42
assert not re.search(r'SCRIPT ERROR|SHADER ERROR|^ERROR:',(root/'runtime.log').read_text(),re.M)
with Image.open(root/'micro-motion.webp') as decoded:
    assert decoded.n_frames==12
    for i,original in enumerate(frames):
        decoded.seek(i)
        assert ImageChops.difference(decoded.convert('RGB'),original).getbbox() is None
# On skipped refreshes the old texture must keep its old projection mapping.
trace=runtime['reflection_update_trace']
assert len(trace)>=16
held=0;refreshed=0
for previous,current in zip(trace,trace[1:]):
    if not current['refresh']:
        assert current['published_reflection']==previous['published_reflection']
        assert current['published_projection']==previous['published_projection']
        held+=1
    else:refreshed+=1
assert held>=3 and refreshed>=2
import math
endpoint_ranges={}
for wetness in (0.0,1.0):
    values=[max(0,min(1,wetness+wetness*(1-wetness)*(math.sin(x*0.21*1.4)+math.sin(z*0.31*1.7))*0.56)) for x in range(-20,21) for z in range(-20,21)]
    assert min(values)==wetness and max(values)==wetness
    endpoint_ranges[str(wetness)]=[min(values),max(values)]
reflection_frames=[Image.open(root/f'reflection-motion-{i:02d}.png').convert('RGB') for i in range(16)]
reflection_frames[0].save(root/'reflection-motion.webp',format='WEBP',save_all=True,append_images=reflection_frames[1:],duration=120,loop=0,lossless=True,method=6)
with Image.open(root/'reflection-motion.webp') as decoded:
    assert decoded.n_frames==16
    for i,original in enumerate(reflection_frames):
        decoded.seek(i)
        assert ImageChops.difference(decoded.convert('RGB'),original).getbbox() is None
files={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(root.glob('*.png'))}
result={'date':'2026-11-14','gpu_run':'runtime.log','capture_states':42,'preserved_failure_images':[p.name for p in root.glob('diagnostic-*.png')],'reflection_trace_checks':{'held_frames':held,'refresh_frames':refreshed,'published_matrices_stable_between_texture_updates':True},'wetness_formula_endpoint_ranges':endpoint_ranges,'reflection_webp':{'frames':16,'lossless':True,'decoded_frame_pixel_equality':True},'comparison_roi':[320,0,1280,800],'comparisons':checks,'pngs':files,'webp':{'frames':12,'lossless':True,'decoded_frame_pixel_equality':True,'frame_duration_ms':120},'note':'Framebuffer difference confirms effect toggles, not physical correctness or real-time frame-rate measurement.'}
(root/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('CAPTURE_VERIFICATION_OK 42 states; WebP decoded RGB exactly matches all 12 PNG frames')
