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
2. **Create:** Jon says *"Atlas, make me a bracket, 3.5 in wide, four bolt holes."*
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
   The v1 demo piece is the build123d test bracket, materializing at table centre over its
   flat schematic. (The trebuchet showcase is parked in `parked/trebuchet-app-20261119/`;
   its finished CAD is in `cad/`.)
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
  dimensions in decimal inches (feet + inches at table scale) — metric is internal
  only, never displayed — updating like a workshop HUD.

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
  and subtle illuminated edge trim. Build tokens: top **2.44 m × 1.22 m (8 ft × 4 ft, Jon 2026-11-19)**,
  height ≈ **0.95 m**, slab ≈ **10 cm** thick, tapered/angular silhouette
  (detail via materials, not geometry — the table stays a handful of boxes);
  the etched grid + rotating ring render on the inset display surface only.
  **Display proportion (Jon, 2026-11-19):** the display covers MOST of the top
  — inset ≈ **2.2 m × 1.0 m** (~85–90% of the surface) with only a slim metal
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

**Table grid token:** etched grid on the display inset (≈2.2 m × 1.0 m, set into
the 2.44 m × 1.22 m (8 ft × 4 ft) metal top per §2) — minor lines every 6 in, major lines every
1 ft at ~2× brightness, plus a UI glyph strip along the player-facing edge.

**Materialize beats (≈2 s total):** (1) flat schematic/wireframe appears on the
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
≈ 2.5 s, room fade ≈ 1.5 s, materialize ≈ 2 s, then Atlas greets. (Done in the
first-contact chunk: ring draw-in 0.6 s + arc fill 1.7 s + pulse 0.2 s = 2.5 s
systems check, room/table fade 1.5 s, materialize 2.0 s; the greeting plays after
materialize completes, then the confirm line — never overlapping.) The renders' text values are
placeholders — ignore them; real UI values follow the imperial-decimal rule
Jon set in the Holodeck chat.

**Film effects → Quest 2 approximations (stated, not silent):** true volumetric
glow column → additive transparent cone + rising particles; real bloom →
emissive materials + sprite halos; glossy surface reflection → a soft glow
decal under the active model (no planar reflections); dense film micro-text →
fewer, larger labels.

