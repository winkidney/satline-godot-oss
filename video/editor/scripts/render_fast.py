#!/usr/bin/env python3
"""Export the approved timeline with FFmpeg; retain all source recordings and WAVs."""
import argparse
import json
import os
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

editor=Path(__file__).resolve().parent.parent
root=editor.parents[1]
work=editor/'.render';work.mkdir(exist_ok=True)
public=editor/'public'
media=json.loads((editor/'src/media.json').read_text())
chapters=json.loads(subprocess.check_output(['node','--input-type=module','-e',"import {chapters} from './src/timeline.js';process.stdout.write(JSON.stringify(chapters))"],cwd=editor))
if media.get('mode')!='recorded' or len(media['chapters'])!=11:raise SystemExit('Recorded footage timeline is incomplete')
parser=argparse.ArgumentParser();parser.add_argument('--chapter',type=int,choices=range(12));parser.add_argument('--resume',action='store_true');parser.add_argument('--prepare-only',action='store_true');args=parser.parse_args()
subprocess.run([sys.executable,str(editor/'scripts/prepare_graphics.py')]+(['--no-srt'] if args.prepare_only else []),check=True,cwd=editor)

def run(command):
    subprocess.run(command,check=True,cwd=editor)

def q(path):return "'"+str(path).replace("'","'\\''")+"'"

def encode_args():
    return ['-c:v','h264_nvenc','-preset','p4','-cq','19','-b:v','0','-g','120','-bf','0','-pix_fmt','yuv420p','-r','60']

def still_video(side):
    output=work/f'historical-{side}.mp4'
    dimensions=''
    if output.exists():
        dimensions=subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height','-of','csv=s=x:p=0',str(output)],text=True).strip()
    if dimensions!='1920x1080':
        run(['ffmpeg','-hide_banner','-loglevel','error','-y','-loop','1','-framerate','60','-i',
             str(public/f'preview/historical-{side}.png'),'-vf','scale=1920:1080','-t','12']+encode_args()+[str(output)])
    return output

def cut_inputs(cmd,cuts,input_index,output,width,height):
    filters=[];names=[]
    for cut in cuts:
        source=still_video('original' if 'historical-original' in cut['src'] else 'godot') if cut.get('image') else public/cut['src']
        length=float(cut['duration']);name=f'cut{input_index}';names.append(f'[{name}]')
        cmd+=['-ss',str(cut['start']),'-t',str(length),'-threads','2','-i',str(source)]
        filters.append(f'[{input_index}:v]setpts=PTS-STARTPTS,fps=60,scale={width}:{height},setsar=1,tpad=stop_mode=clone:stop_duration=1,trim=duration={length},setpts=PTS-STARTPTS[{name}]')
        input_index+=1
    filters.append(''.join(names)+f'concat=n={len(names)}:v=1:a=0[{output}]')
    return filters,input_index

def render_chapter(index):
    output=work/f'chapter-{index:02d}.mp4'
    chapter=chapters[index];duration=chapter['end']-chapter['start']
    # shortcut: resume checks duration only; delete chapter renders after timeline or picture edits.
    if args.resume and output.exists() and output.stat().st_size>10000:
        try:
            existing=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(output)]))
            if abs(existing-duration)<=.02:
                print(f'chapter {index+1}/12: existing',flush=True);return output
        except (ValueError,subprocess.CalledProcessError):pass
    cmd=['ffmpeg','-hide_banner','-loglevel','warning','-y','-filter_complex_threads','4']
    if index==0:
        clip=media['chapters']['0'];filters,input_index=cut_inputs(cmd,clip['godot'],0,'base',1920,1080)
        pip_filters,input_index=cut_inputs(cmd,clip['original'],input_index,'pip',640,360);filters+=pip_filters
        graph=';'.join(filters)+';[base][pip]overlay=1246:34:shortest=1,format=yuv420p[out]'
    elif index==11:
        cmd+=['-loop','1','-framerate','60','-i',str(work/'source-card.png')]
        graph='[0:v]format=yuv420p[out]'
    else:
        clip=media['chapters'][str(index)];filters=[];input_index=0
        for side in ('original','godot'):
            side_filters,input_index=cut_inputs(cmd,clip[side],input_index,'left' if side=='original' else 'right',920,518)
            filters+=side_filters
        cmd+=['-f','concat','-safe','0','-i',str(work/f'cards-{index:02d}.ffconcat')]
        graph=(f'color=c=0x0b1012:s=1920x1080:r=60:d={duration}[bg];'
               +';'.join(filters)+';'
               +f'[{input_index}:v]setpts=PTS-STARTPTS,fps=60,format=rgba[card];'
               '[bg][left]overlay=24:40:shortest=1[first];[first][right]overlay=976:40:shortest=1[second];'
               '[second][card]overlay=0:590:shortest=1,format=yuv420p[out]')
    graph+=';[out]tpad=stop_mode=clone:stop_duration=1[final]'
    cmd+=['-filter_complex',graph,'-map','[final]','-an','-t',str(duration)]+encode_args()+['-movflags','+faststart',str(output)]
    print(f'chapter {index+1}/12: rendering {duration}s',flush=True);run(cmd)
    actual=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(output)]))
    if abs(actual-duration)>.02:raise RuntimeError(f'Chapter {index+1} has duration {actual}, expected {duration}')
    return output

