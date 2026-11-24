# Antigravity final corrective pass — tone lift (Atlas Holodeck)

Your polish pass (17 files, verified: import PASS, suites 13/14, exercise
functional checks all PASS) was reviewed against the owner's reference photo
`design/look-reference-jon-20261124.jpg`. Verdict: the direction was right but
the grade OVERSHOT dark, and the hero hologram lost its teal definition. This
is a small corrective pass, not a redo. Keep everything that worked (crisper
table grid and panel chrome, denser point-sphere, integrated opening).

## Targets (presentation only, as always)
1. **Lift the mid-tones.** In captures/shot-agy1.png the walls, ceiling and
   floor are near-black and the suit platforms are almost lost. The reference
   is dark but READABLE: charcoal architecture with visible mid-tones, suits
   clearly flanking the opening, floor you can read. Lift wall/ambient/floor
   mid-tones toward the reference — land BETWEEN the pre-polish brightness
   (captures/shot-pic16.png, too bright/blue) and your agy1 (too dark).
2. **Hologram back to teal.** In captures/shot-agy2.png the Star Destroyer at
   the table centre washes out WHITE. Pull its centre exposure back so it
   reads as a teal wireframe hologram with visible structure, like the
   reference's engine hologram. The 0.82 m display fit stays.
3. **Kill the floor streak.** shot-agy1 shows a thin bright specular streak
   under the table. Soften it into the floor sheen.
4. Change nothing else. If a target seems to need a functional change, stop
   and write it up as a proposal instead.

## Hard rules (unchanged)
- Presentation only. Never edit `tools/`, `SPEC.md`, `app/hub_secret.cfg`, or
  the demo bundle. No behaviour changes. Lights stay exactly 3; draw calls
  must not materially increase. Do not commit to git.
- Two KNOWN failures are pre-existing and NOT yours to fix or chase:
  interaction_test FAIL (demo-swap vs the test's bracket assumption) and the
  exercise EX PERF sample (102 vs 95, a panel-timing artifact, identical on
  pre-polish code). If you see exactly those, note them and move on.

## Verify (sequential — one godot run at a time on this VM)
1. Import: 0 SCRIPT ERRORs.
2. Suites: panel_test, wall_widgets_test, tools_test, labels_test,
   park_labels_test, explode_test (headless). All must PASS.
3. Captures (windowed under xvfb, same shapes as before):
   shot-agy3 = entrance (0 1.6 1.35 → 0 1.0 -2.2, coast)
   shot-agy4 = close table (0.85 1.5 -0.35 → 0 1.02 -1.55, coast)
   Eyeball both against the reference: walls readable charcoal, suits visible,
   destroyer teal with structure, no floor streak. Iterate once if a target
   clearly missed.

## Deliverable
Append an addendum to POLISH-ANTIGRAVITY.md: what you changed (file, value,
target), suite results, and your own before/after judgement on agy3/agy4.
Leave the tree dirty.
