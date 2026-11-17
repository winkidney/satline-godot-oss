#!/usr/bin/env python3
"""Place recorded shots on the approved chapter timeline and check their lengths."""
import json
import shutil
import subprocess
from pathlib import Path

editor=Path(__file__).resolve().parent.parent
root=editor.parents[1]
public=editor/'public'
media_path=editor/'src/media.json'
media=json.loads(media_path.read_text())
game_offset=json.loads((root/'video/recordings/godot/recording.json').read_text())['capture_start_offset_seconds']
lab_offset=json.loads((root/'video/recordings/lab/recording.json').read_text())['capture_start_offset_seconds']
names=['01-outdoor-action','02-warehouse-light','03-wet-reflection','04-weapons-enemies','05-exposure-shift']
def original(index,start,duration):return {'src':'footage/original/'+names[index]+'.mp4','start':start,'duration':duration}
def game(start,duration):return {'src':'footage/godot/gameplay.mp4','start':max(0,start-game_offset),'duration':duration}
def lab(start,duration,label='独立教学实验'):return {'src':'footage/lab/examples.mp4','start':max(0,start-lab_offset),'duration':duration,'audio':False,'label':label}
def historical(side,duration):return {'src':'preview/historical-'+side+'.png','start':0,'duration':duration,'audio':False,'image':True,'label':('原版' if side=='original' else '旧版 Godot')+' · 历史固定机位'}
o=original;g=game;l=lab
chapters=[
 ([o(0,0,9),o(1,0,9),o(2,0,9),o(3,0,9),o(4,0,9)],
  [g(5,9),g(60,9),g(120,9),g(180,9),g(240,9)]),
 ([o(0,0,10),o(1,0,10),o(2,0,10),o(3,0,10),o(4,0,10)],[g(5,10),g(60,10),g(120,10),g(180,10),g(240,10)]),
 ([o(1,0,60)],[g(60,60)]),
 ([o(2,0,55),o(0,0,15)],[g(120,55),g(5,15)]),
 ([o(2,0,55),o(0,0,10)],[g(120,55),g(5,10)]),
 ([o(3,0,35),o(1,0,30)],[g(180,35),l(43,20),g(60,10)]),
 ([o(3,0,55),o(0,0,5)],[g(180,55),g(5,5)]),
 ([o(3,0,55)],[g(180,55)]),
 ([o(4,0,45),o(1,0,10)],[g(240,45),g(60,10)]),
 ([o(2,0,15),o(1,0,15),o(3,0,15),o(0,0,15)],[g(120,5),l(5,10,'湿润 / 独立教学实验'),g(60,15),l(43,15,'织纹 / 独立教学实验'),g(5,15)]),
 ([historical('original',12),o(1,0,23)],[historical('godot',12),g(60,23)]),
]
expected=[45,50,60,70,65,65,60,55,55,60,35]
evidence=root/'saltline-godot/evidence'
for old,new in [('main-paired-high-interior-source.png','historical-original.png'),('main-paired-high-interior-native.png','historical-godot.png')]:
    shutil.copyfile(evidence/old,public/'preview'/new)
durations={}
for index,((left,right),length) in enumerate(zip(chapters,expected)):
    for side in (left,right):
        if sum(c['duration'] for c in side)!=length:raise SystemExit(f'Chapter {index} does not fill its slot')
        for cut in side:
            path=public/cut['src']
            if not path.is_file():raise SystemExit(f'Missing editing footage: {path}')
            if cut.get('image'):continue
            if path not in durations:
                durations[path]=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(path)]))
            if cut['start']+cut['duration']>durations[path]+.05:raise SystemExit(f'Clip is too short: {path}')
media['mode']='recorded'
media['chapters']={str(i):{'original':left,'godot':right,'non_sync':True} for i,(left,right) in enumerate(chapters)}
media_path.write_text(json.dumps(media,ensure_ascii=False,indent=2)+'\n')
print(f'Prepared {len(chapters)} chapters with explicit source and capture offsets.')
