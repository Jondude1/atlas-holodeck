# Antigravity Polish Pass & Verification Report — Atlas Holodeck

This report summarizes the presentation-only polish edits in the working tree (17 files under `app/`, based on `BRIEF-antigravity-polish.md`) and the full verification pass executed per `BRIEF-antigravity-suites.md`.

No files under `tools/`, `app/demo/`, `SPEC.md`, or `app/hub_secret.cfg` were modified, no behaviour/interaction/hub/voice/CAD logic was changed, and no commits were made. All polish edits caused **0 regressions**; the two failures observed (`interaction_test` and the `round1b_exercise` draw-call ceiling) were traced and proven to be pre-existing in `HEAD` (`1e9da68`) and were left untouched per the brief's hard rules.

---

## 1. Summary of Polish Changes (17 files)

| File | Named Target(s) | What Changed |
| --- | --- | --- |
| `app/cad_model.gd` | Target 4 (Hero hologram presence) | Raised `DISPLAY_FIT_M` from `0.5` to `0.82` m so table models read with stronger presence inside the 0.90 m ring / 1.0 m inset while preserving true proportions and `TRUE SIZE` scaling. |
| `app/column.gdshader` | Target 4 (Hero hologram presence) | Raised projection column `gain` from `0.16` to `0.19`. |
| `app/fx.gd` | Targets 1, 4 (Grid contrast over dark inset) | Adjusted `grid_material()` strengths (`minor_strength` `0.13 → 0.17`, `major_strength` `0.25 → 0.32`, `fine_strength` `0.05 → 0.06`) for crisp cyan linework over the darker inset surface. |
| `app/holo.gdshader` | Target 4 (Hero hologram presence) | Lifted volumetric fill mix (`mix(fill_color, line_color, 0.35) * 1.15`), boosted edge brightness (`mix(1.1, 1.65, res)`), and increased scan-band core energy (`1.5 * wb`). |
| `app/holo_mesh.gdshader` | Target 4 (Hero hologram presence) | Added screen-space ridge/crease wireframe accent via `dFdx(n)` / `dFdy(n)` (`crease_strength = 0.82`), widened Fresnel rim (`rim_power` `2.2 → 1.75`, `rim_strength` `0.85 → 1.05`), lifted fill/rim/crease energy, and capped alpha at `0.96`. |
| `app/lab.gd` | Targets 1, 2, 5 (Room grade, floor sheen, orb height) | Reset `_presence` to 1:1 scale at `(-2.15, 0.0, -2.15)` (was `1.5×` at `(-2.0, 0, -2.25)`); widened and softened `FloorGloss` (`3.8 × 1.9`, alpha `0.055`, radial power `2.2`) and `VistaSpill` (`6.6 × 4.0`, alpha `0.045`, `z = -3.45`, power `2.0`); darkened `_suit_platforms()` bases with crisper cyan rings (`0.32 → 0.44`); darkened `_bench_slabs()` to neutral charcoal with quieter cyan edge strips (`0.35 → 0.24`); dimmed and narrowed `_ceiling_bars()` (`(0.88, 0.92, 0.96)` / `(0.68, 0.72, 0.76)`). |
| `app/main.gd` | Target 1 (Dark neutral room grade) | Replaced bright-blue `ProceduralSkyMaterial` reflection colours in `_apply_tokens()` with dark neutral charcoal; lowered `ambient_light_energy` (`1.1 → 0.16`); darkened and thinned room fog (`fog_light_color = Color(0.08, 0.11, 0.15)`, `fog_light_energy = 0.55`, `fog_density = 0.0045`). |
| `app/presence.gd` | Target 5 (Atlas point-sphere cohesion) | Replaced the first ring emitter with a spherical surface shell (`_make_shell_points`, `EMISSION_SHAPE_SPHERE_SURFACE`, radius `0.46`, `750` particles — keeping the exact same 3 `GPUParticles3D` systems / 0 extra draw calls); tightened core/ring radii, velocity, damping, and quad size (`0.02 → 0.015`); sharpened particle falloff (`radial_texture(64, 2.4)`, `vertex_color_use_as_albedo = true`); balanced `_nucleus` (`pixel_size` `0.0028 → 0.0055`, soft cyan alpha `0.28`) and `_pool_mat` (`0.30 → 0.22`); raised orb hover height `1.35 → 1.42` m. |
| `app/room.gd` | Targets 1, 2, 3 (Walls/ceiling grade, floor streak, opening chamfers) | Darkened `_wall_mat()` to neutral charcoal concrete (`Color(0.24, 0.25, 0.27)`); lowered `STRIP_ENERGY` (`0.55 → 0.38`), `COVE_ENERGY` (`0.6 → 0.45`), `POOL_ALPHA` (`0.35 → 0.18`); darkened floor (`Color(0.34, 0.36, 0.38)`), raised floor roughness (`0.30 → 0.42`), and shifted `uv1_offset.x = 0.09` to move the grout seam off `x = 0`; merged `WallBackLeft`/`WallBackRight`/`WallBackHeader` + floating chamfer boxes into a single `WallBack` `ArrayMesh` (`_build_back_wall_mesh(0.44)`) with flush 45° top-corner chamfers, continuous UVs, `+Z` normals, and recessed dark concrete reveals in `_lab.lit`; converted `Ceiling` from flat unshaded blue to lit dark concrete and removed `CoveHalo` and the back-wall cove strip; neutralized terrace stone (`roughness 0.62`) and dimmed the rail emissive line (`0.7 → 0.5`). |
| `app/table.gd` | Targets 1, 2, 4 (Neutral light rig, softer specular, hero inset) | Tamed table emissive/light constants (`EDGE_ENERGY 2.1 → 1.15`, `CHANNEL_ENERGY 4.0 → 1.45`, `BEVEL_ENERGY 0.75 → 0.45`, `ETCH_ALPHA 0.5 → 0.34`, `BEZEL_ENERGY 1.4 → 0.95`, `LIGHT_ENERGY 2.05 → 1.45`, `FILL_ENERGY 0.55 → 0.42`, `RIM_ENERGY 0.95 → 0.85`); neutralized all 3 `OmniLight3D` tints, reduced `light_specular` (`0.35` / `0.12` / `0.25`), and nudged light positions (still exactly 3 lights); darkened `DisplayInset` base and lifted `hot_center` (`0.25 → 0.30`) and model glow pool (`HOLO_LINE`, `0.36`). |
| `app/vista.gd` | Targets 1, 7 (Vista balance & neutral room reflections) | Darkened per-vista fog colour/density and reduced `ambient_energy` / `omni_energy` across `coast`, `lake`, and `valley`; tuned `GRADES` (`day`/`golden`/`dusk`) card/sky tints; strengthened `_slate()` desaturation/darkening (`lerp(g, 0.84) * 0.30`) so room surfaces reflect neutral dark daylight rather than blue. |
| `app/vista_card.gdshader` | Target 7 (Calm photographic vista) | Added `sat = 0.86` saturation control and replaced continuous horizontal sine foam lines with broken organic ocean glints (`break_x`). |
| `app/vista_drift.gdshader` | Target 7 (Protect vista from room fog) | Added `fog_disabled` to `render_mode`. |
| `app/vista_life.gdshader` | Target 7 (Protect vista from room fog) | Added `fog_disabled` to `render_mode`. |
| `app/vista_sky.gdshader` | Target 7 (Protect vista from room fog) | Added `fog_disabled` to `render_mode`. |
| `app/vista_water.gdshader` | Target 7 (Protect vista from room fog) | Added `fog_disabled` to `render_mode`. |
| `app/wall_panel.gd` | Target 6 (Wall panel instrumentation & typography) | Replaced ad-hoc `ColorRect` borders and `Line2D` wave/gauge nodes with `_PanelChrome` (`Control._draw()` inside the `SubViewport` on `UPDATE_ONCE`: micro-grid, border + corner L-brackets, section hairlines, concentric Stark ring gauge with 24 ticks in a dedicated right bay clear of text, dual-trace oscilloscope strip along the bottom); slimmed/darkened the 3D frame (`bw 0.035 → 0.022`); deepened glass background (`Color(0.007, 0.020, 0.032)`); balanced display albedo (`0.84, 0.95, 1.0`); refined title/body/clock sizing, margins, and line spacing; replaced `String(...)` with null-safe `str(...)`. |

