# WIP-STATE — Atlas Holodeck (updated 2026-11-19 ~21:30 ET)

Checkpoint file per Jon's standing order (Claude limit protocol). Start
here after any interruption; then check git status/diff.

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
