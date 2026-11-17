#!/usr/bin/env python3
"""Extract original r180 CubeUV and mechanically bridge its sampler to Godot."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
text=(root.parent/'artifact-rendering-study/source/extracted/bundle-1.js').read_text()
original=text.split('    U8 = `',1)[1].split('`,',1)[0]
(root/'assets/export/fixtures/source-cube-uv-original.glsl').write_text(original+'\n')
body=original.removeprefix('#ifdef ENVMAP_TYPE_CUBE_UV\n').removesuffix('\n#endif')
start=body.index('\t\t#ifdef texture2DGradEXT');end=body.index('\t\t#endif',start)+len('\t\t#endif')
body=body[:start]+'\t\treturn textureLod(envMap,uv,0.0).rgb;'+body[end:]
for old,new in [('CUBEUV_MAX_MIP','source_env_max_mip'),('CUBEUV_TEXEL_WIDTH','source_env_texel.x'),('CUBEUV_TEXEL_HEIGHT','source_env_texel.y'),('getFace','sourceCubeFace'),('getUV','sourceCubeUv'),('bilinearCubeUV','sourceCubeBilinear'),('roughnessToMip','sourceCubeRoughnessToMip'),('textureCubeUV','sourceCubeTexture')]:body=body.replace(old,new)
body=body.replace('highp vec2','vec2')
body=body.replace('float mipInt ) {','float mipInt, vec2 source_env_texel, float source_env_max_mip ) {')
body=body.replace('float roughness ) {\n\t\tfloat mip = clamp','float roughness, vec2 source_env_texel, float source_env_max_mip ) {\n\t\tfloat mip = clamp')
body=body.replace('sampleDir, mipInt )','sampleDir, mipInt, source_env_texel, source_env_max_mip )').replace('sampleDir, mipInt + 1.0 )','sampleDir, mipInt + 1.0, source_env_texel, source_env_max_mip )')
body=body.replace('source_env_texel','cube_texel').replace('source_env_max_mip','cube_max_mip')
body+='\nvec4 sourceCubeTexture(sampler2D envMap,vec3 direction,float roughness){return sourceCubeTexture(envMap,direction,roughness,source_env_texel,source_env_max_mip);}'
(root/'shaders/source_cube_uv.gdshaderinc').write_text('uniform vec2 source_env_texel=vec2(.0013020833333333333,.0009765625);\nuniform float source_env_max_mip=8.0;\n'+body+'\n')
