# Claude Code brief #2 — Atlas Holodeck: Meta Quest VR manifest via OpenXR Vendors plugin

Follow-up to the skeleton you just built in `~/workspace/atlas-holodeck/app/`.
Problem: the exported APK's manifest has no VR intent category and no
`android.hardware.vr.headtracking` feature, so on a Quest 2 it would launch as a
flat 2D window. Fix it properly with the official Godot OpenXR Vendors plugin and a
Gradle build. Work only inside `~/workspace/atlas-holodeck/` (plus tooling/downloads).

## Steps

1. Download the vendors addon (plugin 5.2.0-stable, the release matched to Godot 4.7):
   `https://github.com/GodotVR/godot_openxr_vendors/releases/download/5.2.0-stable/godotopenxrvendorsaddon.zip`
   Save to `~/workspace/tooling/godot/downloads/godotopenxrvendorsaddon-5.2.0.zip`.
   Extract ONLY the `addons/godotopenxr_vendors/` tree into
   `~/workspace/atlas-holodeck/app/addons/godotopenxr_vendors/`.
2. Enable the plugin in `project.godot` (`[editor_plugins]`), then run
   `godot --headless --editor --quit --path .` and confirm the project still imports
   with no script errors and the main scene still runs headless (fallback camera path)
   with no GDScript errors.
3. Inspect the plugin's export-plugin code under `addons/godotopenxr_vendors/` to find
   the exact export preset option keys it registers (Meta Quest support level etc.).
   In `export_presets.cfg`:
   - set `gradle_build/use_gradle_build=true`
   - set the Meta Quest support option to the level that includes Quest 2
   - leave optional Meta features (hand tracking, passthrough, eye/face tracking,
     scene/spatial anchors) OFF — v1 is controllers + full VR only
   - keep everything else from the existing preset (package id, version, arm64 only,
     XR mode OpenXR, internet permission, export path `../builds/AtlasHolodeck.apk`)
4. Export again with `JAVA_HOME=~/workspace/tooling/jdk-17.0.20.1+1` and
   `ANDROID_HOME=~/workspace/tooling/android-sdk`:
   `godot --headless --export-release Android ../builds/AtlasHolodeck.apk --path .`
   First Gradle build may download Gradle/AGP dependencies — that's fine.
   If it fails asking for an NDK, install the version it names with
   `~/workspace/tooling/android-sdk/cmdline-tools/latest/bin/sdkmanager "ndk;<version>"`
   (accept licenses) and retry. If it fails on the keystore, reuse the debug keystore
   setup from the first build (env vars, nothing in project files).
5. Verify the new APK:
   - `apksigner verify --print-certs` → Verifies, debug cert
   - `aapt2 dump badging` → package `com.jondude.holodeck`, versionName 0.1.0
   - `aapt2 dump xmltree ../builds/AtlasHolodeck.apk AndroidManifest.xml` → MUST now
     contain `com.oculus.intent.category.VR` and
     `android.hardware.vr.headtracking`. Print the matching lines.
   - Report the new APK size.
6. Repo hygiene: the vendored addon is large and reproducible from the pinned release,
   so do NOT plan to commit it. Add `app/addons/` to `~/workspace/atlas-holodeck/.gitignore`
   if it isn't effectively ignored already, and create `app/fetch_addons.sh` (executable)
   that downloads the exact addon zip URL above into `~/workspace/tooling/godot/downloads/`
   (or a `downloads/` beside the script — keep it simple: use a `VENDORS_ZIP` env or a
   fixed path under the workspace tooling dir) and extracts `addons/godotopenxr_vendors`
   into the project. A short comment header in the script must state the pinned version
   (5.2.0-stable) and why (Quest VR manifest entries; not committed due to size).

## Rules

- No credentials in any file. GDScript/config changes minimal and purposeful.
- Don't change scene/script content from the skeleton except if the plugin requires a
  project setting (e.g. an OpenXR feature flag) — note any such change in your summary.
- Print a summary at the end: what changed, export result, the manifest grep lines,
  APK size, and any remaining risk for the first in-headset test.
