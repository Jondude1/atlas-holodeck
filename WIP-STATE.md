# WIP-STATE — Atlas Holodeck (updated 2026-11-20)

Checkpoint file per Jon's standing order (Claude limit protocol). Start
here after any interruption; then check git status/diff.

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
