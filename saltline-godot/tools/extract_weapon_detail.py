#!/usr/bin/env python3
"""Extract original PAC material patch, preserve equations and branch order."""
from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parents[1]
scene=json.loads((root/'assets/prepared/scene.json').read_text())
materials=[m for m in scene['materials'] if '#define D_KIND ' in m.get('patch',{}).get('fragmentShader','')]
assert len(materials)==6
def extract(m):
 text=m['patch']['fragmentShader']
 helpers=text[text.index('float dh3('):text.index('vec3 dBump(')]
 body=text[text.index('vec3 dP = vObjP;'):text.index('float dOcc = 1.0 - 0.80 * dCav;')+len('float dOcc = 1.0 - 0.80 * dCav;')]
 return helpers,body
helpers,body=extract(materials[0])
assert all(extract(m)==(helpers,body) for m in materials)
fixture=root/'assets/export/fixtures'
bump_text=materials[0]['patch']['fragmentShader']
(fixture/'weapon-bump-original.glsl').write_text(bump_text[bump_text.index('vec3 dBump('):bump_text.index('#include <packing>')])
(fixture/'weapon-detail-helpers-original.glsl').write_text(helpers)
(fixture/'weapon-detail-body-original.glsl').write_text(body)
native=body.replace('float dPx = length(fwidth(dP));','float dPx = pixel_width;')
native=native.replace('mat3(0.36, 0.48, -0.80, -0.80, 0.60, 0.0, 0.48, 0.64, 0.60)','mat3(vec3(0.36,0.48,-0.80),vec3(-0.80,0.60,0.0),vec3(0.48,0.64,0.60))')
native=native.replace('diffuseColor.rgb','albedo').replace('metalnessFactor','metalness').replace('roughnessFactor','roughness')
native=re.sub(r'#if D_KIND == (\d+)',r'if(kind==\1){',native)
native=re.sub(r'#elif D_KIND == (\d+)',r'}else if(kind==\1){',native)
native=native.replace('#else','}else{').replace('#endif','}')
native+='\nheight=dHt+dDropH*.17;occlusion=dOcc;detail_debug=vec4(dLo,dMid,dGr,dDrop);\n'
signature='void sourceWeaponSurface(int kind,vec3 vObjP,vec3 vONrm,vec3 vWNrm,vec4 vSurf,float pixel_width,float uRain,inout vec3 albedo,inout float roughness,inout float metalness,out float height,out float occlusion,out vec4 detail_debug){\n'
guard='uniform uint source_weapon_noise_round_guard=0u;\nfloat weaponRound(float x){return uintBitsToFloat(floatBitsToUint(x)+source_weapon_noise_round_guard);}\nvec3 weaponRound3(vec3 x){return uintBitsToFloat(floatBitsToUint(x)+uvec3(source_weapon_noise_round_guard));}\nvec2 weaponRound2(vec2 x){return uintBitsToFloat(floatBitsToUint(x)+uvec2(source_weapon_noise_round_guard));}\n'
production_helpers=helpers.replace('float dh3(vec3 p){ return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }','float dh3(vec3 p){p=weaponRound3(p);float angle=weaponRound(fma(p.z,74.7,fma(p.y,311.7,weaponRound(p.x*127.1))));return fract(weaponRound(weaponRound(sin(angle))*43758.5453));}')
production_helpers=production_helpers.replace('vec2 dh2(vec2 p){ return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }','vec2 dh2(vec2 p){p=weaponRound2(p);vec2 angles=weaponRound2(vec2(fma(p.y,311.7,weaponRound(p.x*127.1)),fma(p.y,183.3,weaponRound(p.x*269.5))));return fract(weaponRound2(weaponRound2(sin(angles))*43758.5453));}')
(root/'shaders/source_weapon_detail.gdshaderinc').write_text('// Mechanically extracted by tools/extract_weapon_detail.py; runtime-zero hash rounding guard.\n'+guard+production_helpers+'\n'+signature+native+'}\n')
manifest={'materials':[{'id':m['id'],'name':m['name'],'kind':int(re.search(r'#define D_KIND (\d+)',m['patch']['fragmentShader'])[1])} for m in materials],'helpers_sha256':hashlib.sha256(helpers.encode()).hexdigest(),'body_sha256':hashlib.sha256(body.encode()).hexdigest()}
(fixture/'weapon-detail-extraction.json').write_text(json.dumps(manifest,indent=2))
print(json.dumps(manifest))
