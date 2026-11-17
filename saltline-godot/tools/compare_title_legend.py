"""Measure the isolated browser/native legend crops; no parity pass threshold."""
import json
from pathlib import Path
from PIL import Image, ImageChops

evidence = Path(__file__).resolve().parent.parent / "evidence"
crop = (528, 527, 1223, 645)
source = Image.open(evidence / "title-legend-source.png").convert("RGB").crop(crop)
native = Image.open(evidence / "title-legend-native.png").convert("RGB").crop(crop)
pixels = list(ImageChops.difference(source, native).get_flattened_data())
report = {
    "scope": "Aligned 695x118 crop on equal ink background; diagnostic difference, not an acceptance threshold or full title parity.",
    "mean_absolute_rgb_0_255": sum(sum(v) for v in pixels) / (len(pixels) * 3),
    "pixels_max_channel_over_16": sum(max(v) > 16 for v in pixels) / len(pixels),
    "maximum_channel_difference": max(max(v) for v in pixels),
}
combined = Image.new("RGB", (source.width, source.height * 2 + 8), (30, 30, 30))
combined.paste(source, (0, 0))
combined.paste(native, (0, source.height + 8))
combined.save(evidence / "title-legend-comparison.png")
(evidence / "title-legend-difference.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report))
