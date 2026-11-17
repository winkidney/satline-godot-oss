#!/usr/bin/env python3
"""Record an isolated Godot window and its audio without fixed game timesteps."""
import json
import os
import re
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

if len(sys.argv)!=3 or sys.argv[1] not in ('game','lab'):
    raise SystemExit('Usage: record_godot.py game|lab SHOT_PLAN_JSON')
kind=sys.argv[1]
root=Path(__file__).resolve().parents[2]
project=root/('saltline-godot' if kind=='game' else 'artifact-rendering-study/godot')
engine=root/'saltline-godot/engine/godot' if kind=='game' else 'godot'
plan=json.loads(Path(sys.argv[2]).read_text())
destination=root/('video/recordings/godot' if kind=='game' else 'video/recordings/lab')
destination.mkdir(parents=True,exist_ok=True)
if any(a['at']>b['at'] for a,b in zip(plan['actions'],plan['actions'][1:])):
    raise SystemExit('Recording actions must be ordered by time')
if not os.environ.get('DISPLAY'):raise SystemExit('DISPLAY must identify the isolated X session')
sink=f'saltline_film_{os.getpid()}'
module=subprocess.check_output(['pactl','load-module','module-null-sink',f'sink_name={sink}'],text=True).strip()
player=recorder=None
try:
    with tempfile.TemporaryDirectory(prefix='saltline-film-') as temporary:
        tmp=Path(temporary);plan['ready']=str(tmp/'ready.json');plan['report']=str(tmp/'report.json')
        (tmp/'plan.json').write_text(json.dumps(plan))
        env=dict(os.environ,PULSE_SINK=sink,XDG_DATA_HOME=str(tmp/'data'),XDG_CONFIG_HOME=str(tmp/'config'))
        with (destination/'runtime.log').open('w') as game_log, (destination/'ffmpeg.log').open('w') as ffmpeg_log:
            args=[str(engine),'--display-driver','x11','--fullscreen','--resolution','1920x1080','--path',str(project)]
            if kind=='lab':args+=['--audio-driver','Dummy']
            args+=['--']+(['--game'] if kind=='game' else [])+[f'--record-plan={tmp / "plan.json"}']
            player=subprocess.Popen(args,env=env,stdout=game_log,stderr=subprocess.STDOUT)
            deadline=time.monotonic()+180
            while not (tmp/'ready.json').exists():
                if player.poll() is not None:raise RuntimeError('Godot exited before the scene was ready')
                if time.monotonic()>deadline:raise TimeoutError('Godot did not become ready')
                time.sleep(.1)
            windows=re.findall(r'0x[0-9a-fA-F]+',subprocess.check_output(['xprop','-root','_NET_CLIENT_LIST'],env=env,text=True))
            target=None
            for window in windows:
                props=subprocess.check_output(['xprop','-id',window,'_NET_WM_PID'],env=env,text=True)
                if re.search(r'=\s*'+str(player.pid)+r'\s*$',props):target=window;break
            if not target:raise RuntimeError('The isolated game window was not found')
            ready=json.loads((tmp/'ready.json').read_text())
            started=time.time();offset=max(0,started-ready['started_unix'])
            args=['ffmpeg','-hide_banner','-loglevel','warning','-y','-thread_queue_size','32',
                  '-f','x11grab','-window_id',target,'-video_size','1920x1080','-framerate','60','-draw_mouse','0','-i',env['DISPLAY']]
            if kind=='game':args+=['-thread_queue_size','512','-f','pulse','-i',f'{sink}.monitor']
            args+=['-t',str(plan['duration']),'-map','0:v']
            if kind=='game':args+=['-map','1:a']
            args+=['-c:v','h264_nvenc','-preset','p4','-cq','21','-b:v','0','-pix_fmt','yuv420p',
                   '-bf','0','-enc_time_base','1:1000000','-video_track_timescale','1000000','-fps_mode','passthrough']
            if kind=='game':args+=['-c:a','aac','-b:a','192k']
            args+=['-movflags','+faststart',str(destination/'recording.mp4')]
            recorder=subprocess.Popen(args,env=env,stdout=ffmpeg_log,stderr=subprocess.STDOUT)
            deadline=time.monotonic()+float(plan['duration'])+60
            while not (tmp/'report.json').exists():
                if player.poll() is not None or recorder.poll() is not None:raise RuntimeError('A recording process exited early')
                if time.monotonic()>deadline:raise TimeoutError('Recording did not finish')
                time.sleep(.5)
            report=json.loads((tmp/'report.json').read_text());report['capture_start_offset_seconds']=offset
            (destination/'recording.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
            try:recorder.wait(timeout=20)
            except subprocess.TimeoutExpired:recorder.send_signal(signal.SIGINT);recorder.wait(timeout=15)
            if recorder.returncode not in (0,255):raise RuntimeError('FFmpeg did not complete; see ffmpeg.log')
            frames=sum(s['frames'] for s in report['samples'])
            print(f"{kind}: {frames/report['duration']:.1f} real-time rendered fps",flush=True)
finally:
    for process in (player,recorder):
        if process and process.poll() is None:
            process.terminate()
            try:process.wait(timeout=10)
            except subprocess.TimeoutExpired:process.kill();process.wait()
    subprocess.run(['pactl','unload-module',module],check=True)
