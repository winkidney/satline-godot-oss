#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,re
study=Path(__file__).resolve().parents[2]/"artifact-rendering-study"
out=study/"output/playwright";out.mkdir(parents=True,exist_ok=True)
source=study/"source/extracted/bundle-1.js";original=study/"source/saltline.original.html";text=source.read_text()
for before,after in [("      metalRects: i,","      metalRects: (window.__groundMetalRects=i),"),("      isMetal: k,","      isMetal: (window.__groundMetalAt=k),")]:
 assert text.count(before)==1,before
 text=text.replace(before,after)
(out/"ground-instrumented.js").write_text(text)
html=original.read_text();scripts=list(re.finditer(r"<script([^>]*)>([\s\S]*?)</script>",html));assert len(scripts)==2
part=scripts[1];html=html[:part.start()]+'<script src="/output/playwright/ground-instrumented.js"></script>'+html[part.end():]
(out/"ground-instrumented.html").write_text(html)
manifest={"source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"original_html_sha256":hashlib.sha256(original.read_bytes()).hexdigest(),"instrumented_sha256":hashlib.sha256(text.encode()).hexdigest(),"changes":["Expose original uw metalRects array by reference at object return","Expose original uw isMetal function by reference at object return"],"no_simulation_changes_intended":True}
(out/"ground-instrumentation.json").write_text(json.dumps(manifest,indent=2));print(json.dumps(manifest))
