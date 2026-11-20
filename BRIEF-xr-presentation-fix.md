# BRIEF #9 — Fix on-device XR presentation (Quest 2 shows Meta 3-dots forever)

## Symptom (Jon, on his Quest 2, 2026-11-19)
The app launches, the boot voice lines play and are audible, but the display
never leaves Meta's own 3-dot loading screen — the app never presents a VR
frame. So: the Godot main loop runs (audio proves it), but the OpenXR
presentation path never comes up on device. Our headless captures can't see
this — they render through the desktop fallback camera.

## What inspection already established (don't re-litigate)
- project.godot: renderer "mobile", xr/openxr/enabled=true.
- main.gd _ready: find_interface("OpenXR") → initialize() → use_xr = true,
  else fallback camera. XROrigin3D + XRCamera3D exist in main.tscn.
- Export preset: xr_mode=2, Meta plugin on, quest_2_support=true.
- APK contains libgodotopenxrvendors.so + the action map. apksigner OK.

## Suspected weak points to harden (in order)
1. **Init timing / no retry.** A single initialize() attempt in the main
   scene's _ready can fail transiently on Quest before the runtime is
   ready, and the code then falls back silently for the whole session.
   Move XR startup into a small autoload that runs before the main scene:
   find the interface, try initialize(); if it fails, retry once per frame
   for up to ~5 s; set get_viewport().use_xr = true the moment it succeeds.
   Keep the desktop fallback exactly as-is when no interface exists.
2. **No session visibility.** Connect XRServer's session signals
   (session_begun, session_visible, session_focussed, session_stopping)
   and print every transition plus the init outcome with msec timestamps,
   so a logcat capture shows exactly where the chain sticks.
3. **Camera arbitration.** When XR initializes, explicitly set
   FallbackCamera.current = false; ensure XRCamera3D is enabled. (Harmless
   if Godot already arbitrates — make it deterministic.)
4. **Manifest audit.** Dump the exported APK's AndroidManifest with aapt2
   xmltree and REPORT the full set of VR-relevant entries actually present
   (intent categories, uses-feature, meta-data). A previous check of this
   was inconclusive (tool output swallowed). If the vendors plugin's Meta
   meta-data is missing, find out why and fix the export config.

## Rules
- Boot storyboard timings, greeting order, hub behaviour, room/HUD content:
  unchanged. This chunk touches XR startup + diagnostics only.
- Desktop/headless path must still work: captures shot-01..04 regenerate
  clean, headless log shows boot + materialize complete.
- No git commits.

## Validation (report each)
- Headless run clean; captures regenerated.
- APK re-export (established pipeline): size, apksigner verify, package,
  the manifest audit from item 4 in full.
- builds/README.md row: "ON-DEVICE BUG: first headset run played audio but
  never presented (Meta 3-dots); XR startup hardened (autoload + retry +
  session logging) — awaiting Jon's retest."
- SPEC.md: short note in the build-status area recording the bug and that
  headless captures do NOT prove XR presentation; on-device smoke test is
  the only proof.
- Final report: files changed + why, the init/session logging design, the
  manifest audit verbatim, validation results.
