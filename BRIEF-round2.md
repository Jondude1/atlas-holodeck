# BRIEF #17 — Iteration Round 2: smoothness & feel (code side)

Executes ITERATION-BACKLOG.md Round 2 (Jon's order 2026-11-20: iterate
to first class). Rounds 1A/1B are built + exported. Start from
WIP-STATE.md. Checkpoint after each item. Feel itself is Jon's headset
call — your job is the machinery, the numbers, and honest baselines.

## Items (backlog Round 2)
1. **Haptics (S):** controller pulses on grab, settle, park, select,
   button press, materialize-complete — short, distinct, subtle.
   Use the XR haptic API; no-op gracefully headless.
2. **Hover/reach highlight (S):** ray hover already raises name + rim —
   extend to a consistent hover state on panel buttons and parked
   models (brighten + tick), so aim is never ambiguous.
3. **Easing pass (S):** audit every tween/animation for consistent
   ease curves (one shared easing helper); no linear mechanical motion
   left in panel/model/boot transitions.
4. **Spawn hitch (M):** model spawn currently parses the glb and paints
   the silhouette synchronously (~0.35–0.45 s for the silhouette alone).
   Move what's movable off the critical path (async/threaded load,
   silhouette painted progressively or after materialize starts) and
   MEASURE before/after spawn frame cost headless.
5. **Startup painting (M):** same treatment for boot-time texture
   painting — measure, defer or pre-bake what's expensive.
6. **Panel ergonomics (M):** panel renders only when dirty (extend the
   1A poke-refresh into full UPDATE_WHEN_DIRTY discipline); verify no
   per-frame viewport cost at idle.
7. **CAD stage progress (M):** the panel + voice status narrate job
   stages (writing → building → validating → rendering) from the hub's
   job status instead of one long "thinking" — hub already exposes job
   status; poll politely (no per-frame requests).
8. **Skippable boot (S):** any button press during boot skips to the
   materialized state (greeting still plays).
9. **Hub-driven greeting (S):** when the hub is reachable, the greeting
   comes from the hub (brain-aware, e.g. time of day) with the recorded
   clip as the offline fallback — never an error if the hub is down.
10. **Render settings + frame baseline (S–M):** set sane Quest 2 values
    in project.godot (MSAA, foveation level, refresh-rate request) and
    add a perf_probe that reports a repeatable headless frame-cost
    baseline for the standard scenes; on-device frame time stays Jon's
    measurement — say so.
11. **Real brain tier on HUD (S):** the HUD brain readout shows the
    hub's actual reported tier when known (from /atlas/status or
    voice-status) instead of the blanket "HERMES".

## Rules
- ≤90 draw calls, 3 lights — report real numbers. No regressions in
  the existing test suites (run them: explode/panel/failure/
  interaction/print/silhouette).
- One export, brief #9 artifact validation. Fresh captures where a
  change is visible (hover state, CAD progress on panel).
- Update WIP-STATE.md per item. Report: per item built/proof, measured
  deltas (spawn cost, idle panel cost), headset-only list. No commits.
