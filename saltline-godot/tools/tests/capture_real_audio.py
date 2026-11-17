#!/usr/bin/env python3
"""Check the real audio backend through a private PulseAudio monitor sink."""
import os
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

root = Path(__file__).resolve().parents[2]
output = Path(sys.argv[1]).resolve()
output.parent.mkdir(parents=True, exist_ok=True)
sink = f"satline_audio_test_{os.getpid()}"
module = subprocess.check_output(["pactl", "load-module", "module-null-sink", f"sink_name={sink}"]).decode().strip()
recorder = None
try:
    recorder = subprocess.Popen([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "pulse",
        "-i", f"{sink}.monitor", "-ac", "2", "-ar", "48000", str(output),
    ], stdin=subprocess.DEVNULL)
    time.sleep(0.8)
    with tempfile.TemporaryDirectory(prefix="satline-audio-test-") as config:
        env = dict(os.environ, PULSE_SINK=sink, XDG_CONFIG_HOME=config, XDG_DATA_HOME=config)
        subprocess.run([
            str(root / "engine/godot"), "--display-driver", "headless", "--audio-driver", "PulseAudio",
            "--path", str(root), "--script", "res://tools/tests/verify_real_audio.gd",
        ], env=env, check=True, timeout=45)
    time.sleep(0.5)
finally:
    if recorder and recorder.poll() is None:
        recorder.send_signal(signal.SIGINT)
        recorder.wait(timeout=10)
    subprocess.run(["pactl", "unload-module", module], check=True)
if not output.is_file() or output.stat().st_size < 10000:
    raise SystemExit("Audio recording was not created")
subprocess.run([
    "ffmpeg", "-hide_banner", "-i", str(output), "-af", "volumedetect", "-f", "null", "-",
], check=True)