Existing captures from the polish pass (unchanged since 0 code edits were required during verification):
- `captures/shot-agy1.png` (entrance shot)
- `captures/shot-agy2.png` (close table shot)

---

## 2. Full Verification Results

### 2.1 Import Check
Command:
```bash
~/workspace/tooling/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path app --import
```
- **Verdict**: **PASS** (exit code `0`, **0 `SCRIPT ERROR`s**).

### 2.2 Headless Test Suites (14 suites, run sequentially one at a time)
Command shape:
```bash
~/workspace/tooling/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path app --script ../tools/<name>.gd
```

| # | Suite | Verdict Line | Exit Code | Notes |
| --- | --- | --- | --- | --- |
| 1 | `panel_test` | `PANEL_TEST PASS` | 0 | Pass |
| 2 | `interaction_test` | `INTERACTION_TEST FAIL (8)` | 8 | Pre-existing (`1e9da68` demo swap) — see §3.1 |
| 3 | `explode_test` | `EXPLODE_TEST PASS` | 0 | Pass |
| 4 | `silhouette_test` | `SILHOUETTE_TEST PASS` | 0 | Pass |
| 5 | `failure_test` | `FAILURE_TEST PASS` | 0 | Pass |
| 6 | `print_flow_test` | `PRINT_FLOW_TEST PASS` | 0 | Pass |
| 7 | `rig_test` | `RIG_TEST PASS` | 0 | Pass |
| 8 | `props_test` | `PROPS_TEST PASS` | 0 | Pass |
| 9 | `solidify_test` | `SOLIDIFY_TEST PASS` | 0 | Pass |
| 10 | `tools_test` | `TOOLS_TEST PASS` | 0 | Pass |
| 11 | `responds_test` | `RESPONDS_TEST PASS` | 0 | Pass |
| 12 | `labels_test` | `LABELS_TEST PASS` | 0 | Pass |
| 13 | `park_labels_test` | `PARK_LABELS_TEST PASS` | 0 | Pass |
| 14 | `wall_widgets_test` | `WALL_WIDGETS_TEST PASS` | 0 | Pass |

