#!/usr/bin/env python3
"""Record calibrated stock-Godot showcases at 1080p using its fixed-step movie writer."""
import argparse
import json
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

SCENES = ('mats', 'props', 'render', 'ground', 'level', 'backdrop', 'enemies', 'weapon', 'hands', 'fx')
parser = argparse.ArgumentParser()
parser.add_argument('scene', choices=('all', *SCENES))
parser.add_argument('--seconds', type=float, default=8)
args = parser.parse_args()
if not 1 <= args.seconds <= 30 or not os.environ.get('DISPLAY'):
    parser.error('Use an isolated display and a duration between 1 and 30 seconds')
root = Path(__file__).resolve().parents[2]
godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
if not godot:
    parser.error('Set GODOT_BIN or put Godot on PATH')
output = root / 'video/recordings/showcases/builtin-calibrated'
output.mkdir(parents=True, exist_ok=True)
selected = SCENES if args.scene == 'all' else (args.scene,)
for scene in selected:
    for suffix in ('.mp4', '.json', '.engine.json', '.runtime.log'):
        if (output / (scene + suffix)).exists():
            raise FileExistsError(f'Archive existing recording before recapturing: {scene + suffix}')
environment = dict(os.environ, XDG_CONFIG_HOME='/tmp/saltline-godot-config',
                   XDG_DATA_HOME='/tmp/saltline-godot-data', XDG_CACHE_HOME='/tmp/saltline-godot-cache')

with tempfile.TemporaryDirectory(prefix='saltline-movie-') as temporary:
    scratch = Path(temporary)
    project = scratch / 'builtin-godot'
    project.mkdir()
    (scratch / 'saltline-godot').symlink_to(root / 'saltline-godot', target_is_directory=True)
    source = root / 'builtin-godot'
    for item in source.iterdir():
        if item.name not in ('.godot', 'project.godot'):
            (project / item.name).symlink_to(item, target_is_directory=item.is_dir())
    config = (source / 'project.godot').read_text()
    if 'viewport_width=1280' not in config or 'viewport_height=720' not in config:
        raise RuntimeError('Unexpected comparison project viewport')
    (project / 'project.godot').write_text(config.replace('viewport_width=1280', 'viewport_width=1920')
                                            .replace('viewport_height=720', 'viewport_height=1080'))
    for scene in selected:
        movie, engine_report = scratch / (scene + '.avi'), scratch / (scene + '-engine.json')
        frames = round((args.seconds + 1) * 60)
        command = [godot, '--audio-driver', 'Dummy', '--display-driver', 'x11', '--rendering-driver', 'vulkan',
                   '--disable-vsync', '--fixed-fps', '60', '--write-movie', str(movie), '--path', str(project), '--',
                   '--scene=' + scene, '--frames=' + str(frames), '--report=' + str(engine_report)]
        log = output / (scene + '.runtime.log')
        started = time.monotonic()
        with log.open('w') as stream:
            subprocess.run(command, env=environment, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=600)
        elapsed = time.monotonic() - started
        text, report = log.read_text(errors='replace'), json.loads(engine_report.read_text())
        if 'SCRIPT ERROR' in text or '\nERROR:' in text or report['warnings']:
            raise RuntimeError(scene + ': engine reported an error')
        log.write_text(text.replace(str(scratch), '<temporary>'))
        temporary_output = scratch / (scene + '.mp4')
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-ss', '1', '-i', str(movie),
                        '-map', '0:v:0', '-an', '-frames:v', str(round(args.seconds * 60)),
                        '-c:v', 'h264_nvenc', '-preset', 'p4', '-cq', '20', '-b:v', '0', '-pix_fmt', 'yuv420p',
                        '-r', '60', '-movflags', '+faststart', str(temporary_output)], check=True)
        probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
            '-show_entries', 'stream=width,height,r_frame_rate,nb_frames', '-of', 'json', str(temporary_output)]))['streams'][0]
        expected = (1920, 1080, '60/1', round(args.seconds * 60))
        actual = (probe['width'], probe['height'], probe['r_frame_rate'], int(probe['nb_frames']))
        if actual != expected:
            raise RuntimeError(f'{scene}: unexpected recording {actual}')
        with tempfile.NamedTemporaryFile(prefix='.' + scene + '-', suffix='.tmp', dir=output, delete=False) as stream:
            staged = Path(stream.name)
        try:
            shutil.copyfile(temporary_output, staged)
            os.replace(staged, output / (scene + '.mp4'))
        finally:
            if staged.exists():
                staged.unlink()
        (output / (scene + '.engine.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        (output / (scene + '.json')).write_text(json.dumps({'scene': scene, 'method': 'Godot fixed-step movie writer',
            'simulation_fps': 60, 'resolution': [1920, 1080], 'frames': actual[3], 'seconds': args.seconds,
            'wall_seconds': round(elapsed, 2), 'render_speed': round((args.seconds + 1) / elapsed, 3),
            'note': 'Rendered frame by frame on the GPU, then encoded; not realtime playback.'}, indent=2) + '\n')
        movie.unlink()
        print(scene, actual[3], 'frames, wall seconds', round(elapsed, 1), flush=True)
