#!/usr/bin/env python3
import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
record=next(m for m in json.loads((root/'assets/prepared/scene.json').read_text())['materials'] if m['name']=='saltline-sky')
source=record['fragmentShader'].replace('precision highp float;','')
source=re.sub(r'uniform (float|vec3) ([^;]+);',lambda m:' '.join('uniform '+m[1]+' '+v.strip()+';' for v in m[2].split(',')),source)
source=source.replace('uniform sampler2D tNoise;','uniform sampler2D tNoise:filter_linear,repeat_enable;')
source=source.replace('texture2D(tNoise, (i + f + 0.5) / 256.0)','texture(tNoise, (i + f + 0.5) / 256.0)')
# Explicit bilinear preserves the source sampling math across hardware filtering precision.
old='float n2(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f); return texture(tNoise, (i + f + 0.5) / 256.0).r; }'
new="""float n2(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 ivec2 a=ivec2(mod(i,vec2(256.0)));
 ivec2 b=ivec2((a.x+1)%256,a.y),c=ivec2(a.x,(a.y+1)%256),d=ivec2(b.x,c.y);
 return mix(mix(texelFetch(tNoise,a,0).r,texelFetch(tNoise,b,0).r,f.x),mix(texelFetch(tNoise,c,0).r,texelFetch(tNoise,d,0).r,f.x),f.y);
}"""
assert old in source
source=source.replace(old,new)
source=source.replace('mat2(1.6, 1.2, -1.2, 1.6)','mat2(vec2(1.6,1.2),vec2(-1.2,1.6))')
source=source.replace('void main(){','void fragment(){').replace('gl_FragColor = vec4(max(col, vec3(0.0)), 1.0);','ALBEDO=max(col,vec3(0.0));')
header="""shader_type spatial;
render_mode unshaded,cull_front,depth_draw_never,fog_disabled;
void vertex(){
 vDir=VERTEX;
 vec4 p=PROJECTION_MATRIX*vec4(mat3(VIEW_MATRIX)*VERTEX,1.0);
 // Godot Forward+ uses reverse Z: the sky is at far depth zero.
 POSITION=vec4(p.xy,0.0,p.w);
}
"""
# Varying declaration precedes the vertex entry point for Godot.
source=source.replace('varying vec3 vDir;','')
(root/'shaders/dynamic_sky.gdshader').write_text('shader_type spatial;\nrender_mode unshaded,cull_front,depth_draw_never,fog_disabled;\nvarying vec3 vDir;\n'+source+'\n'+header[header.index('void vertex(){'):])
print('Ported sky',record['id'])
