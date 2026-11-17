#!/usr/bin/env python3
"""Verify archived runtime evidence without rerunning either application."""
import ast, datetime, hashlib, json, re, struct
from pathlib import Path
from urllib.parse import unquote
from PIL import Image, ImageChops

ROOT=Path(__file__).resolve().parents[1]
errors=[]
def require(value,message):
    if not value: errors.append(message)

source=ROOT/'source/saltline.original.html'
require(hashlib.sha256(source.read_bytes()).hexdigest()=='b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb','Original HTML hash changed')
captures=[]
for name in ('original-ablation','showcases','detail-validation','pristine-original'):
    data=json.loads((ROOT/f'evidence/runtime/{name}.json').read_text())
    for item in data['captures']:
        p=ROOT/'evidence/runtime'/item['archived_file']
        require(p.is_file(),f'Missing capture {p.name}')
        with Image.open(p) as im: require(im.size==(1280,720),f'Unexpected dimensions {p.name}')
        m=item['metadata'];require(not m['errors'] and m['fatal'] is None,f'Application error in {item["name"]}')
        require(m['stats']['advanced'],f'Fallback renderer in {item["name"]}')
        captures.append(item['name'])
require(len(captures)==36,'Expected 36 original capture states')
numeric=json.loads((ROOT/'evidence/runtime/numeric-buffers.json').read_text())
numeric_ranges={}
for item in numeric['exported_assets']:
    if not item['file'].endswith('.bin'): continue
    data=(ROOT/'evidence/runtime'/item['file']).read_bytes()
    kind={1015:'f',1016:'e',1009:'B'}[item['type']]
    require(len(data)==item['width']*item['height']*item['channels']*struct.calcsize('<'+kind),'Numeric size mismatch '+item['file'])
    values=[x[0] for x in struct.iter_unpack('<'+kind,data)]
    import math
    require(all(math.isfinite(x) for x in values),'Non-finite numeric buffer '+item['file'])
    numeric_ranges[item['file']]={'min':min(values),'max':max(values),'values':len(values)}

for name,prefix,expected in [('fx-motion.webp','fx-motion-',12)]:
    frames=sorted((ROOT/'evidence/runtime/captures').glob(prefix+'*.png'))
    with Image.open(ROOT/'evidence/runtime'/name) as animation:
        require(animation.n_frames==expected,'WebP frame count mismatch')
        for i,p in enumerate(frames):
            animation.seek(i)
            with Image.open(p) as frame: require(ImageChops.difference(animation.convert('RGB'),frame.convert('RGB')).getbbox() is None,'WebP frame differs '+p.name)

godot=json.loads((ROOT/'godot/captures/verification.json').read_text())
for name,item in godot['pngs'].items():
    require(hashlib.sha256((ROOT/'godot/captures'/name).read_bytes()).hexdigest()==item['sha256'],'Godot capture hash mismatch '+name)
require(godot['capture_states']==42,'Expected 42 Godot states')
require(godot['reflection_trace_checks']['published_matrices_stable_between_texture_updates'],'Reflection synchronization failed')
log=(ROOT/'godot/captures/runtime.log').read_text()
require('SALTLINE_LABS_CAPTURE_OK' in log,'Godot capture completion missing')
require(not re.search(r'SCRIPT ERROR|SHADER ERROR|Parse Error|^ERROR:',log,re.M),'Godot final log has errors')
for p in (ROOT/'tools').glob('*.py'): ast.parse(p.read_text())
links=anchors=0
for p in ROOT.rglob('*.md'):
    if any(x in p.relative_to(ROOT).parts for x in ('.godot','output')): continue
    for link in re.findall(r'\]\(([^)]+)\)',p.read_text()):
        if link.startswith(('http:','https:','mailto:','#')): continue
        filename,_,anchor=link.partition('#'); dest=(p.parent/unquote(filename)).resolve();links+=1
        require(dest.exists(),f'{p.name}: missing {link}')
        if dest.is_file() and re.fullmatch(r'L\d+',anchor):
            anchors+=1;require(int(anchor[1:])<=len(dest.read_text().splitlines()),'Bad source anchor '+link)

result={'completed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'original_hash_unchanged':True,
 'original_capture_states':len(captures),'godot_capture_states':godot['capture_states'],
 'original_dynamic_webp_lossless_checked':True,'numeric_ranges':numeric_ranges,
 'local_links_checked':links,'source_anchors_checked':anchors,
 'godot_capture_hashes_checked':len(godot['pngs']),'godot_final_log_clean':True,
 'limitations':['No complete game QA','No end-to-end frame budget acceptance','Godot is teaching approximation, not visual parity'], 'errors':errors}
(ROOT/'evidence/runtime-verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False,indent=2))
if errors: raise SystemExit(1)
