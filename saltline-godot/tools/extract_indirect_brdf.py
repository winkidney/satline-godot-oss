#!/usr/bin/env python3
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
source=(root.parent/'artifact-rendering-study/source/extracted/bundle-1.js').read_text()
def function(name):
    start=re.search(r'(?m)^[ \t]*(?:vec[234]|void|float) '+re.escape(name)+r'\(',source).start()
    end=source.index('{',start)+1;depth=1
    while depth:
        if source[end]=='{':depth+=1
        elif source[end]=='}':depth-=1
        end+=1
    body=source[start:end]
    if name=='computeMultiscattering':body=body.replace('\n#endif\n','\n',1)
    return body
names=['DFGApprox','EnvironmentBRDF','computeMultiscattering','RE_IndirectDiffuse_Physical','RE_IndirectSpecular_Physical','computeSpecularOcclusion']
body='\n\n'.join(function(name) for name in names)+'\n'
(root/'assets/export/fixtures/source-indirect-brdf-original.glsl').write_text(body)
(root/'shaders/source_indirect_brdf.gdshaderinc').write_text(body.replace('const in ',''))
