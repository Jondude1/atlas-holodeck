# Vista feel round — build the Oculus Home research into the app

Source: ~/workspace/research_notes/oculus-home-background-feel-20261124-1949/report.md
(read its Godot checklist first). Jon's order 2026-11-24: "build this into the
app." The vista still reads as a picture behind a room; Oculus Home felt like
a place. Their three structural rules: (1) flat layer = far field only, real
geometry in front to parallax against, and the geometry/impostor seam must
never break the spell; (2) blending the sky into the foreground was a
dedicated art pass in the master scene; (3) inside and outside lit once,
together. Motion and scale were carried by a few slow, known-size mid-ground
elements, never by the backdrop itself.

## Preconditions (do not start until ALL true)
- The Antigravity tone-lift is committed (git log shows the polish commit)
  and the working tree is clean. If not, stop and report — never build on a
  dirty tree.
- No `agy -p` process running.

## Scope — vista presentation only (vista.gd, vista shaders, room spill,
## grade data). No changes to interaction, CAD, hub, voice, or tools/.
## Lights stay exactly 3 (the spill is a decal/gradient, not a light).
## Resting draw calls must not materially increase.

## Background image permission (Jon, 2026-11-24: "If you have to change the
## background image do so")
The vista paintings themselves are IN scope. If the coast painting cannot
carry items 1/2/4 (wrong horizon height, no aerial perspective to build on,
light coming from the wrong side), regenerate it with
tools/gemini_image.py (gemini-2.5-flash-image), conditioning on the current
painting and/or design/look-reference-jon-20261124.jpg, with the fix baked
into the prompt: horizon at the locked height, far shore visibly hazier and
cooler than the near shore, light from the one chosen sun azimuth, calm sea.
Keep the format (1536x672, 21:9) and the VRAM-compression import settings;
update the vista's DEFS "sea" band to match the new painting's layout.
Eyeball the new painting before wiring it in; keep the old file in design/
as the fallback and only replace the app/ copy once the new one passes the
capture judgement below. Same permission for lake/valley ONLY if the same
defect is present there; otherwise leave them.

## Build items
1. **One locked horizon.** Audit the far card's horizon line, the water
   plane, and the sky dome gradient: they must share ONE horizon height per
   vista at eye level from the terrace. Fix any mismatch in the DEFS/shader
   params so card, water and sky agree. (Today each was tuned separately.)
2. **Aerial perspective, stepped.** Add a haze gradient to the far card in
   vista_card.gdshader: colours mix toward the vista's horizon/haze colour
   as they approach the horizon band, in at least two perceptible steps
   (far shore hazier than near shore). Set the Environment fog colour per
   vista to MATCH the painted horizon colour so geometry (headland, boat)
   hazes into the same air the painting breathes.
3. **Headland distance fade.** The cliffs currently run disable_fog. Make
   their far reaches take the same haze (fog on, or a distance mix in their
   material toward the horizon colour) so rock → water → card reads as one
   continuous depth ramp with no hard meeting line.
4. **One sun.** Choose one sun azimuth + elevation per vista (from the
   painting's own light). Align to it: the sky dome's bright sector, the
   water shader's glitter lane direction, and the painted highlights stay
   consistent. Then retune lab's VistaSpill decal: colour = the vista's
   light colour, shape elongated from the opening, alpha dying out within
   ~2-3 m inside the room — daylight pooling on the floor, not a glow blob.
5. **Three motions, three rates — audit and subordinate.** Inventory what
   currently moves outside (water scroll/swell, foam collar, mist, cloud
   band, gulls, boat, the card's sea-band UV swell). Reduce to three rates:
   (a) water — continuous and slow; (b) ONE distant crossing at a time
   (boat OR a gull group, irregular, never both on stage together);
   (c) one near whisper (existing mist drift is fine). Jon explicitly asked
   for the backdrop to loop/move (2026-11-24), so do NOT remove the card's
   sea-band motion — subordinate it: halve its amplitude so the painting
   reads still at a glance and the geometry carries the life.
6. **Dark floor.** After grades, no vista element should sit below ~25/255
   in the captures (Quest panels can't separate steps under ~13/255; the
   tone-lift set the room's floor — the vista must respect the same).

## Verify (sequential, one godot run at a time)
- Import: 0 SCRIPT ERRORs.
- Suites: panel_test, wall_widgets_test, tools_test, rig_test, props_test,
  solidify_test (headless) — all PASS.
- Captures (windowed xvfb, shot.gd): entrance (0 1.6 1.35 → 0 1.0 -2.2,
  coast, name feel1); from the terrace looking out/down (0 1.6 -7.6 →
  -6 0.2 -14, coast, name feel2); close over the railing (0 1.5 -8.2 →
  -8 -1.5 -16, coast, name feel3).
- Judge against the research, not just the reference photo: horizon locked
  across all three layers; haze step visible between near and far shore;
  cliffs fade rather than end; spill pools inside the opening; at a glance
  the painting reads still while the water/geometry live. Iterate once if
  an item clearly missed.

## Deliverable
Commit (message: "Vista feel round — Oculus Home research: locked horizon,
stepped aerial perspective, one sun + floor spill, three-rate motion"),
push via push_api.py, and report to Jon in chat
fa2e88d2-20ba-4152-b4bd-a0ff5a49484e with the three captures attached and a
plain mapping of which research items landed. If a precondition fails or a
suite regresses and can't be fixed within the pass, do NOT commit; report
what blocked it.