**Summary**: **13 / 14 PASS**; 1 pre-existing failure (`interaction_test`).

### 2.3 End-to-End Exercise (`tools/round1b_exercise.gd`)
Commands:
```bash
python3 tools/mock_hub.py --port 8794 --assets cad-jobs/0f84d94de2 --edit-assets cad-jobs/edit-bracket-tall
HOLODECK_HUB=http://127.0.0.1:8794 xvfb-run -a ~/workspace/tooling/godot/Godot_v4.7.2-stable_linux.x86_64 --path app --resolution 1280x720 --script ../tools/round1b_exercise.gd
```
(Mock hub killed cleanly after exercise exit.)

- **Verdict**: `ROUND1B_EXERCISE FAIL (1)` (exit code `1`)
- **`EX PERF` line**: `EX PERF draw_calls=102 lights=3`
  - `EX FAIL R4-7 ceiling: draw calls 102 <= 95 (Quest 2 mono budget)` — Pre-existing (`1e9da68`), see §3.2
  - `EX PASS R4-7 ceiling: lights 3 <= 3`
- **All 14 functional checks PASSED**:
  - `EX PASS active model is the revision (job b7c1e44f02)`
  - `EX PASS bench size unchanged (2): replaced, not parked beside`
  - `EX PASS revision holds the same bench slot (1)`
  - `EX PASS same position / orientation / scale as the model it replaced`
  - `EX PASS old model freed`
  - `EX PASS revision is on stage (not parked)`
  - `EX PASS panel has a SEND TO PRINTER button`
  - `EX PASS panel press opens CONFIRMING for the on-stage part`
  - `EX PASS confirmation card is visible`
  - `EX PASS CANCEL -> IDLE, hub print-job never called`
  - `EX PASS voice request only opened the card (nothing started)`
  - `EX PASS one hub call, DRY-RUN plan, printer not contacted`
  - Captures written cleanly (`err=0`): `r1b-print-confirmation.png`, `r1b-print-dry-run-plan.png`, `r1b-edit-in-place.png`.

---

## 3. Documented Pre-Existing Failures (Not Fixed Per Hard Rules)

