# BRIEF — Round 3: Stark fidelity + living lab (brief #19, 2026-11-20)

Backlog R3-1..R3-11. Steering (Jon, 2026-11-20, corrected same day):
the TABLE — what it can do and how it feels to use — is the meat and
potatoes and leads the work order; fidelity is NOT leashed by that.
Build the atmosphere properly too; the only hard limits are the real
ones: ≤90 draw calls / 3 lights on the Quest 2 (perf_probe + exercise
PERF are the gates; current stage scene = 79) and never breaking table
function to buy looks.

## Work order
1. **R3-10 Explode label de-overlap** (functional; the Round 1A owned
   defect). At 100% explode on the 27-part trebuchet, clustered part
   labels pile up. Fix in the label layout: after anchors are computed,
   spread labels apart along the vertical (min separation), keeping the
   tether lines — they already connect anchor to label, so a spread
   label still reads as belonging to its part. Acceptance: treb at 100%
   explode capture with no overlapping label rects (measure in the
   capture harness: label quad screen rects pairwise non-overlapping
   for the pinned/all-labels state the capture uses).
2. **R3-6 Callouts**: two-line captions — line 1 part name + number,
   line 2 the part's true dims from the manifest (real data only; no
   invented material). Builds on the same label pass as R3-10.
3. **R3-1 Hologram presence**: a soft emitter glow column under the
   active model + an under-model glow pool on the display surface
   (shader/quad on existing geometry where possible, +1 draw max),
   model float height above the inset unchanged unless it reads wrong
   in captures.
4. **R3-2 Table surface**: hot-centre radial falloff on the display +
   finer etch lines (shader-side, no new geometry).
5. **R3-11 Living lab (full build)**:
   - Readout wall: one wall quad whose texture is drawn from REAL hub
     data — library part count + names of the 3 most recent library
     entries + hub job count (voice-status) + brain tier. Refreshed on
     boot and after CAD/library events, through the panel's poke-style
     discipline (a CanvasItem draw, not per-frame).
   - Side-station schematic: the active model's own silhouette texture
     on a slowly rotating side pedestal disc (updates when the model
     changes) — the SHIELD "second view" of the work in progress.
   - ONE original-design robot arm at a side station, keyframed task
     loop (no IK): idle sway → reach to its tray → lift a small part →
     hold it in a scanner beam (thin cyan quad + tone) → set it down →
     occasional droop/"sulk" beat. Dark titanium + cyan accents to
     match the table; ≤6 draw calls (merged links); NOT a Marvel
     design, no names/likenesses.
   - A station-pinned Atlas hologram presence at the readout station:
     a simple translucent figure/ bust form with idle motion (breathing
     sway, head turns toward the table when a job completes) — abstract
     hologram, not a character likeness. If it reads wrong in captures,
     it ships OFF by default with a panel toggle.
6. **R3-3 Particles**: a gentle rising mote column over the active
   model (one GPUParticles3D), plus the existing materialize burst
   kept. 
7. **R3-4/R3-8/R3-9**: tonemap/glow threshold tune in project settings;
   a subtle scanline term in the holo shader; reflection-style floor
   gloss (fake mirrored glow strip, no SSR). All subject to the same
   draw-call gate — if the probe goes over 90, the trim order in Rules
   applies, but the intent is to ship them.

## Rules
- Every addition is measured: perf_probe before/after; if the stage
  scene exceeds 90, trim in this order: schematic pedestal, particles,
  glow column — never the arm's legibility or the label fixes.
- No new lights (3-light budget is hard). Emissive/fake-glow only.
- Tests: all suites + exercise + library_test stay green; a labels
  test asserts non-overlap at 100% explode on the trebuchet fixture
  (screen-space rects from the capture camera).
- Captures for Jon: exploded treb labels (the fix), the arm mid-task,
  the readout wall, one wide room shot.
