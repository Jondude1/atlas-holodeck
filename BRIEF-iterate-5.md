# BRIEF — Iterate Round 5 (P5: boot / ambience polish)

Priority: P5 from the iterate loop (P1–P4 done in rounds 1–4).
North Star: design/look-reference-jon-20261124.jpg — the room reads as
powered-up in layers: ceiling bars / shell lit, table glowing at centre,
HUD dials last and lightest. Presentation only; no function changes.

## Chunk (Helios lane, direct)
1. main.gd: replace the uniform boot fade with a cascade. New static
   `boot_phases(v) -> Vector3` maps boot progress v (0..1) to
   (room, table, hud) phases via overlapping smoothstep windows:
   room 0.00–0.55, table 0.30–0.85, hud 0.65–1.00. `_set_fade(v)` applies
   room/table/hud phases respectively; the table's scale ease follows the
   TABLE phase. Endpoints exact: v=0 → all 0, v=1 → all 1, so the skip
   path (`_skip_boot` → `_set_fade(1.0)`) and resting state are unchanged.
   Boot duration stays 1.5 s (SPEC §2.6 timing preserved).
   Note: table.set_fade also drives the 3 mood lights' energy, so the
   light rig now comes up mid-cascade with the table — intended.
2. NEW tools/boot_fade_test.gd: endpoints, monotonicity, ordering at
   mid-boot (room > table > hud, hud still 0 at v=0.4), and integration —
   after `_set_fade(0.5)` the room/hud `_fade` values and the table key
   light's energy match the phases; after `_skip_boot()` all are 1.

## Out of scope
- No new nodes, draw calls, or lights (budget law: ≤90 calls, exactly 3).
- No boot duration change, no skip-behaviour change, no chrome changes.
- Vista, suits, wall panels untouched.

## Verify (sequential)
- godot import: 0 SCRIPT ERRORs.
- boot_fade_test PASS; full suite gate (shared code: main.gd is boot path
  for every suite) + SUITPERF budget windowed under xvfb.
- Captures: mid-boot still (boot cascade at ~50%: shell up, table rising,
  HUD not yet) + standard room shot via tools/shot.gd for regression.
