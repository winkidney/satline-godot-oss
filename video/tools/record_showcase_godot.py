#!/usr/bin/env python3
"""Record each showcase in an isolated X display without changing source evidence."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get('GODOT_BIN') or shutil.which('godot')
CASES = {
    'mats': ('material_catalog_runner', ['--catalog=full', '--catalog-frames=20000']),
    'props': ('material_catalog_runner', ['--catalog=props', '--catalog-frames=20000']),
    'render': ('material_catalog_runner', ['--catalog=render', '--catalog-frames=20000']),
    'ground': ('material_catalog_runner', ['--catalog=ground', '--catalog-frames=20000']),
    'level': ('level_showcase_runner', ['--level-frames=20000']),
    'backdrop': ('level_showcase_runner', ['--showcase=backdrop', '--bshow=all', '--level-frames=20000']),
    'enemies': ('enemies_showcase_runner', ['--eshow=both', '--level-frames=20000']),
    'weapon': ('weapon_showcase_runner', ['--wgun=rifle', '--wpose=side', '--studio-frames=20000']),
    'hands': ('hands_showcase_runner', ['--hview=palm', '--hpose=open', '--studio-frames=20000']),
    'fx': ('fx_showcase_runner', ['--fx-mode=all', '--fx-frames=20000']),
}
LABS = ('pbr', 'diffuse', 'transparency')
if (len(sys.argv) not in (3, 4) or sys.argv[1] not in ('replica', 'builtin', 'lab')
        or sys.argv[2] not in (('all', *LABS) if sys.argv[1] == 'lab' else ('all', *CASES))):
    raise SystemExit('Usage: record_showcase_godot.py replica|builtin|lab SCENE|all [SECONDS]')
kind, selection = sys.argv[1:3]
seconds = float(sys.argv[3]) if len(sys.argv) == 4 else 12.0
if not 1 <= seconds <= 60 or not os.environ.get('DISPLAY'):
    raise SystemExit('Expected an isolated DISPLAY and duration between 1 and 60 seconds')
destination = ROOT / 'video/recordings/showcases' / kind
destination.mkdir(parents=True, exist_ok=True)


def prepare_replica(target):
    source = ROOT / 'saltline-godot'
    target.mkdir()
    shutil.copy2(source / 'project.godot', target)
    for name in ('scripts', 'scenes', 'shaders', 'tools', '.godot'):
        shutil.copytree(source / name, target / name, symlinks=True)
    (target / 'assets').symlink_to(source / 'assets', target_is_directory=True)
    (target / 'evidence').mkdir()
    # shortcut: marker instrumentation is applied to temporary copies only; source paths stay untouched.
    for runner in {v[0] for v in CASES.values()}:
        script = target / 'scripts' / (runner + '.gd')
        text = script.read_text()
        marker = ' if boot_loading!=null:await boot_loading.finish_showcase(game)'
        if text.count(marker) != 1:
            raise RuntimeError(f'Cannot locate ready marker in {runner}')
        text = text.replace(marker, marker + '\n print("SALTLINE_SHOWCASE_READY")')
        counter = 'frame' if runner in ('fx_showcase_runner', 'weapon_showcase_runner', 'hands_showcase_runner') else 'frames'
        needle = counter + '+=1'
        if text.count(needle) != 1:
            raise RuntimeError(f'Cannot locate frame counter in {runner}')
        text = text.replace(needle, needle + ';_film_count(' + counter + ')')
        if runner != 'enemies_showcase_runner':
            text += '\nfunc _film_count(n:int)->void:\n if n%30==0:print("SALTLINE_FRAME ",n," ",Time.get_ticks_msec())\n'
        script.write_text(text)


def record(scene, scratch):
    log_path = destination / (scene + '.runtime.log')
    ffmpeg_log = destination / (scene + '.ffmpeg.log')
    report_path = destination / (scene + '.engine.json')
    environment = dict(os.environ, XDG_CONFIG_HOME=str(scratch / 'config'),
                       XDG_DATA_HOME=str(scratch / 'data'), XDG_CACHE_HOME=str(scratch / 'cache'))
    common = ['--audio-driver', 'Dummy', '--display-driver', 'x11', '--rendering-driver', 'vulkan',
              '--fullscreen', '--resolution', '1920x1080', '--max-fps', '60']
    if kind in ('builtin', 'lab'):
        if not GODOT:
            raise RuntimeError('Set GODOT_BIN or put Godot on PATH')
        args = [GODOT, *common, '--path', str(ROOT / 'builtin-godot'), '--',
                '--scene=' + scene, '--seconds=' + str(seconds + 8), '--report=' + str(report_path)]
        marker = 'BUILTIN_READY'
        if kind == 'lab':
            args = [GODOT, *common, '--path', str(ROOT / 'builtin-godot'),
                    'pbr_lab.tscn', '--', '--mode=' + scene, '--seconds=' + str(seconds + 8), '--report=' + str(report_path)]
            marker = 'PBR_LAB_READY'
    else:
        runner, options = CASES[scene]
        args = [str(ROOT / 'saltline-godot/engine/godot'), *common, '--path', str(scratch / 'replica'),
                '--script', 'res://scripts/' + runner + '.gd', '--', '--game', *options]
        marker = 'SALTLINE_SHOWCASE_READY'
    player = recorder = None
    with log_path.open('w') as runtime, ffmpeg_log.open('w') as ff_log:
        try:
            player = subprocess.Popen(args, env=environment, stdout=runtime, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 180
            while marker not in log_path.read_text(errors='replace'):
                if player.poll() is not None:
                    raise RuntimeError(f'{scene}: Godot exited before ready; see {log_path.name}')
                if time.monotonic() > deadline:
                    raise TimeoutError(f'{scene}: Godot did not become ready')
                time.sleep(.25)
            time.sleep(1)
            started = time.monotonic()
            command = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-y', '-f', 'x11grab',
                       '-video_size', '1920x1080', '-framerate', '60', '-draw_mouse', '0', '-i', environment['DISPLAY'],
                       '-t', str(seconds), '-an', '-c:v', 'h264_nvenc', '-preset', 'p4', '-cq', '21', '-b:v', '0',
                       '-pix_fmt', 'yuv420p', '-r', '60', '-movflags', '+faststart', str(destination / (scene + '.mp4'))]
            recorder = subprocess.Popen(command, env=environment, stdout=ff_log, stderr=subprocess.STDOUT)
            if recorder.wait(timeout=seconds + 90) != 0 or player.poll() is not None:
                raise RuntimeError(f'{scene}: recording or engine failed; see logs')
            elapsed = time.monotonic() - started
            if kind in ('builtin', 'lab'):
                if player.wait(timeout=30) != 0 or not report_path.exists():
                    raise RuntimeError(f'{scene}: builtin engine report missing')
            log = log_path.read_text(errors='replace')
            if 'SCRIPT ERROR' in log or '\nERROR:' in log:
                raise RuntimeError(f'{scene}: engine errors; see log')
            ticks = [line.split()[-2:] for line in log.splitlines() if line.startswith('SALTLINE_FRAME ')]
            measured = None
            if len(ticks) > 1:
                frame_delta = int(ticks[-1][0]) - int(ticks[0][0])
                milliseconds = int(ticks[-1][1]) - int(ticks[0][1])
                measured = frame_delta * 1000 / milliseconds if milliseconds else None
            report = {'scene': scene, 'kind': kind, 'duration_requested': seconds, 'capture_wall_seconds': elapsed,
                      'simulation': 'fixed 1/60 step' if kind == 'replica' and scene in ('mats', 'props', 'render', 'ground', 'weapon', 'hands') else 'real-time',
                      'callback_fps_between_markers': measured,
                      'note': 'Separate captures; 60 fps encoded video does not guarantee 60 engine frames per second.'}
            (destination / (scene + '.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
            print(json.dumps(report, ensure_ascii=False), flush=True)
        finally:
            for process in (recorder, player):
                if process and process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()


with tempfile.TemporaryDirectory(prefix='saltline-showcase-') as temporary:
    scratch = Path(temporary)
    if kind == 'replica':
        prepare_replica(scratch / 'replica')
    for case in ((LABS if kind == 'lab' else CASES) if selection == 'all' else [selection]):
        record(case, scratch)
