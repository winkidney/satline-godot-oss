#!/usr/bin/env python3
"""Shorten the gaps in the recorded edit and rebuild subtitles and chapter navigation."""
import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys
import unicodedata
import wave
from pathlib import Path

editor=Path(__file__).resolve().parent.parent
work=editor/'.render'
fps=60


def removals_for(narration,total_frames,outro_frame):
    removals=[]
    for i,voice in enumerate(narration):
        end=math.ceil(voice['end']*fps-1e-7)
        next_start=round(narration[i+1]['start']*fps) if i+1<len(narration) else total_frames
        gap=next_start-end
        if gap<0:raise ValueError(f"Overlapping narration at {voice['id']}")
        length=gap//2
        if not length:continue
        if i==len(narration)-1:
            # Keep the closing call-to-action and its final hold intact.
            cut_end=min(next_start,outro_frame)
            cut_start=cut_end-length
            if cut_start<end:raise ValueError('Not enough silence before the closing animation')
        else:
            cut_start=end+(gap-length)//2
            cut_end=cut_start+length
        removals.append((cut_start,cut_end))
    return removals


def map_frame(frame,removals):
    return frame-sum(max(0,min(frame,end)-start) for start,end in removals)


def subtitle_text(value):
    value=re.sub(r'(?<=\d)\.(?=\d)','点',value)
    value=''.join(' ' if unicodedata.category(c).startswith('P') else c for c in value)
    return ' '.join(value.split())


def title_lines(title):
    if len(title)<=5:return [title]
    split=title.find('与')
    if split<0:split=title.find('的')
    if split<0:split=4
    elif split<3:split+=1
    return [title[:split],title[split:]]


def ass_time(seconds):
    ticks=round(seconds*100)
    return f'{ticks//360000}:{ticks//6000%60:02d}:{ticks//100%60:02d}.{ticks%100:02d}'


def srt_time(seconds):
    ms=round(seconds*1000)
    return f'{ms//3600000:02d}:{ms//60000%60:02d}:{ms//1000%60:02d},{ms%1000:03d}'


def parse_ass_time(value):
    h,m,s=value.split(':')
    return int(h)*3600+int(m)*60+float(s)


def event(layer,start,end,text):
    return f'Dialogue: {layer},{ass_time(start)},{ass_time(end)},Text,,0,0,0,,{text}'


def rectangle(layer,start,end,x,y,width,height,color,alpha='00'):
    return event(layer,start,end,rf'{{\an7\pos({x},{y})\p1\1c&H{color}&\1a&H{alpha}&}}m 0 0 l {width} 0 {width} {height} 0 {height}{{\p0}}')


def make_overlay(media,chapters,removals):
    def mapped(seconds):return map_frame(seconds*fps,removals)/fps
    duration=mapped(chapters[-1]['end'])
    source=(work/'overlay.ass').read_text().splitlines()
    output=[]
    for line in source:
        if line.startswith('Style: Caption,'):
            line=line.replace(',160,160,90,1',',160,160,150,1')
        if not line.startswith('Dialogue: '):
            output.append(line);continue
        parts=line.split(',',9)
        start,end=mapped(parse_ass_time(parts[1])),mapped(parse_ass_time(parts[2]))
        if end-start<.005:continue
        parts[1],parts[2]=ass_time(start),ass_time(end)
        if parts[3]=='Caption':parts[9]=subtitle_text(parts[9])
        parts[9]=parts[9].replace(r'\pos(960,895)',r'\pos(960,865)').replace('l 400 1022 0 1022','l 400 956 0 956')
        output.append(','.join(parts))

    output.append(rectangle(4,0,duration,0,956,1920,124,'0B0905','35'))
    for i,chapter in enumerate(chapters):
        start,end=mapped(chapter['start']),mapped(chapter['end'])
        x=36+i*154;center=x+77
        output.append(rectangle(5,0,duration,x,966,1,84,'E1EAEE','D0'))
        output.append(rectangle(5,start,end,x+3,962,148,87,'5EB6FF','C8'))
        title=r'\N'.join(title_lines(chapter['title']))
        output.append(event(6,0,duration,rf'{{\an8\pos({center},971)\fs27\1c&HE1EAEE&}}{title}'))
        output.append(event(7,start,end,rf'{{\an8\pos({center},971)\fs27\1c&H5EB6FF&}}{title}'))
        output.append(rectangle(5,0,duration,x,1065,148,5,'E1EAEE','A0'))
        ms=round((end-start)*1000)
        output.append(event(7,start,end,rf'{{\an7\clip({x},1065,{x+148},1070)\move({x-148},1065,{x},1065,0,{ms})\p1\1c&H5EB6FF&}}m 0 0 l 148 0 148 5 0 5{{\p0}}'))
        if end<duration:output.append(rectangle(7,end,duration,x,1065,148,5,'5EB6FF'))

    (work/'revised.ass').write_text('\n'.join(output)+'\n')
    subtitles=[]
    for i,caption in enumerate(media['captions'],1):
        start,end=mapped(caption['start']),mapped(caption['end'])
        if end<=start:raise ValueError(f'Subtitle {i} was cut')
        subtitles.append(f"{i}\n{srt_time(start)} --> {srt_time(end)}\n{subtitle_text(caption['text'])}\n")
    (work/'revised.srt').write_text('\n'.join(subtitles))


