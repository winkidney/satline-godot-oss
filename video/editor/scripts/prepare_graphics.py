#!/usr/bin/env python3
"""Generate timed, flat-colour MG cards and editable captions for fast export."""
import json
import math
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

editor=Path(__file__).resolve().parent.parent
render=editor/'.render';cards=render/'cards';cards.mkdir(parents=True,exist_ok=True)
media=json.loads((editor/'src/media.json').read_text())
chapters=json.loads(subprocess.check_output(['node','--input-type=module','-e',"import {chapters} from './src/timeline.js';process.stdout.write(JSON.stringify(chapters))"],cwd=editor))
font_path=subprocess.check_output(['fc-match','-f','%{file}','Noto Sans CJK SC'],text=True).strip()
def font(size):
    result=ImageFont.truetype(font_path,size)
    try:result.set_variation_by_name('Regular')
    except OSError:pass
    return result
bg='#0b1012';pale='#eeeae1';amber='#ffb65e';blue='#9eb4c1';muted='#65737a';danger='#e18577'

def center_text(draw,rect,text,size=29):
    x1,y1,x2,y2=rect;f=font(size);parts=[];line=''
    for c in text:
        if line and draw.textlength(line+c,font=f)>x2-x1-20:parts.append(line);line=c
        else:line+=c
    if line:parts.append(line)
    height=len(parts)*(size+4)-4;y=(y1+y2-height)/2-4
    for line in parts:
        draw.text(((x1+x2-draw.textlength(line,font=f))/2,y),line,font=f,fill=pale);y+=size+4

def arrow(draw,a,b,colour=muted):
    draw.line([a,b],fill=colour,width=3)
    angle=math.atan2(b[1]-a[1],b[0]-a[0]);length=12
    draw.polygon([b,(b[0]-length*math.cos(angle-.45),b[1]-length*math.sin(angle-.45)),
                  (b[0]-length*math.cos(angle+.45),b[1]-length*math.sin(angle+.45))],fill=colour)

def symbol(draw,kind):
    if kind=='rays':
        draw.ellipse((92,77,120,105),fill=amber);draw.rectangle((181,68,199,193),fill=muted);draw.rectangle((181,110,199,146),fill=bg)
        for y in (95,115,135):draw.line((116,y,244,y+35),fill=amber,width=3)
        for i in range(5):draw.ellipse((126+i*22,104+i*6,135+i*22,113+i*6),fill=pale)
    elif kind=='reflection':
        draw.line((70,150,248,150),fill=blue,width=5)
        draw.polygon([(90,95),(125,110),(90,125)],fill=amber);draw.polygon([(90,205),(125,190),(90,175)],fill=blue)
        draw.line((125,110,224,145),fill=amber,width=3);draw.line((125,190,224,155),fill=blue,width=3)
    elif kind=='pixels':
        for i in range(5):
            draw.line((95+i*29,82,95+i*29,198),fill=muted,width=2);draw.line((95,82+i*29,211,82+i*29),fill=muted,width=2)
        draw.polygon([(102,190),(205,88),(200,188)],fill='#73583d')
        for i in range(4):draw.ellipse((107+i*26,177-i*24,117+i*26,187-i*24),fill=pale)
    elif kind=='bones':
        points=[(85,190),(145,100),(215,155)];draw.line(points,fill=amber,width=6)
        for i,(x,y) in enumerate(points):draw.ellipse((x-9,y-9,x+9,y+9),fill=blue if i==2 else amber)
    elif kind=='meter':
        draw.line((86,200,235,200),fill=muted,width=3);draw.line((86,200,86,85),fill=muted,width=3)
        draw.line([(88,190),(120,182),(145,155),(170,125),(200,110),(235,108)],fill=amber,width=5)
    elif kind=='problem':
        draw.rounded_rectangle((91,92,225,202),radius=6,outline=danger,width=4);draw.line((158,108,158,163),fill=danger,width=6);draw.ellipse((153,177,163,187),fill=danger)
    elif kind=='shadow':
        draw.ellipse((92,85,119,112),fill=amber);draw.rectangle((158,93,176,173),fill=blue)
        draw.line((82,200,236,200),fill=pale,width=3);draw.line((170,170,224,200),fill=amber,width=4)
    else:
        draw.rounded_rectangle((91,91,140,140),radius=5,fill=amber);draw.rounded_rectangle((187,155,236,204),radius=5,fill=blue)
        draw.line([(146,116),(173,116),(173,179),(182,179)],fill=amber,width=4)
    draw.line((284,55,284,245),fill='#39454a',width=2)

