# Brief — Round 5: The Open Wall (Jon's pick 2026-11-24)

**This round + Round 5B ship together as HOLODECK v2.0** (Jon, 2026-11-24: "This will be
a v2 when it lands"). No separate R5A release. Jon's engineering bar, same day: "Build
this the way a vr software engineer would build it" — i.e. a proper rig + locomotion
provider, an interaction framework (grab interactables with hover/select states, not
ad-hoc per-object code), a persistence layer with versioning, comfort standards applied
deliberately, and on-device perf profiling as a release gate. Vision renders (Gemini,
2026-11-24): design/v2-vision-walkin.png (the first walk-in) + design/v2-vision-solid.png
(the solidify feature) — the visual targets for v2.

Jon rejected the enclosed garages (concepts 01–06). Direction, in his words: the garage
placed so ONE WALL IS OPEN to a living, moving background like the original Oculus Home.
He first picked concept-09 (valley), then superseded it: **concept-08 COAST is the view**.
"Build the opening and make the view swappable." Also his orders: take your time; build to
the spec of the original game (Oculus Home); research how Home works on Quest 2 now so the
resource cost stays low enough to run smoothly.

## Deliverables
1. Research report (commissioned 2026-11-24): original Oculus Home construction + Quest 2
   Horizon Home perf budgets → ~/workspace/research_notes/oculus-home-vista-spec-20261124/.
   The build follows its numbers; where this brief and the report disagree, the report wins
   and this brief gets amended.
2. The opening: the room's vista-side wall becomes a wide hangar opening (per concept-08:
   nearly the full wall width, floor-to-near-ceiling, low railing, terrace lip). The holo
   table stays centre; suit platforms flank the opening; benches/data wall stay on the
   closed walls. Room shell rebuilt with R4-3 discipline (merged statics, shared materials).
3. Vista system (class VistaDeck or similar): layered backdrop outside the opening —
   painted panorama (curved card / sky), mid-ground layer, animated life layer (drifting
   cloud/mist cards, water shimmer), per the research spec's budgets. Vista art is DONE:
   design/vistas/vista-coast.png (default), vista-lake.png, vista-valley.png (21:9 Gemini
   renders, eyeballed 2026-11-24).
4. Swappable: panel control cycles COAST → LAKE → VALLEY (and Atlas voice "show me the
   lake" if the route is cheap to add); swap is a crossfade, vistas load on swap (not all
   resident) if the research memory math says so.
5. Perf gate: census + perf probe before/after; total stays inside the ≤90 draw-call worst
   case with a CAD model up; vista itself budgeted in the single digits of draw calls.

## Round 5B — Jon's additions (2026-11-24 09:16 ET): move, touch, take
Jon, while the vista research was landing: "I want to be able to move around the space,
interact with some of the objects, maybe bring in the objects from the table (when I bring
them outside of the table space they become solid and I can place them in the world? Where
they have permanence)" — and the governing bar for all of it: **smooth and intuitive**.

1. **Locomotion.** Thumbstick smooth move + snap turn (comfort defaults), roomscale still
   live inside the play area; movement clamped to the workshop floor + the terrace outside
   the opening (no falling off the world, no walking through the table/benches — simple
   bounds + obstacle circles, no physics engine). Speed gentle; no head-bob; a comfort
   vignette while moving is available in settings if needed.
2. **Interactables.** Bench props become grabbable (pick up, inspect, set down — they stay
   where set down). Suits wake on approach/touch: visor + chest light up, a small status
   readout appears, Atlas can comment. The robot arm already lives; the data station is
   already real. Hover rim + haptic tick is the universal "this is touchable" language.
**Engineering notes (how a VR engineer builds 5B — settled 2026-11-24):**
- *Locomotion* = a dedicated rig script on XROrigin3D. Left stick smooth move (head-relative
  yaw, 1.6 m/s, smoothed accel), right stick snap turn 30° **pivoting on the camera's world
  position** (not the origin — no swing). Collision is analytic, no physics: the *body*
  (origin + camera XZ offset) is clamped into a union of rectangles (room ∪ door ∪ terrace,
  player radius applied) with axis-separated sliding; obstacle rects/circles for the table,
  right bench, station and suit pads. Roomscale leaning still works inside the play area.
  Comfort baseline = snap turn + gentle speed + no bob; a movement vignette is a follow-up
  only if Jon reports discomfort. The rig never touches the fallback camera (sim/tests safe).
- *Interaction framework*: one behaviour contract — hover (rim + haptic tick), grab (follow
  with offset), release (throw velocity) — already embodied by grabbable.gd for CAD models.
  Props join the same group + method trio so hand.gd barely changes. Bench props are
  currently merged into the lab's static mesh; the fix is to unmerge 2 hero prop kinds
  (bench lamp, crate) into individual nodes sharing the lab's lit material (+2–3 draw
  calls, budgeted). Poke the robot arm → it sulks (the pose already exists).
- *Persistence*: a versioned store (user://world.json, schema v1) written by a single
  WorldStore owner; objects restore through the same spawn path as live ones (no second
  code path to drift). GLB bytes cached at download time make restore hub-independent.

3. **Off-table solidify + permanence (the headline).** A model carried beyond the table's
   edge **solidifies**: hologram shader crossfades to a solid material (titanium/clay PBR
   look, same geometry), with a boundary shimmer at the table edge + hysteresis so it never
   flickers mid-crossing. Released in the world, it stays — a world object: grabbable,
   placeable anywhere in the room/terrace, no longer bound by bench rules (no explode/print
   while solid; those live on the table). Carried back over the table it returns to hologram
   + bench behaviour. **Permanence:** placements persist across sessions —
   user://world_placements.json (source id, transform, scale, solid) + the model's GLB
   cached to user://world_cache/ at download time so restore works even with the hub
   offline. On boot, world objects respawn where Jon left them.
   Scope guard: ONE active table model solidifies at a time in v1 of this feature; parked
   bench models stay holograms. Multi-solid is a later call.

## Standing constraints (unchanged)
- Cyan-only hologram/tech palette inside; the vista is the outside world (natural colour).
- Table-first: nothing about the opening may break table function; suits are decoration.
- Amazement gate + APK artifact gates + screenshots to the Holodeck chat when it ships.
- No Marvel/Oculus assets, names, or logos — original art only (Gemini vistas are ours).
