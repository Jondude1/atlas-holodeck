# BRIEF-iterate-2 — Iterate Round 2 (P2: vista residuals) — Helios direct, 2026-11-25

North Star: design/look-reference-jon-20261124.jpg (presentation only; no function changes).

## Targets
1. Water photo-tile character from high terrace angles: vista_water.gdshader samples the
   ocean photo on two axis-aligned repeating grids (period ~22 m / ~7.7 m) — from above
   the repetition reads as tiles. Fix: rotate the fine layer off-axis, and break both
   layers' periodicity with large-scale procedural value noise (mix ratio + brightness
   modulation at ~30–55 m scales, no new textures, no new draw calls).
2. Dome sky paler than the painting beyond the card's 132° arc: measured — coast painting
   horizon row ≈ (0.53,0.71,0.86) vs dome horizon (0.68,0.80,0.89) PLUS a +0.12 additive
   horizon glow in vista_sky.gdshader; lake painting horizon ≈ (0.25,0.31,0.43) vs dome
   (0.36,0.48,0.66). Fix: deepen coast/lake sky_horizon in vista.gd DEFS toward the
   paintings' measured rows, cut the dome's additive glow band 0.12 → 0.05 (sun sector
   0.20 → 0.15), and give vista_card.gdshader a horizontal edge melt (u near 0/1 blends
   toward edge_color over 0.08, mirroring the existing top-edge melt) so the card's arc
   ends dissolve into the dome instead of cutting against it.

## Gates
Import 0 SCRIPT ERRORs; full 14-suite gate (vista.gd DEFS + shared shaders moved);
captures: room view + high terrace view, coast; budget check via suit_perf (≤90 calls, 3 lights).
