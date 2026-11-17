#!/usr/bin/env python3
from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parents[1]
scene=json.loads((root/'assets/prepared/scene.json').read_text())
blink=next(m for m in scene['materials'] if 'varying float vBlink' in str(m.get('onBeforeCompile','')))
gulls=next(m for m in scene['materials'] if 'aOrbit' in str(m.get('onBeforeCompile','')))
blink_body=re.search(r'float bph =[^;]+;\s*vBlink =[^;]+;',blink['patch']['vertexShader'])[0]
gull_body=re.search(r'float ga = aPar.y[\s\S]+?vec3 transformed =[^;]+;',gulls['patch']['vertexShader'])[0]
fixture=root/'assets/export/fixtures'
(fixture/'backdrop-blink-original.glsl').write_text(blink_body)
(fixture/'backdrop-gull-original.glsl').write_text(gull_body)
body='// Extracted from original onBeforeCompile patches.\nfloat sourceBackdropBlink(vec3 blink,float uTime){float vBlink;\n'+blink_body+'\nreturn vBlink;}\nvec3 sourceBackdropGull(vec3 position,vec4 aOrbit,vec4 aPar,float uTime){\n'+gull_body+'\nreturn transformed;}\n'
(root/'shaders/source_backdrop.gdshaderinc').write_text(body)
(fixture/'backdrop-patch-extraction.json').write_text(json.dumps({'blink_material':blink['id'],'gull_material':gulls['id'],'shader_sha256':hashlib.sha256(body.encode()).hexdigest()},indent=2))
