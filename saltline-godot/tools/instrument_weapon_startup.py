#!/usr/bin/env python3
"""Create a local observation-only original-game bootstrap; never overwrite source."""
from pathlib import Path
import hashlib
import json
import re
study = Path(__file__).resolve().parents[2] / "artifact-rendering-study"
out = study / "output/playwright"
out.mkdir(parents=True, exist_ok=True)
source = study / "source/extracted/bundle-1.js"
original_html = study / "source/saltline.original.html"
s = source.read_text()
a = s.index("  function su(n = 1337) {")
b = s.index("  var Hn = ", a)
rng = s[a:b]
rng = rng.replace("function su(n = 1337)", "function su(n = 1337, parent = null)")
rng = rng.replace("let e = n >>> 0,", "let records=window.__rngTrace||(window.__rngTrace=[]), record={id:records.length,parent,seed:n>>>0,state:n>>>0,calls:0};records.push(record);let e = n >>> 0,")
rng = rng.replace("(e |= 0),", "(record.calls++), (e |= 0),")
rng = rng.replace("(e = (e + 1831565813) | 0);", "(e = (e + 1831565813) | 0); record.state=e>>>0;")
rng = rng.replace("su(Math.floor(t() * 4294967296))", "su(Math.floor(t() * 4294967296),record.id)")
rng = rng.replace("      t\n    );", "      (t.__trace=()=>({...record})), t\n    );")
s = s[:a] + rng + s[b:]
a = s.index("  async function I5(n)")
before, weapon = s[:a], s[a:]
weapon = weapon.replace("    let r = n.rng && n.rng.fork ? n.rng.fork() : Math.random,", "    window.__weaponParent = n.rng.__trace();\n    let r = n.rng && n.rng.fork ? n.rng.fork() : Math.random,", 1)
a = weapon.index("    n.events &&")
weapon = weapon[:a] + "    window.__weaponConstruct=structuredClone(a);window.__weaponRng=r;\n" + weapon[a:]
b = weapon.index("    return E;\n  }")
weapon = weapon[:b] + "    window.__weaponBoot={state:structuredClone(a),rng:r.__trace(),parent:n.rng.__trace()};\n" + weapon[b:]
s = before + weapon
(out / "startup-instrumented.js").write_text(s)
html = original_html.read_text()
matches = list(re.finditer(r"<script([^>]*)>([\s\S]*?)</script>", html))
assert len(matches) == 2
m = matches[1]
html = html[:m.start()] + '<script src="/output/playwright/startup-instrumented.js"></script>' + html[m.end():]
(out / "startup-instrumented.html").write_text(html)
manifest = {"source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "original_html_sha256": hashlib.sha256(original_html.read_bytes()).hexdigest(), "instrumented_sha256": hashlib.sha256(s.encode()).hexdigest(), "changes": ["su metadata counters and parent id; same arithmetic/fork call", "weapon parent state before fork", "raw S before constructor events", "S and RNG just before I5 return"], "no_simulation_changes_intended": True}
(out / "startup-instrumentation.json").write_text(json.dumps(manifest, indent=2))
print(json.dumps(manifest))