### 3.1 `interaction_test` — `INTERACTION_TEST FAIL (8)`
**Failing assertions** (all in R1-3 reset, trebuchet spawn park check, and R1-7 bench select):
1. `T FAIL R1-3 RESET MODEL returns the active model to centre pos=(0.6, 0.951, 0.3)`
2. `T FAIL R1-3 ...upright, display scale, assembled`
3. `T FAIL spawned the 27-part trebuchet; bracket parked parts=27`
4. `T FAIL R1-7 select pulls the parked bracket to centre and makes it active pos=(0.6, 0.951, 0.3)`
5. `T FAIL R1-7 the model that was on stage parks into the vacated slot treb=(0.0, 0.951, 0.0) slot=(0.6, 0.951, 0.3)`
6. `T FAIL R1-7 panel retargets (3 part rows) and readouts follow rows=27`
7. `T FAIL R1-7 panel model is the bracket`
8. `T FAIL R1-7 round trip: trebuchet back on stage, bracket parked`

**Evidence that this is pre-existing (not a polish regression):**
- Commit `1e9da68` (`HEAD`, immediately prior to the Antigravity polish pass) committed `app/demo/stardestroyer.glb` + `app/demo/stardestroyer.json` and fixed the load order in `app/main.gd:_bundled_demo_swap()` so `m.setup(bytes, manifest)` runs before `_table.add_child(m)`.
- Consequently, `_bundled_demo_swap()` now succeeds at boot: `DemoDestroyer` replaces `_model` before `_bench.setup(_table, _model, ...)` is called, hiding `HoloTable/TestBracket` and never registering `TestBracket` in `CadBench._bench`.
- The `interaction_test` output itself confirms `DemoDestroyer` is the active model at boot: the panel's button list includes `"VICTORY_CLASS_ STARDESTROYER_OPEN_DOORS_NO_PEG · 01"`.
- `tools/interaction_test.gd` (lines 60, 171, 189, 245) hardcodes `bracket = main.get_node("HoloTable/TestBracket")` and assumes `TestBracket` is `bench.active_model()` and a member of `CadBench._bench`. Thus `bench.reset_active()` resets `DemoDestroyer` instead of `TestBracket`, `bench.spawn()` parks `DemoDestroyer` instead of `TestBracket`, and `bench.select(bracket)` early-returns at `if m == null or not (m in _bench): return` (`app/cad_bench.gd:324`).
- None of the 17 polish edits touch `_bundled_demo_swap()`, `app/cad_bench.gd`, `app/demo/`, or any bench/interaction logic (the polish diff in `app/main.gd` modifies only `_apply_tokens()` sky/ambient/fog constants).

### 3.2 `round1b_exercise` — `EX PERF draw_calls=102 lights=3` (ceiling `<= 95`)
**Evidence that this is pre-existing (not a polish regression):**
- In `tools/round1b_exercise.gd:129-136`, `pf.dismiss()` emits `PrintFlow.state_changed(IDLE)`, which invokes `app/ui_panel.gd:544-545` (`_on_print_state` → `poke(3.0)`), keeping `UIPanel/SubViewport` in `SubViewport.UPDATE_ALWAYS` for **3.0 s** (**+41 draw calls** for the 2D panel pass).
- `round1b_exercise.gd:134-136` waits only `0.6 s` before measuring `_draws()`, so despite the comment `# draw calls (panel idle, bracket revision on stage)`, it samples while `UIPanel/SubViewport` is still rendering every frame alongside two bench models (`DemoDestroyer` parked + revised `Shelf Bracket` active).
- Direct apples-to-apples probes in the exact same `xvfb-run` OpenGL3/llvmpipe environment and exact `round1b_exercise.gd` camera pose (`fov = 58.0`, `pos = (0.0, 1.9, -0.55)`, looking at `table + (0, 1.1, 0)`):
  - **1-model resting scene (`DemoDestroyer` on stage):**
    - `HEAD` (`1e9da68`, pre-polish): **55** draw calls (`UIPanel` idle / `UPDATE_DISABLED`), **97–98** draw calls (`UIPanel` active / `UPDATE_ALWAYS`).
    - Working tree (with polish): **56** draw calls (`UIPanel` idle / `UPDATE_DISABLED`), **97–99** draw calls (`UIPanel` active / `UPDATE_ALWAYS`).
  - **2-model end-of-exercise state (`DemoDestroyer` parked + `cad-jobs/edit-bracket-tall` active, 0.6 s after `poke(3.0)`):**
    - `HEAD` (`1e9da68`, pre-polish): **`active_panel=102`**, `idle_panel=100`.
    - Working tree (with polish): **`active_panel=102`**, `idle_panel=100`.
