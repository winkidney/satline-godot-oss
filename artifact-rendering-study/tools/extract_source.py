#!/usr/bin/env python3
"""Extract this supplied HTML as text. Never execute the application or fetch URLs."""
import argparse
import base64
import hashlib
import json
from html.parser import HTMLParser
from pathlib import Path


class Inventory(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.scripts = []
        self.external = []
        self.current = None

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag == "script":
            self.current = {"attributes": attrs, "html_line": self.getpos()[0], "text": ""}
        for key in ("src", "href"):
            if key in attrs:
                self.external.append({"tag": tag, "attribute": key, "url": attrs[key]})

    def handle_data(self, data):
        if self.current is not None:
            self.current["text"] += data

    def handle_endtag(self, tag):
        if tag == "script" and self.current is not None:
            self.scripts.append(self.current)
            self.current = None


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("html", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    raw = args.html.read_bytes()
    inventory = Inventory()
    inventory.feed(raw.decode("utf-8"))
    args.out.mkdir(parents=True, exist_ok=True)
    records = []
    for index, script in enumerate(inventory.scripts):
        attrs = script["attributes"]
        content = script.pop("text").encode("utf-8")
        if attrs.get("id") == "legacy-v8" and attrs.get("type") == "application/octet-stream":
            content = base64.b64decode(b"".join(content.split()), validate=True)
            filename = "legacy-v8.html"
            role = "embedded legacy HTML; menu may switch to it; not initial executable script"
        else:
            filename = f"bundle-{index}.raw.js"
            role = "executable script" if attrs.get("type", "") in ("", "module", "text/javascript") else "data script"
        (args.out / filename).write_bytes(content)
        records.append({**script, "file": filename, "role": role, "bytes": len(content), "sha256": digest(content)})
    manifest = {
        "input": args.html.name,
        "input_bytes": len(raw),
        "input_sha256": digest(raw),
        "method": "Python HTMLParser and base64 only; no application execution",
        "scripts": records,
        "html_resource_references": inventory.external,
        "limitations": "HTML references do not enumerate runtime requests or prove offline operation."
    }
    (args.out / "extraction.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"scripts": len(records), "input_sha256": digest(raw)}, indent=2))


if __name__ == "__main__":
    main()
