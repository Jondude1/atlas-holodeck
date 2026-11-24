# BRIEF — Round 4: Lean & Robust (Jon's order 2026-11-24)

Jon: "look into the underlying code for this build. Make it as robust and compressed as
possible, while keeping all functionality." Plus his question: a full commercial VR game
runs beautifully on the Quest 2 — why shouldn't one hologram room run at least as well?

## Audit (measured 2026-11-24, tools/census.gd + perf probe history)

| State | Nodes | Mesh inst | UNIQUE materials | Label3D | Particles |
|---|---|---|---|---|---|
| Boot (demo bracket) | 189 | 63 | **55** | 16 | 4,236 / 6 systems |
| Trebuchet (27 parts) | 299 | 119 | **112** | 45 | 4,236 |
| Trebuchet exploded | 299 | 119 | 112 | 45 | — |

Draw calls (exercise, worst scene): 89 / 3 lights. Lights are fine. Everything else is waste:

1. **No material sharing.** 31 material-creation sites in 10 files; Fx builds a fresh material
   per call. 112 unique materials across 119 meshes = effectively ZERO batching. A commercial
   scene atlases/shares down to a few dozen materials for the whole game.
2. **Per-part shader materials.** cad_model._make_material() gives every CAD part its own
   ShaderMaterial because fade/highlight are uniforms. Godot 4 per-instance shader parameters
   exist for exactly this — used 0 times in the codebase. One shared part material + instance
   params collapses all parts into a few render states.
3. **Static geometry unmerged.** MeshBuilder merges within a component (good), but every prop,
   panel and fitting is its own MeshInstance3D (63 at boot for one room). Godot Compatibility
   has no automatic static batching — merging by material class is the manual equivalent.
4. **Labels always resident.** 45 Label3D for a 27-part model; textures/nodes exist even when
   nothing is exploded or pinned. Text should be generated lazily (explode > 0 or pinned) and
   released with the model.
5. **11 _process ticks.** Some already disciplined (HUD text 1 Hz, panel/station viewports
   UPDATE_ONCE) — keep those. Others run unconditionally (table glow follow with nothing on
   stage, etc.). Gate or merge them; kill per-frame allocations.
6. **Code duplication.** Dims formatting in 3 places (ui_panel, model, bench/station), label
   styling in 2, material helpers scattered. Consolidate = the "compressed" half of the order.
7. **Robustness debt.** Fade-accumulation class (fixed once in the orb — audit everywhere a
   stored base is multiplied), await-after-free exposure in bench/voice chains, boot skip
   idempotence. The full suite + exercise is the regression gate for every chunk.

Why the commercial game runs better (the honest version): native engine with automatic
batching/instancing, baked lighting, texture atlases, LOD + occlusion culling, pooled objects
(zero runtime allocation), all content pre-authored — and a team profiling on-device for
months. This app builds geometry, labels and textures AT RUNTIME and gives nearly every object
its own material. None of that is forced by Godot; it's the discipline the feature-first
rounds skipped. Round 4 applies it.

## Work order (each chunk: suites + census + perf, checkpoint in WIP-STATE)

R4-1 Material library: central cache in fx.gd (keyed by kind+colour); all call sites routed
     through it. Target: unique materials boot ≤ 20, trebuchet ≤ 35.
R4-2 CAD parts on ONE shared holo material with per-instance shader parameters
     (fade / highlight / glow). Verify materialize + highlight + pin behaviour unchanged.
R4-3 Static merges: room/lab/table statics merged by material class; interactive pieces stay
     separate. Target: mesh instances boot ≤ 30. (Audit note 2026-11-24: lab.gd already merges
     by material — it's the model citizen. Table body is ~6 instances across 4 materials. The
     single biggest merge is the model's TETHER LINES: 27 per-part MeshInstances sharing one
     material → ONE merged mesh rebuilt on tether updates, −26 draw calls in exploded view.)
R4-4 Lazy labels: tether/dims text textures only while explode > 0 or a part is pinned;
     freed on model clear. Node count may stay; texture memory + texture-gen churn goes.
R4-5 Process diet — AUDITED 2026-11-24, no changes warranted: every _process already
     self-gates (grabbable set_process(false) when idle; table glow early-outs when faded;
     xr_boot self-disables; panel text is change-gated; voice parses only on packets). The
     remaining ticks ARE the intended idle motion (rings, orb, arm). Manufacturing edits here
     would remove life, not waste. Closed as audited.
R4-6 progress: units consolidated into app/units.gd (Units.dec / len_in / dims_line) — the
     trimmer existed twice and cad_bench's dims line skipped the feet conversion (a 30 in
     library part read "30.5 IN" there vs "2' 6.5"" on the model); one formatter now.
     VERIFIED 2026-11-24: import clean (one missed _fmt_dec caller in cad_model.gd caught by
     the import and fixed), all 6 headless suites PASS, round1b_exercise PASS (PERF 89 draw
     calls / 3 lights — unchanged, no regression). R4-6 core DONE; the label-styler dedupe
     half was not needed (label styling already lives in model.gd only).
R4-6 Code compression: one dims formatter, one label styler, shared helpers; target −15% lines
     in app/ with zero behaviour change (suites are the proof).
R4-7 Robustness pass: fade-accumulation audit, await guards, boot idempotence; add a census
     assertion to the exercise (materials/draw calls ceilings) so regressions fail loudly.

## Acceptance
- ALL existing suites pass unmodified (panel, explode, interaction, print_flow, silhouette,
  failure, library, labels, round1b_exercise, SD local).
- Census + perf probe published before/after; draw calls worst-scene ≤ 65 target.
- Every feature from Rounds 1–3 demonstrably intact (exercise + captures eyeballed).
- APK artifact gates as usual; Jon's headset checks remain his.
