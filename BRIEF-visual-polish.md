# Claude Code brief #6 — Atlas Holodeck: visual polish pass

Jon compared the real captures to the concept renders (main chat, 2026-11-19):
"That does look like the renderings, please make it better." This pass closes
the five known visual gaps. Read SPEC.md §2/§2.6 and look at
`design/concept-target-01.webp` (the room/table read to match) and the current
`captures/shot-02-table-idle.png` + `captures/shot-04-materialized.png` (the
before state) before starting. Work in `~/workspace/atlas-holodeck/app/`.
Everything from briefs #1–#5 must keep working. Do NOT commit to git.

Environment/build facts: same as brief #5 (Godot 4.7.2 at
`~/workspace/tooling/godot/`, JDK 17, `GRADLE_USER_HOME=~/workspace/tooling/gradle-home-holodeck`,
debug keystore env vars, IPv4 workaround, vendors addon already fetched).
Regenerate the desktop captures at the end with the existing
`tools/capture.gd` harness so before/after can be compared.

## 1. Room grid — WAY down (currently a loud wireframe box)

Target-01's room is near-black with a faint grid suggestion. Ours shouts.

- `grid.gdshader`: add a camera-distance fade — grid emission attenuates with
  distance from the camera (use a world-position varying +
  `CAMERA_POSITION_WORLD` in fragment): full strength at ≤2.5 m, fading to
  ~15% by 9 m. Gate it behind a uniform (`dist_fade` 0/1) so the table inset
  is unaffected. Add a `strength` multiplier uniform (default 1.0).
- Room instance (in `main.gd` where the room material is made): enable
  dist_fade, strength ≈ **0.4**, thinner lines (line_px ≈ 0.8). The table
  inset keeps its current values.
- Result to judge in captures: from the default framing, the far wall/floor
  grid is a whisper; the grid near the table is still readable.

## 2. Titanium must read as METAL (hotspot lighting wasn't enough)

Root cause: metallic surfaces reflect the environment, and our environment
reflection is a flat colour — so the slab reflects black. Fix the
environment, not just the lights. All within the Quest 2 budget (a static
procedural sky is cheap; no reflection probes, no post chain changes —
the env glow already in the project stays as-is).

- In `main.gd` `_apply_tokens()` (code, not tscn surgery): build a
  `ProceduralSkyMaterial` — sky_top near-black blue (room_bg family),
  sky_horizon a holo_deep band (the blue glow metals will catch), ground
  near-black; assign via a `Sky` resource: `env.background_mode =
  Environment.BG_SKY`, `env.sky = ...`. The room box hides the sky visually;
  it exists for reflections/ambient. Set `env.ambient_light_source =
  Environment.AMBIENT_SOURCE_SKY` with ambient energy ~0.5, and reflected
  light source to sky/BG so PBR materials sample it.
- `fx.gd` titanium: metallic back up to **0.85**, roughness **0.38** (the
  0.6 metallic from brief #5 was a workaround for the black environment).
- Add ONE rim light: OmniLight, holo_primary, energy ~1.2, range ~6, placed
  high behind the table (above/behind the far edge) so slab top edges and
  legs get a rim from the player's view. Scene light total becomes 3 — that
  is the cap, add no more.
- Judge in captures (shot-02 distant + shot-04 close): slab top/front and
  legs must show tonal variation — brushed dark metal, distinguishable from
  the room and from each other — not black shapes with glowing trim. If the
  sky band makes the room itself visibly brighter through the grid shader,
  it isn't (grid is unshaded) — but say what you see.

## 3. Materialize scan plane — a visible sweeping edge

The shader's scan band is subtle, especially on small parts. Add a physical
scan plane in `model.gd` `materialize()`:

- A horizontal quad (additive unshaded material, holo_line/core family from
  Tokens, alpha ~0.45) sized to the model's footprint × 1.15, with a
  **minimum size of 0.3 m** so even small parts get a clear sweep.
- It travels from the model's base to its top in sync with the existing scan
  beat (same delay/duration as the shader scan tween), then fades out by the
  flash beat. It is a child of the model root (so it follows grab/scale) but
  NOT a part: it must not enter the parts list, the bounds, or the explode.
- Keep the shader band as-is; the plane is the readable edge on top of it.

## 4. Schematic layer — real dimension labels under the model

`blueprint.gd` draws dimension lines but no numbers. Add the numbers as flat
labels in `model.gd` (children of the model root, alongside the schematic —
they rotate/scale with the model and lie on the table):

- Two `Label3D`s lying flat (rotation x = −90°, billboard off, shaded off,
  Rajdhani SemiBold via Tokens fonts, holo_line): one centred on the width
  dimension line below the footprint showing the X size, one on the depth
  line showing the Z size. Text in **decimal inches** using the same
  formatting rule as `dims_text()` (up to 2 dp, trimmed; ft/in form ≥ 24 in).
- They fade with the schematic alpha (tie their modulate alpha into
  `_set_schematic_alpha`) and hide with `hide_all()`.
- Keep them small and crisp: pixel_size ~0.0011, positioned just outside the
  dimension lines so they read as part of the blueprint, not floating UI.

## 5. Default framing — standing AT the table

The table currently sits 2.5 m from the player origin — you feel like you're
watching it, not working at it.

- `main.tscn`: HoloTable z −2.5 → **−1.55** (near edge ≈0.94 m from the
  player origin — standing-at-table distance; controllers can reach the
  centre zone, and pull-to-center covers the rest).
- FallbackCamera: move to ≈ (0, 1.62, 0.1); `main.gd` already look_at()s the
  table, so just confirm the composed frame shows table + panel + ring.
- UIPanel: follow the table — position ≈ (1.55, 1.35, −1.15), keep its
  rotation. Check it doesn't intersect the table's right end (table now ends
  at x ±1.22, top y 0.95; panel bottom edge must clear the slab).
- Boot ring stays at RING_DISTANCE 1.3 in front of the player (now just
  above/behind the table's near edge — confirm it doesn't clip the slab;
  nudge the ring height if it does, and say so).

## Validation
- Headless editor import: no script errors. Headless scene run: no GDScript
  errors; boot + materialize complete.
- Regenerate captures with `tools/capture.gd`; in your report, judge each of
  the five items against its target with the capture filenames as evidence.
- Re-export the APK; verify apksigner Verifies, package
  `com.jondude.holodeck`, VR manifest entries + networkSecurityConfig still
  present; report size. Report scene light count (must be 3) and estimated
  draw calls.
- List every file changed and why; flag anything you approximated.

## Rules
- Colours from Tokens only. No new post-processing. Light count ≤ 3.
- No credentials. No git commits. Simpler beats gold-plated; the
  first-contact milestone outranks any single detail.
