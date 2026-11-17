#!/usr/bin/env python3
"""Make review sheets from the three separately recorded showcase versions."""
import io
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2]
out = root / 'video/review/comparisons'
out.mkdir(parents=True, exist_ok=True)
font_path = subprocess.check_output(['fc-match', '-f', '%{file}', 'Noto Sans CJK SC'], text=True).strip()
font = ImageFont.truetype(font_path, 26)
small = ImageFont.truetype(font_path, 20)
scenes = ['mats', 'props', 'render', 'ground', 'level', 'backdrop', 'enemies', 'weapon', 'hands', 'fx']
for page in range(2):
    sheet = Image.new('RGB', (1920, 2060), '#10171b')
    draw = ImageDraw.Draw(sheet)
    for column, title in enumerate(('原版 HTML', 'Godot 定制复刻', '官方 Godot 内建 · 调校后')):
        draw.text((column * 640 + 20, 10), title, font=font, fill='#f2ebe0')
    for row, scene in enumerate(scenes[page * 5:page * 5 + 5]):
        y = 50 + row * 400
        for column, kind in enumerate(('original', 'replica', 'builtin-calibrated')):
            suffix = '.webm' if kind == 'original' else '.mp4'
            source = root / 'video/recordings/showcases' / kind / (scene + suffix)
            input_range, matrix, space = {'original': ('pc', 'bt709', 'bt709'),
                                          'replica': ('tv', 'bt601', 'bt470bg'),
                                          'builtin-calibrated': ('pc', 'bt601', 'bt470bg')}[kind]
            graph = (f'setparams=range={input_range}:colorspace={space},'
                     f'scale=640:360:in_range={input_range}:in_color_matrix={matrix}:out_range=pc,format=rgb24')
            data = subprocess.check_output(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-ss', '3', '-i', str(source),
                                            '-frames:v', '1', '-vf', graph, '-f', 'image2pipe', '-vcodec', 'png', '-'])
            image = Image.open(io.BytesIO(data)).convert('RGB')
            sheet.paste(image, (column * 640, y))
        draw.text((18, y + 365), scene + '  ·  分别录制 非同步  ·  官方版本固定步进', font=small, fill='#ccd5d8')
    sheet.save(out / f'showcases-{page+1:02d}.webp', quality=88, method=5)
print('Created two review sheets covering all ten recorded showcases.')
