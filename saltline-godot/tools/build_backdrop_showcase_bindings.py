"""Match actual original showcase meshes to the existing Main asset streams."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
scene = json.loads((ROOT / "assets/prepared/scene.json").read_text())
nodes = {n["id"]: n for n in scene["nodes"]}
materials = {m["id"]: m for m in scene["materials"]}
config = scene["modules"]["backdrop"]

def descendant(node, root):
    while node:
        if node["id"] == root:
            return True
        node = nodes.get(node["parent"])
    return False

def signature(geo):
    attributes = {}
    for name, info in geo["attributes"].items():
        attributes[name] = {k: info[k] for k in ("dtype", "itemSize", "count", "normalized")}
        attributes[name]["sha256"] = hashlib.sha256((ROOT / "assets/export" / info["file"]).read_bytes()).hexdigest()
    index = geo.get("index")
    if index:
        index = {k: index[k] for k in ("dtype", "count")} | {"sha256": hashlib.sha256((ROOT / "assets/export" / geo["index"]["file"]).read_bytes()).hexdigest()}
    return {"attributes": attributes, "index": index, "groups": geo["groups"]}

geometries = {g["id"]: signature(g) for g in scene["geometries"] if any(n.get("geometry") == g["id"] and descendant(n, config["root"]["$node"]) for n in scene["nodes"])}
candidates = [n for n in scene["nodes"] if n.get("geometry") in geometries and descendant(n, config["root"]["$node"])]
boat = nodes[config["boat"]["$node"]]
reports = []
for part in ("all", "crane", "ship", "boat", "sky"):
    suffix = "" if part == "all" else "-" + part
    inventory = json.loads((ROOT / f"evidence/backdrop{suffix}-showcase-source-inventory.json").read_text())
    source = json.loads((ROOT / f"evidence/main-paired-high-backdrop{suffix}-source.json").read_text())
    label_path = ROOT / f"evidence/backdrop-labels-{part}-source.json"
    labels = json.loads(label_path.read_text())["labels"] if label_path.exists() else []
    bindings, extras, errors = [], [], []
    used = set()
    for ordinal, row in enumerate(inventory["nodes"]):
        matches = []
        for n in candidates:
            if n["id"] in used or geometries[n["geometry"]] != row["geometry"]:
                continue
            if [materials[m]["name"] for m in n["materials"]] != [m["name"] for m in row["materials"]]:
                continue
            matrix = n["matrixWorld"].copy()
            if descendant(n, boat["id"]):
                for axis, base in enumerate((24, .34, 15)):
                    matrix[12 + axis] += base - boat["matrixWorld"][12 + axis]
            error = max(abs(a-b) for a,b in zip(matrix, row["matrix"]))
            if error < 1e-6 and n["castShadow"] == row["castShadow"] and n["receiveShadow"] == row["receiveShadow"]:
                matches.append((n, error))
        if len(matches) == 1:
            n, error = matches[0];used.add(n["id"])
            bindings.append({"id": n["id"], "cast_shadow": n["castShadow"], "maximum_matrix_error": error})
        elif row.get("exported_blink_geometry") and not matches:
            extra_candidates = [n for n in candidates if [materials[m]["name"] for m in n["materials"]] == [m["name"] for m in row["materials"]] and geometries[n["geometry"]]["attributes"].get("uv") == row["geometry"]["attributes"].get("uv") and geometries[n["geometry"]]["attributes"]["position"]["count"] == row["geometry"]["attributes"]["position"]["count"]]
            if not extra_candidates and "blink" in row["geometry"]["attributes"]:
                extra_candidates = [n for n in candidates if "blink" in geometries[n["geometry"]]["attributes"]]
            assert len({tuple(n["materials"]) for n in extra_candidates}) == 1, (part, ordinal, "ambiguous extra material")
            blink = extra_candidates[0]
            extras.append({"geometry": row["exported_blink_geometry"], "materials": blink["materials"], "matrix": row["matrix"], "cast_shadow": row["castShadow"]})
            if all(m["name"] == "label" for m in row["materials"]):
                matches = [label for label in labels if label["position_sha256"] == row["geometry"]["attributes"]["position"]["sha256"]]
                assert len(matches) == 1, (part, ordinal, "missing original label texture")
                texture = matches[0]["maps"]["map"]
                assert texture["wrapS"] == texture["wrapT"] == 1001 and texture["repeat"] == [1, 1] and texture["offset"] == [0, 0] and texture["colorSpace"] == "srgb" and texture["flipY"]
                blob = ROOT / "evidence" / texture["mip_file"]
                assert hashlib.sha256(blob.read_bytes()).hexdigest() == texture["mip_sha256"]
                target = ROOT / "assets/export/showcase/backdrop-labels" / (texture["mip_sha256"] + ".source-miprgba")
                target.parent.mkdir(parents=True, exist_ok=True);shutil.copyfile(blob, target)
                extras[-1]["label_texture"] = {"width": texture["width"], "height": texture["height"], "sha256": texture["mip_sha256"], "file": "res://" + str(target.relative_to(ROOT))}
        else:
            errors.append({"ordinal": ordinal, "matches": len(matches), "attributes": list(row["geometry"]["attributes"])})
    report = {"part": part, "source_sha256": inventory["source_sha256"], "source_time": source["time"]["t"], "camera": source["camera"], "nodes": bindings, "extras": extras, "casters": sum(n["cast_shadow"] for n in bindings), "original_meshes": len(inventory["nodes"]), "errors": errors}
    reports.append({"part": part, "matched": len(bindings), "exact_extra_meshes": len(extras), "errors": errors})
    assert not errors, reports[-1]
    (ROOT / f"assets/export/backdrop-{part}-showcase-bindings.json").write_text(json.dumps(report, indent=2) + "\n")
(ROOT / "evidence/backdrop-showcase-reuse-audit.json").write_text(json.dumps(reports, indent=2) + "\n")
print(json.dumps(reports))
