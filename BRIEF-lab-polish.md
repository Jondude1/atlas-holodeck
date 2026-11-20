# BRIEF #12 — Stark lab visual polish (Jon's order, 2026-11-19)

Jon: "push more polish on the world and visuals themselves in this version.
It needs to be better all round visually — like I'm in Tony Stark's lab."

This brief runs TOGETHER with BRIEF-voice-cad.md (#11) as ONE build (the
floor fix, brief #10, lands first and is already in the tree). One APK:
floor + voice + this polish. North star remains
`design/concept-target-04.webp` (mood: concept-target-01.webp). Before you
change anything visual, copy the current captures to
`captures/before-polish/` — the report needs before/after pairs.

## The gap
Brief #8 made a room; it still reads as an EMPTY room with a table. The
renders read as a working LAB. Close that gap as far as Quest 2 real-time
allows.

## Work
1. **Set dressing (all procedural, no external assets).** Side workbenches
   along the walls; shelving units carrying equipment silhouettes (crates,
   canisters, tool-ish shapes — simple forms, dark materials, cyan rim
   accents); wall-mounted panels/screens with animated Stark-style UI
   graphics (canvas-drawn: rings, graphs, schematics — cyan only, slow
   motion); a ceiling rig / light ring over the table; floor detailing
   (panel seams, a cable run, hazard-free tech trim).
2. **Light & depth.** Layered glow sprites + fake light shafts from the
   ceiling rig down to the table; stronger glow pool and contact shading
   under the table; animated ambience: drifting motes (denser than now),
   a slow-rotating holographic ring or schematic element above the table,
   a gentle pulse travelling the table's edge strips. The standing
   directive is NOTHING STATIC — the room must feel alive at idle.
3. **Materials.** Titanium: clearer brushed texture + bevel highlights so
   the slab reads as machined metal at working distance. Floor: darker,
   richer, with a faked reflection (planar gradient / gloss streak under
   the table and under the cyan strips). Walls: panel seams + greebles
   instead of flat planes.
4. **Table presence.** The table is the hero: heavier machined slab edge
   with the continuous cyan strip, under-glow spilling onto the floor,
   end-zone etchings brighter, the schematic layer crisper.

## Rules
- Cyan/electric-blue ONLY, never orange. Rajdhani thin/tech type. Tokens
  colours only. Imperial units in any text.
- **Budget honesty:** keep 3 lights (fake everything else with emissive /
  sprites). Target ≤90 draw calls at rest; if the polish forces it above,
  REPORT the real number and where it went — never silently blow the
  budget. Quest 2 frame budget is the hard wall.
- Boot storyboard, greeting, hub behaviour, manipulation, and the voice
  work from brief #11: unchanged by this brief.
- Anything from the renders that can't be approximated within budget goes
  in SPEC §2.6 as an approximation note (the established pattern).

## Validation (report each)
- Captures regenerated: shot-01..04, presented in the report as
  before/after pairs against `captures/before-polish/`.
- Draw calls at rest + exploded (real numbers), lights = 3.
- The rest of the validation is the combined build's (brief #11's list,
  incl. the brief #9-style APK artifact checks).
- Final report's visual section: what changed, before/after, the
  approximation list.
