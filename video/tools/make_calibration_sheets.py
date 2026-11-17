#!/usr/bin/env python3
"""Prepare review sheets from the actual source and calibrated default renders."""
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2]
review = root / 'video/review/calibration'
scenes = ['mats', 'props', 'render', 'ground', 'level', 'backdrop', 'enemies', 'weapon', 'hands', 'fx']
font_path = subprocess.check_output(['fc-match', '-f', '%{file}', 'Noto Sans CJK SC'], text=True).strip()
title = ImageFont.truetype(font_path, 24)
label = ImageFont.truetype(font_path, 19)
for page in range(2):
    sheet = Image.new('RGB', (1280, 2010), '#11191f')
    draw = ImageDraw.Draw(sheet)
    draw.text((18, 10), '原版 HTML · 原始程序材质', fill='#f4eee3', font=title)
    draw.text((658, 10), 'Godot 内建 · 调校后', fill='#f4eee3', font=title)
    for row, scene in enumerate(scenes[page * 5:page * 5 + 5]):
        y = 45 + row * 390
        for column, kind in enumerate(('source', 'final-calibrated')):
            with Image.open(review / kind / (scene + '.png')) as image:
                sheet.paste(image.convert('RGB').resize((640, 360), Image.Resampling.LANCZOS), (column * 640, y))
        draw.text((18, y + 365), scene + '  ·  分别实录  状态与时间可能不同', fill='#d3d9db', font=label)
    sheet.save(review / ('comparison-%02d.webp' % (page + 1)), quality=90, method=5)
print('Created two calibrated comparison sheets.')
