# BRIEF #13 — Resume the interrupted combined build (voice #11 + polish #12)

The combined run (briefs #11 + #12 on the #10 floor base) was killed by a
runtime restart ~1h8m in, before its final export and report. A checkpoint
audit by Helios found most of the work ON DISK. Do NOT start over: audit,
complete what's missing, export once, report.

## Already verified on disk / live (trust, but confirm during your audit)
- App tree has: voice.gd, cad_bench.gd, cad_model.gd, lab.gd,
  mesh_builder.gd, holo_mesh.gdshader, lightfx/pulse/screens shaders,
  sounds/wake.wav + end.wav, tools/mock_hub.py, tools/voice_exercise.gd,
  tools/room_views.gd, cad-jobs/, captures incl. shot-05-listening and
  shot-06/07 voice-cad, captures/before-polish/ + captures/lab-views/.
- Hub: `atlas_server.py` modified + new `atlas_voice.py` in
  ~/workspace/atlas-overlay-build/repo/obelisk/; the LIVE hub on Obelisk
  answers /atlas/status and its openapi.json contains cad-job routes.
  **Open question: no voice-stream route appeared in the openapi grep** —
  establish whether /atlas/voice-stream is actually registered and working
  (it may live in atlas_voice.py as a mount the grep missed).
- builds/AtlasHolodeck.apk is still the brief #10 floor build
  (83,023,558 bytes) — the combined export never happened.

## Your job
1. **Audit** the tree + live hub against BRIEF-voice-cad.md (including its
   PTT PRIORITY ADDENDUM — read it; it postdates the killed run's start)
   and BRIEF-lab-polish.md. List per-brief: done / partial / missing, with
   evidence (file, route, test), not vibes.
2. **Complete** the missing pieces. Known likely gaps: voice-stream route
   verification/fix on the hub; the PTT promotion from the addendum (big
   TALK panel control + conflict-free controller hold; mic NEVER hot
   outside a hold when wake is off; KWS non-blocking — ship PTT-only if
   the spotter isn't proven, and say so); final SPEC/README updates.
3. **Hub safety:** additive only; after any hub change, re-verify
   /atlas/status, /atlas/ask, /atlas/transcribe still answer (the phone
   depends on them). Restart the hub service only, never the machine.
4. **Tests:** run the scripted PTT path end to end (hold → transcript →
   reply, and a CAD job round-trip producing a real glb + manifest) using
   the existing tools (mock_hub.py / voice_exercise.gd) and/or a live-hub
   test client. Report wake-word status separately: proven / not proven.
5. **Export ONE APK** and validate the brief #9 way: `--xr_mode_openxr` in
   assets/_cl_, libopenxr_loader.so present, RECORD_AUDIO in the manifest,
   apksigner verify, package, size. Headless run clean; final captures
   (incl. before/after polish pairs) in place.
6. **Report:** audit table (per brief: done/partial/missing + evidence),
   what you completed, hub deploy state, test evidence with the
   proven-vs-headset-only split, draw calls, APK facts. No git commits.
