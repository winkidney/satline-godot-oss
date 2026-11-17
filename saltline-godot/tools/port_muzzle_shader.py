#!/usr/bin/env python3
"""Port the active source shader equations without painting a replacement sprite."""
import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
scene=json.loads((root/'assets/prepared/scene.json').read_text())
record=next(m for m in scene['materials'] if 'uJet' in m.get('uniforms',{}))
source=record['fragmentShader']
source=re.sub(r'#include <[^>]+>','',source)
source=source[source.index('float h1'):]
source=source.replace('void main()','vec3 source_flash()')
source=re.sub(r'gl_FragColor = vec4\((.*?), 1\.0\);',r'vec3 radiance = \1;',source,flags=re.S)
source=source.replace('return;','return radiance;')
# Final output is local to the function and has no source-side display encoding.
source=source.rstrip().removesuffix('}')+'return radiance;\n}\n'
header='''shader_type spatial;
render_mode unshaded,blend_premul_alpha,cull_disabled,depth_draw_never,fog_disabled;
uniform float uSeed=0.0;
uniform float uInt=0.0;
uniform float uHeat=0.0;
uniform float uJet=1.0;
varying vec2 vUv;
varying float vType;
void vertex(){vUv=UV;vType=CUSTOM0.x;}
'''
(root/'shaders/muzzle_flash.gdshader').write_text(header+source+'\nvoid fragment(){ALBEDO=source_flash();EMISSION=vec3(0.0);ALPHA=0.0;}\n')
print('Ported original muzzle equations:',record['id'])
