#!/usr/bin/env python3
"""Assemble the film from recorded showcases and private narration."""
import argparse
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import unicodedata
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

EDITOR = Path(__file__).resolve().parent.parent
ROOT = EDITOR.parents[1]
PLAN = json.loads((EDITOR / 'src/film-plan.json').read_text())
VERSION = int(PLAN['version'])
WORK = EDITOR / f'.render-v{VERSION}'
FPS = 60


def pair(scene, left='original', right='replica'):
    return {'scene': scene, 'left': left, 'right': right}


LAYOUTS = [
    [{'single': 'game5'}, {'single': 'backdrop', 'pip_scene': 'backdrop'}, {'single': 'sea'}, {'single': 'sky'},
     {'single': 'enemies', 'pip_scene': 'enemies'}, {'single': 'weapon', 'pip_scene': 'weapon'},
     {'single': 'fx', 'pip_scene': 'fx'}, {'single': 'game120'}],
    [pair('props'), pair('props', 'replica', 'builtin'), pair('level'), pair('level', 'replica', 'builtin')],
    [pair('render'), pair('render', 'replica', 'builtin'), {'single': 'ao_compare'}, {'single': 'pbr'}, {'single': 'diffuse'}, {'single': 'transparency'}, pair('ground', 'replica', 'builtin')],
    [pair('backdrop'), pair('backdrop', 'replica', 'builtin'), {'single': 'sea'}, {'single': 'sky'}],
    [pair('render'), pair('render', 'replica', 'builtin'), pair('level'), pair('level', 'replica', 'builtin')],
    [pair('ground'), pair('ground', 'replica', 'builtin')],
    [pair('mats'), pair('mats', 'replica', 'builtin'), pair('hands'), pair('hands', 'replica', 'builtin')],
    [pair('weapon'), pair('weapon', 'replica', 'builtin'), pair('enemies'), pair('enemies', 'replica', 'builtin'), pair('enemies', 'original-frozen', 'builtin')],
    [pair('render'), pair('render', 'replica', 'builtin'), {'single': 'game240'}],
    [pair('fx'), pair('fx', 'replica', 'builtin'), {'single': 'game180'}],
    [{'single': x} for x in ('game120', 'sea', 'sky', 'game60', 'labcloth')],
    [pair('ground', 'replica', 'builtin'), pair('hands', 'replica', 'builtin'), pair('fx', 'replica', 'builtin')],
    [{'single': 'card'}],
]

# Each group follows one narration segment so the image explains the words.
CUES = [
    None,
    [[pair('props'), pair('level')], [pair('props')], [pair('mats'), pair('props')],
     [pair('props', 'replica', 'builtin'), pair('level', 'replica', 'builtin')]],
    [[{'single': 'pbr'}], [pair('render'), pair('render', 'replica', 'builtin')],
     [{'single': 'ao_compare'}], [{'single': 'diffuse'}], [{'single': 'transparency'}, pair('ground', 'replica', 'builtin')]],
    [[pair('backdrop'), pair('backdrop', 'replica', 'builtin')], [{'single': 'sky'}], [{'single': 'sea'}]],
    [[pair('level'), pair('level', 'replica', 'builtin')], [pair('level')],
     [pair('render'), pair('render', 'replica', 'builtin')], [pair('level'), pair('level', 'replica', 'builtin')]],
    [[pair('ground')], [pair('ground', 'replica', 'builtin')], [pair('ground')],
     [pair('ground'), pair('ground', 'replica', 'builtin')], [pair('ground')], [pair('ground')]],
    [[pair('mats'), pair('mats', 'replica', 'builtin')], [pair('hands'), pair('hands', 'replica', 'builtin')],
     [pair('weapon')], [pair('weapon', 'replica', 'builtin')]],
    [[pair('weapon')], [pair('weapon')],
     [pair('enemies'), pair('enemies', 'replica', 'builtin'), pair('enemies', 'original-frozen', 'builtin')]],
    [[{'single': 'game120'}, {'single': 'game60'}], [pair('render'), pair('render', 'replica', 'builtin')], [pair('render')]],
    [[pair('fx')], [pair('fx', 'replica', 'builtin')], [pair('fx'), {'single': 'game180'}]],
    [[{'single': 'game120'}, {'single': 'labwet'}], [{'single': 'sea'}, {'single': 'sky'}], [{'single': 'game60'}, {'single': 'lablight'}],
     [{'single': 'labcloth'}], [{'single': 'labcloth'}]],
    [[pair('level'), pair('render')], [pair('ground', 'replica', 'builtin'), pair('hands', 'replica', 'builtin'),
                                        pair('fx', 'replica', 'builtin')], [pair('fx'), pair('enemies')]],
    None,
]
DIAGRAM_CUES = [
    None, [[0], [0, 1], [2], [3]], [[0], [1], [3], [2], [4]], [[0], [0], [1]],
    [[0], [0], [1], [2]], [[0], [3], [2], [1], [4], [4]], [[0, 1], [3], [2], [2]],
    [[0], [1], [2]], [[0], [1], [2]], [[0], [1], [1]], [[0], [1], [2], [3], [3]],
    [[0], [1], [1]], None,
]


