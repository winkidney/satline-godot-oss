#!/usr/bin/env python3
"""Rebuild the pinned, isolated Saltline mono-oblique Godot binary."""
import argparse, hashlib, json, os, subprocess, sys, tarfile, urllib.request, venv
from pathlib import Path
root=Path(__file__).resolve().parent
manifest=json.loads((root/'source-manifest.json').read_text())
parser=argparse.ArgumentParser();parser.add_argument('--jobs',type=int,default=8);args=parser.parse_args()
if args.jobs<1:raise SystemExit('--jobs must be positive')
work=root/'.build';work.mkdir(exist_ok=True);archive=work/'godot-ed1daf0bf.tar.gz'
if not archive.exists():urllib.request.urlretrieve(manifest['source_archive_url'],archive)
if hashlib.sha256(archive.read_bytes()).hexdigest()!=manifest['source_archive_sha256']:raise SystemExit('Source archive checksum mismatch')
with tarfile.open(archive) as tar:
 directory=work/tar.getnames()[0].split('/')[0]
 if not directory.exists():tar.extractall(work,filter='data')
patch=root/manifest.get('patch_file','patches/0001-saltline-mono-reference-projection.patch')
if hashlib.sha256(patch.read_bytes()).hexdigest()!=manifest['patch_sha256']:raise SystemExit('Patch checksum mismatch')
def patched():return all(hashlib.sha256((directory/name).read_bytes()).hexdigest()==expected for name,expected in manifest['patched_file_sha256'].items())
if not patched():
 subprocess.run(['patch','--dry-run','-p1','--forward','--input',str(patch)],cwd=directory,check=True)
 subprocess.run(['patch','-p1','--forward','--input',str(patch)],cwd=directory,check=True)
 if not patched():raise SystemExit('Patched source checksums mismatch')
environment=root/'.venv'
if not environment.exists():venv.create(environment,with_pip=True)
python=environment/'bin/python'
subprocess.run([str(python),'-m','pip','install','--disable-pip-version-check',*[name+'=='+version for name,version in manifest['build_dependencies'].items()]],check=True)
env=os.environ.copy();env['CCACHE_DIR']=str(work/'ccache')
command=[str(environment/'bin/scons'),*[value for value in manifest['build_command'][1:] if not value.startswith('-j')],'import_env_vars=CCACHE_DIR','-j'+str(args.jobs)]
subprocess.run(command,cwd=directory,env=env,check=True)
binary=directory/'bin/godot.linuxbsd.template_debug.x86_64'
with binary.open('rb') as handle:digest=hashlib.file_digest(handle,'sha256').hexdigest()
(root/'build-result.json').write_text(json.dumps({'binary':str(binary),'sha256':digest,'bytes':binary.stat().st_size,'source_commit':manifest['source_commit'],'patch_sha256':manifest['patch_sha256'],'build_command':command},indent=2)+'\n')
print(binary)
