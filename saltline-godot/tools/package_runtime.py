#!/usr/bin/env python3
"""Build an unpruned, relocatable Linux test bundle without the research tree."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    destination = args.destination.resolve()
    if destination.exists():
        parser.error("Destination must not exist; existing bundles are never overwritten")
    if ROOT == destination or destination in ROOT.parents:
        parser.error("Destination cannot contain the project")
    result = json.loads((ROOT / "engine/build-result.json").read_text())
    binary = Path(result["binary"])
    if not binary.is_absolute():
        binary = ROOT / binary
    if digest(binary) != result["sha256"]:
        raise RuntimeError("Built engine does not match build-result.json")
    required = [ROOT / ".godot/global_script_class_cache.cfg", ROOT / ".godot/imported"]
    for path in required:
        if not path.exists():
            raise RuntimeError(f"Missing prepared import data: {path}")
    destination.mkdir(parents=True)
    for name in ["assets", "scripts", "shaders", "scenes"]:
        shutil.copytree(ROOT / name, destination / name)
    shutil.copy2(ROOT / "project.godot", destination / "project.godot")
    (destination / ".godot").mkdir()
    shutil.copytree(ROOT / ".godot/imported", destination / ".godot/imported")
    for name in ["global_script_class_cache.cfg", "uid_cache.bin", ".gdignore"]:
        path = ROOT / ".godot" / name
        if path.exists():
            shutil.copy2(path, destination / ".godot" / name)
    (destination / "engine").mkdir()
    shutil.copy2(binary, destination / "engine/godot")
    for name in ["build-result.json", "source-manifest.json"]:
        shutil.copy2(ROOT / "engine" / name, destination / "engine" / name)
    shutil.copy2(ROOT / "engine/.build/godot-ed1daf0bf/COPYRIGHT.txt", destination / "engine/COPYRIGHT.txt")
    launch = destination / "run.sh"
    launch.write_text('#!/bin/sh\nset -eu\nSALTLINE_BUNDLE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec "$SALTLINE_BUNDLE_DIR/engine/godot" --path "$SALTLINE_BUNDLE_DIR" "$@"\n')
    launch.chmod(0o755)
    (destination / "evidence").mkdir()
    (destination / "README.txt").write_text("Saltline Godot Linux x86_64 test bundle\nRun ./run.sh -- --game\nRequires a Vulkan Forward+ compatible GPU and Linux desktop libraries.\nIncludes source assets and imported resource cache; this is an unpruned development test bundle.\nNo audio. Full visual/gameplay parity is still under investigation.\nEngine provenance is in engine/source-manifest.json and engine/build-result.json.\nCold-start quality assets:\n./run.sh -- --game --cold-quality=low\n./run.sh -- --game --cold-quality=medium\n./run.sh -- --game --cold-quality=ultra\nDefault cold assets follow the source device classification. Explicit cold-quality overrides that classification; saved quality applies to rendering. Live menu changes still apply and do not rebake textures.\nCatalogs and inspection:\n./run.sh --script scripts/material_catalog_runner.gd -- --game --catalog=render\n./run.sh --script scripts/material_catalog_runner.gd -- --game --catalog=ground\n./run.sh --script scripts/material_catalog_runner.gd -- --game --catalog=full\n./run.sh --script scripts/material_catalog_runner.gd -- --game --catalog=props\n./run.sh --script scripts/material_catalog_runner.gd -- --game --only=decals\n./run.sh --script scripts/material_catalog_runner.gd -- --game --names=forklift,container20,barrel\n./run.sh --script scripts/material_catalog_runner.gd -- --game --only=brick,concrete --wet=0\n./run.sh --script scripts/material_catalog_runner.gd -- --game --catalog=full --asset-quality=low\nEscape exits the catalog. Catalogs retain default source seed/options; other generated variants remain incomplete.\n")
    with (destination / "README.txt").open("a") as stream:
        stream.write('Current included work: font-correct high/low/ultra material catalogs and props, 2048 hero asphalt, cold-quality startup precedence, original-style menu buttons/settings controls, interrupted UI transitions and rich controls notes.\nUltra material inspection:\n./run.sh --script scripts/material_catalog_runner.gd -- --game --catalog=full --asset-quality=ultra --only=asphalt\nRemaining qualification includes full visual/gameplay fidelity, small cross-backend gradient/noise differences and all-device behavior.\n')
    with (destination / "README.txt").open("a") as stream:
        stream.write('Original level inspection:\n./run.sh --script scripts/level_showcase_runner.gd -- --game\nOriginal backdrop inspection:\n./run.sh --script scripts/level_showcase_runner.gd -- --game --showcase=backdrop --bshow=boat\nSelectors: all/crane/ship/boat/sky.\nOriginal enemies inspection:\n./run.sh --script scripts/enemies_showcase_runner.gd -- --game --eshow=both\nSelectors: both/gull/hound/fight/dead; --epre=seconds; --efreeze. Source-only diagnostic --source-nav-tape is not included in this bundle.\nNative weapon and hands studios:\n./run.sh --script scripts/weapon_showcase_runner.gd -- --game --wgun=rifle --wpose=side\n./run.sh --script scripts/hands_showcase_runner.gd -- --game --hview=palm --hpose=open\nWeapon: named closeups, hip/ads/sprint/fire/reload/empty/locked/switch, --wt, --wlook, --wview. Hands: back/palm/side/arm/fp, --hheld, --hpose, --hblend, --htrig, --hgun, --hgrip, --hwet. Both accept --cam=x,y,z,tx,ty,tz --fov=30 --exposure=1. Escape exits.\nIncludes once-only fresh enemy pools and original pooled activation history. Includes shared navigation/FX/sky Math.random semantics and stock-editor parse compatibility. Includes original navigation HUD cross/marker CSS transitions and enemy showcase warmup camera/global bootstrap. Includes Ultra per-frame shadow cadence, paused panel Start back behavior, corrected studio environment/initialization, source device classification, and per-viewport source raster orientation with world/weapon/planar output normalization. Studio visuals still require final original-frame qualification.\n')
    records = [{"path": str(path.relative_to(destination)), "bytes": path.stat().st_size, "sha256": digest(path)}
               for path in sorted(destination.rglob("*")) if path.is_file()]
    manifest = {"kind": "unpruned-linux-development-runtime", "engine_sha256": result["sha256"],
                "file_count": len(records), "total_bytes": sum(record["bytes"] for record in records), "files": records}
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({key: value for key, value in manifest.items() if key != "files"}))

if __name__ == "__main__":
    main()