def run(command):
    subprocess.run([str(x) for x in command], check=True, cwd=EDITOR)


def render_input_signature():
    digest = hashlib.sha256()
    for path in (Path(__file__), EDITOR / 'src/film-plan.json', WORK / 'timeline.json',
                 WORK / 'overlay.ass', WORK / 'picture.mp4', WORK / 'mix.m4a'):
        with path.open('rb') as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(block)
    return digest.hexdigest()


def voice_file(index, number, voice):
    identifier = voice.get('reuse', f'v{VERSION}-{index:02d}-{number:02d}')
    return EDITOR / 'public/private-voice' / (identifier + '.wav')


def wav_duration(path):
    if not path.is_file():
        raise SystemExit(f'Missing authorized narration: {path.name}')
    with wave.open(str(path), 'rb') as audio:
        if (audio.getframerate(), audio.getnchannels(), audio.getsampwidth()) != (48000, 1, 2):
            raise SystemExit(f'Unexpected narration format: {path.name}')
        return audio.getnframes() / audio.getframerate()


def subtitle_text(value):
    value = re.sub(r'(?<=\d)\.(?=\d)', '点', value)
    return ' '.join(''.join(' ' if unicodedata.category(c).startswith('P') else c for c in value).split())


def make_timeline():
    chapters, voices, captions, shots = [], [], [], []
    cursor = 0
    for ci, chapter in enumerate(PLAN['chapters']):
        samples = [(voice, voice_file(ci, vi, voice), wav_duration(voice_file(ci, vi, voice)))
                   for vi, voice in enumerate(chapter['narration'])]
        spoken = sum(item[2] for item in samples)
        minimum = 45 if ci == 0 else 15 if ci == 12 else len(LAYOUTS[ci]) * 5.5
        duration = math.ceil(max(minimum, spoken + max(0, len(samples) - 1) * .8 + 2) * FPS) / FPS
        start = cursor / FPS
        count = round(duration * FPS)
        end = (cursor + count) / FPS
        current = start + (0 if ci == 0 else .7)
        voice_starts = []
        for voice, path, length in samples:
            voice_starts.append(current)
            voices.append({'start': current, 'end': current + length, 'src': str(path), 'text': voice['text']})
            phrases = [part for part in re.split(r'(?<=[，。；：！？])', voice['text']) if subtitle_text(part)]
            weights = [max(1, len(subtitle_text(part).replace(' ', ''))) for part in phrases]
            at = current
            for phrase, weight in zip(phrases, weights):
                until = at + length * weight / sum(weights)
                captions.append({'start': at, 'end': until, 'text': subtitle_text(phrase)})
                at = until
            current += length + .8
        if current - .8 > end + .01:
            raise ValueError('Narration exceeds chapter: ' + chapter['title'])
        diagram_cues = []
        if CUES[ci] is None:
            intervals = [(cursor, cursor + count, LAYOUTS[ci])]
        else:
            assert len(CUES[ci]) == len(samples) == len(DIAGRAM_CUES[ci])
            boundaries = [cursor] + [round(x * FPS) for x in voice_starts[1:]] + [cursor + count]
            intervals = [(boundaries[i], boundaries[i+1], choices) for i, choices in enumerate(CUES[ci])]
            for i, indexes in enumerate(DIAGRAM_CUES[ci]):
                a, b = boundaries[i] / FPS, boundaries[i+1] / FPS
                for j, index in enumerate(indexes):
                    diagram_cues.append({'start': a + (b-a)*j/len(indexes), 'end': a + (b-a)*(j+1)/len(indexes),
                                         'text': chapter['diagrams'][index]})
        chapters.append({'title': chapter['title'], 'start': start, 'end': end, 'diagram_cues': diagram_cues})
        for first_frame, last_frame, choices in intervals:
            span = last_frame - first_frame
            shot_count = 1 if ci == 12 else max(len(choices), math.ceil(span / (7.3 * FPS)))
            for index in range(shot_count):
                first = first_frame + span * index // shot_count
                last = first_frame + span * (index + 1) // shot_count
                shots.append({'chapter': ci, 'start_frame': first, 'frames': last - first, **choices[index % len(choices)]})
        cursor += count
    if not 480 * FPS <= cursor <= 720 * FPS:
        raise ValueError(f'Film duration {cursor/FPS:.1f}s is outside 8–12 minutes')
    assert shots[0]['start_frame'] == 0 and shots[-1]['start_frame'] + shots[-1]['frames'] == cursor
    assert all(a['start_frame'] + a['frames'] == b['start_frame'] for a, b in zip(shots, shots[1:]))
    for scene in ('mats', 'props', 'render', 'ground', 'level', 'backdrop', 'enemies', 'weapon', 'hands', 'fx'):
        assert any(s.get('scene') == scene and s.get('right') == 'replica' for s in shots)
        assert any(s.get('scene') == scene and s.get('right') == 'builtin' for s in shots)
    result = {'fps': FPS, 'frames': cursor, 'chapters': chapters, 'shots': shots, 'narration': voices, 'captions': captions}
    (WORK / 'timeline.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    return result


def shot_source(kind, scene=None):
    if kind in ('original', 'original-frozen', 'replica', 'builtin'):
        suffix = '.webm' if kind in ('original', 'original-frozen') else '.mp4'
        folder = 'builtin-calibrated' if kind == 'builtin' else kind
        return ROOT / 'video/recordings/showcases' / folder / (scene + suffix), .2
    if kind.startswith('game'):
        return EDITOR / 'public/footage/godot/gameplay.mp4', float(kind[4:])
    if kind in ('backdrop', 'enemies', 'weapon', 'fx'):
        return ROOT / 'video/recordings/showcases/replica' / (kind + '.mp4'), .2
    if kind in ('pbr', 'diffuse', 'transparency'):
        return ROOT / 'video/recordings/showcases/lab' / (kind + '.mp4'), .2
    if kind == 'sea': return ROOT / 'video/recordings/godot/sea-quay-fixed.mp4', .2
    if kind == 'sky': return ROOT / 'saltline-godot/evidence/native-dynamic-sky.mp4', .2
    if kind == 'labwet': return EDITOR / 'public/footage/lab/examples.mp4', 11.5
    if kind == 'lablight': return EDITOR / 'public/footage/lab/examples.mp4', 28
    if kind == 'labcloth': return EDITOR / 'public/footage/lab/examples.mp4', 43
    if kind == 'card': return WORK / 'source-card.png', 0
    if kind == 'ao_compare': return WORK / 'ao-comparison.png', 0
    raise ValueError('Unknown source: ' + kind)


def label(kind, scene=None):
    if kind == 'original': return '原版 HTML · 调试场景'
    if kind == 'original-frozen': return '原版 HTML · 冻结姿态'
    if kind == 'replica':
        return 'Godot 复刻 · 固定步进' if scene in ('mats', 'props', 'render', 'ground', 'weapon', 'hands') else 'Godot 复刻 · 调试场景'
    if kind == 'builtin':
        return {'backdrop': '官方 Godot · 静态天空 · 固定步进', 'enemies': '官方 Godot · 冻结姿态 · 固定步进',
                'weapon': '官方 Godot · 冻结姿态 · 固定步进', 'ground': '官方 Godot · 烘焙湿地与 SSR · 固定步进',
                'hands': '官方 Godot · 烘焙材质 · 固定步进', 'fx': '官方 Godot · 粒子近似 · 固定步进'}.get(scene, '官方 Godot · 内建渲染 · 固定步进')
    return {'sea': 'Godot 复刻 · 海面 · 固定步进', 'sky': '历史受控画面 · 天空 · 720p',
            'labcloth': '独立教学实验 · 织纹过滤', 'ao_compare': '原版遮蔽开关 · 官方内建调校', 'pbr': '官方标准材质实验',
            'labwet': '独立教学实验 · 湿润与反射', 'lablight': '独立教学实验 · 窄窗光照',
            'diffuse': '官方标准材质 · 漫反射对照', 'transparency': '官方标准材质 · 透明叠层',
            'backdrop': 'Godot 复刻 · 背景调试场景', 'enemies': 'Godot 复刻 · 敌人调试场景',
            'weapon': 'Godot 复刻 · 武器调试场景', 'fx': 'Godot 复刻 · 特效调试场景'}.get(kind, 'Godot 复刻 · 游戏实录')


def ass_time(value):
    centi = round(value * 100)
    return f'{centi//360000}:{centi//6000%60:02d}:{centi//100%60:02d}.{centi%100:02d}'


def srt_time(value):
    ms = round(value * 1000)
    return f'{ms//3600000:02d}:{ms//60000%60:02d}:{ms//1000%60:02d},{ms%1000:03d}'


def event(layer, start, end, text, style='Text'):
    return f'Dialogue: {layer},{ass_time(start)},{ass_time(end)},{style},,0,0,0,,{text}'


def box(layer, start, end, x, y, width, height, color, alpha='00', extra=''):
    return event(layer, start, end, rf'{{\an7\pos({x},{y})\p1\1c&H{color}&\1a&H{alpha}&{extra}}}m 0 0 l {width} 0 {width} {height} 0 {height}{{\p0}}')


def wrap(text, limit=13):
    if len(text) <= limit: return text
    split = text.rfind(' ', 0, limit + 1)
    if split < 4: split = limit
    return text[:split] + r'\N' + text[split:].strip()


def diagram_icon(chapter, start, end):
    shapes = {
        1: 'm 4 80 l 48 80 48 124 4 124 m 54 50 l 98 50 98 124 54 124 m 104 15 l 148 15 148 124 104 124',
        2: 'm 75 4 b 36 4 5 35 5 74 b 5 113 36 144 75 144 b 114 144 145 113 145 74 b 145 35 114 4 75 4 m 52 26 b 41 26 32 35 32 46 b 32 57 41 66 52 66 b 63 66 72 57 72 46 b 72 35 63 26 52 26',
        3: 'm 4 74 l 32 62 60 74 88 62 116 74 146 62 146 75 116 87 88 75 60 87 32 75 4 87 m 4 106 l 32 94 60 106 88 94 116 106 146 94 146 107 116 119 88 107 60 119 32 107 4 119 m 99 12 l 121 12 121 34 99 34',
        4: 'm 5 60 l 25 50 145 8 145 20 38 61 145 65 145 77 38 74 145 119 145 131 25 86 5 76 m 32 54 l 44 54 44 66 32 66 m 75 41 l 87 41 87 53 75 53',
        5: 'm 3 70 l 147 70 147 78 3 78 m 32 16 l 85 16 85 52 32 52 m 85 25 l 123 12 123 56 85 44 m 32 96 l 85 96 85 132 32 132 m 85 104 l 123 92 123 136 85 124',
        6: 'm 10 12 l 24 12 24 136 10 136 m 50 12 l 64 12 64 136 50 136 m 90 12 l 104 12 104 136 90 136 m 130 12 l 144 12 144 136 130 136 m 10 32 l 144 32 144 44 10 44 m 10 72 l 144 72 144 84 10 84 m 10 112 l 144 112 144 124 10 124',
        7: 'm 10 98 l 24 85 68 59 81 70 38 101 26 116 m 70 59 l 91 21 104 28 84 68 m 93 20 l 127 15 144 30 136 43 103 35 m 7 100 l 28 100 28 121 7 121 m 64 54 l 84 54 84 74 64 74',
        8: 'm 7 104 l 25 104 25 133 7 133 m 33 85 l 51 85 51 133 33 133 m 59 48 l 77 48 77 133 59 133 m 85 24 l 103 24 103 133 85 133 m 111 69 l 129 69 129 133 111 133 m 7 137 l 143 137 143 145 7 145',
        9: 'm 75 4 l 88 50 130 20 101 61 146 73 100 85 130 128 87 99 75 145 63 99 20 128 49 85 4 73 49 61 20 20 62 50',
        10: 'm 8 15 l 68 15 68 60 8 60 m 82 15 l 142 15 142 60 82 60 m 8 82 l 68 82 68 127 8 127 m 82 82 l 142 82 142 127 82 127',
        11: 'm 4 12 l 66 12 66 132 4 132 m 82 12 l 144 12 144 132 82 132 m 69 4 l 79 4 79 140 69 140',
    }
    path = shapes.get(chapter, shapes[10])
    return event(6, start, end, rf'{{\an7\pos(35,807)\fscx30\fscy30\p1\1c&H5EB6FF&\1a&H30&\fad(200,120)}}{path}{{\p0}}')


def prepare_graphics(timeline):
    font_path = subprocess.check_output(['fc-match', '-f', '%{file}', 'Noto Sans CJK SC'], text=True).strip()
    font = lambda size: ImageFont.truetype(font_path, size)
    image = Image.new('RGB', (1920, 1080), '#0b1012')
    draw = ImageDraw.Draw(image)
    draw.text((130, 175), 'SALTLINE · GODOT', font=font(30), fill='#ffb65e')
    draw.text((130, 235), '项目与参考资料', font=font(62), fill='#eeeae1')
    for i, text in enumerate(['原版：claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp',
                              '项目：github.com/winkidney/satline-godot-oss',
                              '项目待公开  原作素材授权待核实',
                              "This audio was created with Boson AI's Higgs Audio",
                              '旁白为经授权的合成配音']):
        draw.text((130, 355 + i * 62), text, font=font(27), fill='#b6c4cb')
    qr = Image.open(EDITOR / 'public/preview/project-qr.png').convert('RGB').resize((300, 300), Image.Resampling.NEAREST)
    draw.rectangle((1426, 215, 1754, 543), fill='white')
    image.paste(qr, (1440, 229))
    image.save(WORK / 'source-card.png')

    ao_image = Image.new('RGB', (1920, 520), '#10171b')
    ao_draw = ImageDraw.Draw(ao_image)
    ao_sources = [ROOT / 'video/review/calibration/ablation/source-weapon-full-exp-0.706.png',
                  ROOT / 'video/review/calibration/ablation/source-weapon-full-exp-0.706-no-ao.png',
                  ROOT / 'video/review/calibration/final-calibrated/weapon.png']
    for i, (source, text) in enumerate(zip(ao_sources, ('原版 SSAO 开', '原版 SSAO 关', 'Godot 内建 调校后'))):
        x = 140 + i * 620
        with Image.open(source) as picture:
            crop = picture.convert('RGB').crop((590, 350, 795, 555)).resize((400, 400), Image.Resampling.LANCZOS)
        ao_image.paste(crop, (x, 80))
        ao_draw.text((x, 20), text, font=font(34), fill='#ffc07a')
    ao_draw.text((140, 485), '同一曝光  分别采集  局部裁切', font=font(24), fill='#b6c4cb')
    ao_image.save(WORK / 'ao-comparison.png')

    total = timeline['frames'] / FPS
    ass = ['[Script Info]', 'ScriptType: v4.00+', 'PlayResX: 1920', 'PlayResY: 1080', 'ScaledBorderAndShadow: yes', '',
           '[V4+ Styles]', 'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding',
           'Style: Text,Noto Sans CJK SC,25,&H00E1EAEE,&H00E1EAEE,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,1,0,7,0,0,0,1',
           'Style: Caption,Noto Sans CJK SC,42,&H00FFFFFF,&H00FFFFFF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,2,1,2,100,100,0,1', '',
           '[Events]', 'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text']
    ass.append(box(20, 0, total, 0, 924, 1920, 156, '0B0905', '35'))
    ass.append(box(21, 0, total, 36, 1069, 1848, 5, 'E1EAEE', 'B0'))
    ass.append(event(22, 0, total, rf'{{\an7\clip(36,1069,1884,1074)\move(-1812,1069,36,1069,0,{round(total*1000)})\p1\1c&H5EB6FF&}}m 0 0 l 1848 0 1848 5 0 5{{\p0}}'))
    for i, chapter in enumerate(timeline['chapters']):
        row, col, cols = (0, i, 7) if i < 7 else (1, i - 7, 6)
        width = 1848 / cols
        x, y = round(36 + col * width), 930 + row * 68
        end_x = round(36 + (col + 1) * width)
        ass.append(box(21, chapter['start'], chapter['end'], x + 2, y, end_x - x - 4, 61, '5EB6FF', 'C4'))
        title = wrap(chapter['title'], 12)
        ass.append(event(22, 0, total, rf'{{\an5\pos({(x+end_x)//2},{y+30})\fs22\1c&HE1EAEE&}}{title}'))
        ass.append(event(23, chapter['start'], chapter['end'], rf'{{\an5\pos({(x+end_x)//2},{y+30})\fs22\1c&H5EB6FF&}}{title}'))
        if i:
            ass.append(event(18, chapter['start'], chapter['start'] + .45,
                             r'{\an7\move(-360,0,1920,0,0,450)\p1\1c&H5EB6FF&\1a&H40&}m 0 0 l 300 0 300 924 0 924{\p0}'))
        if i in (0, 12): continue
        for cue in chapter['diagram_cues']:
            a, b, diagram = cue['start'], cue['end'], cue['text']
            parts = [x.strip() for x in diagram.split('→') if x.strip()][:4]
            if len(parts) == 1:
                parts = [parts[0], '场景效果']
            ass.append(diagram_icon(i, a, b))
            width = min(500, 1660 // len(parts))
            origin = (1920 - len(parts) * width) // 2
            for k, part in enumerate(parts):
                x = origin + k * width
                reveal = a + k * .22
                ass.append(box(7, reveal, b, x, 806, width - 30, 46, '33444D', '10', r'\fad(250,120)'))
                ass.append(event(8, reveal, b, rf'{{\an5\pos({x+(width-30)//2},829)\fs22\fad(250,120)}}{wrap(part, 14)}'))
                if k < len(parts) - 1:
                    ass.append(event(8, reveal + .12, b, rf'{{\an5\pos({x+width-15},829)\fs28\1c&H5EB6FF&\fad(180,100)}}→'))
    for shot in timeline['shots']:
        a, b = shot['start_frame'] / FPS, (shot['start_frame'] + shot['frames']) / FPS
        if shot.get('single') == 'card': continue
        if 'single' in shot:
            name = label(shot['single'])
            top = 36 if shot['chapter'] == 0 else 19
            ass.append(box(10, a, b, 28, top, min(800, 30 + len(name) * 29), 42, '12100B', '30'))
            ass.append(event(11, a, b, rf'{{\an7\pos(42,{top+7})\fs27}}{name}'))
            if 'pip_scene' in shot:
                ass.append(box(10, a, b, 1414, 42, 460, 45, '12100B', '28'))
                ass.append(event(11, a, b, r'{\an7\pos(1425,48)\fs24}原版调试画面 · 分别实录'))
        else:
            for side, x in (('left', 42), ('right', 994)):
                name = label(shot[side], shot['scene'])
                ass.append(box(10, a, b, x - 10, 45, min(850, 24 + len(name) * 26), 42, '12100B', '28'))
                ass.append(event(11, a, b, rf'{{\an7\pos({x},50)\fs25}}{name}'))
            ass.append(event(11, a, b, r'{\an9\pos(1880,658)\fs22\1c&HC1B49E&}分别采集 · 非同步操作'))
    for caption in timeline['captions']:
        text = caption['text'].replace('{', '｛').replace('}', '｝').replace('\\', '＼')
        ass.append(event(30, caption['start'], caption['end'], rf'{{\an2\pos(960,910)}}{text}', 'Caption'))
    last = timeline['chapters'][-1]
    for i, word in enumerate(('点赞', '投币', '收藏')):
        ass.append(event(31, last['end'] - 3 + i * .15, last['end'] - .2,
                         rf'{{\an5\move({150+i*160},690,{150+i*160},670,0,300)\fad(150,150)\fs32\1c&H5EB6FF&}}● {word}'))
    (WORK / 'overlay.ass').write_text('\n'.join(ass) + '\n')
    srt = [f"{i}\n{srt_time(c['start'])} --> {srt_time(c['end'])}\n{c['text']}\n" for i, c in enumerate(timeline['captions'], 1)]
    (WORK / 'subtitles.srt').write_text('\n'.join(srt))


def encode_shot(index, shot):
    output = WORK / f'shot-{index:03d}.mp4'
    def checked():
        probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
            '-show_entries', 'stream=nb_frames,pix_fmt,color_range,color_space,color_transfer,color_primaries',
            '-of', 'json', str(output)]))['streams'][0]
        if (int(probe['nb_frames']), probe.get('pix_fmt'), probe.get('color_range'), probe.get('color_space'),
                probe.get('color_transfer'), probe.get('color_primaries')) != (shot['frames'], 'yuv420p', 'tv', 'bt709', 'iec61966-2-1', 'bt709'):
            raise RuntimeError(f'Shot {index} has unexpected frame count or color properties: {probe}')
        return output
    def normalized(width, height, kind):
        # Chrome's VP8 frame tags conflict with its container; captured PNGs support pc/709.
        if kind in ('original', 'original-frozen', 'card', 'ao_compare'):
            in_range, matrix, colorspace = 'pc', 'bt709', 'bt709'
        elif kind in ('builtin', 'sea', 'sky'):
            in_range, matrix, colorspace = 'pc', 'bt601', 'bt470bg'
        else:
            in_range, matrix, colorspace = 'tv', 'bt601', 'bt470bg'
        return (f'fps=60,setparams=range={in_range}:colorspace={colorspace},'
                f'scale={width}:{height}:in_range={in_range}:in_color_matrix={matrix}:out_range=pc,'
                'format=rgb24,setsar=1,setpts=PTS-STARTPTS,setparams=range=pc:colorspace=gbr')
    finish = ('scale=in_range=pc:out_range=tv:out_color_matrix=bt709,format=yuv420p,'
              'setparams=range=tv:colorspace=bt709:color_primaries=bt709:color_trc=iec61966-2-1')
    kinds = [shot['single']] if 'single' in shot else [shot['left'], shot['right']]
    if 'pip_scene' in shot:
        kinds.append('original')
    files = [shot_source(kind, shot.get('pip_scene') if i and 'pip_scene' in shot else shot.get('scene'))
             for i, kind in enumerate(kinds)]
    for path, _ in files:
        if not path.is_file(): raise SystemExit(f'Missing source footage: {path}')
    fingerprint = hashlib.sha256(json.dumps(shot, sort_keys=True).encode())
    fingerprint.update(Path(__file__).read_bytes())
    for path, _ in files:
        stat = path.stat()
        fingerprint.update(f'{path}:{stat.st_size}:{stat.st_mtime_ns}'.encode())
    signature = fingerprint.hexdigest()
    stamp = output.with_suffix('.sha256')
    if output.is_file() and stamp.is_file() and stamp.read_text() == signature:
        return checked()
    duration = shot['frames'] / FPS
    command = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-filter_complex_threads', '2']
    for path, start in files:
        if path.suffix == '.png': command += ['-loop', '1', '-framerate', '60']
        else: command += ['-ss', str(start)]
        command += ['-i', str(path)]
    if 'pip_scene' in shot:
        graph = (f'[0:v]{normalized(1920, 1080, kinds[0])}[main];[1:v]{normalized(448, 252, kinds[1])}[pip];'
                 f'[main][pip]overlay=1425:95:format=rgb:shortest=1,{finish}[out]')
    elif len(files) == 2:
        graph = (f'color=c=0x0b1012:s=1920x1080:r=60:d={duration},format=rgb24,setparams=range=pc:colorspace=gbr[bg];'
                 f'[0:v]{normalized(944, 531, kinds[0])}[left];[1:v]{normalized(944, 531, kinds[1])}[right];'
                 f'[bg][left]overlay=8:95:format=rgb:shortest=1[a];[a][right]overlay=968:95:format=rgb:shortest=1,{finish}[out]')
    elif shot['chapter'] in (0, 12):
        graph = f'[0:v]{normalized(1920, 1080, kinds[0])},{finish}[out]'
    elif shot.get('single') == 'ao_compare':
        graph = (f'color=c=0x0b1012:s=1920x1080:r=60:d={duration},format=rgb24,setparams=range=pc:colorspace=gbr[bg];'
                 f'[0:v]{normalized(1840, 498, kinds[0])}[picture];'
                 f'[bg][picture]overlay=40:105:format=rgb:shortest=1,{finish}[out]')
    else:
        graph = (f'color=c=0x0b1012:s=1920x1080:r=60:d={duration},format=rgb24,setparams=range=pc:colorspace=gbr[bg];'
                 f'[0:v]{normalized(1280, 720, kinds[0])}[picture];'
                 f'[bg][picture]overlay=320:72:format=rgb:shortest=1,{finish}[out]')
    command += ['-filter_complex', graph, '-map', '[out]', '-an', '-frames:v', str(shot['frames']),
                '-c:v', 'h264_nvenc', '-preset', 'p4', '-cq', '20', '-b:v', '0', '-g', '120', '-bf', '0',
                '-pix_fmt', 'yuv420p', '-color_range', 'tv', '-colorspace', 'bt709',
                '-color_primaries', 'bt709', '-color_trc', 'iec61966-2-1', '-r', '60', '-movflags', '+faststart', str(output)]
    run(command)
    checked()
    stamp.write_text(signature)
    return output


