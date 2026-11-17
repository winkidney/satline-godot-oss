#!/usr/bin/env python3
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
source=(root.parent/'artifact-rendering-study/source/extracted/bundle-1.js').read_text()
def function(name):
 start=re.search(r'(?m)^[ \t]*(?:vec[234]|void|float) '+name+r'\(',source).start();end=source.index('{',start)+1;depth=1
 while depth:
  if source[end]=='{':depth+=1
  elif source[end]=='}':depth-=1
  end+=1
 return source[start:end]
def struct(name):
 start=source.index('struct '+name+' {');end=source.index('};',start)+2;return source[start:end]
body='\n\n'.join([function('pow4'),function('getDistanceAttenuation'),function('getSpotAttenuation'),struct('PointLight'),function('getPointLightInfo'),struct('SpotLight'),function('getSpotLightInfo')])+'\n'
(root/'assets/export/fixtures/source-local-lights-original.glsl').write_text(body)
native=body.replace('const in ','')
for old,new in [('getPointLightInfo','sourcePointLightInfo'),('getSpotLightInfo','sourceSpotLightInfo'),('getDistanceAttenuation','sourceDistanceAttenuation'),('getSpotAttenuation','sourceSpotAttenuation'),('PointLight','SourcePointLight'),('SpotLight','SourceSpotLight'),('pow4','sourceLightPow4')]:native=native.replace(old,new)
native=native.replace('sourceSourcePointLightInfo','sourcePointLightInfo').replace('sourceSourceSpotLightInfo','sourceSpotLightInfo')
(root/'shaders/source_local_light_math.gdshaderinc').write_text(native)
