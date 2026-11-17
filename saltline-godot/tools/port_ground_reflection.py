#!/usr/bin/env python3
"""Port the original RP radiance override; camera/texture producer is separate."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root.parent/'artifact-rendering-study/source/extracted/bundle-1.js').read_text()
a=source.index('    RP = `')+len('    RP = `');b=source.index('`;\n  function Nw',a)
code=source[a:b].replace('cameraPosition','CAMERA_POSITION_WORLD').replace('material.roughness','ROUGHNESS').replace('textureLod(uRefl,','sourceReflectionLod(uRefl,').replace('radiance = mix(radiance, pr, pw);','RADIANCE = vec4(pr,pw);')
def inject_file(path):
 p=Path(path);shader=p.read_text();marker=' // SOURCE_PLANAR_RADIANCE_BEGIN'
 shader=shader.replace('#include "res://shaders/source_ibl_surface.gdshaderinc"\n','').replace(' vec3 source_planar_rgb=vec3(0.0);float source_planar_weight=0.0;\n','')
 if marker in shader:shader=shader[:shader.index(marker)]+'}\n'
 shader=shader.replace('uRefl:filter_linear_mipmap_anisotropic','uRefl:filter_linear_mipmap')
 shader=shader.replace('uniform sampler2D uRefl:filter_linear_mipmap,repeat_enable;','uniform sampler2D uRefl:filter_linear_mipmap,repeat_disable;')
 helper='vec4 sourceReflectionLod(sampler2D t,vec2 uv,float lod){return textureLod(t,vec2(uv.x,1.0-uv.y),lod);}'
 if helper not in shader:shader=shader.replace('void vertex()',helper+'\n\nvoid vertex()')
 end=shader.rfind('}');shader=shader[:end]+marker+'\n if(uReflOn>0.0)'+code+'\n // SOURCE_PLANAR_RADIANCE_END\n'+shader[end:]
 p.write_text(shader)
 from ibl_shader_bridge import inject_file as inject_ibl
 inject_ibl(p)

if __name__=='__main__':
 inject_file(root/'shaders/ground.gdshader')
 print('Ported original RP plus source IBL radiance integration')