def make_audio(timeline):
    command = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-stream_loop', '-1', '-i', str(EDITOR / 'public/music/ambient.wav')]
    game_shots = [shot for shot in timeline['shots'] if shot.get('single', '').startswith('game')]
    for shot in game_shots:
        path, offset = shot_source(shot['single'])
        command += ['-ss', str(offset), '-i', str(path)]
    for voice in timeline['narration']: command += ['-i', voice['src']]
    filters = ['[0:a]aformat=sample_rates=48000:channel_layouts=stereo,volume=0.10[bed]']
    inputs = ['[bed]']
    for i, shot in enumerate(game_shots, 1):
        duration, delay = shot['frames'] / FPS, round(shot['start_frame'] * 1000 / FPS)
        filters.append(f'[{i}:a]atrim=duration={duration},asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo,volume=0.05,afade=t=in:d=0.15,afade=t=out:st={max(0, duration-.15)}:d=0.15,adelay={delay}:all=1[g{i}]')
        inputs.append(f'[g{i}]')
    for i, voice in enumerate(timeline['narration'], 1 + len(game_shots)):
        delay = round(voice['start'] * 1000)
        filters.append(f'[{i}:a]aformat=sample_rates=48000:channel_layouts=stereo,adelay={delay}:all=1[v{i}]')
        inputs.append(f'[v{i}]')
    filters.append(''.join(inputs) + f'amix=inputs={len(inputs)}:duration=first:normalize=0,alimiter=limit=0.95[out]')
    command += ['-filter_complex', ';'.join(filters), '-map', '[out]', '-t', str(timeline['frames'] / FPS),
                '-c:a', 'aac', '-b:a', '192k', str(WORK / 'mix.m4a')]
    run(command)


