#!/usr/bin/env python3
import argparse,os,re,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('mode',choices=['run','capture','import'],default='run',nargs='?');a=p.parse_args()
if a.mode=='import' or 'GODOT' in os.environ:
 cmd=[os.environ.get('GODOT','godot'),'--path',str(root)]
else:cmd=[str(root/'tools/run_native.sh')]
if a.mode=='import':cmd+=['--audio-driver','Dummy','--headless','--editor','--import']
else:
 if os.environ.get('DISPLAY'):cmd+=['--display-driver','x11']
 cmd+=['--','--capture' if a.mode=='capture' else '--game']
env=os.environ.copy();env['XDG_DATA_HOME']='/tmp/saltline-port-data';env['XDG_CONFIG_HOME']='/tmp/saltline-port-config'
proc=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,env=env);lines=[]
for line in proc.stdout:print(line,end='');lines.append(line)
code=proc.wait();(root/f'evidence/{a.mode}.log').write_text(''.join(lines))
if code or re.search(r'SCRIPT ERROR|SHADER ERROR|Parse Error|^ERROR:', ''.join(lines),re.M):raise SystemExit(1)
