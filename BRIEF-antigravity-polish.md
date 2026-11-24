# Antigravity polish pass — Atlas Holodeck (Godot 4.7.2, Meta Quest 2 VR)

You are the look-and-feel polish lane for an existing, working VR app. The owner
reviews captures against a reference picture and rejects anything that drifts
from it. Your job: make the app LOOK and FEEL closer to the reference, on real
Quest 2 hardware budgets. Presentation only — the app's behaviour is frozen.

## Read first
- `SPEC.md` (design tokens §2.6, budgets) and `WIP-STATE.md` (current state).
- Governing look reference: `design/look-reference-jon-20261124.jpg` — the room
  from behind/above the table: dark polished room, cyan wireframe hologram over
  the table centre, dense cyan point-sphere at LEFT, two dark suits on ring-lit
  pads flanking a wide opening onto a calm coast, large framed cyan data panels
  on both side walls, thin floating rings above the table, slim dim ceiling
  light bars, glossy dark floor.
- Gemini's restyle target of the current build: `design/polish-targets/target-entrance-01.png`.
- Current build capture (your "before"): `captures/shot-pic16.png`.

## Hard rules (violating any of these fails the pass)
1. PRESENTATION ONLY. Do not change behaviour, interaction logic, voice/hub/CAD
   logic, locomotion, or any test expectations. If a polish idea needs a
   functional change, write it in your report as a proposal instead of doing it.
2. Quest 2 budgets: scene light count stays EXACTLY 3. Draw calls must not
   materially increase (resting scene ≤ 90 mono). No new per-frame CPU work of
   consequence; prefer shader/material/constant changes.
3. Colour: holograms are cyan / electric-blue ONLY — never orange/amber.
   Architecture stays dark and quiet (charcoal/satin, neutral-leaning). Cyan is
   for thin accents and the holograms themselves. The heroes are the part on
   the table and the view outside the opening.
4. Do not read, print, or modify `app/hub_secret.cfg`. Do not modify `tools/`,
   `SPEC.md`, or the demo bundle in `app/demo/`. Do not commit to git.
5. Units on any user-facing text stay imperial (decimal inches / feet+inches).

## Named polish targets (from review of captures/shot-pic16.png)
1. The room still reads BRIGHT BLUE overall; the reference is much darker and
   more neutral. Deepen the grade (walls, floor, ambient) without crushing the
   vista or the holograms.
2. The floor has a hard vertical light streak down its centre (ceiling-bar
   gloss) that reads as a searchlight beam. Soften/widen it into a believable
   polished-floor sheen.
3. The two chamfer blocks at the opening's top corners read as floating dark
   panels. Integrate them into the wall/head geometry (colour, size, angle) or
   restyle them so they read as architecture.
4. The hero hologram on the table (currently a Star Destroyer) reads small and
   faint from the entrance; the reference shows a large, present hologram over
   the table centre. Improve its presence via presentation parameters only
   (display fit, glow, material energy) — it must still sit ON the table and
   keep its true proportions.
5. The Atlas point-sphere (left station) reads as a scattered spray at distance.
   Tighten its perceived density/cohesion (particle size/alpha/core balance)
   without adding particle systems or draw calls.
6. Wall panels: keep the framed teal-display direction (dark glass, inner
   border, waveform, ring gauge). Refine typography weight/spacing and panel
   brightness balance so they read as instruments, not stickers.
7. Vista: keep it calm and photographic; if the grade work washes it out or
   makes the room's daylight balance fight the holograms, rebalance.

## Godot 4.7.2 gotchas in this codebase (learned the hard way — obey them)
- After adding any script with a `class_name`, run the import once or other
  scripts fail with stale-cache parse errors.
- `BaseMaterial3D.texture_repeat` is a BOOL in 4.7.2 (`= true` enables tiling);
  the TEXTURE_REPEAT_* constants do not exist.
- `render_priority` is NOT a MeshInstance3D property.
- Spatial shaders have NO `alpha_scissor_threshold` render_mode; use the
  `ALPHA_SCISSOR_THRESHOLD` built-in in fragment().
- `String(x)` throws when x is null — use `str()` or a null guard.
- GDScript function scope spans the whole function: a duplicate `var` name
  anywhere in one function is a parse error.
- `:=` cannot infer from Variant/Dictionary/array-element values — type locals.
- Per-file parse check: from inside `app/`, run
  `~/workspace/tooling/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --check-only --script <file>`.

## Verify your work (required before you finish)
1. Import: `~/workspace/tooling/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path app --import`
   must report 0 SCRIPT ERRORs.
2. Headless suites (from repo root, each prints a PASS line):
   `for t in panel_test interaction_test explode_test silhouette_test failure_test print_flow_test rig_test props_test solidify_test tools_test responds_test labels_test park_labels_test wall_widgets_test; do ~/workspace/tooling/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path app --script ../tools/$t.gd; done`
   All must PASS. If one fails because of your change, fix the change, not the test.
3. Captures — ALWAYS windowed under xvfb (headless captures time out here):
   `xvfb-run -a ~/workspace/tooling/godot/Godot_v4.7.2-stable_linux.x86_64 --path app --resolution 1280x720 --script ../tools/shot.gd -- agy1 0 1.6 1.35 0 1.0 -2.2 coast`
   Take the entrance shot (agy1) and one closer table shot:
   `... -- agy2 0.85 1.5 -0.35 0 1.02 -1.55 coast`
   Eyeball them against the reference; iterate if a named target got worse.

## Deliverable
Write `POLISH-ANTIGRAVITY.md` in the repo root: every file you changed, what
changed, why (which named target), the suite results, and any proposals that
needed functional changes (not implemented). Leave the working tree dirty —
review and commit happen outside your pass.