def write_storyboard(timeline, draft=False):
    timing = '预估时间线' if draft else '实际时间线'
    lines = ['# Saltline 复刻视频：执行分镜与旁白', '',
             f"版本 {VERSION}，{timing} {timeline['frames']/FPS:.1f} 秒，1920×1080、60 fps。调试场景分别采集，画面标注来源、固定步进和非同步操作；正式游戏画面不做原版并排对比。", '',
             '原版许多模型按程序参数组合，很多基础贴图由 GPU 生成缓存；复刻使用导出资产重建，动态天空、海面、湿润和动作仍由程序计算。官方 Godot 对照中的灯光、天空和部分动态为近似，不能把差异全部归因于材质。', '',
             '字幕去标点并以空格分隔；透明底色的纯色 MG 展示原理，底栏两行展示全部章节并高亮当前章节。原游戏音量不变，仅在成片中压低。末尾仅用简短三连动画。', '']
    for ci, (source, actual) in enumerate(zip(PLAN['chapters'], timeline['chapters'])):
        start, end = round(actual['start']), round(actual['end'])
        diagrams = '；'.join(source['diagrams']) if ci not in (0, 12) else (
            '片头保留画中画与章节栏' if ci == 0 else '片尾简短展示点赞 投币 收藏')
        lines += [f"## {start//60:02d}:{start%60:02d}–{end//60:02d}:{end%60:02d}｜{source['title']}", '',
                  '**画面：** ' + '；'.join(source['shots']) + '。', '', '**MG：** ' + diagrams + '。', '']
        if not draft:
            groups = []
            for shot in (s for s in timeline['shots'] if s['chapter'] == ci):
                if 'single' in shot:
                    description = label(shot['single'])
                    if 'pip_scene' in shot: description += ' + 原版调试画面画中画'
                else:
                    description = shot['scene'] + '：' + label(shot['left'], shot['scene']) + ' / ' + label(shot['right'], shot['scene'])
                first, last = shot['start_frame'], shot['start_frame'] + shot['frames']
                if groups and groups[-1][2] == description and groups[-1][1] == first:
                    groups[-1] = (groups[-1][0], last, description)
                else:
                    groups.append((first, last, description))
            def stamp(frame):
                seconds = frame / FPS
                return f'{int(seconds//60):02d}:{seconds%60:05.2f}'
            lines += ['**实际镜头：**', '']
            lines += [f'- {stamp(first)}–{stamp(last)} {description}' for first, last, description in groups]
            lines.append('')
        lines += ['**旁白：**', '']
        for voice in source['narration']: lines += ['> ' + voice['text'], '>']
        lines.append('')
    (ROOT / f'video/storyboard-v{VERSION}.md').write_text('\n'.join(lines))


