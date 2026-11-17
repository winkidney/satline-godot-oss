#!/usr/bin/env python3
"""Regenerate the current isolated-engine patch from its pinned source archive."""
import difflib,hashlib,json,tarfile
from pathlib import Path
root=Path(__file__).resolve().parent
manifest=json.loads((root/'source-manifest.json').read_text());base=root/'.build/godot-ed1daf0bf';patch=[]
with tarfile.open(root/'.build/godot-ed1daf0bf.tar.gz') as archive:
 prefix=archive.getnames()[0].split('/')[0]
 for name in sorted(manifest['patched_file_sha256']):
  original=archive.extractfile(prefix+'/'+name).read().decode();current=(base/name).read_text()
  patch.extend(difflib.unified_diff(original.splitlines(True),current.splitlines(True),fromfile='a/'+name,tofile='b/'+name))
p=root/manifest['patch_file'];p.write_text(''.join(patch));manifest['patch_sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
manifest['patched_file_sha256']={name:hashlib.sha256((base/name).read_bytes()).hexdigest() for name in manifest['patched_file_sha256']}
(root/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(manifest['patch_sha256'])