**Room + polish pass approximations (brief #8, vs `concept-target-04`):**
- Floor reflection → no planar/SSR reflections; a dark metallic-rough floor with a procedural scuff/seam tile, a cyan glow-pool decal and a soft contact shadow under the table.
- Volumetric glow / god-rays → environment fog (single density), additive halo sprites around wall accents and the cove, denser mote/dust particles; no volumetric fog.
- Room detail → four canvas-drawn wall planes (panel seams, recessed bays, shelving/crate/drum silhouettes on the side walls), dark ceiling beams, one cyan cove strip and six recessed accent strips; flat textures, no real geometry depth, no external assets.
- Brushed titanium → tiled procedural grain texture + metallic/roughness tune + bevel highlight strip; no anisotropic reflection or per-pixel env probes.
- Tethered labels → one box leader line + Label3D per part, tracking explode; no per-part screen-space avoidance.
- HUD frame → status strip, two counter-rotating arc frames, EXPLODE radial gauge and status card are flat quads/shaders in world space (not head-locked); the renders' decorative telemetry (SYNC, BAT, TEMP, POWER, LOAD, hex-panel graphs) is deliberately omitted: every value shown is real (system clock, LINK/BRAIN from the hub check, PARTS/DIMS/EXPLODE from the model).
- Surface schematics → one low-alpha etched-drawing texture in the inset's end zones; far simpler than the renders' dense blueprint overlays.
- Budget at rest (brief #8 build): 60 draw calls (target <= 90), 3 lights.

**Lab polish approximations (brief #12, "like I'm in Tony Stark's lab"; vs `concept-target-04` / `-01`):**
- Set dressing → all procedural, merged by material: workbenches with cabinets/equipment, two shelving units, wall pilasters/pipe runs/vents/junction boxes, a ceiling rig, floor trim, cables = ONE lit vertex-coloured mesh; cyan trim/LEDs/ring light/accent strips/cove = ONE emissive mesh. Dark titanium / deep blue with cyan rim accents only. Equipment is simple forms (crates, canisters, tool silhouettes, monitor, printer frame) — no real modelling, no external assets, no per-object lighting detail.
- Wall screens → seven animated displays (rings, scrolling graphs, hex schematic, readout rows) in one mesh with one procedural shader (`screens.gdshader`, TIME-driven, cyan tokens only): no canvas re-draw per frame, no real data. The renders' dense micro-text and photographic UI are NOT approximated beyond dashed readout rows.
- Light shafts / volumetrics → additive open cones from the rig to the table + layered additive halos (one mesh, `lightfx.gdshader`); no volumetric fog, no shadowed god-rays, no real light-linked scattering.
- Floor reflection → still no SSR/planar reflection: a dark glossy tile (seams + scuffs), additive gloss streaks under the slab edges and legs, an under-glow spill pool and a tight contact core. A reflection of the hologram or of the room is not drawn.
- Glow → emissive HDR materials + the existing environment glow; sprite halos. No bloom chain beyond the environment's.
- Brushed titanium → procedural grain + a normal map from the same height field (streak highlights), a heavier slab (0.13 m) with a protruding top lip, bottom skirt and a recessed light channel; the env reflection is a procedural sky lifted one step so metal reads blue instead of black. No anisotropic BRDF.
- Ambient life → a pulse travelling the slab's edge strip (and up each leg channel), slow-rotating holographic ring above the table, 240 room motes + 90 table motes, shimmering shafts, scrolling screens: nothing is static at idle.
- Budget (brief #12, measured by the capture harness `RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`): 62 draw calls at rest and exploded in the capture framing; worst case 82 from a wide standing pose with the whole lab in view; 77-80 with a voice-CAD model on the table. 3 lights (table glow, player fill, rim) — everything else is emissive/sprite. Where it went: the lab is 5 draws (lit set, emissive set, light FX, screens, holo ring); the room's 5 beams + 6 accent strips + cove (12 draws) and the table's legs/channels/bevels/bezel lines (10 draws) were merged to pay for it.

## 3. Architecture

```
 Quest 2 (Godot/OpenXR)                Home network (LAN / tailnet)
 ┌────────────────────┐   HTTPS/WS    ┌──────────────────────────────┐
 │ Holodeck room      │ ────────────► │ Atlas hub (Obelisk)          │
 │ PTT mic capture    │               │ LAN 192.168.4.51:8765        │
 │ TTS playback       │ ◄──────────── │ tailnet fb 100.65.202.81:8765│
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
| Atlas hub | Obelisk, `:8765` — LAN primary `192.168.4.51:8765`, tailnet fallback `100.65.202.81:8765`; cleartext permitted to those two hosts only (Android network security config) | Same hub the phone app uses; app authenticates the same way (hub-served provisioning, no secrets typed on the Quest) |
| Brain | Hermes on Athena | Primary tier (Claude subscription via DirectSDK); atlas:14b remains the local last-resort through Hermes, unchanged |
| CAD worker | Athena | Existing HA Slicer 3D stack (build123d). Input: natural-language spec → generated build123d script. Output: `.glb` + `.step` + source `.py`, saved to the slicer library |
| Printer | Kobra S1 (Nino, `s1_`) | Send-to-print only behind the confirmation gate |

### Voice architecture (brief #11, 2026-11-20)

```
 Quest 2 mic ──PCM16 16 kHz──► WS /atlas/voice-stream (hub, token-gated) ──► sherpa-onnx KWS ("Atlas"/"Hey Atlas")
 TALK button / left trigger ─ptt_start/end─►                                           └─► energy end-pointing (1.2 s) ──► faster-whisper
                                                                                     │ transcript
                                  ◄── wake / utterance_end / transcript / reply ◄────┤
                                                                                     ├─ "make me a …" ─► POST-equivalent CAD job (below)
                                                                                     └─ otherwise      ─► the /atlas/ask path (25 s voice budget)
 reply text ──POST /atlas/speak (Kokoro, mp3)──► spatial AudioStreamPlayer3D at the panel
```

- **Hub (`obelisk/atlas_voice.py`, additive):** installed by one guarded block placed *before* the hub's catch-all `app.mount("/", _mcp_app)` (a route registered after that mount would be shadowed). Adds `WS /atlas/voice-stream`, `POST /atlas/speak` (proxy of the Kokoro server on Obelisk, the phone's voice `af_heart`; the headset never talks to :8880 directly, one origin, one token), `POST /atlas/cad-job`, `GET /atlas/cad-job/<id>` (status + manifest), `GET /atlas/cad-job/<id>/model` (glb), `GET /atlas/voice-status`. All token-gated exactly like `/atlas/ask`. No existing route touched.
- **Wake word:** the phone's own spotter family (sherpa-onnx zipformer KWS, the same model files and `keywords.txt`), run server-side on the stream; `num_trailing_blanks=2` (the phone uses 1) cut false wakes on adversarial phrases from 5/20 to 1/20. Measured on synthesized voices: "Hey Atlas…"/"Okay Atlas…" 14/14, bare sentence-initial "Atlas" 6/14, 0/8 false wakes on non-wake speech. **Real-voice, real-mic wake reliability is unproven until the headset runs; PTT is the proven path.**
- **STT:** faster-whisper `base.en` pinned to CPU/int8 *inside the voice module*. The hub's own `/atlas/transcribe` loads the model with `compute_type="auto"`, which selects CUDA and fails on a missing `libcublas.so.12` on Obelisk (500 on any real audio — pre-existing, untouched under the additive-only rule; its `model.bin` cache was also incomplete and was completed).
- **Conversation:** same path as `/atlas/ask`, bounded to 25 s for the headset; on timeout the reply is an honest in-character line. (`/atlas/ask` itself takes 60 s+ on Obelisk today — the 14B model is split CPU/GPU at 16k context — an existing hub condition the phone shares.)
- **Intent routing:** a deterministic rule first ("make/build/design/create/model/generate … me a/an/the/some …", not a question); only when a CAD verb is present but the shape is ambiguous does the hub ask its local LLM a yes/no. Everything else is conversation.
- **CAD jobs:** `claude -p` (Claude Code, headless, no tools; Hermes `hermes -z` as fallback) writes a build123d script against a fixed contract (mm, Z-up, named PascalCase parts, `build()`); the script is copied to Athena and run **inside the live `build123d` container via `ssh jon@athena docker exec build123d python /work/scripts/voicecad/run_job.py <id>`**. The runner enforces the CAD quality standard below as a machine-checked acceptance list (valid, one solid, volume > 0, watertight mesh, minimum wall ≥ 0.8 mm, no unexplained interference; overhang reported) and exports `model.glb` (Y-up metres, one node per named part), `model.step`, `manifest.json` (decimal inches, the `cad/trebuchet.manifest.json` shape), `source.py`, `report.txt` to `C:\Users\jon\mediastack\3d-work\out\voicecad\<job_id>\` (container `/work/out/voicecad/<job_id>/`). A failed checklist is fed back to the writer for up to two repair passes — never waived. The hub copies glb + manifest to `~/.local/share/atlas/cad-jobs/<id>/` and serves them.
- **App (`voice.gd`, `cad_bench.gd`, `cad_model.gd`):** mic = `AudioStreamMicrophone` → bus `HoloMic` (`AudioEffectCapture` tap, then −80 dB so the mic is never played back) → mono, box-filter resample to 16 kHz, 60 ms binary frames. Android `RECORD_AUDIO` is declared in the export preset and requested at runtime before first use (`audio/driver/enable_input=true`). Voice-CAD materializes through the existing language via the runtime GLB loader promoted from `parked/trebuchet-app-20261119/` (`GLTFDocument.append_from_buffer`; fresnel mesh shader `holo_mesh.gdshader`); parts are scaled to a table-readable size on load and every displayed dimension is divided back to true inches (`display_scale`). The previous model is **parked** at the table's edge (multi-object bench); explode/scale/panel/HUD/readouts retarget to the new model. Completion is followed by socket event *and* a REST poll, so a dropped socket can't lose a finished part.
- **Credential:** the hub token is read from the gitignored `app/hub_secret.cfg` at export time and baked into the APK (`include_filter="hub_secret.cfg"`); it is not in this repo. The phone is given the same token by hand ("Hub token, if you set one").
- **Send-to-print:** this build has **no print path**. Voice alone never prints; when a print route is added it must be gated by an explicit panel confirmation.
- **Failure behaviour:** hub unreachable → state `VOICE OFFLINE`, the recorded greeting/confirm lines stay as they are, the socket retries with backoff (3/6/12/20 s) and re-probes LAN then tailnet; TTS failure → a chime and the text on screen; no error screens, no hangs.

**Indication & logging rules (Atlas standing rule — explicit, indicated, logged):**
- **PUSH-TO-TALK IS PRIMARY (Jon's addendum, 2026-11-19 20:58 ET); the wake word is experimental and OFF by default (`VoiceLink.wake_enabled=false`).** **MIC LIVE ⇔ PCM frames are actually leaving the headset.** With wake off that is *only* state `LISTENING` during a hold: the OS microphone capture itself is started on press and stopped on release (`_sync_mic`), nothing is streamed or captured while idle (idle reads `MIC OFF - HOLD TO TALK`), and a scripted run proves 0 audio bytes reach the hub before the first hold. `THINKING` and `SPEAKING` never stream (Atlas never hears itself); `MUTED`, `VOICE OFFLINE` and `MIC BLOCKED` send nothing — each says so in words. Only if the experimental wake is switched on (`set_wake_enabled`) does `ARMED` also stream, and then it reads `MIC LIVE`.
- Indicators (all Tokens colours): an orb + state word under the HUD status strip (steady glow = MIC LIVE; bright core pulsing with the real input level = LISTENING; slow pulse = THINKING; wave = SPEAKING; dark = off), the state word in the Atlas panel's voice row, a `VOICE` line on the status card, and a subtitle with the last thing heard/said. Wake → rising earcon + LISTENING; utterance end → falling earcon + THINKING.
- **PTT controls (both required, both conflict-free):** (a) the big **HOLD TO TALK** button on the table panel (`TalkButton`, press = `ptt_begin`, release = `ptt_end`); (b) the **LEFT controller trigger** (`trigger_click`), unconditional. Conflict-free because: the left hand has no pointer role (the laser/UI click is the right trigger), grip = grab/rotate/scale, left menu long-press = RESET FLOOR — the left trigger is bound to nothing else. Secondary: the right trigger when aimed off the panel (on the panel it clicks UI). Hold = tone + LISTENING + mic live; release = falling tone + THINKING; PTT while Atlas speaks cuts the reply off (barge-in). Same hub pipeline for every path. The panel's **MUTE VOICE** button stops everything (socket closed, indicator off).
- Logging: every state change prints `[VOICE] t+ms state A -> B (mic streaming: …)` (logcat), CAD steps print `[CAD]`; the hub logs each session (wake source, transcript, reply, CAD job id) to the journal and to the vault's daily log (`device: holodeck`).

### CAD quality standard (Jon's standing rule, 2026-11-19 — ALL build123d work)

Every build123d output must be (1) **designed for 3D printing** — real wall thickness,
overhang/orientation awareness, fit tolerances (pivots clear by 0.3 mm), watertight/manifold
solids, supports considered — and (2) **visually appealing every time**: no crude
box-and-cylinder placeholders (chamfered timber, iron fittings as darker solids, rope with a
pouch). Acceptance checklist, printed per part by the script: `is_valid()`, solid + exported
mesh watertight/manifold, volume > 0, minimum wall, worst overhang vs the intended print
orientation (and that orientation), no part interference; render eyeballed. A failed line is
fixed in the script, never waived. This doubles as the voice-CAD worker's generation checklist.

### Data flow — one CAD request

1. Quest captures PTT audio → hub → Hermes turn (Atlas understands "make me a…").
2. Hermes delegates the CAD job: a build123d script is written for the described part
   (parametric, named solids — each part of an assembly is a named node so the explode
   view can separate them).
3. Athena worker executes the script in the build123d environment, checks the result
   is a valid solid (watertight where applicable), exports **glTF binary (.glb)** with
   part names preserved as node names.
4. Hub notifies the Quest session; the app downloads the `.glb` and spawns it on the
   holo-table at a default display scale (true scale available on request — a 3 in
   bracket is small in the hand; default spawn is display-sized, with a "true scale"
   toggle).
5. Jon manipulates locally (grab/rotate/scale/explode are client-side, zero network).
6. Follow-ups ("make the holes bigger", "add a gusset") repeat the loop; the script
   on Athena is edited and re-run, and the model on the table is replaced in place.

### Round 1B additions (brief #16, 2026-11-20)

- **Follow-up edits (R1-4).** The hub remembers the Holodeck's latest job (`last_job`, 30 min window). An utterance that
  matches the narrow edit cues ("make it taller", "add two holes", "thicker walls", "remove the lip") while a finished job
  exists is routed to a **revision**: `new_job(text, parent)` stores `parent`/`kind: "edit"`, a composite prompt (original
  request + the change), and the writer is handed the parent's `job.py` plus the requested change, not a blank page. A
  "make me a ..." / "new" / "another" request is always a fresh design; while the last job is still building the hub asks
  Jon to wait. `POST /atlas/cad-job` also takes `edit_of` (must name a finished job, else 409). The headset sees the job's
  `parent` in the status JSON and **replaces the parent's model in place** (same bench slot, position, orientation, scale;
  TRUE SIZE stays TRUE SIZE; old node freed) instead of parking it.
- **Send-to-print, dry run only (R1-8).** Panel `SEND TO PRINTER` or a spoken "send it to the printer" opens a confirmation
  card (part, material PLA, printer S1, estimated time) — and nothing else. Only the panel CONFIRM press, or a spoken yes
  arriving while the card is open for that same part, moves on; cancel / no / 45 s timeout / the part being replaced
  closes it with nothing sent (`PrintFlow`, `print_flow.gd`). The hub classifies the spoken yes/no only while a request is
  pending (voice request, or the app's `print_pending` socket message) and merely reports it; the headset then calls
  `POST /atlas/print-job {job_id, confirmed:true}`, which validates and returns a **dry-run plan** (`dry_run:true`,
  `contacted_printer:false`, `sliced:false`: file, printer S1, profile, steps) and logs `[print-job DRY-RUN]`. It never
  slices and never contacts the printer. The live path is the `live_print()` stub + `PRINT_LIVE=False` in `atlas_voice.py`
  and the client refuses any reply that is not a dry run: wiring it needs Jon's separate sign-off.
- **Real silhouette schematic (R1-12).** `Blueprint.make_silhouette` rasterises every part's triangles top-down (XZ), takes
  the union as the outline, finds the real through-holes as enclosed empty regions (centre/size from the raster, crosshair on
  round ones), adds a section hatch and the dimension lines. The layer is a child of the model, so it rotates and scales
  with it. Holes whose axis is horizontal (a screw hole through a wall) are not visible from above and are not drawn.
  The old bounding-box + bolt-pattern layer remains reachable via `Blueprint.legacy` for comparison only.
- **Save-back (R1-9).** After a successful build the hub copies `model.py` (the script that ran), `model.step`,
  `model.glb`, `manifest.json`, `job.json` into the shared Athena library tree:
  `C:\Users\jon\mediastack\3d-work\out\holodeck\<name-slug>-<job_id>\` (container `/work/out/holodeck/...`), recorded in
  the job as `library`. The runner's own `out/voicecad/<id>/` copy and the hub job folder are kept. Redirect by changing
  `LIBRARY_SUBDIR` in `atlas_voice.py`.

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

**Known on-device bug (2026-11-19, brief #9):** the first Quest 2 run played the boot
audio but never presented a VR frame (Meta's 3-dot loading screen stayed up). Causes
found: preset `xr_mode=2` was invalid, so the APK carried `--xr-mode off` and no OpenXR
loader; XR init was also a single attempt in the main scene. Hardened: `xr_mode=1`, an
`XrBoot` autoload (per-frame retry ~5 s, `[XR]` logcat lines with msec timestamps for
init and XRServer session signals, deterministic camera arbitration). **Headless
captures do NOT prove XR presentation — they render through the desktop fallback
camera. An on-device smoke test is the only proof.** Status: awaiting Jon's retest.

**Known on-device bug #2 (2026-11-20, brief #10):** floor height didn't match Jon's real standing height. `XrBoot` now requests reference space STAGE → LOCAL_FLOOR → LOCAL (via `xr/openxr/reference_space` + `XRInterface.supports_play_area_mode`), logs requested/granted space and camera height (`[XR]`), and the panel's RESET FLOOR button / left-menu long-press runs `XRServer.center_on_hmd(…, keep_height=false)`. Status: awaiting Jon's retest.

**Combined build (2026-11-20, briefs #10 + #11 + #12):** floor fix (above) + voice conversation + voice-to-CAD + Stark-lab visual polish, one APK. Headless/mock-hub validation proves the client protocol, state machine, indicators and the CAD materialize path; **only the headset can prove** real mic capture + the Quest audio permission prompt, wake-word reliability with a real voice, TTS audibility/spatialization, and the on-device frame rate with the lab (draw calls measured, frame time not).

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

### Round 2 additions (brief #17, 2026-11-20 — Helios takeover build)

Built by Helios directly under Jon's Claude-limit takeover order (the
Claude session limit stalled the run; resets 12:40 ET). Same gates.

- **Render settings (R2-10).** project.godot: MSAA 2x, OpenXR display
  refresh request 90 Hz, foveation level 2. On-device effect is
  headset-verifiable only; headless frame baseline comes from
  tools/perf_probe.gd draw-call counts.
- **CAD stage narration (R2-7).** The bench status now reads the hub
  job's real stage — QUEUED / WRITING / REPAIRING / BUILDING /
  FETCHING / SAVING — with elapsed seconds, instead of one blanket
  BUILDING for the whole wait.
- **Real brain tier (R2-11).** /atlas/voice-status reports the hub's
  configured chat model + locality (brain_model, brain_local). The HUD
  BRAIN line shows it (e.g. "LOCAL · ATLAS:14B"), "HUB" when the tier
  fetch fails, "OFFLINE" when no hub answers. Replaces the blanket
  "HERMES" label, which claimed a tier the app could not know.
- **Skippable boot (R2-8).** Any controller button press (or a desktop
  key) during the ring sequence jumps to the normal completion path;
  the greeting and materialize still happen. A guard prevents the
  completion running twice.
- **Haptics (R2-1).** Short pulses on grab, release, bench select,
  panel poke, and materialize-complete. No-ops unless XR is live.
- **Easing (R2-3).** app/ease.gd is the one easing language (cubic-out
  for motion, sine-in-out for fades); the previously linear fades use
  it. Designed exceptions (panel pop, boot fill) are documented there.
- **Hover (R2-2).** A parked model under the ray now glows as one
  whole selectable object; active-model per-part hover is unchanged.
- **Hub greeting (R2-9).** When the hub answers the boot probe, the
  greeting is spoken by the hub's voice with the time of day; the
  recorded clips are the offline fallback.
- **Panel rendering (R2-6).** Idle panel viewport is DISABLED between
  a 5 s safety pulse (was: full re-render every 0.5 s). All content
  changes funnel through poke(); expiry draws one final frame.
- **Spawn/boot hitch (R2-4/R2-5).** The silhouette texture paint
  (~0.35-0.45 s) no longer runs inside the model's _ready; it is
  deferred a frame and materialize's schematic fade waits for it.
  The paint still costs what it costs — it no longer stacks onto the
  spawn/boot frame.
