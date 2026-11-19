# Atlas Holodeck — v1 Spec

**Status:** Approved by Jon, 2026-11-19 ("Start it — build v1 as specced").
**Product:** A Meta Quest 2 VR app that fuses a voice conversation with Atlas and a
Star Trek-style holodeck for CAD: describe a part out loud, watch it materialize on a
holo-table as a real build123d model, then grab it, turn it, zoom it, and pull it apart.

- **Engine:** Godot 4 (stable, 4.3+) + OpenXR, exported as a sideloaded Android APK.
- **Package id:** `com.jondude.holodeck`
- **Repo:** `Jondude1/atlas-holodeck` (public; no secrets, ever)
- **Workspace:** `~/workspace/atlas-holodeck/` — Godot project in `app/`, APKs in `builds/`
- **Build rule:** implementation goes through Claude Code; Helios briefs, reviews diffs, verifies.
- **Testing reality:** Helios builds blind (no headset on this side). Jon is the
  in-headset tester; expect short iterate rounds on feel (scale, grab distance, table height).

---

## 1. Experience (v1)

Jon puts on the Quest 2 at home and launches Atlas Holodeck. A short boot sequence
runs — a systems-check ring fills — and Atlas greets him by voice. He is standing in a
dark room lit in blue holographic light (the Stark design language, §2), facing the
holo-table: a wide, glowing work surface in the Agents-of-SHIELD style. Atlas is
present as a voice.

1. **Talk:** Jon holds a controller button (push-to-talk) and speaks. Atlas answers out
   loud, with the same memory, personality, and guardrails as the phone app — it is a
   new face on the same brain, not a second assistant.
2. **Create:** Jon says *"Atlas, make me a bracket, 80 mm wide, four bolt holes."*
   The request goes to Hermes, which (via its Claude Code lane) writes a build123d
   Python script. Athena's 3D worker runs it, validates the solid, and exports glTF.
   The finished model **materializes on the holo-table** with a scan/build-up effect,
   and Atlas confirms it out loud: *"Bracket rendered. Four parts."*
3. **Inspect:** Jon works the model **on the table surface** — drags it across the
   plane, spins it, stretches it with two hands — or lifts it off the table to grab,
   rotate, and scale it freehand. A flat blueprint layer (outline, dimension lines,
   labels) lies on the surface under the hologram and rotates with it. The **explode
   slider** on a floating panel separates the assembly into its named parts — then
   slides it back together.
4. **Keep / print:** The source `.py`, `.step`, and `.glb` are saved on Athena under
   the HA Slicer library. *"Send it to the printer"* is **confirmation-gated**: Atlas
   states what will print (part, material, estimated time) and waits for an explicit
   yes. A voice command alone never starts a print (material-consuming action).

## 2. Stark design language

**Jon's directive, 2026-11-19 — a first-class requirement for every build chunk, not
decoration:** *"Make this look and feel and act like a Stark Tech app."*

### LOOK
- Cinematic JARVIS/Stark holograms: deep dark room, **cyan/electric-blue holograms
  only — never orange** (stricter than the phone Atlas app, which keeps an orange
  accent; the holodeck does not).
- Translucent layered panels with fine line-work; circular HUD motifs — concentric
  rings, tick marks, radial gauges.
- Thin futuristic typography: a bundled tech font (Rajdhani, SIL OFL — license file
  ships in the project). Godot's default font is not acceptable.
- Soft glow on holo elements; subtle scanlines and drifting particles in the air.

### FEEL
- Nothing pops in statically: panels unfold/scale in with easing, buttons and
  controls answer with light pulses.
- The holo-table idles alive: a slow rotating ring and rising particle motes.
- Models materialize with a build-up: a wireframe/scan sweep resolving into the
  solid hologram.
- Gestures and interactions get immediate light + sound feedback — soft UI ticks and
  blips, **generated tones only, no copyrighted audio**.

### ACT
- Boot sequence on open: a systems-check ring fills; once connected, Atlas greets
  Jon by voice.
- Atlas speaks confirmations for actions ("Bracket rendered. Four parts.").
- Live workshop readouts around the table edge — connection, brain tier, part count,
  dimensions in mm — updating like a workshop HUD.

### Performance budget (Quest 2)
- Glow via emissive materials + cheap fake-bloom sprites rather than a heavy
  post-processing chain; room geometry stays light; effects are shader/sprite-cheap.
  (If real glow costs frame rate in-headset, fake-bloom sprites replace it — measure
  first, then decide.)

