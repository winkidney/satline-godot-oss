#!/usr/bin/env python3
import re
from pathlib import Path
root=Path(__file__).resolve().parents[1];source=root.parent/'artifact-rendering-study/source/shaders'
ao=(source/'35619-ao.glsl').read_text();sv=(source/'35625-sv.glsl').read_text()
def declarations(shader):
 shader=re.sub(r'uniform (float|vec2|vec3|mat4) ([^;]+);',lambda m:' '.join('uniform '+m[1]+' '+v.strip()+';' for v in m[2].split(',')),shader)
 return re.sub(r'uniform sampler2D ([^;]+);',lambda m:' '.join('uniform sampler2D '+v.strip()+':filter_linear,repeat_disable;' for v in m[1].split(',')),shader)
helper='vec4 sourceSample(sampler2D tex,vec2 uv){return texture(tex,vec2(uv.x,1.0-uv.y));}\n'
tk=(source/'35891-tk.glsl.template').read_text().replace('${ao}',ao).replace('${sv}',sv).replace('LOOK_POWER','1.180').replace('LOOK_SAT','1.220')
tk=declarations(tk).replace('varying vec2 vUv;','').replace('texture2D(','sourceSample(').replace('void main(){','vec4 source_composite(vec2 vUv){').replace('gl_FragColor = vec4(col, dot(col, vec3(0.299, 0.587, 0.114)));','return vec4(col,dot(col,vec3(.299,.587,.114)));')
(root/'shaders/source_composite.gdshader').write_text('shader_type canvas_item;\nrender_mode unshaded,blend_disabled;\n'+helper+tk+'\nvoid fragment(){COLOR=vec4(source_composite(vec2(UV.x,1.0-UV.y)).rgb,1.0); }\n')
down=declarations((source/'35800-j9.glsl.template').read_text().replace('${ao}',ao)).replace('texture2D(','sourceSample(').replace('void main(){','void fragment(){').replace('gl_FragColor','COLOR')
(root/'shaders/source_downsample.gdshader').write_text('shader_type canvas_item;\nrender_mode unshaded,blend_disabled;\n'+helper+down+'\nvoid vertex(){vUv=vec2(UV.x,1.0-UV.y); }\n')
print('Ported original tk and 13-tap j9 kernels')

for name,filename in [('source_upsample','35820-K9.glsl.template'),('source_streak','35830-J9.glsl.template')]:
 code=declarations((source/filename).read_text().replace('${ao}',ao).replace('${sv}',sv)).replace('texture2D(','sourceSample(').replace('void main(){','void fragment(){').replace('gl_FragColor','COLOR')
 (root/f'shaders/{name}.gdshader').write_text('shader_type canvas_item;\nrender_mode unshaded,blend_disabled;\n'+helper+code+'\nvoid vertex(){vUv=vec2(UV.x,1.0-UV.y); }\n')
tv=(source/'35303-tv.glsl').read_text()
code=(source/'35871-ek.glsl.template').read_text().replace('${ao}',ao).replace('${tv}',tv)
noise_start=code.index('float n2(vec2 p)');noise_end=code.index('\nfloat fbm5',noise_start)
noise="""float n2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);ivec2 a=ivec2(mod(i,vec2(256.0)));ivec2 b=ivec2((a.x+1)%256,a.y),c=ivec2(a.x,(a.y+1)%256),d=ivec2(b.x,c.y);return mix(mix(texelFetch(tNoise,a,0).r,texelFetch(tNoise,b,0).r,f.x),mix(texelFetch(tNoise,c,0).r,texelFetch(tNoise,d,0).r,f.x),f.y);}"""
code=code[:noise_start]+noise+code[noise_end:]
code=code.replace('mat2(1.6, 1.2, -1.2, 1.6)','mat2(vec2(1.6,1.2),vec2(-1.2,1.6))')
code=declarations(code).replace('void main(){','void fragment(){').replace('gl_FragColor','COLOR')
(root/'shaders/source_dirt.gdshader').write_text('shader_type canvas_item;\nrender_mode unshaded,blend_disabled;\n'+code+'\nvoid vertex(){vUv=vec2(UV.x,1.0-UV.y); }\n')
print('Ported original K9 upsample, J9 streak and ek static dirt')

