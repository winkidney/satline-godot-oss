#!/usr/bin/env python3
"""Package source and persistent evidence; exclude runtime caches and scratch logs."""
import datetime,hashlib,json,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
excluded={'.godot','output','__pycache__','node_modules','.git'}
files=[p for p in sorted(root.rglob('*')) if p.is_file() and not any(x in excluded for x in p.relative_to(root).parts)]
manifest={str(p.relative_to(root)):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files if p!=root/'evidence/sha256.json'}
(root/'evidence/sha256.json').write_text(json.dumps({'algorithm':'sha256','completed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'excludes':sorted(excluded)+['evidence/sha256.json'],'files':manifest},ensure_ascii=False,indent=2)+'\n')
archive=root.parent/'artifact-rendering-study-runtime-20261115.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for p in files:z.write(p,Path(root.name)/p.relative_to(root))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for name,item in manifest.items():assert hashlib.sha256(z.read(root.name+'/'+name)).hexdigest()==item['sha256'],name
sha=hashlib.sha256(archive.read_bytes()).hexdigest()
Path(str(archive)+'.sha256').write_text(sha+'  '+archive.name+'\n')
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'files':len(files),'verified_hash_entries':len(manifest),'sha256':sha},indent=2))