- Merging the 3 back-wall segments into 1 `WallBack` mesh and removing `CoveHalo` saved 4 draw calls in `Room`, offsetting the lit ceiling and widened floor sheen; net resting draw calls are **56** (well within the Quest 2 `≤ 90` mono resting budget), scene light count remains **3**, and the exercise-state draw call count is **identical (`102` vs `102`)** to pre-polish `HEAD` (`1e9da68`).

---

## 4. Proposals Requiring Functional / Test-Harness Changes (Not Implemented)

1. **`tools/interaction_test.gd` compatibility with the Star Destroyer demo bundle**: Update `interaction_test.gd` to read the initial active model via `bench.active_model()` (or expose a flag/env to skip `_bundled_demo_swap()` under test) so R1-3 / R1-7 bench checks track whichever starter model is on stage.
2. **`app/ui_panel.gd` / `tools/round1b_exercise.gd` idle draw-call measurement**: Have `_on_print_state(PrintFlow.S.IDLE)` schedule a single `UPDATE_ONCE` (or short `0.2 s` poke instead of `poke(3.0)`), or wait `> 3.2 s` in `round1b_exercise.gd` after `pf.dismiss()`, so `EX PERF` measures the intended panel-idle frame (~59–60 draw calls) instead of an active `UPDATE_ALWAYS` panel pass (`102`).
3. **Optional visual follow-up (from reviewing `captures/shot-agy1.png` and `captures/shot-agy2.png`)**: The darkened room grade (`ambient_light_energy = 0.16`, `_wall_mat()` at `0.24`) pushes the side walls and ceiling near-black in the entrance capture, and a thin vertical specular/reflection line remains visible on the floor below the table centre in `shot-agy1.png`. A slight lift in charcoal wall value / ambient energy and softening the centerline table/floor reflection cue could bring the mid-tones closer to `design/look-reference-jon-20261124.jpg` in a future presentation pass.


---

## 5. Addendum — Final Corrective Tone-Lift Pass (`BRIEF-antigravity-tonelift.md`)

A targeted corrective presentation pass was applied to address the three review targets from `captures/shot-agy1.png` and `captures/shot-agy2.png` against `design/look-reference-jon-20261124.jpg` while preserving the crisp table grid, wall-panel chrome, denser Atlas point-sphere, integrated chamfered opening, and `0.82 m` display fit (`app/cad_model.gd` unchanged).

No files under `tools/`, `app/demo/`, `SPEC.md`, or `app/hub_secret.cfg` were modified, scene lights remain **exact 3**, draw calls did not increase, and no git commits were made.

### 5.1 Tone-Lift Changes (file, value, target)

