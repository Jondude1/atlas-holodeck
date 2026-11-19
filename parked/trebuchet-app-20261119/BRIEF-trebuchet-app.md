# Claude Code brief #7b — Atlas Holodeck: trebuchet APP integration (continuation)

Context: brief #7 (BRIEF-trebuchet.md) ran in two parts. The CAD half is
DONE and verified by Helios — do not redo it:
- `cad/trebuchet.py` (with the full acceptance-checklist machinery:
  CLEAR = 0.3 mm pivot clearance, overhang + min-wall checks) —
  re-run it once to confirm it completes clean and prints the checklist;
  keep its outputs.
- `cad/trebuchet.glb` + `.step` + `.manifest.json` + 3 previews exist;
  GLB verified: 27 nodes == 27 manifest parts, names match exactly
  (SideRailL/R, CrossBeamFront/Rear, AFrameL/R, StrutL/R, Axle,
  ThrowingArm, CounterweightBox, WeightBlock1–6, HingePin, SlingPouch,
  Stone, WheelFL/FR/RL/RR, ReleasePin, SlingRope, CockingRope).
  True dims 14 × 7 × 10 in. Copies already in `app/models/`.
- The APP half never started: no trebuchet code exists in `app/` yet, the
  APK is still the brief-#6 build. That is this brief.

Work in `~/workspace/atlas-holodeck/`. Read BRIEF-trebuchet.md §2–§4 —
they are the spec for this run (loader, fresnel mesh holo shader, display
scale 0.75 m fit at table x ≈ −0.62 facing +X, SCALE readout, explode +
tethered labels, bracket parked at the RIGHT end x ≈ +0.88, manipulation
state machine REST/COCKED/FIRING/SETTLING with panel COCK/FIRE/RESET +
WT−/WT+, pin-grab firing, stone flight scaled to the model, SPEC
updates). Everything from briefs #5/#6 must keep working. Do NOT commit.

Two additions from Jon's marketplace quality-bar research (2026-11-19):
1. **Counterweight mass in grams.** Compute the WeightBlock solid volume
   from the CAD model; assuming printed PLA at ~40% effective density
   (1.24 g/cm³ solid), add `"counterweight_g_per_block"` to the manifest
   (regenerate it from the script with the field added — a small,
   surgical script edit is fine) and show total mass in the panel weight
   readout: `WEIGHT — 4 BLOCKS · 360 G` (actual numbers from the model).
2. **Release tuning rule.** Name the sling-release timing/angle constant
   in the controller (e.g. `RELEASE_ANGLE_DEG`) and document it in SPEC
   §3's manipulation summary as the tuning knob ("release earlier/later by
   adjusting…"), the way real kits document pin-bend tuning.

Validation (from BRIEF-trebuchet.md, unchanged): headless import + run
clean; boot + materialize on the trebuchet; exercise cock → fire → reset
headlessly with no errors; report stone landing distances for 1 / 4 / 6
blocks; captures = standard four + shot-05-trebuchet-cocked +
shot-06-trebuchet-firing if the harness can catch the stone in flight
(say so if it can't); APK re-export with apksigner Verifies, package + VR
entries + networkSecurityConfig present; report size, light count (3),
draw calls at rest / exploded; files changed + why; approximations
flagged honestly.

Rules: colours from Tokens only; no new post-processing; no credentials;
no git commits.