code=declarations((source/'35844-Q9.glsl.template').read_text().replace('${ao}',ao)).replace('texture2D(','sourceSample(').replace('void main(){','void fragment(){').replace('gl_FragColor','COLOR')
code=code.replace('uniform sampler2D tDepth:filter_linear','uniform sampler2D tDepth:filter_nearest').replace('sourceSample(tDepth, uv)','texture(tDepth,vec2(uv.x,1.0-uv.y))')
# Explicit bilinear interpolation avoids device-dependent fixed-point texture weights
# at high-contrast metering boundaries (same rationale as original sky noise bridge).
code=code.replace('sourceSample(tLum, uv)','source_lum(uv)')
code=code.replace('void fragment(){',"""vec4 source_lum(vec2 uv){
 ivec2 size=textureSize(tLum,0);vec2 p=vec2(uv.x,1.0-uv.y)*vec2(size)-0.5;
 ivec2 a=ivec2(floor(p));vec2 f=fract(p);ivec2 hi=size-ivec2(1);
 return mix(mix(texelFetch(tLum,clamp(a,ivec2(0),hi),0),texelFetch(tLum,clamp(a+ivec2(1,0),ivec2(0),hi),0),f.x),mix(texelFetch(tLum,clamp(a+ivec2(0,1),ivec2(0),hi),0),texelFetch(tLum,clamp(a+ivec2(1),ivec2(0),hi),0),f.x),f.y);
}
void fragment(){""")
# Independent world and weapon render targets preserve the source solar threshold.
code=code.replace('uniform sampler2D tDepth:filter_nearest,repeat_disable;','uniform sampler2D tDepth:filter_nearest,repeat_disable; uniform sampler2D tWeaponSolarDepth:filter_nearest,repeat_disable; uniform bool uUseWeaponDepth=false;')
code=code.replace('step(0.99999, texture(tDepth,vec2(uv.x,1.0-uv.y)).r)','step(0.99999,min(texture(tDepth,vec2(uv.x,1.0-uv.y)).r,uUseWeaponDepth?texture(tWeaponSolarDepth,vec2(uv.x,1.0-uv.y)).r:1.0))')
# Match original HalfFloat render-target round-to-nearest-even before native store.
code=code.replace('void fragment(){',"""float source_half_rne(float value){
 if(value<0.00006103515625){float scaled=value*16777216.0;float base=floor(scaled);float f=fract(scaled);return (base+((f>0.5 || (f==0.5 && mod(base,2.0)>0.0))?1.0:0.0))/16777216.0;}
 uint bits=floatBitsToUint(value);return uintBitsToFloat((bits+4095u+((bits>>13u)&1u))&4294959104u);
}
void fragment(){""").replace('COLOR = vec4(a, v, 0.0, 1.0);','COLOR = vec4(source_half_rne(a), source_half_rne(v), 0.0, 1.0);')
(root/'shaders/source_adapt.gdshader').write_text('shader_type canvas_item;\nrender_mode unshaded,blend_disabled;\n'+helper+code+'\nvoid vertex(){vUv=vec2(UV.x,1.0-UV.y); }\n')
print('Ported original Q9 centre-weighted log metering and adaptation')

