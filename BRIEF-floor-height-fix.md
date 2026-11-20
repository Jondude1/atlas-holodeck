# BRIEF #10 — Floor height: reference space + recalibration (Jon's on-device report)

## Symptom (Jon, on the brief #9 build — the app now renders, he's in the room)
"it doesn't recognize my height from the real floor" — the virtual
floor/table sit at the wrong height relative to his real standing height.

## Prime suspect
Reference space. If the session runs on plain LOCAL space, Y=0 is wherever
the headset happened to be at launch, not the real floor. The app must ask
for a floor-anchored space.

## Work
1. **Reference space priority.** In XrBoot, BEFORE initialize(): request
   the reference space in this order — STAGE first, then LOCAL_FLOOR,
   then LOCAL as last resort — using the OpenXR interface's supported-
   space check (set_reference_space_type / is_reference_space_type_supported
   or the Godot 4.7 equivalent). Also set the matching project setting if
   one exists, so the intent is visible in project.godot. The desktop
   fallback path stays exactly as-is.
2. **Log it ([XR] prefix, same format as brief #9).** At session_begun log:
   which reference space was REQUESTED, which was actually GRANTED
   (get_reference_space_type after the session starts), and the
   XRCamera3D height (camera position.y relative to the origin) — once at
   session_begun and once ~2 s later. The next logcat read must prove what
   the device gave us.
3. **In-app recalibration.** Add a RESET FLOOR button to the existing UI
   panel (Tokens styling, imperial-era copy rules — no units needed here).
   It calls XRServer.center_on_hmd with a full reset INCLUDING height
   (keep_height = false), and logs the camera height before/after with the
   [XR] prefix. If there is a clean unused controller action in the action
   map, also wire a long-press (~0.8 s) of it to the same reset; if not,
   the button alone is fine — say which you did.
4. **Nothing else changes.** Boot timings, greeting, hub, room, HUD,
   manipulation: untouched. Budget held: ≤90 draw calls, 3 lights.

## Validation (report each — the brief #9 way, artifact-level)
- Headless run clean (boot + materialize complete; desktop path intact).
- Captures shot-01..04 regenerated.
- APK re-export (established pipeline): size, apksigner verify, package;
  AND the artifact checks that would have caught brief #9's bug:
  `assets/_cl_` contains `--xr_mode_openxr`; `libopenxr_loader.so` present.
- builds/README.md row for this build (on-device bug #2: floor height —
  reference space priority + RESET FLOOR; awaiting Jon's retest).
- SPEC.md: one-line note in the build-status area.
- No git commits. Final report: files changed + why, the reference-space
  selection logic, the new [XR] log lines, validation results, APK facts.
