# Claude Code brief — Atlas Holodeck v1 skeleton (Godot 4 project)

You are building the first skeleton of a Meta Quest 2 VR app in Godot 4.
Work ONLY inside `~/workspace/atlas-holodeck/app/`. Do not touch anything outside it.

## Environment

- Godot binary: `~/workspace/tooling/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2 stable)
- JDK 17: `~/workspace/tooling/jdk-17.0.20.1+1` (set `JAVA_HOME` to this for exports)
- Android SDK: `~/workspace/tooling/android-sdk` (set `ANDROID_HOME`/`ANDROID_SDK_ROOT`)
- Export templates are being installed separately to
  `~/.local/share/godot/export_templates/4.7.2.stable/` — if an export fails with a
  missing-template error, check that directory exists and contains `android_release.apk`;
  if it is still empty, wait/retry once, then report.

## Deliverable

A Godot 4 project in `~/workspace/atlas-holodeck/app/` that:

1. Has OpenXR enabled and a main scene `main.tscn` (set as the run main scene).
2. Renders a holodeck room: dark room (~12×4×12 m), blue holographic grid on floor and
   walls (a small custom spatial shader is ideal: near-black base, glowing cyan-blue
   grid lines), a `WorldEnvironment` with a very dark blue background and glow/bloom on.
3. Has a central **holo-table**: a pedestal (cylinder) with a glowing disc on top,
   emissive blue materials, plus a soft blue `OmniLight3D` above it.
4. Has an `XROrigin3D` rig: `XRCamera3D`, left/right `XRController3D`. Also add a
   fallback non-XR `Camera3D` + simple code so the scene loads and renders without
   errors when no HMD is present (headless validation): if the OpenXR interface fails
   to initialize, enable the fallback camera instead of crashing.
5. Has a **test assembly** named `TestBracket` on the table disc, built from 3 named
   `MeshInstance3D` parts forming an L-bracket:
   - `BasePlate` — flat box (0.24 × 0.02 × 0.16 m)
   - `UprightArm` — vertical box (0.02 × 0.18 × 0.16 m) at the back edge of the base
   - `Gusset` — a thin box rotated ~45° as a diagonal brace between base and upright
   Holographic material: blue, emissive. A script `model.gd` on the assembly stores
   each part's home position and an explode direction (part position minus assembly
   centroid, normalized, computed at ready) and exposes `set_explode(t: float)` that
   offsets each part by `dir * t * 0.25` from home.
6. **Grab interaction (custom minimal code, no external addons):** a script
   `grabbable.gd` on the assembly + grab logic on the controllers:
   - Use the project's OpenXR action map for input. FIRST run the headless editor once
     (`godot --headless --editor --quit --path .`) and check whether
     `openxr_action_map.tres` was auto-generated. Read the action names it defines and
     write controller code against THOSE names (grip/squeeze click for grab, trigger
     for UI pointer). If no action map was generated, hand-author a minimal
     `openxr_action_map.tres` in the standard Godot format with one action set
     containing pose actions (aim/grip) and boolean actions for trigger click and
     squeeze click, with bindings for the Oculus Touch controller profile, and point
     `xr/openxr/default_action_map` at it in `project.godot`.
   - One-hand grab: while grip is held near the model (distance check or an Area3D on
     the model + Area3D on the controller — your call, keep it simple and robust), the
     model follows that controller's aim pose (position + rotation, with the grab
     offset captured at grab time). Release = let go (model stays where it is).
   - Two-hand grab (both grips on the model): scale the model by the ratio of current
     hand distance to the distance at second-grab time; position follows the midpoint.
7. **UI panel:** a floating panel anchored near the table (a quad with a `SubViewport`
   + `Control` UI) containing:
   - a title label "ATLAS HOLODECK"
   - an `HSlider` (0..1) wired to `TestBracket.set_explode()`
   - a label listing the part names
   - scale buttons (0.5×, 1×, 2×) that set the assembly scale
   Pointer interaction: a laser ray from the right controller (use a `RayCast3D` or a
   physics-space ray query from the aim pose); on trigger press/drag over the panel,
   convert the hit UV into mouse events pushed into the SubViewport
   (`push_input` with `InputEventMouseMotion` / `InputEventMouseButton`). Keep this
   pointer code as small as possible while actually working.
8. **Android export preset** in `export_presets.cfg`:
   - preset name `Android`, platform Android
   - package unique name `com.jondude.holodeck`, app name `Atlas Holodeck`
   - version code 1, version name `0.1.0`
   - architectures: arm64-v8a only
   - XR mode: OpenXR (`xr_features/xr_mode` = 2 in preset options)
   - permission: internet = true (the voice link to the Atlas hub lands in the next
     milestone; the skeleton itself makes no network calls)
   - export path `../builds/AtlasHolodeck.apk`
   - rendering method: mobile (`rendering/renderer/rendering_method="mobile"` in
     project.godot)

## Validation you must run before reporting done

1. `godot --headless --editor --quit --path .` — project imports with no script errors.
2. Run the main scene headless briefly (e.g. `timeout 20 godot --headless --path .`
   or `--quit-after` if supported) and confirm no crash / no GDScript errors in output
   (OpenXR "interface not found" style warnings are acceptable and expected headless).
3. Export the APK:
   `godot --headless --export-release Android ../builds/AtlasHolodeck.apk --path .`
   with `JAVA_HOME`/`ANDROID_HOME` set. If it fails (keystore, SDK component, template),
   diagnose and fix: e.g. set the Android SDK path in the Godot editor settings file
   (`~/.config/godot/editor_settings-4.7.tres` — keys under `export/android/`),
   generate a debug keystore with the JDK's `keytool` (alias `androiddebugkey`,
   passwords `android`) if Godot asks for one and point the settings/preset at it,
   or install a missing SDK component with
   `~/workspace/tooling/android-sdk/cmdline-tools/latest/bin/sdkmanager`.
   Debug signing is fine — this APK is for sideloading.
4. Verify the APK: file exists, size, and confirm it is signed
   (`~/workspace/tooling/android-sdk/build-tools/34.0.0/apksigner verify --print-certs`
   on it) and that `aapt dump badging` shows package `com.jondude.holodeck`.

## Rules

- GDScript only; no addons from the internet (network to GitHub works if you truly
  need a reference, but prefer zero dependencies).
- No credentials or tokens in any file. No absolute paths inside project files except
  where Godot itself requires them (editor settings live outside the project — fine).
- Keep code small and commented where non-obvious. This is a skeleton to grow on.
- When done, print a short summary: files created, validation results (with the actual
  command outputs for the export + apksigner), and anything that is stubbed or risky
  for the first in-headset test.
