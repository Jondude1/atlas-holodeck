# Claude Code brief #3 — Atlas Holodeck: Stark design pass on the skeleton

Apply the Stark design language (SPEC.md §2 — read it first, in
`~/workspace/atlas-holodeck/SPEC.md`) to the Godot skeleton in
`~/workspace/atlas-holodeck/app/`. This is a styling/behavior pass on the existing
skeleton, NOT a rewrite: keep the grab/explode/pointer logic and scene structure,
keep everything working headless, and re-export the APK at the end.

Environment is unchanged (Godot 4.7.2 at `~/workspace/tooling/godot/`, JDK 17,
Android SDK, Gradle export with the vendors plugin from brief #2). Build facts
from brief #2's run, so you don't rediscover them: use
`GRADLE_USER_HOME=~/workspace/tooling/gradle-home-holodeck`; the debug keystore
is `~/.android/debug.keystore` (standard debug credentials) passed via the
`GODOT_ANDROID_KEYSTORE_RELEASE_*` env vars; apply the Gradle IPv4 workaround
(`-Djava.net.preferIPv4Stack=true` in GRADLE_OPTS and on the command line); the
Gradle build template and SDK platform 36 / build-tools 36.1.0 are already
installed; the vendors addon lives at `app/addons/godotopenxrvendors/`
(gitignored, already fetched — do not re-download it).

## Do, in this order

1. **Font.** Bundle Rajdhani (SIL Open Font License 1.1 — clean) in `app/fonts/`:
   Regular/Medium/SemiBold/Bold TTFs + the OFL license text file in the same folder.
   Download from a canonical source (the Impallari/Rajdhani GitHub repo or Google
   Fonts). Apply it: project default theme font for the SubViewport UI, and use it
   for any Label3D readouts. If Rajdhani is unreachable, Orbitron (also OFL) is the
   fallback — say which you used.
2. **Boot sequence.** On scene start: room starts near-black; a circular
   "systems check" ring (a flat ring mesh + a filling arc — a shader or a
   `TextureProgressBar`-style 3D arrangement, keep it cheap) in front of the spawn
   point fills over ~2 s with tick-mark rings around it; the room grid, table glow,
   and UI panel then fade/scale in with easing (tweens). Under the fallback camera
   (headless) it must still run without errors — timings can be identical, nobody
   sees it. Voice lands in step 10 below — a soft generated boot chime (see 5)
   plays during the ring fill.
3. **Idle table life.** The holo-table disc gets: a slowly rotating ring (torus or
   flat ring mesh with the grid/holo material, rotating ~6°/s) and rising particle
   motes above the disc (`GPUParticles3D`, small count ~40, slow, blue, additive).
   Cheap sprites/emissive only — no new post-processing.
4. **Materialize effect.** Add `materialize()` to the model script: parts start
   invisible; a scan plane sweeps bottom-to-top over ~0.8 s (per-part: scale/clip via
   a shader uniform is ideal; a simpler acceptable version: parts fade/scale in
   staggered bottom-to-top with a bright emissive pulse). Play it on scene start for
   the test bracket, and expose it for future spawned models. Keep the shader, if
   any, tiny.
5. **UI sounds (generated only).** Synthesize 3 short WAVs with a small script
   (Python stdlib `wave`/`struct` is fine): `tick.wav` (short 2 kHz blip, ~60 ms),
   `confirm.wav` (two-tone up, ~150 ms), `grab.wav` (soft low blip). Save under
   `app/sounds/`, add `AudioStreamPlayer3D` nodes or a tiny `sfx.gd` autoload-free
   helper, and wire: tick on UI button/slider interaction, grab sound on grab and
   release, confirm on scale-button press. Volume low. No external audio files.
6. **Table-edge readouts.** Three small `Label3D`s standing at the table edge
   (billboarded, Rajdhani, cyan): left = "LINK — LOCAL (XR)" or "LINK — FALLBACK"
   depending on whether OpenXR initialized; center = "PARTS — 3"; right = the test
   bracket's real dimensions in mm computed from its part AABBs ("240 × 160 × 200 MM"
   style — compute, don't hardcode the string). These stand in for the live workshop
   HUD (connection / brain tier / part count / dims) until the hub link lands.
7. **SHIELD table touches (light).** The model already sits at table-surface height —
   verify its base rests exactly on the disc top (no floating, no sinking). Add the
   flat schematic layer: a quad lying on the disc directly under the model, child of
   the model root (so it rotates/slides with the model), showing a generated
   blueprint texture — draw it in code (an `Image` drawn with lines: top-down
   outline rectangle of the base plate, a circle for the bolt pattern suggestion,
   dimension lines with end ticks, dark blue background, cyan lines) at 512×512.
   It must explode/scale WITH the model root but the parts' explode must not tear it
   (it's the model's floor projection — keep it attached to the root, not a part).
8. **Panel animation.** The UI panel scales/fades in (tween from 0.9 scale + transparent
   to full) when the boot sequence finishes, instead of being statically present.
   Buttons get a brief emissive/color pulse on press (theme modulate tween is fine).
9. **Show-accuracy tokens (SPEC §2.6 — read it; apply exactly).** Recolor to the
   token palette: room_bg #04070C, holo_deep #0B3556 (panel/volume fills, alpha
   0.35–0.55), holo_primary #2F7FC4 (bodies, grid majors), holo_line #7FD4FF
   (edges, ring strokes, text accents), holo_core #EAF7FF (active highlights),
   grid minor #1D5F8A @ ~0.35 alpha, table surface #06283F, volume fill alpha
   0.18–0.35. Define the tokens ONCE in code (e.g. a `tokens.gd` with consts) and
   reference them everywhere instead of scattering literals. Rebuild the boot
   ring to the ring token: 60 minor ticks (every 6°), 12 major ticks (every 30°,
   ~2× length), inner rings at 0.82/0.64 radius, progress arc brighter than the
   base ring. Bend the table grid shader toward the table token: minor lines
   every 10 cm, majors every 50 cm at ~2× brightness. Shape `materialize()` to
   the §2.6 beats: schematic/wireframe first → scan sweep bottom-to-top → volume
   fill + edge brighten → labels last, ~1.2 s total (supersedes the ~0.8 s in 4).