# tk intermediate alpha carries luminance into original nk; final display stays opaque.
composite=(root/'shaders/source_composite.gdshader').read_text().replace('COLOR=vec4(source_composite(vec2(UV.x,1.0-UV.y)).rgb,1.0);','COLOR=source_composite(vec2(UV.x,1.0-UV.y));')
(root/'shaders/source_composite_data.gdshader').write_text(composite)
code=declarations((source/'35998-nk.glsl.template').read_text().replace('${ao}',ao)).replace('texture2D(','sourceSample(').replace('void main(){','void fragment(){').replace('gl_FragColor','COLOR')
code=code.replace('gl_FragCoord.xy','vec2(FRAGCOORD.x,float(textureSize(tSrc,0).y)-FRAGCOORD.y)')
# Test-only diagnostic gain, default preserves the original unconditional dither.
code=code.replace('void fragment(){','uniform float uDither=1.0;\nvoid fragment(){').replace(') / 255.0;',') * uDither / 255.0;')
(root/'shaders/source_finish.gdshader').write_text('shader_type canvas_item;\nrender_mode unshaded,blend_disabled;\n'+helper+code+'\nvoid vertex(){vUv=vec2(UV.x,1.0-UV.y); }\n')
print('Ported original nk final FXAA/sharpen/grain/dither and tk luminance-alpha intermediate')

for name,filename in [('source_ao','35641-X9.glsl.template'),('source_ao_blur','35731-QM.glsl.template')]:
 code=declarations((source/filename).read_text().replace('${ao}',ao).replace('${e_}','0.05').replace('AO_TAPS','12').replace('BLUR_TOL','0.04'))
 code=code.replace('filter_linear','filter_nearest').replace('texture2D(','sourceSample(').replace('void main(){','void fragment(){').replace('gl_FragColor','COLOR')
 code=code.replace('gl_FragCoord.xy','vec2(FRAGCOORD.x,uResolution.y-FRAGCOORD.y)')
 if name=='source_ao':
  code=code.replace('void fragment(){','vec4 source_ao_value(vec2 source_fragcoord){').replace('COLOR = vec4(1.0); return;','return vec4(1.0);').replace('COLOR = vec4(ao, ao, ao, 1.0);','return vec4(ao, ao, ao, 1.0);').replace('vec2(FRAGCOORD.x,uResolution.y-FRAGCOORD.y)','source_fragcoord')
  code+='\nvoid fragment(){COLOR=source_ao_value(vec2(FRAGCOORD.x,uResolution.y-FRAGCOORD.y));}\n'
 (root/f'shaders/{name}.gdshader').write_text('shader_type canvas_item;\nrender_mode unshaded,blend_disabled;\nuniform vec2 uResolution;\n'+helper+code+'\nvoid vertex(){vUv=vec2(UV.x,1.0-UV.y); }\n')
print('Ported original AO12 and nearest 7tap bilateral AO blur kernels')

code=declarations((source/'35745-$9.glsl.template').read_text().replace('${ao}',ao).replace('${sv}',sv).replace('${sg}','0.05')).replace('texture2D(','sourceSample(').replace('void main(){','void fragment(){').replace('gl_FragColor','COLOR')
for key in ['tDepth','tDepthHalf','tAO','tVol']:
 code=code.replace('uniform sampler2D '+key+':filter_linear','uniform sampler2D '+key+':filter_nearest').replace('sourceSample('+key+',','sourceNearest('+key+',')
nearest='vec4 sourceNearest(sampler2D tex,vec2 uv){return texture(tex,vec2(uv.x,1.0-uv.y));}\n'
(root/'shaders/source_ao_composite.gdshader').write_text('shader_type canvas_item;\nrender_mode unshaded,blend_disabled;\n'+helper+nearest+code+'\nvoid vertex(){vUv=vec2(UV.x,1.0-UV.y); }\n')
print('Ported original joint-bilateral AO/volume scene composite')

