#!/usr/bin/env python3
"""Record approved, real-time browser shots through an existing Playwright CLI session."""
import json
import re
import subprocess
import sys
from pathlib import Path

if len(sys.argv) != 3:
    raise SystemExit("Usage: record_original.py PLAYWRIGHT_CLI_JS SHOT_PLAN_JSON")
cli, plan = map(Path, sys.argv[1:])
root = Path(__file__).resolve().parents[2]
source = Path(__file__).with_suffix('.js').read_text()
shots = json.loads(plan.read_text())
destination = root / 'video/recordings/original'
destination.mkdir(parents=True, exist_ok=True)
for shot in shots:
    shot['output'] = str(destination / (shot['name'] + '.webm'))
    code = source.replace('__CAPTURE_SPEC__', json.dumps(shot, ensure_ascii=False))
    result = subprocess.run(['node', str(cli), '-s=saltline-record', 'run-code', code],
                            cwd=root, capture_output=True, text=True, timeout=shot['duration'] + 90)
    match = re.search(r'### Result\n(\{[^\n]*\})', result.stdout)
    if result.returncode or not match:
        raise SystemExit(f"Recording {shot['name']} failed: {result.stderr[-500:]} {result.stdout[-500:]}")
    report = json.loads(match.group(1))
    (destination / (shot['name'] + '.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    if report['fatal'] or report['errors']:
        raise SystemExit(f"Game reported an error while recording {shot['name']}")
    print(f"{shot['name']}: {report['frames']/report['seconds']:.1f} rendered fps", flush=True)
