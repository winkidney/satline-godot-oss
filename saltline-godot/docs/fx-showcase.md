# Godot FX showcase

Run from the saltline-godot directory (isolated engine, no audio):

```sh
./tools/run_native.sh --script scripts/fx_showcase_runner.gd -- --game --fx-mode=all
```

Escape exits. Modes: `all`, `impact`, `tracer`, `explosion`. `--fx-hold=muzzle` adds the original repeated muzzle pair. `--fx-size=1.2` fixes explosion scale; omitted scale cycles1/2/3. `--fx-prewarm=2` runs original30Hz startup prewarm. `--fx-age=0.5` clears FX, creates an explosion at(0,.25,3.5), advances60Hz to requested age and freezes FX. `--fx-fixed` advances60Hz independent of elapsed render time. `--fx-frames=60` exits after60 rendered loop iterations; omit for interactive viewing. `--fx-capture=res://evidence/my-showcase.png` saves a screenshot on exit.

```sh
./tools/run_native.sh --script scripts/fx_showcase_runner.gd -- --game --fx-mode=explosion --fx-size=1.2 --fx-age=0.5 --fx-fixed --fx-frames=30 --fx-capture=res://evidence/fx-showcase-explosion-frozen.png
```

Native360frame effect integration and shorter standalone all/prewarm and explosion/freeze runs are verified on RTX4070SUPER. Existing whole-game initialization is reused then map geometry/collision, HUD and weapons are isolated. This is a working research entry point, not completed source pixel parity. Source showcase boot stubs backdrop/ground/player/game; native still initializes world services, reads existing settings and has imported environment/weather history. No user settings are written. Original random/time interleaving, source screenshot matching and environment boot reset remain pending. Fixed-step screenshots do not measure realtime performance.

`--fx-tape=res://evidence/fx-showcase-tape.json` supplies a shared deterministic FX random tape for original/native captures. The browser collector creates this tape; it controls FX randomness, not renderer history.

Diagnostics: `--fx-render-warmup=3` adds real renderer warmup frames; `--fx-manual-exposure=0.7` disables auto exposure. They alter rendering history and are not interchangeable with setting world/FX time. Capture freezes feedback viewports before its forced redraw. Original browser manual collector uses `SALTLINE_FX_MANUAL=0.7`.

Case capture: `--fx-state=res://evidence/my-case.json` saves independent metadata including screenshot SHA256. Browser collector supports `SALTLINE_FX_AGE=0.1 SALTLINE_FX_SIZE=1.2 SALTLINE_FX_CASE=age010`; case labels accept lowercase letters, digits and hyphens.

`--fx-soft=0` disables soft intersection fading for diagnosis; default retains it. Browser counterpart is `SALTLINE_FX_SOFT=0`, which passes original `fxsoft=0`.

Layer diagnostics: `--fx-hide-particles` hides only lit/add draw batches; `--fx-no-point-lights` zeros transient pool peaks/intensities. Browser counterparts are `SALTLINE_FX_HIDE_PARTICLES=1` and `SALTLINE_FX_NO_POINT_LIGHTS=1`. Defaults retain all effects.

`--fx-surface=albedo` outputs final material color without lighting for surface diagnosis; `normal`/`roughness` variants are also available. Browser collector uses `SALTLINE_FX_SURFACE=albedo`. This changes the diagnostic render, not normal gameplay materials.

Lighting diagnostics now include `direct-diffuse`, `direct-specular`, `indirect-diffuse`, and `indirect-specular` for `--fx-surface` and `SALTLINE_FX_SURFACE`. They output the final component after the original lighting/occlusion work. Native captures additionally write `<state-name>.world.bin` with format/dimensions/origin in the state JSON. Original collector opt-in `SALTLINE_FX_HDR=1` captures the main-camera world render target before postprocessing as RGBA16F, bottom-left origin. Godot captures RGBH, top-left origin. `tools/compare_showcase_hdr.py` handles the channel count and row reversal. It compares board interiors and tests four-term reconstruction when matching beauty captures exist. The source collector accepts `SALTLINE_FX_BASE_URL` so only the original source directory needs local HTTP service.

Native roughness debug now outputs `clamp(rr,.045,1.0)`, matching the original final roughnessFactor. Earlier roughness comparison images used unclamped rr and must not be interpreted as proof of a production roughness defect.

Additional material-input diagnostics are `orm`, `normal-length`, and `macro` (mac/mac2/wet). `compare_showcase_hdr.py --inputs` compares saved `hdr-*` pairs and reports actual normal angular errors. Diagnostic-only `--fx-noise=plain|affine-free|tail-free|fused` retains the historical split-affine baseline when constructing each alternative. Normal mode is `production`, now explicit affine FMA. No-noise flags are needed for normal gameplay.