def main():
    parser = argparse.ArgumentParser()
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--prepare-only', action='store_true')
    modes.add_argument('--storyboard-only', action='store_true')
    modes.add_argument('--finalize-only', action='store_true')
    args = parser.parse_args()
    if args.storyboard_only:
        chapters = [{'start': item['start'], 'end': item['start'] + item['duration']} for item in PLAN['chapters']]
        write_storyboard({'chapters': chapters, 'frames': round(chapters[-1]['end'] * FPS)}, draft=True)
        print(f'Prepared storyboard v{VERSION} with estimated timing')
        return
    WORK.mkdir(exist_ok=True)
    timeline = make_timeline()
    prepare_graphics(timeline)
    write_storyboard(timeline)
    print(f"Prepared {len(timeline['shots'])} shots, {len(timeline['narration'])} narration clips and {timeline['frames']/FPS:.1f}s", flush=True)
    if args.prepare_only: return
    result = WORK / 'final.mp4'
    if not args.finalize_only:
        parts = []
        for index, shot in enumerate(timeline['shots']):
            parts.append(encode_shot(index, shot))
            if index % 5 == 0: print(f'Shots {index+1}/{len(timeline["shots"])}', flush=True)
        listing = WORK / 'shots.ffconcat'
        listing.write_text('ffconcat version 1.0\n' + ''.join("file '" + str(path).replace("'", "'\\''") + "'\n" for path in parts))
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', listing,
             '-c', 'copy', '-an', str(WORK / 'picture.mp4')])
        make_audio(timeline)
        (WORK / 'final-input.sha256').write_text(render_input_signature())
        print('Rendering chapter bar, diagrams, subtitles and audio', flush=True)
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', WORK / 'picture.mp4', '-i', WORK / 'mix.m4a',
             '-vf', f'ass=.render-v{VERSION}/overlay.ass', '-map', '0:v:0', '-map', '1:a:0', '-frames:v', str(timeline['frames']),
             '-c:v', 'h264_nvenc', '-preset', 'p4', '-cq', '20', '-b:v', '0', '-g', '120', '-bf', '0', '-pix_fmt', 'yuv420p',
             '-color_range', 'tv', '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'iec61966-2-1',
             '-r', '60', '-c:a', 'copy', '-movflags', '+faststart', result])
    else:
        signature = WORK / 'final-input.sha256'
        if not signature.is_file() or signature.read_text() != render_input_signature():
            raise RuntimeError('Cannot finalize: render inputs changed or their signature is missing')
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries',
                       'stream=codec_type,codec_name,width,height,nb_frames,r_frame_rate,pix_fmt,color_range,color_space,color_transfer,color_primaries,sample_rate,channels,duration', '-of', 'json', str(result)]))
    video = next(stream for stream in probe['streams'] if stream['codec_type'] == 'video')
    if (video['width'], video['height'], video['r_frame_rate'], int(video['nb_frames']), video.get('pix_fmt'),
        video.get('color_range'), video.get('color_space'), video.get('color_transfer'), video.get('color_primaries')) != (
            1920, 1080, '60/1', timeline['frames'], 'yuv420p', 'tv', 'bt709', 'iec61966-2-1', 'bt709'):
        raise RuntimeError('Final video frame count, format or color properties differ from the timeline')
    audio = next((stream for stream in probe['streams'] if stream['codec_type'] == 'audio'), None)
    if (not audio or audio.get('codec_name') != 'aac' or audio.get('sample_rate') != '48000' or audio.get('channels') != 2
            or abs(float(audio.get('duration', 0)) - timeline['frames'] / FPS) > .05):
        raise RuntimeError('Final audio format or duration differs from the timeline')
    archive = ROOT / 'video/archive'
    archive.mkdir(exist_ok=True)
    final = ROOT / 'video/final.mp4'
    current_subtitles = ROOT / 'video/subtitles.srt'
    revision = 1
    while True:
        suffix = '' if revision == 1 else f'-revision-{revision:02d}'
        previous = archive / f'previous-cut-before-v{VERSION}{suffix}.mp4'
        old_subtitles = archive / f'previous-cut-before-v{VERSION}{suffix}.srt'
        if not previous.exists() and not old_subtitles.exists(): break
        if (final.exists() and previous.exists() and os.path.samefile(final, previous)
                and (not current_subtitles.exists() or not old_subtitles.exists()
                     or old_subtitles.read_bytes() == current_subtitles.read_bytes())): break
        revision += 1
    if final.exists():
        if not previous.exists(): os.link(final, previous)
    if current_subtitles.exists():
        if not old_subtitles.exists(): shutil.copy2(current_subtitles, old_subtitles)
    os.replace(result, final)
    shutil.copy2(WORK / 'subtitles.srt', ROOT / 'video/subtitles.srt')
    print('Finished:', final, flush=True)


if __name__ == '__main__': main()
