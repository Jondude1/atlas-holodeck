# BRIEF — Round 6: The room from the picture + wall widgets (2026-11-24)

Jon's orders (2026-11-24 09:54 ET, three messages):
1. "Take what I have now, extract the table and redo the garage to look like the picture,
   from the lighting to the placement of everything. In the version now it's too
   cluttered. The picture has the perfect blend of space and hologram."
   (The picture = design/v2-vision-walkin.png.)
2. "The holograms are in the right places too. I like working on the items from all
   angles of the table but the default view should be the direction the picture is facing."
3. "Have the readouts and things on the wall be items I can move around and make into
   pictures or readouts that matter to me."
4. "Do this all as a vr software engineer would, keeping in mind the constraints of
   the quest 2."

## R6-1 — Room rebuild (BUILT, verifying)
- The HoloTable is extracted unchanged — it is Jon's design and the room's centre.
- Layout per the picture: opening on the BACK wall (5.8 × 2.9 m) with titanium frame +
  dim cyan edge line; terrace + railing beyond (z −5 → −8.3); VistaDeck rotated to
  face it; suit pads flanking the opening INSIDE at (±2.95, −4.15); Atlas Presence
  (point sphere, extracted from the old DataStation) floating LEFT at (−2.45, 0, 0.8);
  bare slab benches along both side walls (props + arm live on the right slab); three
  slim WHITE ceiling light bars (HDR vertex colour); data-station wall, shelves,
  greebles, screen bank, ceiling rig, cables, light shafts — DELETED.
- HUD: status strip raised to y 2.32 (it was silhouetted dead-centre against the
  vista — the "grey slab" in captures), arcs pushed to the jambs (±2.35), 1.35 size,
  alpha 0.4.
- LocoRig AREAS/BLOCKS/PADS + Prop supports re-derived; RIG_TEST rewritten + PASS.
- Default view: the entrance end of the table looking down it to the opening is the
  spawn framing; the table still works from every side.
- Budgets: merged statics only for architecture; resting draw calls stay ≤ ~85 mono.

## R6-2 — Wall widgets (NEXT)
Wall panels Jon owns: grab a panel, slide it along its wall, let go — it stays.
Tap/point-press cycles or picks what it shows. Content types:
- OVERVIEW — the bench's workshop overview lines (cad_bench.overview_lines()).
- MODEL — active model name/dims/parts + its schematic texture.
- LIBRARY — parts library count + recents.
- CLOCK — time + date, big and quiet.
- HUB — link state / brain tier (from hub status the HUD already tracks).
- PICTURE — a framed image; cycles through bundled pictures (the vista paintings,
  suit renders, concept targets in app/pictures/, VRAM-compressed).
Design rules (Quest 2 discipline):
- Fixed set: 5 panels (2 large 1.5×0.85 m, 3 small 0.95×0.6 m), default layout per the
  picture: left wall — one large upper + two small; right wall — one large + one small.
- One SubViewport per panel, UPDATE_ONCE discipline (content redraws only on change;
  CLOCK ticks 1/min). Pictures are plain textured quads — no viewport.
- Panels are individual nodes (not merged) — 5 draw calls + ≤5 viewport draws when
  dirty; frames are thin titanium borders via one shared material.
- Movement: hand ray/grip drag constrained to the panel's wall plane, clamped to the
  wall's usable area, 0.05 m snap; panels cannot leave their wall in v1 (cross-wall
  moves are a later call). Hover rim + haptic tick = the universal touchable language.
- Persistence: user://wall_layout.json {version, panels:[{id, wall, x, y, type,
  picture}]} written on release/retarget; restored at boot; a PICTURE panel remembers
  its picture. Same versioned-store pattern as world placements.
- Voice later: "make this one a picture" is a natural Atlas command — wire after the
  touch path works (hub round-trip not required; local intent in voice.gd).
Tests: wall_widgets_test.gd — spawn defaults, drag-along-wall clamp, type cycle,
save/restore round-trip, picture persistence.
