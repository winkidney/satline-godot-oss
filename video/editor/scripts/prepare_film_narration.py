#!/usr/bin/env python3
"""Reuse matching narration and create private AW jobs for the added script."""
import json
import os
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
import yaml

if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] != '--prepare-only'):
    raise SystemExit('Usage: prepare_film_narration.py PRIVATE_AW_PROJECT [--prepare-only]')
private = Path(sys.argv[1]).resolve()
editor = Path(__file__).resolve().parent.parent
plan = json.loads((editor / 'src/film-plan.json').read_text())
version = int(plan['version'])
old_jobs = {j['id']: j for j in json.loads((private / 'narration-jobs.json').read_text())}
for manifest in sorted(private.glob('film-v*-jobs.json')):
    for job in json.loads(manifest.read_text()):
        old_jobs[job['id']] = {'text': yaml.safe_load((private / job['input']).read_text())['text']}
reference = private / old_jobs['00-02']['input']
template = yaml.safe_load(reference.read_text())
assert template['mode'] == 'clone' and (private / 'audio-project.yaml').is_file()
os.umask(0o077)
new_jobs = []
for ci, chapter in enumerate(plan['chapters']):
    for vi, voice in enumerate(chapter['narration']):
        identifier = f'v{version}-{ci:02d}-{vi:02d}'
        if 'reuse' in voice:
            old = old_jobs[voice['reuse']]
            if old['text'] != voice['text'] or not (editor / 'public/private-voice' / (voice['reuse'] + '.wav')).is_file():
                raise SystemExit(f'Reused narration differs or is missing: {voice["reuse"]}')
            continue
        directory = private / f'art/inputs/audio/film-v{version}' / identifier
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        for filename in ('reference.wav', 'reference.txt', 'provenance.json'):
            destination = directory / filename
            source = reference.parent / filename
            if destination.exists() and destination.read_bytes() != source.read_bytes():
                raise SystemExit(f'Existing private reference differs: {identifier}')
            if not destination.exists():
                shutil.copyfile(source, destination)
                destination.chmod(0o600)
        recipe = dict(template, text=voice['text'])
        path = directory / 'recipe.yaml'
        content = yaml.safe_dump(recipe, allow_unicode=True, sort_keys=False)
        if path.exists() and path.read_text() != content:
            raise SystemExit(f'Existing private recipe differs: {identifier}')
        path.write_text(content)
        path.chmod(0o600)
        new_jobs.append({'id': identifier, 'text': voice['text'], 'input': str(path.relative_to(private)),
                         'output': f'art/derived/audio/film-v{version}/{identifier}'})
manifest = private / f'film-v{version}-jobs.json'
if manifest.is_file():
    previous = {job['id']: job for job in json.loads(manifest.read_text())}
    if set(previous) != {job['id'] for job in new_jobs}:
        raise SystemExit('Existing narration manifest differs; use a new film version')
    for job in new_jobs:
        old = previous[job['id']]
        if any(old.get(key, job[key]) != job[key] for key in ('text', 'input', 'output')):
            raise SystemExit(f'Existing narration job differs: {job["id"]}')
        if 'completed_output' in old:
            job['completed_output'] = old['completed_output']
manifest.write_text(json.dumps(new_jobs, ensure_ascii=False, indent=2) + '\n')
manifest.chmod(0o600)
print(f'Prepared {len(new_jobs)} private AW jobs; existing matching voice clips are reused.', flush=True)
if len(sys.argv) == 3:
    raise SystemExit(0)
for job in new_jobs:
    base = private / job['output']
    destination = base
    retry = 0
    while destination.exists() and not (destination / 'steps/delivery/attempt-001/delivery.wav').is_file():
        run_record = destination / 'run.json'
        if not run_record.is_file() or json.loads(run_record.read_text()).get('status') != 'failed':
            raise SystemExit(f'AW output has unknown or active state: {destination.name}')
        retry += 1
        destination = base.with_name(f'{base.name}-retry-{retry:02d}')
    delivery = destination / 'steps/delivery/attempt-001/delivery.wav'
    if not delivery.is_file():
        log = private / (destination.name + '.log')
        command = ['aw', '--project', str(private), '--project-config', 'audio-project.yaml', 'workflow', 'run',
                   'audio.tts', '--input', job['input'], '--output', str(destination.relative_to(private)), '--json']
        with log.open('x') as output:
            if subprocess.run(command, stdout=output, stderr=subprocess.STDOUT).returncode:
                raise SystemExit(f'AW synthesis failed for {job["id"]}; inspect its private log')
        if not delivery.is_file():
            raise SystemExit(f'AW did not produce delivery for {job["id"]}')
    target = editor / 'public/private-voice' / (job['id'] + '.wav')
    if not target.exists():
        with wave.open(str(delivery), 'rb') as audio:
            if (audio.getframerate(), audio.getnchannels(), audio.getsampwidth()) != (48000, 1, 2):
                raise SystemExit(f'Unexpected AW delivery format: {job["id"]}')
            samples = np.frombuffer(audio.readframes(audio.getnframes()), dtype='<i2').astype(np.int32)
        peak = float(np.max(np.abs(samples))) / 32768 if samples.size else 0
        if peak <= 0:
            raise SystemExit(f'AW delivery is empty or silent: {job["id"]}')
        gain = min(2.0, 0.89 / peak)
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(delivery),
                        '-af', f'volume={gain:.6f}', str(target)], check=True)
        target.chmod(0o600)
        target.with_suffix('.json').write_text(json.dumps({'source_peak': peak, 'gain': gain}, indent=2) + '\n')
        target.with_suffix('.json').chmod(0o600)
    job['completed_output'] = str(destination.relative_to(private))
    manifest.write_text(json.dumps(new_jobs, ensure_ascii=False, indent=2) + '\n')
    manifest.chmod(0o600)
    print(f'Completed {job["id"]}', flush=True)