def diagram(beat,reveal,path):
    _,_,kind,nodes=beat;im=Image.new('RGB',(1920,300),bg);d=ImageDraw.Draw(im);symbol(d,kind)
    if kind in ('branch','merge'):
        main=(307,105,595,195) if kind=='branch' else (1535,105,1848,195)
        if kind=='branch' or reveal>=len(nodes):
            d.rectangle(main,fill='#192126',outline=amber,width=2);center_text(d,main,nodes[0] if kind=='branch' else nodes[-1])
        rows=nodes[1:] if kind=='branch' else nodes[:-1]
        for i,label in enumerate(rows):
            if i+1>=reveal and kind=='branch':continue
            if i>=reveal and kind=='merge':continue
            rect=(700,35+i*76,1430,93+i*76);d.rectangle(rect,fill='#192126',outline=blue,width=2);center_text(d,rect,label,27)
            arrow(d,(620,150),(680,64+i*76)) if kind=='branch' else arrow(d,(1450,64+i*76),(1515,150))
    else:
        n=len(nodes);gap=38;width=(1540-gap*(n-1))/n
        for i,label in enumerate(nodes):
            if i>=reveal:continue
            x=307+i*(width+gap);rect=(round(x),108,round(x+width),192)
            d.rectangle(rect,fill='#192126',outline=danger if kind=='problem' and i==n-1 else amber if i==0 else blue,width=2)
            center_text(d,rect,label,25 if n>4 else 29)
            if i>0:arrow(d,(round(x-gap+4),150),(round(x-7),150))
    im.save(path)

for chapter_index,chapter in enumerate(chapters[1:-1],1):
    manifest=['ffconcat version 1.0']
    for beat_index,beat in enumerate(chapter['beats']):
        node_count=len(beat[3]);step=.12;duration=beat[1]-beat[0]
        for reveal in range(1,node_count+1):
            path=cards/f'{chapter_index:02d}-{beat_index:02d}-{reveal}.png';diagram(beat,reveal,path)
            length=step if reveal<node_count else duration-step*(node_count-1)
            manifest += ["file '"+str(path).replace("'","'\\''")+"'",f'duration {length:.3f}']
    manifest.append("file '"+str(path).replace("'","'\\''")+"'")
    (render/f'cards-{chapter_index:02d}.ffconcat').write_text('\n'.join(manifest)+'\n')

source=Image.new('RGB',(1920,1080),bg);d=ImageDraw.Draw(source)
d.text((130,180),'SALTLINE · GODOT',font=font(26),fill=amber)
d.text((130,230),'项目与参考资料',font=font(56),fill=pale)
for i,line in enumerate(['原版：claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp',
                         '项目：github.com/winkidney/satline-godot-oss',
                         "This audio was created with Boson AI's Higgs Audio"]):
    d.text((130,340+i*64),line,font=font(28),fill=blue)
qr=Image.open(editor/'public/preview/project-qr.png').convert('RGB').resize((300,300),Image.Resampling.NEAREST)
d.rectangle((1426,211,1754,539),fill='white');source.paste(qr,(1440,225));d.text((1502,560),'项目待公开',font=font(24),fill=pale)
source.save(render/'source-card.png')

def ass_time(value):
    centi=round(value*100);h=centi//360000;m=centi//6000%60;s=centi//100%60;c=centi%100
    return f'{h}:{m:02d}:{s:02d}.{c:02d}'
def srt_time(value):
    ms=round(value*1000);return f'{ms//3600000:02d}:{ms//60000%60:02d}:{ms//1000%60:02d},{ms%1000:03d}'
def event(layer,start,end,style,text):
    return f'Dialogue: {layer},{ass_time(start)},{ass_time(end)},{style},,0,0,0,,{text}'
def vector(start,end,x,y,w,h,colour,alpha='00',layer=1):
    return event(layer,start,end,'Text',rf'{{\an7\pos({x},{y})\p1\1c&H{colour}&\1a&H{alpha}&}}m 0 0 l {w} 0 {w} {h} 0 {h}{{\p0}}')

ass=['[Script Info]','ScriptType: v4.00+','PlayResX: 1920','PlayResY: 1080','ScaledBorderAndShadow: yes','',
     '[V4+ Styles]','Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding',
     'Style: Text,Noto Sans CJK SC,25,&H00E1EAEE,&H00E1EAEE,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1',
     'Style: Caption,Noto Sans CJK SC,44,&H00FFFFFF,&H00FFFFFF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,2,1,2,160,160,90,1','',
     '[Events]','Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text']
