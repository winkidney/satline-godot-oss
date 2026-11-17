"""Audit captured Main assets and their prepared runtime representations."""
import array
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
EXPORT = ROOT / "assets/export"
source = json.loads((EXPORT / "scenes/main.json").read_text())
prepared = json.loads((ROOT / "assets/prepared/scene.json").read_text())
html_hash = hashlib.sha256((ROOT.parent / "artifact-rendering-study/source/saltline.original.html").read_bytes()).hexdigest()
assert source["sourceHash"] == prepared["sourceHash"] == html_hash
assert source["errors"] == prepared["errors"] == []
assert sys.byteorder == "little", "Captured buffers use little endian"
assert source["nodes"] == prepared["nodes"] and source["materials"] == prepared["materials"]
node_ids = {n["id"] for n in source["nodes"]}
geometry_ids = {g["id"] for g in source["geometries"]}
material_ids = {m["id"] for m in source["materials"]}
assert len(node_ids) == len(source["nodes"])
for node in source["nodes"]:
    assert node["parent"] is None or node["parent"] in node_ids, node["id"]
    assert "geometry" not in node or node["geometry"] in geometry_ids, node["id"]
    assert all(m in material_ids for m in node.get("materials", [])), node["id"]

sizes = {"Float32Array": 4, "Float64Array": 8, "Uint8Array": 1, "Uint16Array": 2, "Uint32Array": 4, "Int8Array": 1, "Int16Array": 2, "Int32Array": 4}
attributes = indices = triangles = raw_bytes = 0
prepared_geometry = {g["id"]: g for g in prepared["geometries"]}
for geometry in source["geometries"]:
    ready = prepared_geometry[geometry["id"]]
    assert {k: v for k, v in ready.items() if k != "godot_index"} == geometry
    for attribute in geometry["attributes"].values():
        blob = (EXPORT / attribute["file"]).read_bytes()
        assert len(blob) == attribute["count"] * attribute["itemSize"] * sizes[attribute["dtype"]], geometry["id"]
        attributes += 1
        raw_bytes += len(blob)
    index = geometry["index"]
    if index:
        values = array.array({"Uint16Array": "H", "Uint32Array": "I"}[index["dtype"]])
        blob = (EXPORT / index["file"]).read_bytes()
        assert len(blob) == index["count"] * sizes[index["dtype"]]
        values.frombytes(blob)
    else:
        values = array.array("I", range(geometry["attributes"]["position"]["count"]))
    assert len(values) % 3 == 0
    assert not values or max(values) < geometry["attributes"]["position"]["count"]
    native = array.array("i")
    native.frombytes((ROOT / ready["godot_index"].removeprefix("res://")).read_bytes())
    assert len(native) == len(values)
    for offset in range(0, len(values), 3):
        assert list(native[offset:offset+3]) == [values[offset], values[offset+2], values[offset+1]], geometry["id"]
    indices += len(values)
    triangles += len(values) // 3

mips = {m["id"]: m for m in json.loads((EXPORT / "texture-mips/manifest.json").read_text())["records"]}
textures = {t["id"]: t for t in prepared["textures"]}
texture_bytes = mip_bytes = 0
for texture in source["textures"]:
    ready = textures[texture["id"]]
    raw = (EXPORT / texture["file"]).read_bytes()
    assert len(raw) == texture["width"] * texture["height"] * 4
    png = Image.open(ROOT / ready["godot_file"].removeprefix("res://")).convert("RGBA")
    assert png.size == (texture["width"], texture["height"])
    assert png.transpose(Image.Transpose.FLIP_TOP_BOTTOM).tobytes() == raw, texture["id"]
    texture_bytes += len(raw)
    record = mips[texture["id"]]
    blob = (ROOT / ready["godot_mip_file"].removeprefix("res://")).read_bytes()
    assert hashlib.sha256(blob).hexdigest() == record["sha256"] == ready["godot_mip_sha256"], texture["id"]
    original_rows = (ROOT / ready["godot_source_mip_file"].removeprefix("res://")).read_bytes()
    assert hashlib.sha256(original_rows).hexdigest() == ready["godot_source_mip_sha256"], texture["id"]
    assert len(original_rows) == len(blob) == sum(level["bytes"] for level in record["levels"])
    mip_bytes += len(blob)

report = {"source_sha256": html_hash, "nodes": len(node_ids), "geometries": len(geometry_ids), "materials": len(material_ids), "textures": len(textures), "attribute_buffers": attributes, "attribute_bytes": raw_bytes, "index_entries": indices, "triangles": triangles, "base_rgba_bytes": texture_bytes, "mip_bytes_each_row_contract": mip_bytes, "modules": list(source["modules"]), "failures": [], "scope": "Current captured Main node/material metadata unchanged in preparation, all attribute lengths/references and complete triangle winding correspondence;132 decoded PNGs equal captured RGBA8 with declared row orientation; both prepared mip representations validate their recorded hashes. Source HTML identity is checked. Does not recapture original browser geometry, prove the historical RGBA8 readback recovers original HDR, cover separate catalogs or prove shader/runtime pixel parity."}
(ROOT / "evidence/asset-inventory-verification.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
