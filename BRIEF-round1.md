# BRIEF #15 — Iteration Round 1A: the table interaction core + cheap fixes

Executes the first half of ITERATION-BACKLOG.md Round 1 (Jon's order
2026-11-20: integrate all v1 features, then iterate to first class).
Round 1B (follow-up edit-in-place, print path, real silhouette
schematic, save-back path) follows as its own chunk — do not start it.

## First: close the audit's two unverified risks (with fixes if real)
1. **Multi-part explode:** verify whether exploded parts separate along
   real part centroids or all lift from a shared origin. Fix to use each
   part's geometry/AABB centroid (R1-10). Prove it headless with a
   multi-part test model (the Phone Stand job's 3 parts or a fixture):
   at explode 1.0 the parts' positions must differ in more than Y.
2. **Panel overflow:** measure the panel content vs its 480 px viewport;
   fix any clipping (part of R1-6).

## Then build (backlog IDs)
- **R1-1 (M)** Table-plane work mode: while a model is on the table,
  drag slides it across the plane; release settles it back onto the
  surface at table height; released off-table it stays freehand.
- **R1-2 (M)** Swipe-spin with inertia on the surface + flick-aside
  (velocity carries, decays smoothly; flick parks the model).
- **R1-3 (S)** Model reset-to-center button/gesture (distinct from floor
  reset — rename the floor button so the two never confuse), true-scale
  panel button alongside 0.5×/1×/2×.
- **R1-7 (M)** Bench select: point at a parked model and pull it back to
  center (it becomes the active model; the current one parks).
- **R1-6 (M)** Panel part list: a real scrollable list of named parts
  (not one clipped string) + the overflow fix above.
- **R1-5 (S–M)** Spoken failure reasons: when a CAD job fails, Atlas
  speaks the hub's actual failure reason (sanitized, one sentence), not
  the generic line. Hub change additive only if needed; phone routes
  re-verified after any hub touch.
- **R1-11 (S)** A/X as an additional PTT binding (SPEC §5) + part name
  shown on hover/select.

## Rules
- Checkpoint discipline: update WIP-STATE.md when you finish (what's
  done, what's next = Round 1B items). Smaller verifiable increments;
  if you stall, the state file must say exactly where.
- Keep the ≤90 draw-call budget; report the real number. No new lights.
- One export at the end, validated the brief #9 way (xr_mode_openxr,
  loader lib, RECORD_AUDIO, apksigner). Fresh captures for the new
  interactions where a capture can show them (bench select, part list).
- Headless verification for everything provable headless; mark clearly
  what only Jon's headset can prove (drag feel, inertia feel).
- No git commits.