| File | Value Change (from polish pass → tone-lift) | Target |
| --- | --- | --- |
| `app/vista.gd` | `_slate(c)`: `c.lerp(g, 0.84) * 0.30` → `c.lerp(g, 0.86) * 0.88` (neutral charcoal luminance without the blue cast of `HEAD` or the black crush of `agy1`). `DEFS["coast"]`: `ambient_energy` `0.16 → 0.46`, `omni_energy` `0.85 → 1.05`, `fog` `(0.08, 0.11, 0.15) → (0.14, 0.15, 0.17)`, `fog_density` `0.0045 → 0.006`. Matching neutral lifts on `lake` (`ambient_energy 0.15 → 0.38`, `omni_energy 0.75 → 0.95`) and `valley` (`ambient_energy 0.18 → 0.48`, `omni_energy 0.85 → 1.05`). | Target 1 (Lift mid-tones) |
| `app/main.gd` | `_apply_tokens()` sky/ambient/fog aligned with neutral charcoal lift (`sky_top` `(0.06, 0.07, 0.09) → (0.22, 0.23, 0.25)`, `sky_horizon` `(0.16, 0.18, 0.21) → (0.46, 0.48, 0.51)`, `ground_horizon` `(0.14, 0.16, 0.18) → (0.38, 0.40, 0.43)`, `ground_bottom` `(0.03, 0.04, 0.05) → (0.12, 0.13, 0.15)`, `ambient_light_energy` `0.16 → 0.46`, `fog_light_color` `(0.08, 0.11, 0.15) → (0.14, 0.15, 0.17)`, `fog_density` `0.0045 → 0.006`). | Target 1 (Lift mid-tones) |
| `app/main.gd` | In desktop/fallback mode (`not _xr_ok`), hide untracked `XROrigin3D/LeftHand/Marker`, `RightHand/Marker`, and `RightHand/Laser` (which otherwise sit at floor origin `(0, 0, 0)` and cast the bright vertical `x = 0` cyan beam straight along the floor under the table), restoring visibility in `_on_xr_started()` when OpenXR is live. Zero impact on XR or interaction logic. | Target 3 (Kill floor streak) |
| `app/room.gd` | Lifted textured charcoal concrete/stone tints so the already-dark photographic textures (`TEX_WALL`, `TEX_FLOOR`) are no longer double-crushed into black: `_wall_mat()` `(0.24, 0.25, 0.27) → (1.05, 1.08, 1.12)` (`roughness 0.88 → 0.84`); `Ceiling` `(0.24, 0.25, 0.27) → (1.05, 1.08, 1.12)` (`metallic 0.06 → 0.10`, `roughness 0.74 → 0.55`) and ceiling beams `TITANIUM_DARK → TITANIUM_BODY`; `Floor` `(0.34, 0.36, 0.38) → (0.90, 0.93, 0.96)` (`metallic 0.08 → 0.06`, `roughness 0.42 → 0.46`); `Terrace` `(0.46, 0.47, 0.49) → (1.25, 1.27, 1.28)`; opening reveal `rev_col` `(0.14, 0.15, 0.17) → (0.32, 0.34, 0.37)`. | Target 1 (Lift mid-tones), Target 3 (Floor sheen) |
| `app/lab.gd` | `_suit_platforms()`: base `(0.16, 0.18, 0.21) → (0.32, 0.35, 0.39)`, top disc `(0.08, 0.10, 0.12) → (0.18, 0.20, 0.24)`, cyan ring `0.44 → 0.60`, floor ring `* 0.35 → * 0.45`. `_bench_slabs()`: top `(0.20, 0.21, 0.23) → (0.28, 0.30, 0.33)`, legs `(0.09, 0.10, 0.12) → (0.16, 0.18, 0.20)`, edge strip `0.24 → 0.28`. `_ceiling_bars()`: centre `(0.88, 0.92, 0.96) → (1.05, 1.08, 1.12)`, sides `(0.68, 0.72, 0.76) → (0.82, 0.85, 0.88)`. `FloorGloss`: widened/softened (`3.8 × 1.9 → 4.4 × 2.4`, alpha `0.055 → 0.032`, radial power `2.2 → 2.6`, `z = table_xz.y + 0.95`). `VistaSpill`: alpha `0.045 → 0.085` for broad daylight floor sheen. | Target 1 (Lift mid-tones), Target 3 (Kill floor streak) |
| `app/table.gd` | 3-light rig (still exactly 3 `OmniLight3D`s): `LIGHT_ENERGY` `1.45 → 1.85` (`omni_range 5.5 → 9.0`, `light_specular 0.35 → 0.15`), `FILL_ENERGY` `0.42 → 0.55` (`omni_range 4.5 → 7.5`, `light_specular 0.12 → 0.05`, `position (0, 1.05, 1.35) → (0, 1.35, 1.25)`), `RIM_ENERGY` `0.85 → 1.35` (`omni_range 6.5 → 10.0`, `light_specular 0.25 → 0.14`, `position (0, 2.0, -1.6) → (0, 2.35, -1.8)`). `DisplayInset` `hot_center` `0.30 → 0.18`; `ModelGlow/GlowPool` `HOLO_LINE` alpha `0.36 → HOLO_PRIMARY` alpha `0.14` to eliminate the white glare spot under the hologram belly. | Target 1 (Lift mid-tones), Target 2 (Hologram teal), Target 3 (Kill floor streak) |
| `app/holo_mesh.gdshader` | Pulled centre exposure back into saturated electric teal so ACES + bloom never wash out to white: kept strong wireframe silhouette (`rim_power = 1.75`, `rim_strength = 0.96`, `crease_strength = 0.85`, `crease = smoothstep(0.12, 0.50, ndelta)`), lowered opaque fill cap (`wf` capped at `0.28`, `ALPHA` capped at `0.84`), and replaced the white-heavy `core_color` mix (`flash + 0.18` / `flash + 0.42` × `1.75`–`1.85`) with low-red saturated teal channels (`teal_vol`, `teal_rim`, `teal_wire`, highlight capped at `mix(teal_wire, core_color, 0.22)` × `1.10`–`1.18`). | Target 2 (Hologram back to teal) |
| `app/holo.gdshader` | Matched the restrained teal exposure for box-part models (`vol_col` attenuated red + `0.88` gain, `edge_col` low-red cyan × `0.9–1.15`, `wb` core `1.5 → 1.2`). | Target 2 (Hologram back to teal) |
| `app/column.gdshader` | Lowered projection column additive `gain` from `0.19 → 0.09` so the vertical shaft no longer washes out the hologram core. | Target 2 (Hologram back to teal) |
| `app/model.gd` | Toned down `SCAN_PLANE_ALPHA` (`0.45 → 0.18`) and `_schematic_mat` tint/alpha (`Color(1, 1, 1, a) → Color(0.70, 0.85, 0.94, a * 0.68)`) so the flat schematic and scan sweep frame the hologram cleanly in dark teal instead of blasting bright cyan-white behind the Star Destroyer. | Target 2 (Hologram back to teal) |

