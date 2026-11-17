#!/usr/bin/env python3
"""Generate an isolated page using the unchanged source stylesheet."""
from pathlib import Path
import re

study = Path(__file__).resolve().parents[2] / "artifact-rendering-study"
source = (study / "source/saltline.original.html").read_text()
css = re.search(r"<style>(.*?)</style>", source, re.S).group(1)
output = study / "output/playwright/location-css-reference.html"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(
    "<!DOCTYPE html><style>" + css + "</style>"
    '<div id="app"><div class="loc-card"><i></i>'
    "<b>Saltline Terminal · Berth 4 · 05:42</b>"
    "<span>Port Authority Breach Unit — one breacher, no backup</span>"
    "</div></div>"
)
print(output)
