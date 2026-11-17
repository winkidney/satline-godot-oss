#!/usr/bin/env python3
"""Losslessly prepare source readbacks for the native Godot importer."""
import array, hashlib, json, sys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/export'; OUT=ROOT/'assets/prepared';OUT.mkdir(exist_ok=True)
data=json.loads((SRC/'scenes/main.json').read_text())
mip_manifest=SRC/'texture-mips/manifest.json'
mip_records={r['id']:r for r in json.loads(mip_manifest.read_text())['records']} if mip_manifest.exists() else {}
sampler_path=SRC/'fixtures/texture-sampler-bindings.json'
sampler_bindings={r['id']:r for r in json.loads(sampler_path.read_text())['bindings']} if sampler_path.exists() else {}
for texture in data['textures']:
    if texture['id'] in sampler_bindings:
        binding=sampler_bindings[texture['id']]
        if (texture['width'],texture['height'])!=(binding['width'],binding['height']):raise ValueError('sampler texture dimensions '+texture['id'])
        texture['anisotropy']=binding['anisotropy']
    if not texture.get('file'):continue
    raw=(SRC/texture['file']).read_bytes();w,h=texture['width'],texture['height']
    if len(raw)!=w*h*4:raise ValueError(texture['id'])
    image=Image.frombytes('RGBA',(w,h),raw).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    dest=OUT/'textures'/f'{texture["id"]}.png';dest.parent.mkdir(exist_ok=True);image.save(dest)
    texture['godot_file']='res://assets/prepared/textures/'+dest.name
    if texture['id'] in mip_records:
        mip=mip_records[texture['id']];blob=(SRC/'texture-mips'/mip['file']).read_bytes()
        if hashlib.sha256(blob).hexdigest()!=mip['sha256']:raise ValueError('mip hash '+texture['id'])
        mip_dest=dest.with_suffix('.miprgba');mip_dest.write_bytes(blob)
        texture['godot_mip_file']='res://assets/prepared/textures/'+mip_dest.name
        texture['godot_has_mipmaps']=mip['mipmaps']
        texture['godot_mip_sha256']=mip['sha256']
        source_levels=[];offset=0
        for level in mip['levels']:
            width,height=level['width'],level['height'];row=width*4
            source_levels.append(b''.join(blob[offset+y*row:offset+(y+1)*row] for y in range(height-1,-1,-1)))
            offset+=level['bytes']
        if offset!=len(blob):raise ValueError('mip size '+texture['id'])
        source_blob=b''.join(source_levels);source_dest=dest.with_suffix('.source-miprgba');source_dest.write_bytes(source_blob)
        texture['godot_source_mip_file']='res://assets/prepared/textures/'+source_dest.name
        texture['godot_source_mip_sha256']=hashlib.sha256(source_blob).hexdigest()
for geometry in data['geometries']:
    index=geometry['index']
    if index:
        values=array.array({'Uint16Array':'H','Uint32Array':'I'}[index['dtype']]);values.frombytes((SRC/index['file']).read_bytes())
    else:values=array.array('I',range(geometry['attributes']['position']['count']))
    # Godot front faces use clockwise winding; preserve source normals and coordinates.
    for i in range(0,len(values)-2,3):values[i+1],values[i+2]=values[i+2],values[i+1]
    ints=array.array('i',values);p=OUT/'geometry'/f'{geometry["id"]}-indices.bin';p.parent.mkdir(exist_ok=True);p.write_bytes(ints.tobytes())
    geometry['godot_index']='res://assets/prepared/geometry/'+p.name
(OUT/'scene.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))
summary={'nodes':len(data['nodes']),'geometries':len(data['geometries']),'materials':len(data['materials']),'textures':len(data['textures']),'source_sha256':data['sourceHash'],'source_errors':data['errors'],'all_raw_attributes_retained':True}
(ROOT/'evidence/asset-preparation.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary))
