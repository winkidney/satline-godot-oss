"""Diagnostic on/off comparison; this does not establish source pixel parity."""
import json
from pathlib import Path
from PIL import Image, ImageChops

evidence = Path(__file__).resolve().parent.parent / "evidence"
on = Image.open(evidence / "fire-light-on.png").convert("RGB")
off = Image.open(evidence / "fire-light-off.png").convert("RGB")
regions = {"full": (0, 0, 1280, 720), "container": (300, 250, 850, 570), "weapon": (680, 430, 1100, 700), "ground": (0, 580, 700, 720)}
rows = {}
for name, box in regions.items():
    differences = list(ImageChops.difference(on.crop(box), off.crop(box)).get_flattened_data())
    rows[name] = {
        "mean_absolute_rgb_0_255": sum(sum(v) for v in differences) / (len(differences) * 3),
        "pixels_max_channel_over_3": sum(max(v) > 3 for v in differences),
        "pixels": len(differences),
    }
report = {"scope": "Actual native persistent fire light on/off with FX simulation and world dt frozen; diagnostic image changes, not a browser parity or exact light-isolation gate.", "regions": rows}
(evidence / "fire-light-difference.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report))