### The table — the Agents of SHIELD model

Stark/JARVIS is the overall look/feel/act language; **the holo table from Agents of
SHIELD defines how the table itself works**:

- **A physical metal table, not a hologram pedestal (Jon, 2026-11-19).** The
  SHIELD holotable is a heavy, real metal workstation with the holographic
  display surface set INTO the top as a glowing glass-like panel — restyled to
  **Stark Industries language** (Jon, 2026-11-19): sleeker machined surfaces,
  an angular **tapered** slab profile and tapered, splayed legs instead of boxy
  industrial, a premium **dark titanium** finish with clean panel lines (bolts
  and seams subtle, not military-crate), a **continuous cyan light strip inset
  along the slab's side edge**, matching light channels down the angled legs,
  and subtle illuminated edge trim. Build tokens: top ≈ **2.2 m × 1.2 m**,
  height ≈ **0.95 m**, slab ≈ **10 cm** thick, tapered/angular silhouette
  (detail via materials, not geometry — the table stays a handful of boxes);
  the etched grid + rotating ring render on the inset display surface only.
  **Display proportion (Jon, 2026-11-19):** the display covers MOST of the top
  — inset ≈ **1.95 m × 1.0 m** (~85–90% of the surface) with only a slim metal
  bezel/rim of ~10–12 cm around it, like the show table whose working surface
  is nearly all display. Holograms rise from the inset; the schematic layer
  lives on the inset; readouts are a mix of small physical bezel/edge displays
  and floating panels (the show table has both). Current visual reference:
  `design/concept-target-04.webp` (02 set the metal look, 03 fixed the
  proportions, 04 restyled it Stark-futuristic and supersedes both for the
  table).

- **A work surface, not a pedestal.** Models sit ON a glowing table plane and are
  manipulated ON it: drag across the surface to slide/rotate the model, swipe to
  spin it (with inertia), two-hand stretch on/above the surface to scale.
- **Layered display.** A flat 2D layer is projected ON the table surface under the
  3D model — blueprint/schematic: top-down outline, dimension lines, and labels
  lying flat — while the 3D hologram rises from it. Both layers are live: rotating
  the model rotates its flat schematic with it.
- **Physical feel.** Objects rest at table height, cast their glow onto the surface,
  and can be pushed around the plane; a flick slides a design aside or sends it
  spinning rather than it floating free.
- **Multi-object bench.** Several designs sit on the table at once, parked around
  the surface, pulled to center when selected — a shared workspace, not a
  single-item pedestal.
- **Aesthetic.** Blue-white holograms, a fine grid etched into the table surface, a
  soft glow column above the active object, thin labels tethered to parts.

**v1-chunk work** (after the skeleton): swipe-spin with inertia, flick-to-slide,
table-plane manipulation as the default mode (free-space grab stays available),
multi-object bench with park/select, dimension lines + labels in the flat layer,
glow column + tethered part labels.
**Skeleton implications (now):** the model root sits at table-surface height; the
model node carries its flat schematic/dimension layer; manipulation code treats the
table plane as the default work plane.

### 2.6 Show-accuracy reference (Jon, 2026-11-19: "as show accurate as possible")

Reference pass done 2026-11-19 from film/show stills (Iron Man workshop, Avengers
JARVIS panels, Agents of SHIELD S01 holotable). Stills are kept local-only in
`research/stills/` (never committed — copyrighted frames, internal reference only).
Palette values below were sampled programmatically from the hologram pixels of
five stills; geometry/beats were read from the frames.

**Design targets (committed):** `design/concept-target-01.webp` — a concept render
generated for Jon (2026-11-19) that distills the references into this app's exact
scene: exploded bracket assembly floating over the table with thin tethered part
labels ("BRACKET • MAIN", "STANDOFF • M4", "MOUNT PLATE • 04", "CLAMP • LOCK"),
concentric ring + radial-gauge HUD motifs left and right, the flat blueprint
schematic layer with dimension lines lying ON the table surface in front, etched
grid + rotating ring on the tabletop, cyan-only palette, particles rising.
`design/concept-target-02.webp` revised the table to the heavy metal SHIELD
workstation; `design/concept-target-03.webp` fixed the display proportions
(inset ≈85–90% of the top, slim bezel); `design/concept-target-04.webp`
restyled the metalwork Stark-futuristic (tapered slab, angled legs with light
channels, continuous edge light strip, dark titanium) and is the **current
table reference**, superseding 02 and 03 for the table. 01 remains the
reference for everything above the surface. Together 01 + 04 are the
**amazement-gate comparison targets** for the first-contact build: if the
in-headset scene doesn't read like these frames at first glance, the gate
fails.

