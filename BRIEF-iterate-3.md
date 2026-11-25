# BRIEF iterate round 3 — P3 VistaSpill follows vista/grade swaps (Helios, 2026-11-25)

Priority: P3 from the iterate list (P1 suits DONE round 1, P2 vista residuals DONE round 2).
North Star: design/look-reference-jon-20261124.jpg — presentation only, no function change.

## Problem
Lab.build() creates VistaSpill as a static glow decal:
Color(0.82, 0.87, 0.93, 0.10) — tuned to coast/day. Swapping to lake (dusk-blue)
or valley (warm golden) or grading day→golden→dusk leaves the floor spill
coast-pale, breaking the mood bundle VistaDeck otherwise crossfades together
(env fog/ambient, table omni rig, card/dome/rock tints, ambience audio).

## Fix (this round, Helios direct)
- vista.gd DEFS: per-vista "spill" colour + "spill_alpha".
  coast = the existing static values exactly (0.82,0.87,0.93 / 0.10) so
  coast/day is unchanged; lake = dimmer blue (0.50,0.62,0.82 / 0.065);
  valley = warm (0.95,0.85,0.64 / 0.11).
- VistaDeck.spill_target(): spill * grade fog tint (clamped ≤1 per channel),
  alpha = spill_alpha * grade amb_mul — same grade multipliers _apply_mood
  already applies to the light rig, so spill, fog and lights move together.
- VistaDeck.bind(env, lights, spill_mat=null): when a spill material is
  bound, _apply_mood sets it instantly at dur 0 and tweens its albedo_color
  in the same parallel 0.6 s mood tween as fog/ambient/lights.
- lab.gd: keep the spill material in _spill_mat + spill_material() accessor.
  room.gd: spill_material() delegating to Lab (same pattern as presence()).
  main.gd: pass _room.spill_material() into _vista.bind(...).
- tools/spill_test.gd (new, NOT shipped): boots the scene, asserts coast/day
  equals the old static colour, lake changes hue+alpha, valley is warm
  (r>b), dusk grade dims alpha and shifts colour. Counts as a touched suite;
  the full 14-suite gate still runs.

## Budget / law
No new nodes, lights or draw calls — one existing decal's material colour
tweened. Resting draw calls must stay ≤90, lights exactly 3.

## Verify
Import 0 SCRIPT ERRORs; spill_test PASS; full 14 suites PASS sequentially;
suit_perf budget unchanged (84 calls / 3 lights expected); captures:
room view coast/day (unchanged baseline), lake/day, valley/day, coast/dusk
via tools/shot.gd (vista arg + grade arg).
