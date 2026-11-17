#!/usr/bin/env python3
"""Reject invalid calibration files without starting a broken scene or hanging."""
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[2]
godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
assert godot, 'Set GODOT_BIN or put Godot on PATH'
env = dict(os.environ, XDG_CONFIG_HOME='/tmp/saltline-godot-config',
           XDG_DATA_HOME='/tmp/saltline-godot-data', XDG_CACHE_HOME='/tmp/saltline-godot-cache')
cases = [([], 'Calibration must be an object'), ({'unknown': 1}, 'Unknown calibration setting'),
         ({'sky_index': 0.5}, 'Expected source sky 0 or 1'), ({'arm_atlas': 0.5}, 'Expected a boolean'),
         ({'source_grade': 3}, 'Unknown color grade'), ({'exposure': -1}, 'must be positive')]
with tempfile.TemporaryDirectory(prefix='saltline-calibration-') as temporary:
    for index, (payload, expected) in enumerate(cases):
        config = Path(temporary) / (str(index) + '.json')
        config.write_text(json.dumps(payload))
        result = subprocess.run([godot, '--headless', '--path', str(root / 'builtin-godot'), '--',
                                 '--calibration=' + str(config)], env=env, text=True, capture_output=True, timeout=15)
        assert result.returncode != 0 and expected in result.stdout + result.stderr, (payload, result)
print('Invalid calibration settings are rejected without hanging')
