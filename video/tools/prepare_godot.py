#!/usr/bin/env python3
"""Create a 60 fps editing proxy while preserving the variable-rate recording."""
import subprocess
import sys
from pathlib import Path

if len(sys.argv)!=2 or sys.argv[1] not in ('game','lab'):
    raise SystemExit('Usage: prepare_godot.py game|lab')
kind=sys.argv[1]
root=Path(__file__).resolve().parents[2]
source=root/('video/recordings/godot/recording.mp4' if kind=='game' else 'video/recordings/lab/recording.mp4')
target=root/('video/editor/public/footage/godot/gameplay.mp4' if kind=='game' else 'video/editor/public/footage/lab/examples.mp4')
target.parent.mkdir(parents=True,exist_ok=True)
args=['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(source),
      '-c:v','h264_nvenc','-preset','p4','-cq','21','-b:v','0','-r','60','-fps_mode','cfr']
if kind=='game':args+=['-c:a','aac','-b:a','192k']
args+=['-movflags','+faststart',str(target)]
subprocess.run(args,check=True)
print(target.name)