def create_audio():
    rate=48000;channels=2;sample_width=2;bed=work/'game-bed.wav'
    with wave.open(str(bed),'wb') as output:
        output.setnchannels(channels);output.setsampwidth(sample_width);output.setframerate(rate)
        for index in range(11):
            for cut in media['chapters'][str(index)]['godot']:
                count=round(cut['duration']*rate)*channels*sample_width
                if cut.get('audio',True):
                    command=['ffmpeg','-hide_banner','-loglevel','error','-ss',str(cut['start']),'-t',str(cut['duration']),
                             '-i',str(public/cut['src']),'-vn','-af','volume=0.08','-ar',str(rate),'-ac',str(channels),'-f','s16le','-']
                    data=subprocess.check_output(command,cwd=editor)
                    output.writeframesraw(data[:count]);output.writeframesraw(b'\0'*max(0,count-len(data)))
                else:output.writeframesraw(b'\0'*count)
        output.writeframesraw(b'\0'*(20*rate*channels*sample_width))
    with wave.open(str(bed),'rb') as stream:
        if stream.getnframes()!=640*rate:raise RuntimeError('Game audio duration is not 640 seconds')
        game=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').reshape(-1,2).astype(np.float32)/32768
    with wave.open(str(public/'music/ambient.wav'),'rb') as stream:
        music=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').reshape(-1,2).astype(np.float32)/32768
    for start in range(0,len(game),len(music)):
        count=min(len(music),len(game)-start);game[start:start+count]+=music[:count]*.12
    for voice in media['narration']:
        with wave.open(str(public/voice['src']),'rb') as stream:
            if stream.getframerate()!=rate or stream.getnchannels()!=1 or stream.getsampwidth()!=2:raise RuntimeError('Unexpected narration format')
            sound=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').astype(np.float32)/32768
        start=round(voice['start']*rate);end=min(start+len(sound),len(game));game[start:end,0]+=sound[:end-start];game[start:end,1]+=sound[:end-start]
    peak=float(np.max(np.abs(game)));gain=min(1.0,.97/max(peak,.00001));mixed=work/'mix.wav'
    with wave.open(str(mixed),'wb') as output:
        output.setnchannels(channels);output.setsampwidth(sample_width);output.setframerate(rate)
        for start in range(0,len(game),rate*10):output.writeframesraw((np.clip(game[start:start+rate*10]*gain,-1,1)*32767).astype('<i2').tobytes())
    (work/'mix-metadata.json').write_text(json.dumps({'peak_before_gain':peak,'output_gain':gain,'duration':640},indent=2)+'\n')
    audio=work/'mix.m4a';run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(mixed),'-c:a','aac','-b:a','192k',str(audio)])
    print(f'audio: 640s mixed, peak gain {gain:.3f}',flush=True);return audio

if args.chapter is not None:
    render_chapter(args.chapter);raise SystemExit(0)
parts=[render_chapter(i) for i in range(12)]
listing=work/'chapters.ffconcat';listing.write_text('ffconcat version 1.0\n'+''.join('file '+q(p)+'\n' for p in parts))
silent=work/'picture.mp4'
run(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i',str(listing),'-c','copy','-an','-movflags','+faststart',str(silent)])
audio=create_audio();final=editor.parent/'final.mp4'
if args.prepare_only:
    print('Prepared source picture and audio for the revised edit',flush=True);raise SystemExit(0)
print('final: compositing captions, chapter bar and narration',flush=True)
run(['ffmpeg','-hide_banner','-loglevel','warning','-y','-i',str(silent),'-i',str(audio),'-vf','ass=.render/overlay.ass',
     '-map','0:v','-map','1:a','-t','640','-c:v','h264_nvenc','-preset','p4','-cq','20','-b:v','0',
     '-g','120','-bf','0','-pix_fmt','yuv420p','-r','60','-c:a','copy','-movflags','+faststart',str(final)])
print(f'Finished: {final}',flush=True)
