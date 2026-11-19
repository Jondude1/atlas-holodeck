# BRIEF #8 — The room + rendering-fidelity polish (Jon's order, 2026-11-19)

Jon: "add the room and polish everything to match as close to your original
renderings as possible UI and looks wise."
Jon (2026-11-19 18:22 ET, BINDING): "the polish is good, keep the original
heading" — this brief runs AS ORIGINALLY WRITTEN, HUD frame included (its
values are real data only, which is what makes it acceptable). Two earlier
runs of this brief were killed minutes in (one original, one briefly
trimmed) and may have left partial edits — assess the tree first and
complete THIS brief from wherever the tree stands.

The original renderings are `design/concept-target-01.webp` (mood) and
`design/concept-target-04.webp` (governing: table + room + UI). The current
build (captures/shot-01..04) is a black void with a faint grid box and a
thin, dark table. Close that gap as far as real-time Quest 2 allows. Where a
rendering effect is not practical in real time, use the closest approximation
and NOTE it in SPEC §2.6 — do not drift silently (show-accuracy rule).

## What the renderings have that the build lacks (work list)
1. **A room, not a void.** Dark workshop: a floor the table stands ON
   (dark, subtly reflective look — fake it with material/env, no real
   reflections), wall panels with panel lines and a few recessed cyan strip
   accents, dim shelving/equipment silhouettes on the side walls
   (procedural canvas textures on planes — NO external assets), a ceiling
   hint (dark beams + one soft cyan cove strip), atmospheric depth
   (environment fog + the existing motes, slightly denser near the table).
   The room must read at first glance in shot-02's framing.
2. **Table presence.** Titanium that reads as brushed metal at working
   distance (env/ambient/material tune — target-04's slab is clearly lit
   metal, not near-black), bevel highlight along the slab edge, brighter
   cyan strips in the slab edge AND the leg light channels, a soft contact
   shadow/glow pool on the floor under the table so it sits in the room.
3. **HUD frame (from target-04).** A top status strip: left
   "HOLODECK • LIVE • <real clock>", right shows the REAL link state
   (LINK — LAN / TAILNET / LOCAL ONLY from hub.gd) — no fake telemetry.
   Large, faint circular HUD arcs framing the workspace left and right,
   slow-rotating. A radial gauge whose value is REAL (drive it from the
   explode factor 0–100%); label it EXPLODE.
4. **Tethered part labels** for the demo bracket's parts (thin leader line +
   small caps label, tech font, Tokens colours) — the SHIELD table spec has
   always called for these; the renderings show them on every part.
5. **Status card** near the Atlas panel with real values only:
   LINK state, BRAIN tier (from hub state), PARTS count, DIMS (existing
   readout may move here — keep the on-table readouts too).
6. **Table surface dressing.** Faint etched schematic drawings on the inset
   surface away from centre (procedural blueprint-outline texture, very low
   alpha), like the renderings' surface schematics. The etched 6 in / 1 ft
   grid and centre ring stay as they are.

## Budget and rules (hard)
- Draw calls at rest ≤ 90 (currently 39 — you have headroom, spend it on
  the room, not on the model). Report rest + exploded counts.
- Lights stay at 3. Everything else is emissive/fake-bloom, per SPEC.
- No external assets: procedural geometry and canvas-generated textures
  only. Colours from Tokens only. Imperial units only in any text.
- Boot storyboard timings, greeting order, hub behaviour, manipulation —
  unchanged. This is a look/UI chunk, not a behaviour chunk.
- SPEC.md: update §2.6 with what was approximated vs the renderings and how
  (one line per effect: floor reflection, volumetric glow, room detail).

## Validation (report each)
- Headless run clean (boot + materialize complete, no script errors).
- Captures regenerated: shot-01..04. shot-02 must show the room; shot-04
  must show tethered labels + surface dressing.
- APK re-export with the established pipeline (Godot 4.7.2, JDK 17 on PATH,
  GRADLE_USER_HOME=~/workspace/tooling/gradle-home-holodeck, release
  keystore env, IPv4 workaround): size, apksigner verify, package, VR
  entries, networkSecurityConfig.
- builds/README.md: add the row (status: awaiting main-chat gate).
- No git commits. Final report: files changed + why, each validation
  result, draw calls, APK facts, and the approximation list.