nv=(source/'35309-nv.glsl').read_text()
volume=declarations((source/'35674-Y9.glsl.template').read_text().replace('${ao}',ao).replace('${nv}',nv).replace('${e_}','0.05').replace('VOL_STEPS','24'))
volume=volume.replace('filter_linear','filter_nearest').replace('texture2D(','sourceSample(')
volume=volume.replace('dot(sourceSample(tShadow, sc.xy), vec4(0.99609375, 0.99609375 / 256.0, 0.99609375 / 65536.0, 1.0 / 16777216.0))','sourceSample(tShadow,sc.xy).r')
volume=volume.replace('void main(){','vec4 source_volume(vec2 source_fragcoord){').replace('gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0); return;','return vec4(0.0,0.0,0.0,1.0);').replace('gl_FragCoord.xy','source_fragcoord').replace('gl_FragColor = vec4(acc, T);','return vec4(acc,T);')
adapt=(root/'shaders/source_adapt.gdshader').read_text();start=adapt.index('float source_half_rne');end=adapt.index('\nvoid fragment()',start);rounding=adapt[start:end]
finish='\nvoid fragment(){vec4 v=source_volume(vec2(FRAGCOORD.x,uResolution.y-FRAGCOORD.y));COLOR=vec4(source_half_rne(v.r),source_half_rne(v.g),source_half_rne(v.b),source_half_rne(v.a));}\nvoid vertex(){vUv=vec2(UV.x,1.0-UV.y); }\n'
(root/'shaders/source_volume.gdshader').write_text('shader_type canvas_item;\nrender_mode unshaded,blend_disabled;\nuniform vec2 uResolution;\n'+helper+rounding+'\n'+volume+finish)
blur=declarations((source/'35731-QM.glsl.template').read_text().replace('${ao}',ao).replace('BLUR_TOL','0.30')).replace('filter_linear','filter_nearest').replace('texture2D(','sourceSample(').replace('void main(){','vec4 source_volume_blur(){').replace('gl_FragColor = ws > 1e-4 ? acc / ws : sourceSample(tSrc, vUv);','return ws>1e-4?acc/ws:sourceSample(tSrc,vUv);')
(root/'shaders/source_volume_blur.gdshader').write_text('shader_type canvas_item;\nrender_mode unshaded,blend_disabled;\n'+helper+rounding+'\n'+blur+'\nvoid fragment(){vec4 v=source_volume_blur();COLOR=vec4(source_half_rne(v.r),source_half_rne(v.g),source_half_rne(v.b),source_half_rne(v.a));}\nvoid vertex(){vUv=vec2(UV.x,1.0-UV.y); }\n')
print('Ported original highY9 volume24 and QM volume bilateral blur with RGBA16F storage')

# Original Z9 camera reprojection; keep nearest depth and linear HDR colour separate.
code=declarations((source/'35778-Z9.glsl.template').read_text().replace('${ao}',ao).replace('${sg}','0.05'))
code=code.replace('uniform sampler2D tDepth:filter_linear','uniform sampler2D tDepth:filter_nearest')
code=code.replace('texture2D(tDepth,','sourceDepth(tDepth,').replace('texture2D(','sourceSample(')
code=code.replace('void main(){','vec4 source_motion(vec2 source_fragcoord){').replace('gl_FragColor = c0; return;','return c0;').replace('gl_FragColor = vec4(acc / ws, 1.0);','return vec4(acc/ws,1.0);').replace('gl_FragCoord.xy','source_fragcoord')
depth_helper='vec4 sourceDepth(sampler2D tex,vec2 uv){return texture(tex,vec2(uv.x,1.0-uv.y));}\n'
(root/'shaders/source_motion.gdshader').write_text('shader_type canvas_item;\nrender_mode unshaded,blend_disabled;\n'+helper+depth_helper+rounding+'\n'+code+'\nvoid fragment(){vec4 v=source_motion(vec2(FRAGCOORD.x,uRes.y-FRAGCOORD.y));COLOR=vec4(source_half_rne(v.r),source_half_rne(v.g),source_half_rne(v.b),source_half_rne(v.a));}\nvoid vertex(){vUv=vec2(UV.x,1.0-UV.y); }\n')
print('Ported original Z9 camera motion blur: nine taps, weapon depth bypass, original velocity clamp')