### 5.2 Tone-Lift Verification Results (sequential — one Godot run at a time)

- **Import check** (`--headless --path app --import`): **PASS** (exit `0`, **0 `SCRIPT ERROR`s**).
- **Scene lights**: **3** (`TableGlow`, `PlayerFill`, `RimLight` in `app/table.gd`); 0 new meshes, lights, or particle systems added.
- **Headless suites** (all 6 required suites + `silhouette_test`):

| Suite | Verdict Line | Exit Code |
| --- | --- | --- |
| `panel_test` | `PANEL_TEST PASS` | 0 |
| `wall_widgets_test` | `WALL_WIDGETS_TEST PASS` | 0 |
| `tools_test` | `TOOLS_TEST PASS` | 0 |
| `labels_test` | `LABELS_TEST PASS` | 0 |
| `park_labels_test` | `PARK_LABELS_TEST PASS` | 0 |
| `explode_test` | `EXPLODE_TEST PASS` | 0 |
| `silhouette_test` (extra sanity check for `model.gd`) | `SILHOUETTE_TEST PASS` | 0 |

*(Pre-existing `interaction_test` demo-swap mismatch and `round1b_exercise` `EX PERF draw_calls=102` timing artifact were not re-chased per the brief's hard rules.)*

### 5.3 Before / After Judgement (`shot-agy3.png` & `shot-agy4.png`)

Captures generated under `xvfb-run -a` (`1280×720`, `tools/shot.gd`):
- `captures/shot-agy3.png` — entrance (`0 1.6 1.35 → 0 1.0 -2.2, coast`)
- `captures/shot-agy4.png` — close table (`0.85 1.5 -0.35 → 0 1.02 -1.55, coast`)

**Judgement vs `design/look-reference-jon-20261124.jpg`, `captures/shot-pic16.png`, and `captures/shot-agy1.png` / `shot-agy2.png`:**
1. **Mid-tones (`agy1` → `agy3`)**: Major improvement. `shot-agy1.png` crushed the walls, ceiling, and floor to near-black and swallowed the suit platforms. `shot-agy3.png` lands cleanly between `shot-pic16.png` (too bright and blue) and `shot-agy1.png` (too dark): the side walls, back piers, integrated chamfered opening, ceiling, and cross-beam now read as genuine neutral dark-charcoal concrete with visible surface texture; the dark stone floor and veining read clearly with soft daylight spill; and both flanking suit platforms and side benches sit cleanly in the space without re-introducing `pic16`'s blue wash.
2. **Hero hologram (`agy2` → `agy4` & `agy3`)**: Fixed. In `shot-agy2.png`, the Star Destroyer's centre blew out to opaque white soup over a glaring white table pool. In `shot-agy4.png`, the Star Destroyer reads as a saturated electric-teal wireframe hologram at the preserved `0.82 m` display fit, with its terraced hull, side trenches, bridge tower, and translucent layered interior clearly visible over a dark-teal schematic and crisp cyan grid — closely matching the teal clarity of the reference's engine hologram. Even from the entrance (`shot-agy3.png`), the Star Destroyer reads as a distinct glowing teal silhouette above the table centre.
3. **Floor streak (`agy1` → `agy3`)**: Completely eliminated. The razor-thin vertical cyan line under the table in `shot-agy1.png` (caused by the untracked desktop fallback `RightHand/Laser` resting along `x = 0, y = 0`) and its concentrated specular hotspot are gone in `shot-agy3.png`, leaving a smooth, grounded satin floor sheen and clean table contact shadow.
