# BRIEF #14 — v1 feature audit + iteration backlog (Jon, 2026-11-20)

Jon's order: "Integrate all of the features I asked for in the beginning
and then do iterations to make it into a first class experience" —
smoother, more Stark-tech. Before building anything, audit what the
beginning actually asked for against what the current build really has.
AUDIT ONLY this run: no feature code, no export.

## Method
Walk SPEC.md §1 (Experience), §4 (v1 scope "In" list), §5 (Interaction
details), §6 (Safety), and §2/§2.5/§2.6 (design language + table model)
line by line. For EVERY promised item, find the evidence in app/ (file +
function) and, where relevant, in the hub code
(~/workspace/atlas-overlay-build/repo/obelisk/). Classify each:
**PRESENT** (works as specced) / **PARTIAL** (exists but weaker than
spec — say exactly how) / **MISSING** (not there). No vibes: cite the
code or the absence.

Items Helios already suspects (verify, don't trust): confirmation-gated
send-to-print end-to-end; save-back of .py/.step/.glb to Athena's slicer
library; the SHIELD surface set (drag-on-plane, swipe-spin inertia,
two-hand stretch on the surface, flick-aside, lift-off freehand, settle
back, reset-to-center); true-scale panel button; in-room spoken
explanation when a CAD job fails validation; part list on the panel;
boot greeting timing.

## Also audit for the iteration rounds
- **Smoothness:** interaction latency paths, grab/spin/scale feel
  (inertia curves present? easing? snap?), animation transitions,
  panel ergonomics (reach, size, legibility), boot duration, any
  per-frame allocations or polling that could hitch on Quest 2.
- **Stark fidelity:** current build vs design/concept-target-04.webp +
  §2.6 tokens — the top visual gaps, ranked by how much they'd move the
  first-glance read (lighting, materials, HUD density/motion, sound).
- **Performance headroom:** current draw calls/lights vs budget; what
  the iteration rounds can afford.

## Deliverable
Write `ITERATION-BACKLOG.md` in the repo root:
1. The feature table (item → status → evidence → gap).
2. A prioritized build backlog grouped as: Round 1 = missing v1
   features; Round 2 = smoothness/feel; Round 3 = Stark fidelity.
   Each item sized S/M/L with its verification method (headless-provable
   vs Jon-headset-only).
3. Update WIP-STATE.md to point at the backlog.
Print the feature table + the round plan in your report. No git commits.
