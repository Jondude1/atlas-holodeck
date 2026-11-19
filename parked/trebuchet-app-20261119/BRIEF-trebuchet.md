# Claude Code brief #7 (REVISED) — Atlas Holodeck: the working trebuchet showcase

**Change of order from Jon (2026-11-19): the CX-5 showcase is DROPPED
entirely.** A previous run on it was killed minutes in — it created no CAD
or model files, but check for residue (step 0). The new showcase piece is a
**trebuchet Jon can manipulate on the table**: a detailed build123d
assembly that doesn't just sit there — it cocks, fires, and resets.

Work in `~/workspace/atlas-holodeck/` (CAD under `cad/`, Godot in `app/`).
Read SPEC.md §1–§3 first. Do NOT commit to git. Briefs #5 (first-contact)
and #6 (visual polish) are done and verified — everything from them must
keep working.

Environment: Godot facts as brief #5/#6. Python: use the venv at
`~/workspace/tooling/build123d-venv/bin/python` (build123d 0.13.0 +
trimesh) for all CAD work.

## Step 0 — decontaminate
Grep the repo for `cx5` / `CX-5` / `CX5` (code, SPEC, docs). Remove any
residue from the killed run. Then verify the baseline still runs: headless
scene run prints "boot complete" + "materialize complete" with no script
errors (the bracket demo, as of brief #6). Only then start.

## Jon's build123d quality bar (standing rule, 2026-11-19 — applies in full)
Every build123d output must be (1) **designed with 3D printing in mind** —
real wall thickness, overhang/orientation awareness, fit tolerances,
watertight/manifold solids, support strategy considered — and (2)
**visually appealing every time** — no crude box-and-cylinder placeholders.
For the trebuchet: real timber-frame look — beams with slight chamfers,
tapered arm, iron fittings (axle caps, straps, pin) as darker simple
solids, rope sling with a pouch, a hanging counterweight box with visible
separate weight blocks. The script self-verifies and prints the acceptance
checklist per part: `is_valid()`, watertight/manifold (solid AND exported
mesh), volume > 0, minimum wall thickness, worst overhang vs the part's
intended print orientation, and the orientation itself. A failed line gets
fixed in the script, not waived.

## 1. The CAD script — `cad/trebuchet.py`

Model at **true size in millimetres**: a TABLETOP trebuchet — Jon's sizing
(2026-11-19): **about 10 inches tall overall, frame top / arm pivot height
~10 in**, everything else proportioned like a realistic ~10 in desktop
trebuchet. Dimensions in inches × 25.4 (Jon's figures govern): A-frame
apex (axle height) **10 in**, base **14 in long × 7 in wide**, throwing
arm **15 in total** (long end 11 / short end 4), sling rope ~7 in, stone
Ø ~1.5 in, counterweight box ~4 × 3.5 × 4 in holding up to 6 blocks.
Coordinates: X = length (throw direction +X), Y = width, Z = up, origin
at ground centre of the base. (The loader maps Z-up → Godot Y-up.)

Named parts (target 20–24; every part a separate labelled solid in one
assembly Compound, `label` = part name):
- `SideRailL`, `SideRailR` — base rails (chamfered beams)
- `CrossBeamFront`, `CrossBeamRear` — base cross beams
- `AFrameL`, `AFrameR` — upright assemblies (two angled posts + crossbar
  each, or a single A solid per side — builder's choice, keep the A
  readable)
- `StrutL`, `StrutR` — diagonal braces, A-frame to base
- `Axle` — iron bar through the apex + cap discs
- `ThrowingArm` — tapered beam (wider at pivot, narrow at tip), iron tip ring
- `CounterweightBox` — open-top box (4 walls + floor as ONE part is fine)
- `WeightBlock1` … `WeightBlock6` — six separate blocks (stone/iron slabs)
- `SlingRope` — the rope (a swept tube along a gentle curve, pouch end at
  rest drape) and `SlingPouch` — a small shallow cup/sheet under the stone
- `Stone` — the projectile (rounded rock: a sphere slightly irregular —
  scaled/perturbed, still a valid solid)
- `WheelFL`, `WheelFR`, `WheelRL`, `WheelRR` — small transport wheels
  under the base corners (disc + hub)
- `ReleasePin` — iron pin + ring at the base rear (the trigger Jon grabs)
- `CockingRope` — short rope from arm long-end down to the pin (swept tube)

Outputs (the pipeline contract — same shape the Athena voice-CAD worker
will emit):
- `cad/trebuchet.glb` — one node per part, **node names = part names**
  (verify by parsing the GLB JSON chunk; fix labels until names survive).
- `cad/trebuchet.step` — assembly STEP (save-back artefact).
- `cad/trebuchet.manifest.json` — `{ "name": "Trebuchet", "true_dims_in":
  [14, 7, 10], "units": "in", "parts": [{ "name": ..., "dims_in": [...] },
  ...] }` generated from the actual solids.
- Copy .glb + manifest into `app/models/`.
- 2–3 preview renders into `cad/` (offscreen render or per-view SVG
  projections — say which) so the shape can be judged without a headset.

**Assembly structure note:** the GLB must carry the animation hierarchy:
an `ArmPivot` node at the axle containing ThrowingArm, the counterweight
hanger group (box + blocks hang from the arm's short end), and the sling
anchor at the arm tip; Stone starts parented to the pouch. If build123d's
glTF export flattens hierarchy, say so and instead export flat parts —
the app can rebuild the pivot grouping from part names + manifest pivot
metadata (add `"pivot": {"axle_height_in": 19, "arm": "ThrowingArm", ...}`
to the manifest if you go that way — axle height 10 in). Either is fine;
document which.

## 2. The app — loader (same contract as the dropped car, now the trebuchet)
- Load `res://models/trebuchet.glb` (Godot imports .glb as PackedScene;
  GLTFDocument fallback) + manifest at boot; collect MeshInstance3Ds as
  parts (name = node name).
- **Holo material for real meshes**: the existing part shader derives edges
  from the part's AABB (a box outline — wrong for real meshes). Add a mesh
  variant: translucent volume fill + **fresnel rim** + the same world-Y
  scan/flash behaviour. Bracket keeps the box-edge shader.
- **Display scale**: this is a tabletop model shown enlarged enough to
  work on — fit longest horizontal dimension to **0.75 m** on the inset
  (≈2.1× true size; pivot ends up ~0.53 m above the table). Model root
  placed at table-local **x ≈ −0.62**, facing +X (it fires along the
  table's length). SCALE readout at the table shows the actual factor and
  true size — enlargement form: `SCALE 2.1× · TRUE 14 × 7 × 10 IN`
  (reduction form `SCALE 1:X.X` if a future model is scaled down). DIMS
  readout keeps its current meaning (on-table size, decimal inches).
- **Explode + tethered labels** work on the trebuchet's real part names
  (labels fade in with explode, as brief #7 originally specced); panel part
  list shows trebuchet names + count.
- **Boot flow**: the trebuchet materializes at boot (scan plane from
  brief #6 applies). Bundled spoken lines stay as-is (no new voice audio).
- **Bracket parked**: existing TestBracket → table's left end is taken by
  the trebuchet — park the bracket at the table's **right end**
  (x ≈ +0.88), scale 0.6, already materialized, schematic under it; panel
  + readouts + boot target the trebuchet.
- **Draw calls**: report estimates at rest and exploded; keep ≤ ~90 by
  merging only genuinely static non-part geometry.

## 3. MANIPULATION — the point of this piece (Jon's word)

A working machine, driven by a kinematic state machine (no physics
engine). States: **REST** (arm up/spent), **COCKED**, **FIRING**,
**SETTLING**, then REST. Implement in a dedicated controller (e.g.
`trebuchet.gd` driving the assembly's pivot groups), with panel + grab
wiring in main/panel.

- **Cock**: animate the arm rotating about the axle from rest (long end up
  ~65°) down to loaded (long end down-back, tip near the base; counterweight
  raised), ~1.2 s, ease-in-out, winch feel (slight ratchet steps are a nice
  touch if cheap — the tick cue per step sells it). Stone sits in the
  pouch, sling draped along the base trough. Pin slides in at the end.
- **Fire** (only from COCKED): triggered by the panel FIRE button OR by
  laser-selecting/grabbing the `ReleasePin` part. Sequence ~1.2 s to
  release: counterweight drops (hanger swings down), arm whips up with
  accelerating ease, sling trails the tip then whips over the top, and the
  **stone releases near the top of the arc**. Then the arm carries through
  to rest angle while the counterweight oscillates with damped swing
  (~1 s SETTLING). Sling ends draped over the arm/base.
- **Stone flight**: simple projectile sim in scene units — launch velocity
  from the release point/direction the animation implies, gravity tuned so
  the arc scales to the model (Jon: "a satisfying arc across the table,
  not across the room" — the stone stays over the table: start g ≈ 18
  m/s², tune by playtest). **Counterweight blocks change the throw**: v0
  scales with active block count (1 block = lob, 6 blocks = flat and
  fast). Targets: 1 block lands ~0.7 m from release, default 4 blocks
  **1.3–1.7 m**, 6 blocks ≤ ~2.1 m — always on the inset; stone bounces
  once small, settles, fades after ~2 s. Log landing distances for 1 / 4 /
  6 blocks in your report (headless sim check).
- **Weight adjust**: panel WT − / WT + (1–6). Active blocks sit stacked in
  the counterweight box; spares rest in a row on the table beside the
  machine (still parts, still labelled). Adjustable in REST or COCKED.
  Changing the count also changes the fire animation's swing speed
  slightly (heavier = faster) — one parameter, two effects.
- **Reset**: animate back to REST (arm returns to rest angle, a fresh
  stone fades in at the pouch position on the table, sling re-drapes),
  ready to cock again.
- **Panel**: add a trebuchet control row — COCK, FIRE, RESET, WT−, WT+,
  and a `WEIGHT — N BLOCKS` readout. Buttons enable/disable by state
  (FIRE only in COCKED, COCK only in REST, etc.). Explode + scale controls
  disable during FIRING/SETTLING.
- **Sounds**: existing generated cues only — tick while cocking, confirm
  on fire, grab blip on pin select. No new audio.
- Sling during animation: rope + pouch are driven per-frame from the arm
  tip (stretch/orient the rope mesh between tip and pouch point; pouch
  follows its computed drape/swing position). A simple two-segment drape
  at rest, straightening as it whips, is enough — it must READ right:
  trail, whip, release at the top.

## 4. SPEC updates
- Showcase sections (§1, §2, §7 gate item): the demo is now the **working
  trebuchet** (cock/fire/reset, adjustable counterweight) — bracket = parked
  secondary item. Remove any CX-5 wording.
- §3: manifest sidecar + display-scale contract (as before), plus the
  manipulation state machine summary.
- **New §3 subsection — CAD quality standard (Jon's standing rule,
  2026-11-19, ALL build123d work):** print-minded (wall thickness,
  overhang/orientation, tolerances, watertight/manifold, supports
  considered) AND visually appealing (no crude placeholders); acceptance
  checklist = manifold verified, min wall + worst overhang + orientation
  reported, render eyeballed. This doubles as the voice-CAD worker's
  generation checklist.

## Validation
- CAD: script runs clean; checklist table printed (all parts pass);
  GLB node names == manifest part list exactly; preview renders exist.
- Headless: import + run clean; boot + materialize complete on the
  trebuchet; **exercise the state machine headlessly** (call cock → fire →
  reset from the capture/test harness) with no errors; report stone landing
  distances for 1 / 4 / 6 blocks.
- Captures: regenerate the standard four, plus `shot-05-trebuchet-cocked`
  and, if the harness can catch it, `shot-06-trebuchet-firing` (stone in
  flight) — if timing defeats the harness, say so and provide a CAD-side
  or schematic proof instead.
- APK re-export: apksigner Verifies, package + VR entries +
  networkSecurityConfig present; report size, light count (stays 3),
  draw-call estimates (rest / exploded).
- List every file changed + why; flag approximations honestly (especially
  sling behaviour and any body-shape shortcuts).

## Rules
- Colours from Tokens only. No new post-processing. Light count stays 3.
- No credentials. No git commits. The machine WORKING (cock/fire/reset
  reading right) outranks cosmetic gold-plating — but the CAD quality bar
  is a standing rule, not a garnish.
