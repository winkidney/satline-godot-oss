#!/usr/bin/env python3
"""Make constant-rate editing proxies without changing the original recordings."""
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = root / 'video/recordings/original'
target = root / 'video/editor/public/footage/original'
target.mkdir(parents=True, exist_ok=True)
for path in sorted(source.glob('*.webm')):
    out = target / (path.stem + '.mp4')
    subprocess.run([
        'ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(path),
        '-c:v','h264_nvenc','-preset','p4','-cq','21','-b:v','0','-r','60','-fps_mode','cfr',
        '-c:a','aac','-b:a','192k','-movflags','+faststart',str(out),
    ], check=True)
    print(out.name,flush=True)
