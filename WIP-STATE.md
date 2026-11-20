# WIP-STATE — Atlas Holodeck (updated 2026-11-20)

Checkpoint file per Jon's standing order (Claude limit protocol). Start
here after any interruption; then check git status/diff.

## NEXT WORK: Round 1B (BRIEF-round1.md Round 1A is DONE, 2026-11-20)
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
