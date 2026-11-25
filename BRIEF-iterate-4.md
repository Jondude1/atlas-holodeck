# BRIEF iterate round 4 — P4 wall panel richness (Helios, self lane)
North Star: design/look-reference-jon-20261124.jpg — teal data walls with live waveforms/graphs.
Scope (presentation only, panels stay movable widgets, no function change):
- WallPanel chrome waveform + gauge gain a slowly advancing phase so text panels feel live.
- Throttled tick (~0.9 s per panel, staggered), NOT per-frame: each tick = one UPDATE_ONCE viewport repaint. Pictures never tick. No new 3D nodes, draw calls, or lights.
- Proof: new tools/wall_live_test.gd (phase advances on tick, picture tick is a no-op, phase changes the drawn waveform offset), wall_widgets_test, full suite gate, SUITPERF budget, captures.
