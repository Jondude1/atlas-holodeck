# BRIEF-iterate-1 — P1: Suits on the pads (2026-11-25, Helios self-lane)

North Star: design/look-reference-jon-20261124.jpg (suits flanking the opening).

Source: design/suits3d/suit-01-hero.glb (298,927 tris) + suit-04-heroine.glb
(293,654 tris), TRELLIS output, each incl. a display disc (faces with centroid
y < -0.44, radius ~0.30 in normalised coords).

Do:
1. tools/decimate_suits.py → app/suits/suit_hero.glb + suit_heroine.glb:
   disc trimmed, quadric decimation to 25k tris PRESERVING uv/normals/PBR
   textures, feet at y=0, uniform scale to 1.78 m tall.
2. app/suit.gd (SuitDisplay): load GLB, add emissive visor slit (on a yaw
   pivot at head centre) + chest core disc; visitor within 2.4 m → glow fades
   up, visor yaw-tracks visitor (clamp ±0.65 rad); else faint idle ember.
   NO new lights (3-light law), presentation only.
3. lab.gd build(): SuitDisplay hero at (-2.5, 0.081, -4.3), heroine at
   (+2.5, 0.081, -4.3) — the existing pad positions.

Verify: import 0 SCRIPT ERRORs; captures vs North Star (room view + close
suit view, one awake via debug_set_visitor); perf probe resting ≤90 calls,
lights exactly 3; suites the chunk touches (rig/props/wall_widgets + full
14 if time). Commit + push via push_api.py; WIP-STATE entry.
