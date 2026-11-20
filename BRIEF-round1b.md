# BRIEF #16 — Iteration Round 1B: the big three + save-back

Executes the rest of ITERATION-BACKLOG.md Round 1 (Jon's order
2026-11-20). Round 1A is built, exported and verified — start from
WIP-STATE.md. Checkpoint discipline applies throughout: update
WIP-STATE.md after EACH item below lands, not just at the end.

## R1-4 (L) Follow-up edits replace the model in place
"Make it taller / add two holes / thicker walls" after a CAD job must
EDIT the current design, not spawn an unrelated new one. Hub side: the
voice/CAD pipeline keeps the session's last job (script + prompt) and
routes edit-intent utterances to a revision of that script (the writer
gets the previous script + the requested change). App side: the revised
model replaces the on-stage model in place (same bench slot, same
transform as far as sensible) instead of parking it. Prove headless:
scripted two-step (create → edit) against the live hub or mock, showing
the second job carries the first job's context and the app swaps in
place. Hub changes additive only; phone routes re-verified after.

## R1-8 (L) Confirmation-gated send-to-print — DRY-RUN ONLY
Build the full flow, but the printer is NOT touched in this round:
- Panel + voice entry: "Send to printer" opens a confirmation state
  naming the part, material (PLA), and an estimated print time.
- Nothing proceeds without an explicit confirm (panel press or spoken
  yes); a voice command alone never starts anything (SPEC §6).
- Hub: a /atlas/print-job route that validates the request and returns
  a DRY-RUN plan (what WOULD be sliced/sent: file, printer S1, profile)
  — it must not slice for real, must not contact the printer, and must
  log the dry-run distinctly. The live-print wiring is a later,
  separately-approved step (Jon's sign-off) — leave a clean seam.
- Prove headless: the confirmation state machine (request → confirm →
  dry-run plan returned; request → cancel → nothing) in tests.

## R1-12 (M–L) Real silhouette schematic
Replace the bounding-box + fake bolt pattern under the model with the
actual part outline: project the model's geometry (top-down silhouette
+ real hole positions where the geometry has them) onto the table's
schematic layer, rotating in sync with the model as specced. Multi-part
models: silhouette per assembly footprint is fine. Prove with captures
(bracket + one multi-part model) against the old layer.

## R1-9 (S–M) Save-back to the real library
CAD outputs (.py + .step + .glb) must land in the shared Athena 3D
library tree (the 3d-work tree the build123d/Jupyter worker uses), not
only in the hub's job folder. If the exact library path is ambiguous
from the code, save to the shared tree's out/ area under a holodeck/
subfolder AND keep the job-folder copy; state the chosen path in the
report for Jon to redirect if he wants it elsewhere.

## Also
- Add to ITERATION-BACKLOG.md (Round 3 list): "explode label
  de-overlap — at 100% explode, labels of clustered parts pile up
  illegibly (seen in captures/r1-trebuchet-exploded-pinned.png);
  needs leader-line spreading / distance fade." (Backlog only, no build.)
- Keep the ≤90 draw-call budget; report the real count. No new lights.
- One export at the end, validated the brief #9 way. Fresh captures
  for: silhouette schematic (old vs new), print confirmation state.
- Report per item: what was built, headless proof, what remains
  headset-only. No git commits.
