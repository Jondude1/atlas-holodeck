# WIP-STATE — Atlas Holodeck (updated 2026-11-25 11:25 ET)

## ITERATE ROUND 1 — P1 SUITS ON THE PADS: DONE + VERIFIED 2026-11-25 (Helios)
- The TRELLIS GLBs in design/suits3d/ (arrived 09:04–09:06, 299k/294k tris,
  each with a display disc) are IN: tools/decimate_suits.py (meshoptimizer,
  suit-venv) trims the disc (face centroids y < -0.44), decimates to
  27,482 / 25,000 tris preserving UVs/normals/PBR textures (textures capped
  1024 → 3.0 + 2.4 MB), feet at y=0, height 1.78 m → app/suits/*.glb.
  NOTE: meshopt simplify_with_attributes has a ctypes bug in the installed
  binding; plain simplify is index-only so attributes stay exact.
- app/suit.gd (SuitDisplay) + lab.gd _spawn_suits(): hero at (-2.5, 0.081,
  -4.3), heroine at (+2.5, 0.081, -4.3), facing +Z into the room. Wake:
  visitor < 2.4 m → visor slit + chest core fade up (emissive only, NO new
  lights), visor yaw-tracks visitor clamped ±0.65 rad; idle ember 0.04.
  Verified numerically (suit_capture.gd: WAKE hero=1.0 heroine=0.04).
- Gates: import 0 SCRIPT ERRORs; 14/14 suites PASS; budget A/B via
  tools/suit_perf.gd — baseline 78 calls / 89,866 prims → with suits 84
  calls / 142,852 prims (+6 calls, +52,986 prims = the suits), lights
  exactly 3 both. Captures: shot-suits-room / shot-suits-awake — room view
  matches the North Star composition; close-up shows some decimation
  faceting on the torso at arm's length (acceptable at room distance).
- design/suits3d/ source GLBs (22 MB) deliberately NOT committed; they live
  on disk only. tools/perf_probe.gd currently hangs on its hub-dependent
  CAD case while the hub is down — pre-existing, not a suit regression.
- NEXT round picks P2 (vista residuals) per the iterate priority list.

## ITERATE ROUND 2 — P2 VISTA RESIDUALS: DONE + VERIFIED 2026-11-25 (Helios)
- Water photo-tile (high terrace angles): baseline capture proved the blocks
  are the ocean photo's non-matching edges stamping a seam per tile. Fix in
  vista_water.gdshader: mirrored-repeat sampling (muv) for both layers, the
  fine layer rotated 0.62 rad off the coarse grid, and large-scale value
  noise (30–55 m) modulating layer mix + brightness. Terrace A/B:
  shot-r2-terrace-base (HEAD: hard rectangular tile grid) vs
  shot-r2-terrace2 (continuous water; only a faint mirror symmetry at the
  centre seam, far less visible than the tiles).
- Dome paler than painting beyond the 132° arc: measured — coast painting
  horizon (0.53,0.71,0.86) vs dome (0.68,0.80,0.89) + a 0.12 additive glow;
  lake painting (0.25,0.31,0.43) vs dome (0.36,0.48,0.66). Fix: coast
  sky_horizon → (0.57,0.72,0.87), lake → (0.28,0.38,0.55) in vista.gd DEFS;
  vista_sky glow band 0.12 → 0.05, sun sector 0.20 → 0.15; vista_card gains
  a side-edge melt (u near 0/1 → edge_color over 0.08) mirroring its top melt.
- Gates: import 0 SCRIPT ERRORs; 14/14 suites PASS; budget SUITPERF
  84 draw calls / 3 lights (unchanged — shader-only). Room capture
  shot-r2-room matches the North Star composition; sky through the opening
  now deepens like the reference painting instead of washing pale.
- CONCURRENT EDIT NOTICED: app/lab.gd changed at 11:26 ET mid-round (not by
  this round — Jon's "hero on both pads, heroine parked" instruction). Left
  untouched and OUT of this round's commit; its owner should commit it.
- NEXT round picks P3 (VistaSpill follows vista/grade swaps).

Checkpoint file per Jon's standing order (Claude limit protocol). Start
here after any interruption; then check git status/diff.

## CURRENT STATE (2026-11-24 17:37 ET) — v2.0 APK EXPORTED, all gates pass
- `builds/AtlasHolodeck-v2.apk` — 89,978,158 bytes. Gates: `--xr_mode_openxr`
  ✓, libopenxr_loader.so ✓, package com.jondude.holodeck ✓, RECORD_AUDIO ✓,
  apksigner ✓, signer SHA-256 d38ad98976d4df388a6d84faea908e26b604901c85771a
  692b7d5df76219e6e7 (matches installed builds). APKs gitignored, never
  committed. Awaiting Jon's on-device smoke test.
- Remote head `b109c621` (vista feel round); tree clean apart from runtime
  scratch (builds/logs/, __pycache__).
- Landed 2026-11-24 after the Round 6 notes below: Star Destroyer demo
  bundle + swap load-order fix; Antigravity polish + tone-lift (full gate
  green: 14/14 suites, exercise PASS, EX PERF resting 57, lights 3);
  harness fixes (interaction_test model-agnostic; exercise PERF samples
  3.6 s after panel dismiss); vista feel round (locked horizon, stepped
  haze, fog = painted horizon colour, one sun per vista, three-rate
  motion; coast painting NOT regenerated). Jon on the feel captures:
  "Much better."
- Open/blocked: R7-5 suits (TRELLIS.2 ZeroGPU quota — retry after reset);
  R7-1 TV panel (needs Jon's Jellyfin address + vault API key); Jon's v2
  headset checks (vista feel in stereo, hum, orb, arm, frame rate, hub
  LAN check-in, Tailscale path). Pi DOWN (Jon fixing 2026-11-25) — SSH
  routes via the Pi jump are dead; hub HTTP API via :3130 proxy works.
- Process lessons: agy headless needs --dangerously-skip-permissions;
  mock hub MUST launch with --assets AND --edit-assets; captures windowed
  under xvfb via tools/shot.gd only; VERIFY scheduled jobs by their run
  records — one was silently skipped by safety review on 2026-11-24.

## History (pre-17:37 state, for reference)

## ROUND 6 — ROOM REBUILD TO THE PICTURE (Jon 2026-11-24 09:54 ET, in progress)
Jon: "Take what I have now, extract the table and redo the garage to look like the
picture" (design/v2-vision-walkin.png) + wall readouts must become MOVABLE widgets he
can switch between readouts and PICTURES (R6-2, next) + Quest 2 budgets stay law.
The TABLE is untouched (his design). DONE so far:
- presence.gd NEW: the Atlas point-sphere extracted from data_station.gd (orb only;
  celebrate/set_fade kept). Lab places it LEFT at (-2.45, 0, 0.8). DataStation is out
  of the scene (file remains, unused); cad_bench.bind_presence() + overview_lines()
  getter feed the coming wall widgets; bench celebrate -> Presence.
- lab.gd: clutter DELETED (shelves, greebles, ceiling rig, screen bank, cables, floor
  trim, light shafts, workbench dressing). _bench_slabs() = bare dark slabs on both
  side walls (top 0.9475); props (lamp/crates) on the right slab; arm at the right
  slab's far end (3.5, 0.9475, -4.0); _suit_platforms() flanking the FAR opening at
  (±2.95, -4.15); _ceiling_bars() = 3 slim WHITE HDR bars (the picture's lighting).
  _seal() skips empty fx/screens builders. Dead dressing functions deleted.
- room.gd: opening MOVED to the back wall (OPEN_X0/X1 ±2.9, OPEN_TOP 2.9, TERRACE_Z
  -8.3): _build_opening() + _wall_segment_back() (3 segments, one shared material),
  full left wall restored, right wall texture now PLAIN (shelf silhouettes removed),
  terrace + railing rebuilt along z=-8.15. Wall strips on the back wall removed.
- vista.gd: deck rotated -90° in main.gd (faces the back opening now); coast card_top
  12.9->15.5, lake 12.2->14.5 (close the sky gap at the opening's top corners).
- hud.gd: StatusStrip raised (STRIP_POS y 2.32 — it was the "grey slab" silhouetted
  against the vista at centre view; bisected via captures dbg-*), arcs pushed out
  (ARC_X 2.35), smaller (1.35), dimmer (0.4).
- rig.gd AREAS/BLOCKS/PADS + prop.gd supports re-derived for the new layout.
  RIG_TEST rewritten for the new geometry (table block, side wall, pad flank guard,
  doorway->terrace, head-pivot turn) — PASS. panel/interaction/explode/props PASS.
- DEFAULT VIEW: spawn framing faces the opening (captures r6-* from the entrance end).
VERIFIED captures: r6-picture/r6-terrace/r6-lake/r6-wide (2nd pass in flight).
STILL TO DO: R6-2 wall widgets (movable, content types incl. pictures, persistence);
solidify test fix (lift-first drag — plane drag clamps to the inset BY DESIGN, LIFT_OFF
0.10 m; test now lifts to 1.8 before carrying; null guards added) — re-run pending;
commit R6 + props + solidify chunks; v2.0 export after R4-3/R4-4/R4-7.


## ROUND 5 (BRIEF-round5.md) — CHUNK A BUILT + VERIFIED 2026-11-24 (Helios)
Jon rejected the enclosed Gemini garages; direction = ONE OPEN WALL to a living vista like
the original Oculus Home, COAST chosen (concept-08), view SWAPPABLE. Research spec:
~/workspace/research_notes/oculus-home-vista-spec-20261124/report.md (hybrid backdrop,
≤10 calls + ~6 MB per vista, all resident, mood bundle swap; Godot Compatibility multipass
=> device calls ≈ 2× mono). BUILT: room.gd — left wall is now pillars + header around a
6.0 × 2.9 m opening (OPEN_Z0/Z1/TOP consts), titanium frame + cyan light line merged into
lab builders, terrace floor (x −7.3..−4.0) + railing; lab.gd — left workbench REMOVED,
_suit_platforms() (2 ring-lit pads flanking the opening; suits arrive via image-to-3D later).
vista.gd (class VistaDeck) + vista_sky/water/drift.gdshader: per vista = gradient dome +
painting on a 55 m cylindrical card (132° arc) + procedural water (coast/lake) + 2 mist
banks + cloud band; all shader-TIME motion, unshaded, fog off, layer 2 only. Paintings:
app/vistas/*.png (1536×672 Gemini masters, VRAM-compressed imports). Swap = panel VIEW
button (ui_panel.bind_vista) -> visibility toggle + 0.6 s tween of Environment fog/ambient/
sky colours + table omni tints (table.mood_lights()); mood numbers tuned so the interior
keeps its dark character (coast ambient 0.5 / lake 0.35 / valley 0.45, fog_density per vista).
GOTCHA hit: render_priority is NOT a MeshInstance3D property — assigning it aborted
_build_vista mid-build (Nil roots); removed, depth sorting handles transparency order.
VERIFIED: import clean; 6/6 headless suites PASS (panel needed the VIEW button at font 24,
"VIEW: COAST" — the bottom row's min width is the constraint); perf probe idle 77/79/83
(Round 3: 69/70/74 — delta = the visible vista + segments, inside budget); captures
r5-coast-room / r5-coast-terrace / r5-lake-room / r5-valley-wide eyeballed GOOD.
Exercise (mock hub) re-run for R5 in flight at checkpoint time — check builds/logs/exercise_r5.log.
NEXT: export + deliver R5A APK; then Round 5B (locomotion, interactables, off-table
solidify + permanence — specced in BRIEF-round5.md); R4-3 folds into future room work;
R4-4 + R4-7 still open (SD re-run needs the tailnet proxy back).

## ROUND 4 (BRIEF-round4.md) — IN PROGRESS 2026-11-24 (Jon's order: robust + compressed, all functionality kept)
Audit first (tools/census.gd): boot 189 nodes / 63 meshes / 55 unique materials; trebuchet
299 / 119 / 112. CHUNK 1 DONE + VERIFIED: R4-1 radial_texture cache in fx.gd (rest of R4-1's
cache candidates proved unsafe on inspection — nearly every material is mutated by a fade or
built per-texture; documented in BRIEF-round4.md). R4-2: holo.gdshader + holo_mesh.gdshader
per-part uniforms (aabb/wire/scan/y0/y1/flash) converted to INSTANCE uniforms (mechanism
probe-verified in Compatibility first: `instance uniform` syntax, set via
set_instance_shader_parameter); Fx.part_material()/mesh_part_material() are now singletons;
model.gd _mats array deleted (debug_scan() accessor added; 5 capture/perf tools updated).
Census after: boot materials 55->53, trebuchet 112->84 (upper bound — census also counts GLB
surface materials the renderer never uses under material_override). Suites: 6 headless PASS,
labels_test PASS. DEFERRED to the R4-7 pass: stardestroyer_local re-run (its /tmp/sd fixture
was wiped by a runtime restart; refetch from the hub is blocked while the tailnet proxy is
down — egress + Pi API both 000 on 2026-11-24 ~08:57 ET; NOT an app regression).
GARAGE (Jon, 2026-11-24): pixel-for-pixel asset ripping of Marvel's Iron Man VR DECLINED
(copyrighted assets); Jon approved the ORIGINAL recreation instead — same layout/behaviour,
own assets, his holo table centred. Gemini concept renders (via tools/gemini_image.py +
custom.google-gemini key; models gemini-2.5-flash-image) in design/garage-concepts/
01-wide / 02-table / 03-layout (+04–06) — ALL REJECTED by Jon; superseded by the open-wall
direction, see ROUND 5 above. Asset pipeline research done: TRELLIS.2
(MIT, HF demo ~1 model/day, needs decimation) or Tripo free tier for hero props via
image-to-3D from the Gemini concepts. Garage build folds in R4-3 (room rebuild = static merge).

## ROUND 3 (BRIEF-round3.md, brief #19) — DONE 2026-11-20 ~13:17 ET (Helios takeover build)
Stark fidelity + living lab, table-first per Jon's steering (fidelity NOT leashed, 11:39 ET).
SHIPPED: R3-10 explode label de-overlap (reading-plane relaxation, labels_test PASS 27/27 zero
overlaps); R3-6 scoped (pinned part label gains true-dims line; elbow leaders + material lines
not built — materials aren't in manifests); R3-1 model glow (pool + column + motes following the
active model); R3-2 table hot-centre falloff; R3-11 living lab: original-design robot arm on a
keyframed task loop (cyan emission sheen added after captures showed it reading as a black post
under ACES), data station (real-data wall + schematic pedestal), and the Atlas presence —
REPLACED by Jon's direction (2026-11-20 12:18-12:24 ET): no bust/figure; a DENSE living sphere
of ~3,900 points (2,600 churning core, two tilted orbital rings, bright nucleus), cyan only,
modelled on the JARVIS/Vision projection; celebrate = swell + churn surge. R3-4 ACES tonemap +
glow threshold 0.85; R3-8 animated scanline term in both holo shaders; R3-9 fake floor gloss
strip in front of the table; R3-7 sound (synthesized hum bed after boot, materialize sweep,
explode sweep on slider release, error tone on job failure). Trims: scanner beam + empty
schematic disc hidden when unused. VERIFIED: all 6 headless suites PASS; library_test PASS;
labels_test PASS; round1b_exercise PASS (its PERF: 89 draw calls / 3 lights); perf probe idle
69-74 (panel forced-always = 100-105 worst case; lived panel renders UPDATE_ONCE per R2-6).
Exported builds/AtlasHolodeck.apk = 83,251,255 bytes, artifact gates verified, signer identical.
Round 2.5 APK kept as builds/AtlasHolodeck-round25.apk.
ALSO THIS ROUND (Jon's live test): the Victory-class Star Destroyer STL exposed two hub bugs —
(1) STL->GLB conversion kept the raw filename (with .stl) as the node name so the app rejected
it by name-match (fixed: conversion names the node by stem; app also adopts a lone mesh for
one-part manifests — cad_model.gd), (2) no Z-up->Y-up rotation so parts stood on their tails
(fixed: -90 deg X rotation in the converter). Hub backups: atlas_voice.py.bak-20261120-namefix
(+ the pre-rotation deploy used the same deploy path). SD_TEST PASS end to end (spawn 11 s in
sim, drag 0.22 m, yaw 45 deg, 2x scale). NEXT: Jon headset retest of Round 3; Round 4 candidates
in ITERATION-BACKLOG (R3-5 HUD density was NOT built; R3-3 burst refinement partial).

## ROUND 2.5 (BRIEF-round2b.md, brief #18) — DONE 2026-11-20 ~11:30 ET (Helios takeover build)
Parts Library, hub + app. HUB (deployed live, backup atlas_voice.py.bak-20261120-r25):
GET /atlas/library (walks the Athena save-back tree + 3d-work/library/*.stl via
one container script; creates the drop folder), POST /atlas/library/<id>/load
(materializes a hub job folder — spawn/edit/print reuse Round 1 machinery),
POST .../delete {confirmed:true} (409 without), STL->GLB in the container
(trimesh, mm->m exact), STL jobs have NO job.py: REST edit_of 409s and the
voice route answers edit_nosource in words; print dry-run accepts model.stl.
Tests: tests/test_voice_library.py 5/5, round1b suite 8/8 no regressions.
LIVE-PROVEN: list returns the 2 real save-back brackets; load pulled the real
590,276 B glb; a 20 mm calibration cube STL (left in the drop folder on
purpose) lists at 0.79 in and its converted GLB bounds measure exactly
0.02 m. APP: panel LIBRARY toggle (rows: name/dims/date, EDIT holodeck-only,
DEL -> confirmation card), fetch spawns via _on_done; library_test 10/10,
all 6 headless suites PASS, exercise 12/12, PERF 79 draw calls / 3 lights.
Exported builds/AtlasHolodeck.apk = 83,139,827 bytes, artifact gates verified,
signer identical to installed builds. Round 2 APK kept as
builds/AtlasHolodeck-round2.apk. NEXT: Round 3 (fidelity + living lab,
table-first cap applies).

## ROUND 2 (BRIEF-round2.md, brief #17) — DONE 2026-11-20 ~11:05 ET (Helios takeover build)
All 11 items coded by Helios directly (Claude session limit). Verified:
ALL 7 suites PASS — explode, panel, interaction, print_flow, silhouette,
failure, and the full round1b exercise 12/12 (exit 0) against the mock
hub; PERF 76 draw calls / 3 lights with a CAD model on stage (budget 90).
Exported builds/AtlasHolodeck.apk = 83,132,355 bytes; artifact gates
verified by Helios (--xr_mode_openxr, libopenxr_loader.so, RECORD_AUDIO,
package com.jondude.holodeck, hub_secret baked, signer SHA-256 IDENTICAL
to the installed Round 1B build so it installs over it). Round 1B APK
kept as builds/AtlasHolodeck-round1b.apk.
TWO REAL BUGS found + fixed by the exercise (both pre-existing risks,
not Round 2 regressions): (1) Sfx.play_and_wait awaited the raw audio
`finished` signal uncapped — under a windowed dummy-audio run it never
fired and boot hung forever before voice start; now deadline-capped
(clip length + 1.5 s). (2) Hub probe timeout 2.0 s was too tight for a
frame-polled HTTPRequest on a loaded renderer — the probe falsely
reported LOCAL ONLY and voice arming fell into the long retry backoff;
_status_ok + _fetch_brain now 5.0 s. (The sandbox's llvmpipe <1 FPS
boot is what exposed both; on the Quest at 72-90 FPS neither bit, but
the fixes are strictly safer.) Jon's steering (2026-11-20): TABLE
FUNCTION FIRST — hobbyist engineering workspace; atmosphere secondary;
backlog header carries the rule. Firewall blocker RESOLVED same day
(UFW LAN rule added with Jon-provided sudo; LAN path proven from the
Pi) — in-headset voice/CAD unblocked. NEXT: Round 2.5 Parts Library.

## ⚠ CLAUDE SESSION LIMIT — TAKEOVER RECORD (2026-11-20 ~09:58 ET)
The Round 2 Claude Code run (BRIEF-round2.md) hit the session limit
IMMEDIATELY ("You've hit your session limit · resets 12:40pm
America/New_York") — it changed NO code. Per Jon's takeover order,
Helios coded Round 2 DIRECTLY in this tree (same brief, same gates).
When Claude resumes, it re-reads this file + git log/diff first.
Round 1B commit+push DID complete before the stall: remote head
de6cfe58 (hub_secret not in commit — verified count 0).
Takeover progress (Helios, direct):
- [x] R2-10 render settings: project.godot — MSAA 2x (anti_aliasing/
  quality/msaa_3d=2), openxr/display_refresh_rate=90.0, foveation_level=2.
  On-device effect is Jon-verifiable only.
- [x] R2-7 CAD stage narration: cad_bench.gd maps the hub job's real
  `stage` (queued/writing/repairing/building/fetching/saving) into the
  status text with elapsed seconds (was one blanket "BUILDING n s").
- [x] R2-11 real brain tier: hub /atlas/voice-status now returns
  brain_model + brain_local (DEPLOYED to Obelisk 2026-11-20, backup
  atlas_voice.py.bak-20261120-r2, md5 verified, atlas-server restarted;
  phone routes re-verified: status 200, ask POST 401 w/o token,
  transcribe 200). Live answer: atlas:14b / local=true. App: Hub.probe
  fetches the tier after a base wins; HUD shows e.g. "LOCAL · ATLAS:14B",
  "HUB" if the fetch fails, "OFFLINE" if no hub. (Was blanket "HERMES".)
- [x] R2-8 skippable boot: any controller button (or desktop key) kills
  the boot tweens, sets final ring/fade state, runs the normal
  completion once (_boot_finished guard). Headless boot verified clean.
- [x] R2-1 haptics: hand.gd buzz() (no-op unless XrBoot.ready_ok) wired
  to grab (0.03s/0.5), release (0.02/0.3), bench select (0.04/0.45),
  panel poke (0.015/0.25), materialize-complete both hands (0.06/0.3).
- [x] R2-3 easing: app/ease.gd (class_name Ease — mv = cubic-out,
  fd = sine-in-out); the linear materialize fades, tether/readout
  fades and button-press fade now use it. NOTE: after adding a
  class_name file, run `godot --headless --path app --import` once or
  every script fails with "Identifier Ease not declared".
- [x] R2-2 hover: parked models glow whole-model (model.set_all_hot,
  flash 0.6 all parts, labels untouched) as the bench-select affordance;
  active-model per-part hover unchanged; panel buttons already had
  hover styleboxes.
- [x] R2-9 hub greeting: main._greet() — hub answered => Atlas speaks a
  time-of-day greeting via hub TTS (say()); offline => recorded clips.
  2.5 s grace for the un-awaited boot probe. confirm_render follows both.
- [x] R2-6 panel: idle is now UPDATE_WHEN_DIRTY + a 5 s safety pulse
  (was a full re-render every 0.5 s, ~34 draw calls each, forever).
- [x] R2-4/R2-5 hitch: model._build_schematic no longer paints inline;
  the silhouette texture is painted in a deferred call and materialize's
  schematic fade waits for it (_schem_fade_pending). Same path serves
  the boot demo bracket (R2-5). Paint cost itself unchanged (~0.4 s on
  its own frame instead of stacked onto the spawn frame).
- [ ] Full test suites + headless boot + export + gates + captures —
  IN PROGRESS (Helios).

## ROUND 1B (BRIEF-round1b.md, brief #16) — DONE 2026-11-20, exported, awaiting Jon's headset feel-test
No git commits made. Hub source of truth: `~/workspace/atlas-overlay-build/repo/obelisk/atlas_voice.py` (pre-change copy kept at
`.atlas_voice.py.pre-round1b`). **DEPLOYED to the live hub** (Obelisk /home/jon/Projects/Anzu-1/obelisk/atlas_voice.py, md5 148e6ae4...;
backup `atlas_voice.py.bak-round1b-<stamp>` beside it; atlas-server.service restarted, active). Phone routes re-verified after:
/atlas/status 200, token gating 401, /atlas/voice-status 200 (kws true), /atlas/ask 200 (answer text is the known degraded
brain-chain issue, unrelated). Helper scripts: ~/workspace/tooling/{deploy_voice,verify_hub,live_two_step,export_holodeck}.*
- [x] R1-4 edit-in-place — hub `last_job` + edit-intent routing + writer gets parent script; app swaps the model in place.
  Proof: hub pytest (8 tests, tests/test_voice_round1b.py); app `tools/round1b_exercise.gd` vs `tools/mock_hub.py --edit-assets`
  (same bench slot / position / orientation / scale, old node freed); LIVE two-step on the real hub (3x1x3 in -> 3x1x5 in + holes,
  the real writer revised job A's script).
- [x] R1-8 send-to-print, DRY RUN ONLY — panel SEND TO PRINTER + voice entry -> confirmation card (part, PLA, printer S1, est. time)
  -> explicit confirm only; hub POST /atlas/print-job returns a dry-run plan, never slices/contacts the printer, logs
  `[print-job DRY-RUN]`; `live_print()` stub + `PRINT_LIVE=False` is the seam (needs Jon's sign-off). Proof: print_flow_test.gd
  (21 checks), hub pytest, exercise captures. Panel viewport grew 640x720 -> 640x800 (quad 0.8x1.0, y 1.47) to fit the new row.
- [x] R1-12 silhouette — `Blueprint.make_silhouette` (real outline + real plan-view through-holes + hatch). silhouette_test.gd PASS
  (holes at the exact CAD positions/radii); captures r1b-silhouette-{bracket,treb}-{new,old,model}.png. ~0.35-0.45 s one-off at spawn.
- [x] R1-9 save-back — hub copies model.py/.step/.glb/manifest/job.json to Athena `3d-work/out/holodeck/<slug>-<job_id>/`
  (+ job-folder + runner out/voicecad copies kept); verified LIVE on Athena (5 files per job).
- [x] Backlog: R3-10 explode label de-overlap added to ITERATION-BACKLOG.md.
- [x] Export: builds/AtlasHolodeck.apk 83,127,176 B (release, debug cert), apksigner Verifies (v2), package com.jondude.holodeck,
  _cl_ = --xr_mode_openxr, libopenxr_loader.so, RECORD_AUDIO + INTERNET, hub_secret.cfg baked, VR category x2, networkSecurityConfig.
  Round 1A APK kept as builds/AtlasHolodeck-round1a.apk.
Draw calls: 76-77 (bracket revision + parked bracket, panel active), 3 lights; the 27-part trebuchet stays above 90 (known, R2 item).
Headset-only (NOT proven): confirm-button/ray ergonomics on the new card, spoken-yes over the real mic, in-place swap feel while holding
the model, schematic legibility at table distance, real print flow (not built by design).

## (history) Round 1A notes — Round 1B above is now done; next is Round 2
Round 1A (brief #15) built + headless-proven (explode/panel/failure/interaction tests PASS). Exported 2026-11-20 09:01 in the recovery run: builds/AtlasHolodeck.apk, 83,108,181 bytes (release export, debug cert CN=Android Debug), apksigner Verifies (v2), package com.jondude.holodeck, assets/_cl_ = --xr_mode_openxr, lib/arm64-v8a/libopenxr_loader.so present, RECORD_AUDIO + INTERNET in manifest, hub_secret.cfg baked. Not yet handed to Jon; awaiting his headset feel-test. (Earlier note claiming 'exported' was premature: the first run was killed before export.) Draw-call probe not re-run in recovery; numbers below are from the earlier run. Round 1B items, in
ITERATION-BACKLOG.md order, are NOT started: follow-up edit-in-place (R1-4, hub keeps last job id + edit intent),
print path (R1-8, needs Jon's sign-off before touching the printer), real silhouette schematic (R1-9), save-back
path (R1-?), then Round 2 (smoothness: haptics, hover reticle, spawn hitch) / Round 3 (Stark fidelity).
Round 1A as built (all in app/, no commits made):
- Audit risk 1 REAL, fixed: explode used node origins; the glb exporter bakes world-space verts (all origins 0), so a
  27-part model lifted straight up (old code: 0/27 parts moved in XZ). model.gd now uses each part's AABB centre
  (also fixes center_local/grab centre). Proof: tools/explode_test.gd (old code FAIL, new PASS).
- Audit risk 2 REAL, fixed: panel content needed 570 px in a 480 px viewport (RESET FLOOR fully off-panel). Viewport
  now 640x720 (quad 0.8x0.9, y 1.42); part list is a fixed 4-row scroller so it never grows. tools/panel_test.gd.
- R1-1/R1-2 grabbable.gd: plane drag at table height (yaw follows hand twist), lift >10 cm = freehand, release over
  the slab settles (0.35 s ease, tilt levelled), off-table stays; release velocity coasts (exp friction 3.2/s slide,
  2.4/s spin), flick resting >0.5 m from centre parks via CadBench. Constants at the top of grabbable.gd = tuning knobs.
- R1-3 RESET MODEL (panel + LEFT menu TAP; long-press = floor fix unchanged), TRUE SIZE button, floor button renamed
  FIX FLOOR HEIGHT, scale buttons ease.  R1-7 CadBench.select(): point right ray at a parked model + trigger = pull to
  centre (on-stage model parks into the vacated slot; panel/HUD/readouts retarget).  R1-6 real part list (rows,
  scroll arrows, right-stick scroll over the panel, press = pin highlight+name).  R1-5 FailureReason (failure_reason.gd):
  hub detail -> one sanitized sentence; no hub change needed.  R1-11 A/X = extra hold-to-talk; ray hover raises the
  part name + rim.
- Perf: panel SubViewport now renders only while poked (pointer/voice/list) + 0.5 s idle refresh (was always).
Headless tools (all in tools/): explode_test, panel_test, failure_test, interaction_test (46 checks), perf_probe,
round1_capture (captures/r1-*.png). Run: godot --headless --path app --script ../tools/<name>.gd
NOT proven headless (headset only): drag/inertia FEEL + friction/flick thresholds, ray hover on real controllers,
A/X + menu-tap button mapping on Touch controllers, right-stick scroll, trigger-on-parked-model select, and the
real PTT start/stop from A/X (hand logic proven, VoiceLink path was proven in brief #11).
Known: 27-part trebuchet fixture = 128-153 draw calls (3D parts+tethers), outside the 90 budget; realistic 1-3 part
models measure 59-63 idle / 85-89 panel-active. Parked many-part models still cost draws (R2 perf item).

## Current state: COMBINED BUILD COMPLETE — awaiting Jon's headset retest
- The combined build (floor #10 + voice #11 with PTT addendum + lab
  polish #12) is DONE, exported, artifact-verified by Helios, and being
  committed/pushed this session. APK: builds/AtlasHolodeck.apk,
  83,091,342 bytes, `--xr_mode_openxr` in _cl_, libopenxr_loader.so
  present, RECORD_AUDIO + INTERNET in manifest, apksigner Verifies (same
  Godot debug cert — installs over the top).
- Download link given to Jon (Muse storage, expires 2026-11-21 ~21:25 ET).

## What the build contains (all verified in the resume run's report)
- Floor: STAGE → LOCAL_FLOOR → LOCAL reference-space priority, [XR]
  granted-space + camera-height logging, RESET FLOOR panel button +
  left-menu long-press.
- Voice: hub /atlas/voice-stream (websocket, live on Obelisk) +
  /atlas/speak + /atlas/cad-job — all live; phone routes re-verified
  after testing. PTT is PRIMARY: big TALK panel button + left-trigger
  hold (conflict-free: left hand has no pointer role, grip = grab, menu
  long-press = RESET FLOOR); right trigger off-panel secondary. Mic is
  NEVER hot outside a hold (wake_enabled=false default; the OS mic starts
  on press, stops on release). Barge-in: PTT press cuts a spoken reply.
- Wake word: NOT proven ("Hey Atlas" fired on synthesized speech 2×, bare
  "Atlas," didn't) — OFF in this build by design; revisit later.
- CAD: pipeline live on the hub (Shelf Bracket + Phone Stand jobs
  completed; in-app round-trip downloaded a 501,944 B glb and
  materialized it, dims 4 × 1.25 × 4 in). Queue is SERIAL — a long job
  (e.g. main chat's N64 mount test, 9871393bc4) blocks later jobs.
- Lab polish: lab.gd/mesh_builder.gd + lightfx/pulse/screens shaders,
  wall screens, ceiling shafts, set dressing. Draw calls 62 rest/exploded,
  worst case 80 — inside the ≤90 budget; 3 lights.

## Known problems (not app bugs)
- **General-question replies are slow/degraded:** /atlas/ask takes ~60 s —
  the hub's chat path is landing on atlas:14b (~4 tok/s, reasoning-heavy)
  instead of the Hermes/Claude chain, blows the hub's 25 s voice budget,
  and falls back to a report digest (once returned raw "athena exec:"
  text). Flagged to main chat — it's an Atlas brain-chain issue; CAD
  requests are unaffected (different route). Fix belongs on the hub side.
- Hub CAD queue serial + a `claude -p` writer can run long on complex
  prompts (N64 job "writing" since 21:11 ET hub clock at last check).

## Next steps
1. Jon installs + retests: floor height (RESET FLOOR if needed), hold
   left trigger (or TALK) → ask for a part, lab feel, frame rate.
2. If Jon's logcat is needed: Quest USB → Athena; filter `[XR]` lines.
3. Wake word: only revisit with a real-voice test plan; never block on it.
4. Brain-chain fix (hub /atlas/ask latency) — main chat / Atlas side.

## How to build / verify (unchanged pipeline)
- Godot: ~/workspace/tooling/godot/Godot_v4.7.2-stable_linux.x86_64;
  headless: `timeout 60 <godot> --headless --path app` → "boot complete"
  + "materialize complete".
- Export: RELEASE export, JDK 17 on PATH, GRADLE_USER_HOME=
  ~/workspace/tooling/gradle-home-holodeck, keystore env
  GODOT_ANDROID_KEYSTORE_RELEASE_* → ~/.local/share/godot/keystores/
  debug.keystore worked for the resume run.
- APK gates before ANY APK goes to Jon: _cl_ has --xr_mode_openxr;
  libopenxr_loader.so present; RECORD_AUDIO in manifest; apksigner OK.
- Hub: additive changes only; restart the hub service only, never the
  machine. Token lives in gitignored app/hub_secret.cfg, baked at export
  via the preset include_filter — never commit it (check git status for
  hub_secret before every commit).

## 2026-11-24 late morning — R7-3 + Jon fixes + R7-4 (Helios)
- R7-3 bench tools DONE: tape measure (panel MEASURE + trigger pins, AABB-face approximation, house-format readout), section view (clip_y in both shared holo shaders via Fx.set_section), 15° snap ticks in grabbable plane turns, RefBoard (Prop; BOARD button; double-grab flips picture). tools_test 17/17. Panel funded by parts-scroll trim (content 799/800).
- Jon fixes (same morning): opening frame REMOVED (jambs/head/light-lines out, flush threshold stays; the "inner rectangle" was the frame's inner face); suit pads moved (±2.95,-4.15) -> (±2.5,-4.3) — they overlapped the bench slabs (3.53 > 3.2); rig pad guard 0.82 -> 0.68 (was eating doorway lanes; rig_test lanes recalibrated to the real corridor x=1.62); gulls/boat pushed to the far sky (bases x -47..-56, orbit r 6-12, boat x -52.5 slower).
- R7-4 (minus suits): orb drift_visit on job land (presence.gd; bench calls it beside celebrate); tabletop tap = knock (new tap.wav) + hot_pulse ring in grid shader (hot_point/hot_pulse uniforms), hand-tracked downward crossing only; props knock on set-down. responds_test PASS. Suits visor/wake moves to R7-5.
- Pushes: R7-2 remote 785d80a5; R7-3 remote 4666bffc. Still outstanding: library_test success-path re-run for the hub probe race (background run never produced a verdict under load).

## 2026-11-24 midday — R7-6 living vista + demo swap (Helios)
- R7-6 (Jon: balcony INTO the scene, look down at cliffs/water, backdrop must MOVE): terrace extended (TERRACE_Z -8.3 -> -8.8, railing -8.65, rig terrace area -8.55) so the balcony reaches into the vista; NEW headland per vista (vista.gd _headland_mesh): noise-displaced cliff skirt tucked under the terrace (local x -6.9) dropping to the sea (coast water_y -1.6 -> -4.2, drop 9.5; lake -3.0/7.0; valley slope 8.5, grass tint), photographic basalt texture (design/textures/cliff-rock.png), ledge quantization + wet darkening vertex colours, grades tint it via _rocks. Foam collar at the waterline (drift shader, streaky procedural foam tex, scrolls ashore). Water: subdivided plane + vertex swell + shore wash bands + jitter octave + near-calm sparkle. Profile lesson: pow 0.55 plumb drop hid under the railing; pow 1.15 apron reads from above. Terrace fascia box added (room.gd) — without it, sightlines under the paper-thin terrace lip showed the headland's raw top row as "teeth" in entrance captures.
- TAILSCALE PROBE RACE **VERIFIED** 2026-11-24: library_test PASS 10/10 against the mock hub (the earlier background FAIL was a harness error: mock_hub --assets pointed at cad-jobs/ root instead of a job folder, so no hub ever started — the probe correctly reported unreachable).
- DEMO SWAP (Jon): main.gd _bundled_demo_swap() — if res://demo/stardestroyer.glb + .json exist at boot, a CadModel takes the stage and the bracket retires hidden; machinery verified with a stand-in GLB (5 suites PASS incl. model-agnostic tools_test aims). **The real GLB is NOT yet bundled**: it lives in the hub job folder on Obelisk (edce928564) and the tailnet proxy from this VM is DOWN (proxy closed during CONNECT, since ~08:57); paramiko also had to be reinstalled into ~/workspace/tooling/ssh-venv (use that python for obelisk.py). When the proxy returns: fetch model.glb + manifest.json from ~/.local/share/atlas/cad-jobs/edce928564/ on Obelisk into app/demo/, set the manifest name to "Victory-class Star Destroyer", re-run the gate + a capture, commit.

## 2026-11-24 midday 2 — R7-6b moving backdrop + R4-3 tether merge (Helios)
- R7-6b (Jon: "that weird plane right after the balcony — take it away; get a background like a gif looping endlessly, cliffside with the ocean rolling beneath"): the flat procedural water is GONE. The sea is now a photographic ocean texture (design/textures/ocean-surface.png) scrolled at two scales/directions in vista_water.gdshader (swell + glitter + ashore wash kept as overlays). The far painting itself now lives: vista_card.gdshader breathes the painting's SEA BAND (slow UV swell + faint foam streaks, TIME-looped, endless) — per-vista "sea" band in DEFS, in TOP-ORIGIN shader UV (v=0 at the image top — the first attempt used bottom-origin values and painted wavy contour lines across the sky; fixed, verified clean in shot-pic13). Grades tint the card via the shader's tint param (_cards now holds ShaderMaterials). Headland + foam collar stay (the cliff beneath the balcony).
- R4-3 tether merge DONE: model.gd leader lines were 1 MeshInstance per part (27 draw calls exploded) — now ONE merged ArrayMesh rebuilt in _update_tethers Pass 3 (thin oriented boxes, outward-wound); per-part line visibility (park/unpark/_set_state) maps to the mesh's visible flag; pin styling maps to a _line_hidden set consulted at rebuild. LABELS_TEST PASS (27 labels, no overlaps), explode/interaction/panel suites PASS, import clean.
- ANTIGRAVITY CLI (Jon's order, main thread of this chat): installed from Google's official installer (reviewed first) — ~/.local/bin/agy v1.5.16; --print/--mode/--model flags all present. NOT yet signed in: first run prints a Google OAuth URL + waits ~60 s for a pasted code — do it live with Jon (the URL is single-shot).
- R4-4 DONE 2026-11-24 (label textures): park() now blanks every tether + dim label text (an empty Label3D holds no texture) and unpark() restores them (captions recomputed; dim texts kept in _dim_texts; a pinned part's two-line label re-asserted via _style_part). Parked bench models — up to 4 × 27 labels — no longer carry texture memory. New proof tools/park_labels_test.gd PASS 6/6; labels/explode/interaction suites PASS.
- ANTIGRAVITY first sign-in attempt FAILED at token exchange (invalid_grant): the auth URL had been hand-rebuilt from a wrapped 80-col TUI. Fix that worked: run agy under `script -qefc "sh -c 'stty cols 400 rows 60; exec ~/.local/bin/agy'"` so the URL prints (nearly) unwrapped and can be copied byte-exact. Second attempt in flight 2026-11-24 11:33 ET.
- ANTIGRAVITY SIGNED IN 2026-11-24 11:41 ET: TUI confirms dmj1621@gmail.com (Google AI Pro), Gemini 4 Neon (High); data-collection opt-in left OFF; workspace /home/hatch trusted; `agy -p` verified ("ready"). Token at ~/.gemini/antigravity-cli/antigravity-oauth-token.
- R8 LOOK WORKFLOW (Jon, 2026-11-24): Gemini leads look & feel/UI polish ("It does UI and UX better than you and Claude") — presentation only, function frozen. Governing reference: design/look-reference-jon-20261124.jpg. gemini_image.py gained --ref (image conditioning). First target: design/polish-targets/target-entrance-01.png (Gemini restyle of shot-pic13 from the reference) — deltas to build: much darker polished room + glossy floor reflections, framed teal data panels (waveforms/gauges) on both walls, larger denser orb at the left station, dark slab table with fine grid + floating ring under the part, chamfered opening corners, suits on ring pads (assets still TRELLIS-quota-blocked), slim dim ceiling bars, subtle floating rings over the table's far end (from Jon's reference — they return as environment, chrome toggle still governs UI clutter).

## ROUND A — HERO HOLOGRAM PRESENCE (2026-11-25)
- cad_model.gd DISPLAY_FIT_M 0.82 → 0.96. Tried 1.4 first: the destroyer's long
  axis lies across the table's DEPTH (its 5.54 in maps to model Z), so at 1.4 the
  volume measured 1.40 m in Z vs the 1.22 m slab / 1.0 m inset — overhang front
  and back (demo_probe AABB). At 0.96: displayed (0.571 × 0.345 × 0.961) m,
  inside the inset with margin; dims readouts unchanged (3.3 × 5.54 × 1.99 IN —
  dims divide by display_scale). NEXT-ROUND OPTION (needs a Jon/parent call):
  yaw the demo 90° in the swap so its length runs along the table's 2.2 m axis —
  that would make a ~1.4 m fit clean.
- Hero rings (new app/hero_ring.gd + cad_model._build_hero_rings): two TorusMesh
  rings as model children sharing Fx.mesh_part_material() (instance params pin
  the resolved state; the section clip applies to them too). RingUnder: R =
  0.62 × footprint bounding radius, flat, 5 mm over the model's base plane,
  wire-alpha 0.60, yaw +5°/s. RingOrbit: R = 1.18 × bounding radius, tilt 18°
  about X, pivot raised so its low arc clears the base plane, wire-alpha 0.42,
  yaw −3.5°/s. Rotation lives on the pivots because grabbable toggles
  set_process on the model root. Visibility rides _set_state/park/unpark
  overrides: shown when materialized, hidden when parked, follow grab, scale
  and solidify as children. Cost: +2 draw calls; lights still 3.
- Verification: import 0 SCRIPT ERRORs; suites panel/tools/interaction/labels/
  explode/solidify/wall_widgets ALL PASS. solidify needed a clean standalone
  re-run (PASS in ~10 s): under parallel cron contention it starved once and
  false-exited once — environment flake, not a regression. Captures:
  ra-base1/2 (before), ra-try140 (1.4 diagnostic), ra-hero1/2 (after),
  demo_probe AABB-verified at both fits.
- Residuals: from the entrance the ship still washes pale against the bright
  vista (fresnel volume vs bright backdrop — a shader/exposure matter for a
  later round); shot.gd snaps ~2 frames after boot-skip, so entrance stills
  catch the demo mid-materialize — judge the ship from ra-hero2 and the probe
  capture, the rings from either.
- PUSH STATUS (2026-11-25 11:35 ET): commit d0957cf is LOCAL ONLY. Two
  push_api.py attempts this round did not land (remote head still b109c621;
  the script re-uploads all 418 blobs / 163 MB every run at ~0.1-0.3 MB/s
  through the proxy and the first attempt exited silently mid-transfer).
  Re-run `python3 push_api.py` when the network is idle; expect 15-45 min.
  NOTE: a447f8e (Iteration A) is also ahead of remote — one push syncs all.