10. **Voice (amazement gate).** Two pre-generated Kokoro lines already exist in
    `app/sounds/`: `greeting.mp3` ("All systems online. Welcome to the holodeck,
    Jon.") and `confirm_render.mp3` ("Test bracket rendered. Three parts.").
    Wire them: when the boot sequence completes, fire a quick hub check
    (HTTPRequest GET http://100.65.202.81:8765/atlas/status, ~2 s timeout — the
    result only sets the LINK readout text, e.g. "LINK — HUB OK" vs
    "LINK — LOCAL ONLY") and play `greeting.mp3` regardless of the result: the
    greeting IS the graceful fallback, there is never an error screen. When
    `materialize()` completes for the demo bracket, play `confirm_render.mp3`.
    Plain AudioStreamPlayers at modest volume; no network TTS in this chunk.

## Validation (same bar as before)
- Headless editor import: no script errors.
- Headless scene run: no GDScript errors (fallback path exercises boot + materialize).
- Re-export the APK (Gradle + vendors plugin, same preset) and re-verify:
  apksigner Verifies, package id, and the manifest still contains
  `com.oculus.intent.category.VR` + `android.hardware.vr.headtracking`. Report new size.
- Report the scene's node count and an estimated draw-call count (count
  MeshInstance3D/visible renderables) for the Quest 2 frame-budget record.

## Rules
- Emissive/sprite glow only; do NOT add post-processing beyond what the skeleton has.
- No credentials anywhere. Keep diffs reviewable: list every file you changed and why.
- If a piece fights you (e.g. shader clip for materialize), ship the simpler version
  and say so — do not gold-plate; the APK milestone outranks any single effect.