**What the references actually look like**

- JARVIS holograms are a *mix* of wireframe and translucent volume, never solid:
  dark navy fills you can see through, thin bright cyan edge line-work, and
  white-hot cores where energy concentrates (repulsor, arc reactor, hologram
  hotspots in the SHIELD frames are near-white).
- Circular motifs everywhere: 2–3 concentric rings, an outer tick ring (fine
  ticks all the way around, longer majors), one brighter arc segment, small
  radial spokes/gauges nested inside. Nothing is a plain circle.
- Panels: dark translucent rectangles, 1px cyan borders, dense small text blocks
  and micro-diagrams. (VR legibility forces our panels to be sparser and larger
  — noted as an approximation, not drift.)
- SHIELD holotable: a large luminous table plane with faint panel seams and UI
  glyph strips along the near edge; the hologram floats just above the surface,
  parts translucent with bright edges; the surface visibly reflects the glow.
  The show occasionally uses an amber accent object — **our app stays cyan-only**
  per Jon's stricter rule; that is a deliberate deviation.

**Design tokens (the Godot theme/materials use exactly these)**

| Token | Value | Use |
|---|---|---|
| `room_bg` | `#04070C` | room/background near-black blue |
| `holo_deep` | `#0B3556` | panel fills, translucent volume base (alpha 0.35–0.55) |
| `holo_primary` | `#2F7FC4` | sampled mid-cluster blue — bodies, grid majors |
| `holo_line` | `#7FD4FF` | edge line-work, ring strokes, text accents |
| `holo_core` | `#EAF7FF` | white-hot cores, active highlights |
| `grid_minor` | `#1D5F8A` @ alpha ~0.35 | table/wall grid minor lines |
| `table_surface` | `#06283F` | table plane base (dark-room approximation of the show's bright plane) |
| fill alpha | 0.18–0.35 | hologram volume translucency range |

**Ring geometry token:** outer tick ring = 60 minor ticks (every 6°), 12 major
ticks (every 30°, ~2× length), 2 inner concentric rings at 0.82 / 0.64 radius,
one progress arc drawn brighter/thicker than the base ring.

**Table grid token:** etched grid on the display inset (1.95 m × 1.0 m, set into
the 2.2 m × 1.2 m metal top per §2) — minor lines every 10 cm, major lines every
50 cm at ~2× brightness, plus a UI glyph strip along the player-facing edge.

**Materialize beats (≈1.2 s total):** (1) flat schematic/wireframe appears on the
table surface → (2) a scan plane sweeps bottom-to-top, wireframe resolving as it
passes → (3) translucent volume fills in, edges brighten to `holo_line` →
(4) part labels fade in last.

**Boot beats:** black → ring + ticks draw in → progress arc fills clockwise
with tick highlights → one pulse at 100% → room and table fade up → demo part
materializes → Atlas greeting by voice.

**Boot storyboard (committed, Jon 2026-11-19):** `design/boot-frame-01.webp`
(ring ignition) → `design/boot-frame-02.webp` (systems check ~70%, gauge panels
either side of the ring) → `design/boot-frame-03.webp` (room reveal / table
power-on) → `design/boot-frame-04.webp` (demo part materializing over its
schematic). **Target timings:** frame 01→02 ≈ 1 s, systems check completes
≈ 2.5 s, room fade ≈ 1.5 s, materialize ≈ 2 s, then Atlas greets. (The current
build's boot runs ≈2.7 s with a 1.2 s materialize — aligning the timings to the
storyboard is a first-contact-chunk task.) The renders' text values are
placeholders — ignore them; real UI values follow the imperial-decimal rule
Jon set in the Holodeck chat.

**Film effects → Quest 2 approximations (stated, not silent):** true volumetric
glow column → additive transparent cone + rising particles; real bloom →
emissive materials + sprite halos; glossy surface reflection → a soft glow
decal under the active model (no planar reflections); dense film micro-text →
fewer, larger labels.

## 3. Architecture

```
 Quest 2 (Godot/OpenXR)                Home network (LAN / tailnet)
 ┌────────────────────┐   HTTPS/WS    ┌──────────────────────────────┐
 │ Holodeck room      │ ────────────► │ Atlas hub (Obelisk)          │
 │ PTT mic capture    │               │ http://100.65.202.81:8765    │
 │ TTS playback       │ ◄──────────── │ session, auth, routing       │
 │ glTF loader        │               └──────────────┬───────────────┘
 │ grab/explode UI    │                              │ brain turns
 └─────────▲──────────┘               ┌──────────────▼───────────────┐
           │ glTF (.glb)              │ Hermes (Athena) — primary    │
           │                          │ brain on Claude subscription │
           │                          └──────────────┬───────────────┘
           │                                         │ CAD job (build123d script)
           │                          ┌──────────────▼───────────────┐
           └──────────────────────────│ Athena 3D worker             │
                                      │ build123d → validate → glTF  │
                                      │ HA Slicer trio (existing)    │
                                      └──────────────────────────────┘
```

### Components

| Piece | Where | Notes |
|---|---|---|
| Holodeck app | Quest 2 (this repo, `app/`) | Godot 4 + OpenXR; renders room, table, models; mic in, TTS out |
| Atlas hub | Obelisk, `:8765` | Same hub the phone app uses; app authenticates the same way (hub-served provisioning, no secrets typed on the Quest) |
| Brain | Hermes on Athena | Primary tier (Claude subscription via DirectSDK); atlas:14b remains the local last-resort through Hermes, unchanged |
| CAD worker | Athena | Existing HA Slicer 3D stack (build123d). Input: natural-language spec → generated build123d script. Output: `.glb` + `.step` + source `.py`, saved to the slicer library |
| Printer | Kobra S1 (Nino, `s1_`) | Send-to-print only behind the confirmation gate |

### Data flow — one CAD request

1. Quest captures PTT audio → hub → Hermes turn (Atlas understands "make me a…").
2. Hermes delegates the CAD job: a build123d script is written for the described part
   (parametric, named solids — each part of an assembly is a named node so the explode
   view can separate them).
3. Athena worker executes the script in the build123d environment, checks the result
   is a valid solid (watertight where applicable), exports **glTF binary (.glb)** with
   part names preserved as node names.
4. Hub notifies the Quest session; the app downloads the `.glb` and spawns it on the
   holo-table at a default display scale (true scale available on request — a 80 mm
   bracket is small in the hand; default spawn is display-sized, with a "true scale"
   toggle).
5. Jon manipulates locally (grab/rotate/scale/explode are client-side, zero network).
6. Follow-ups ("make the holes bigger", "add a gusset") repeat the loop; the script
   on Athena is edited and re-run, and the model on the table is replaced in place.

## 4. v1 scope

**In:**
- Holodeck room: dark room, blue holographic grid (floor + walls), central holo-table
  (wide glowing work surface, §2), Stark-blue palette throughout.
- Stark design language (§2) applied from the skeleton on: bundled tech font, boot
  sequence, idle table animation (rotating ring + motes), materialize scan effect,
  UI tick sounds, table-edge status readouts; the table works to the SHIELD model
  (work surface, layered schematic, physical feel) with its full interaction set
  landing as v1-chunk work.
- XROrigin + two controllers; teleport-free standing/seated play (room-scale optional).
- Grab / rotate / scale for the model on the table; explode slider on a floating UI
  panel; parts keep their build123d names (shown on hover/select).
- Push-to-talk voice link to the hub/Hermes with spoken replies (same TTS path Atlas
  already uses).
- Voice-to-CAD loop as in §3, for single parts and simple assemblies (2–8 parts).
- Save-back to Athena (script + STEP + glTF land in the slicer library automatically).
- Confirmation-gated send-to-print.
- Home network only (LAN/tailnet addresses as the phone app uses).

**Out (v2+):**
- Passthrough / mixed reality placement on the real workbench (Quest 2 passthrough is
  black-and-white; deferred by Jon's v1 decision).
- Tailscale-on-Quest / away-from-home access.
- In-VR dimension editing with handles, measurement readouts, section views.
- Multi-user / shared holodeck.
- Hand-tracking-only interaction (controllers are the v1 input; hand tracking may be
  added if Godot/OpenXR support proves clean).
- The Fletcher room-node tie-in (office/garage nodes) — separate project; this app is
  the headset surface only.

## 5. Interaction details

- **Push-to-talk:** hold trigger (or A/X) to talk; release sends. A soft chime + orb
  pulse confirms Atlas is listening; the orb shows thinking/speaking state.
- **Grab:** grip button near the model grabs it; it follows the hand. The table
  plane is the default work plane (§2): released over the table, the model settles
  back onto the surface at table height; released away from the table it stays where
  it is. A "reset" gesture/button returns it to table center.
- **Scale:** two-hand grab and stretch, plus panel buttons for 0.5× / 1× / 2× / true scale.
- **Explode:** slider 0→1; each named part translates away from the assembly centroid
  along its own offset vector (computed from part centroids at load), labels fade in.
- **Panel:** one floating UI panel (table-anchored): explode slider, scale buttons,
  part list with names, "Send to printer" (opens the confirmation state, never fires
  directly), status line for Atlas/CAD job progress.

## 6. Safety & guardrails

- Money/send/delete class actions follow Atlas's existing Amendment 1 guardrails;
  send-to-print always confirms first, every time.
- No credentials in the app binary, the repo, or on the Quest: provisioning comes from
  the hub the same way the phone app's does.
- CAD scripts run in Athena's existing worker sandbox; a script that fails validation
  produces an Atlas explanation in the room, not a silent failure.
- Proactive speech rules carry over: the holodeck never speaks unprompted beyond the
  guardrails Atlas already runs under.

## 7. Build classes and verification gates

**Two build classes (Jon's quality bar, 2026-11-19 — "This needs to be amazing
when I install it and put it on"):**

1. **INTERNAL skeleton APK** — pipeline proof only: it exports, installs, and the
   scene loads. Produced during setup; it is NEVER handed to Jon as "the build."
2. **FIRST-CONTACT build** — the first APK Jon installs. It must pass the
   AMAZEMENT GATE below first. If a run lands only the skeleton, it is reported
   as skeleton-complete and the first-contact build stays the next milestone.

**AMAZEMENT GATE — every item true, verified as far as possible headlessly
(scene loads clean, no errors, timings sane):**

- [ ] Boot sequence plays: dark → systems-check ring fills → room fades up; no
      static first frame.
- [ ] The room reads Stark/SHIELD at first glance: §2.6 palette tokens applied,
      glowing table with etched grid + rotating idle ring + particle motes, HUD
      ring motifs present. Comparison targets: `design/concept-target-01.webp`
      (above the surface) + `design/concept-target-04.webp` (the table).
- [ ] Atlas greets Jon by voice on entry (hub connection; if the hub is
      unreachable, a graceful in-character fallback line — never an error
      screen).
- [ ] The demo assembly materializes on the table with the wireframe-scan
      build-up effect, schematic layer flat beneath it, and can be
      grabbed/rotated/scaled and pulled apart with the explode control.
- [ ] UI sounds on interactions; spoken confirmation for the materialize action.
- [ ] Frame-rate sanity: scene complexity within the Quest 2 budget (draw calls
      kept modest; the counts are noted in the build report).

**Skeleton (first build, internal) — ALL MET 2026-11-19:**
- [x] Godot project opens and runs headless with no errors; scene loads.
- [x] Android APK exports headless, is signed (debug signing acceptable for sideload),
      package id `com.jondude.holodeck`.
- [x] APK contains the holodeck room + table + a 3-part named test assembly with grab
      and explode wired (verified by code/scene inspection + headless run; in-headset
      feel check is Jon's first test).

**v1 acceptance (Jon, in headset):**
- [ ] App launches on the Quest 2 from Unknown Sources; room renders at a stable frame
      rate; table and test model visible at comfortable scale.
- [ ] PTT round-trip: Jon speaks, Atlas answers audibly, with the right memory
      (seed-fact probe: Fiona, Jenna alert rule, never restart Athena).
- [ ] "Make me a…" a simple part → model appears on the table within a reasonable
      time, named parts intact; explode slider separates and reassembles it.
- [ ] A follow-up edit replaces the model in place.
- [ ] Send-to-print stops at the confirmation and prints only after an explicit yes.
- [ ] One week of real use before anyone calls it v1.0 (same bar as Atlas).

## 8. Open questions (park, don't block the skeleton)

- STT path: hub-side transcription of the PTT clip vs. on-device — decide when the
  voice link is wired (skeleton ships without it).
- Display-scale default: fixed display size vs. true-scale-with-minimum — tune with
  Jon's first in-headset session.
- Whether the CAD job rides Hermes delegation or a dedicated hub endpoint — the hub
  lane decides during voice-link work; the app's contract is "POST a job, get a .glb".
