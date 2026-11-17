#!/usr/bin/env python3
"""Place approved AW delivery WAVs on the film timeline without copying voice references."""
import json
import re
import subprocess
import sys
from pathlib import Path

editor = Path(__file__).resolve().parent.parent
private_project = Path(sys.argv[1]).resolve()
jobs = json.loads((private_project / "narration-jobs.json").read_text())
starts = [
    0, 12, 32, 45, 58, 77, 95, 112, 122, 133, 155, 184, 207,
    225, 240, 258, 290, 317, 344, 355, 368, 403, 415, 430, 458,
    470, 488, 503, 525, 540, 555, 570, 585, 602, 620,
]
if len(jobs) != len(starts):
    raise SystemExit("Narration job count does not match the approved timeline")
target = editor / "public/private-voice"
target.mkdir(parents=True, exist_ok=True, mode=0o700)
media_path = editor / "src/media.json"
media = json.loads(media_path.read_text())
media["narration"], media["captions"] = [], []
for index, (job, start) in enumerate(zip(jobs, starts)):
    source = private_project / job["completed_output"] / "steps/delivery/attempt-001/delivery.wav"
    duration = float(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", str(source),
    ]))
    if index + 1 < len(starts) and start + duration > starts[index + 1]:
        raise SystemExit(f"Narration {job['id']} overlaps the next clip")
    end = start + duration
    name = job["id"] + ".wav"
    subprocess.run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
        "-af", "volume=2", str(target / name),
    ], check=True)
    (target / name).chmod(0o600)
    media["narration"].append({"id": job["id"], "start": start, "end": end, "src": "private-voice/" + name})
    phrases = [part for part in re.findall(r"[^，。；：！？]+[，。；：！？]?", job["text"]) if part.strip()]
    weights = [len(re.sub(r"\s+", "", part)) for part in phrases]
    at = start
    for part, weight in zip(phrases, weights):
        next_at = at + duration * weight / sum(weights)
        media["captions"].append({"start": round(at, 3), "end": round(next_at, 3), "text": part.strip()})
        at = next_at
media_path.write_text(json.dumps(media, ensure_ascii=False, indent=2) + "\n")
print(f"Prepared {len(jobs)} voice clips and {len(media['captions'])} captions; references remain private.")