include_footer='--no-footer' not in sys.argv
if include_footer:
    ass.append(vector(0,640,0,1022,1920,58,'0B0905','40',4))
    ass.append(vector(0,640,36,1068,1848,5,'E1EAEE','B0',5))
    ass.append(event(6,0,640,'Text',r'{\an7\clip(36,1068,1884,1073)\move(-1812,1068,36,1068,0,640000)\p1\1c&H5EB6FF&}m 0 0 l 1848 0 1848 5 0 5{\p0}'))
    for chapter in chapters[1:]:
        x=round(36+1848*chapter['start']/640);ass.append(vector(0,640,x,1065,2,11,'E1EAEE','30',7))
for index,chapter in enumerate(chapters):
    start,end=chapter['start'],chapter['end']
    if include_footer:ass.append(event(8,start,end,'Text',rf'{{\an7\pos(36,1027)\fs28}}{chapter["title"]}'))
    if index>0:
        ass.append(event(12,start,start+.5,'Text',r'{\an7\move(-420,0,1920,0,0,500)\p1\1c&H5EB6FF&\1a&H30&}m 0 0 l 400 0 400 1022 0 1022{\p0}'))
    if 0<index<11:
        ass.append(event(3,start,end,'Text',r'{\an9\pos(1880,575)\fs24\1c&HC1B49E&}非同步操作 · 场景对照'))
        for side,x in [('original',54),('godot',1006)]:
            offset=0
            for cut in media['chapters'][str(index)][side]:
                a=start+offset;b=a+cut['duration'];offset+=cut['duration']
                label=cut.get('label','原版 HTML' if side=='original' else 'Godot 应用示例' if index==9 else 'Godot 复刻')
                ass.append(vector(a,b,x-12,50,min(610,24+len(label)*28),46,'12100B','20',5))
                ass.append(event(6,a,b,'Text',rf'{{\an7\pos({x},53)\fs30}}{label}'))
ass.append(vector(0,45,14,12,150,46,'12100B','20',5))
ass.append(event(6,0,45,'Text',r'{\an7\pos(28,15)\fs30}Godot 复刻'))
ass.append(vector(0,45,1246,34,640,3,'5EB6FF','00',5));ass.append(vector(0,45,1246,391,640,3,'5EB6FF','00',5))
ass.append(vector(0,45,1246,34,3,360,'5EB6FF','00',5));ass.append(vector(0,45,1883,34,3,360,'5EB6FF','00',5))
ass.append(vector(0,45,1260,48,330,46,'12100B','20',5))
ass.append(event(6,0,45,'Text',r'{\an7\pos(1273,53)\fs28}原版 HTML · 非同步操作'))
ass.append(vector(0,12,60,90,810,104,'12100B','20',5));ass.append(vector(0,12,60,90,6,104,'5EB6FF','00',6))
ass.append(event(7,0,12,'Text',r'{\an7\pos(88,108)\fs34}Claude Fable 5.2 → HTML 游戏 → Godot 复刻'))
ass.append(event(7,0,12,'Text',r'{\an7\pos(90,157)\fs22\1c&HC1B49E&}探索 Godot 的能力边界'))
prompts=['提示词：用湿润状态驱动底色、粗糙度和倒影','提示词：固定窗、墙和光源，再加入受遮挡的雾','提示词：让织纹跟随表面，远处逐渐过滤细节','提示词：说明输入、目标，并给出验证方法']
for i,prompt in enumerate(prompts):ass.append(event(8,525+i*15,540+i*15,'Text',rf'{{\an8\pos(960,895)\fs22\1c&HC1B49E&}}{prompt}'))
for i,label in enumerate(['点赞','投币','收藏']):
    ass.append(event(8,635+i*.15,638,'Text',rf'{{\an7\move({130+i*155},640,{130+i*155},620,0,300)\fad(150,150)\fs31\1c&H5EB6FF&}}● {label}'))
srt=[]
for i,caption in enumerate(media['captions'],1):
    text=caption['text'].replace('{','｛').replace('}','｝').replace('\\','＼')
    ass.append(event(10,caption['start'],caption['end'],'Caption',text))
    srt.append(f"{i}\n{srt_time(caption['start'])} --> {srt_time(caption['end'])}\n{text}\n")
(render/'overlay.ass').write_text('\n'.join(ass)+'\n')
if '--no-srt' not in sys.argv:(editor.parent/'subtitles.srt').write_text('\n'.join(srt))
print(f'Generated MG cards for {len(chapters)-2} chapters and {len(srt)} subtitle spans.')