def audio_filter_for(removals,cut_expression):
    filters=['asetnsamples=n=800:p=0']
    for start,end in removals:
        for kind,frame in [('out',start-1),('in',end)]:
            lo=(frame-.2)/fps;hi=(frame+.2)/fps
            filters.append(f"afade=t={kind}:ss={frame*800}:ns=800:enable='between(t,{lo:.6f},{hi:.6f})'")
    return ','.join(filters+[f"aselect='not({cut_expression})'",'asetpts=N/SR/TB'])


def prepare():
    media=json.loads((editor/'src/media.json').read_text())
    chapters=json.loads(subprocess.check_output(['node','--input-type=module','-e',"import {chapters} from './src/timeline.js';process.stdout.write(JSON.stringify(chapters))"],cwd=editor))
    total=round(chapters[-1]['end']*fps)
    for voice in media['narration']:
        with wave.open(str(editor/'public'/voice['src']),'rb') as audio:
            actual=audio.getnframes()/audio.getframerate()
        if abs((voice['end']-voice['start'])-actual)>1/fps:raise ValueError(f"Narration duration changed: {voice['id']}")
    outro=round(chapters[-1]['beats'][1][0]*fps)
    removals=removals_for(media['narration'],total,outro)
    for start,end in removals:
        for voice in media['narration']:
            if start<voice['end']*fps-1e-7 and end>voice['start']*fps+1e-7:raise ValueError('A cut intersects narration')
    sections=[];source_start=0;out_start=0
    for start,end in removals+[(total,total)]:
        if start>source_start:
            sections.append({'sourceStart':source_start,'sourceEnd':start,'outputStart':out_start})
            out_start+=start-source_start
        source_start=end
    revision={'fps':fps,'sourceFrames':total,'totalFrames':out_start,'removedFrames':total-out_start,
              'removals':[list(x) for x in removals],'sections':sections,
              'chapters':[{'title':c['title'],'lines':title_lines(c['title']),'startFrame':round(map_frame(c['start']*fps,removals)),
                           'endFrame':round(map_frame(c['end']*fps,removals))} for c in chapters]}
    (editor/'src/revision.json').write_text(json.dumps(revision,ensure_ascii=False,indent=2)+'\n')
    subprocess.run([sys.executable,'scripts/prepare_graphics.py','--no-footer','--no-srt'],cwd=editor,check=True)
    make_overlay(media,chapters,removals)
    print(f"Removed {revision['removedFrames']/fps:.2f}s from gaps; final duration {out_start/fps:.2f}s",flush=True)
    return revision


def render(revision):
    picture=work/'picture.mp4';audio=work/'mix.wav'
    if not picture.is_file() or not audio.is_file():raise SystemExit('Run render_fast.py --resume --prepare-only first')
    cut_expression='+'.join(f'between(n,{start},{end-1})' for start,end in revision['removals']) or '0'
    video_filter=f"select='not({cut_expression})',setpts=N/(60*TB),ass=.render/revised.ass"
    audio_filter=audio_filter_for(revision['removals'],cut_expression)
    temp=work/'revised-final.mp4'
    # shortcut: source chapters must keep matching dimensions and pixel format when colour tags change.
    cmd=['ffmpeg','-hide_banner','-loglevel','warning','-y','-reinit_filter','0','-i',str(picture),'-i',str(audio),
         '-vf',video_filter,'-af',audio_filter,'-map','0:v:0','-map','1:a:0',
         '-c:v','h264_nvenc','-preset','p4','-cq','20','-b:v','0','-g','120','-bf','0','-pix_fmt','yuv420p','-r','60',
         '-c:a','aac','-b:a','192k','-movflags','+faststart',str(temp)]
    print('Rendering revised film',flush=True)
    subprocess.run(cmd,cwd=editor,check=True)
    probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','stream=codec_type,width,height,nb_frames,r_frame_rate,duration','-of','json',str(temp)]))
    video=next(x for x in probe['streams'] if x['codec_type']=='video')
    if (video['width'],video['height'],video['r_frame_rate'],int(video['nb_frames']))!=(1920,1080,'60/1',revision['totalFrames']):
        raise RuntimeError('The revised export did not match the expected frame count')
    archive=editor.parent/'archive';archive.mkdir(exist_ok=True)
    final=editor.parent/'final.mp4';old=archive/'first-cut.mp4'
    if final.exists() and not old.exists():os.link(final,old)
    old_subtitles=archive/'first-cut.srt'
    if (editor.parent/'subtitles.srt').exists() and not old_subtitles.exists():shutil.copy2(editor.parent/'subtitles.srt',old_subtitles)
    os.replace(temp,final)
    os.replace(work/'revised.srt',editor.parent/'subtitles.srt')
    print(f'Finished: {final}',flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--prepare-only',action='store_true');args=parser.parse_args()
    work.mkdir(exist_ok=True)
    revision=prepare()
    if not args.prepare_only:render(revision)
