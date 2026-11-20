# ITERATION-BACKLOG — v1 feature audit + round plan (Brief #14, 2026-11-20)

**Audit only.** Built from a line-by-line read of SPEC §1, §2/§2.5/§2.6, §4, §5, §6 against `app/*.gd`, `app/main.tscn`,
`app/project.godot` and the hub module `~/workspace/atlas-overlay-build/repo/obelisk/atlas_voice.py`; looked at
`design/concept-target-04.webp` against `captures/shot-04` and `shot-07`. No code was run on a headset; nothing here is
frame-time-measured. Evidence cites file:line where I read it. Items I could not prove from code are marked **(unverified)**.

**JON'S PRIORITY ORDER (2026-11-20, steering all rounds):** this is a hobbyist ENGINEERING WORKSPACE — the table and what it can DO come first; visuals and atmosphere are welcome but secondary. Get the table working the way the Agents of SHIELD holotable worked: a real work surface you manipulate designs on (drag/spin/scale/bench/labels/schematic), not a display pedestal. When a round forces a trade-off, table function wins over ambience; Round 3's living-lab dressing stays capped and never displaces table work.

Legend: **PRESENT** works as specced · **PARTIAL** exists, weaker than spec (how) · **MISSING** not there.

## 1. Feature table

### Experience (§1) / Boot / Voice

| # | Promised item | Status | Evidence | Gap |
|---|---|---|---|---|
| 1 | Boot: ring fills, room fades up, no static first frame | PRESENT | `main.gd:103-126` `_boot()`; 0.6 + 1.7 + 0.2 s ring, 1.5 s fade, 2.0 s materialize = SPEC §2.6 timings | `_apply_tokens()` builds room/lab/HUD and CPU-paints textures (`room.gd:150-250`, `fx.gd:82-103`) *before* the first boot frame — on Quest the black wait before the ring is unmeasured (see S-5). |
| 2 | Atlas greets by voice on entry ("once connected"; graceful fallback if hub down) | PARTIAL | `main.gd:137-138` plays pre-recorded `greeting.mp3` + `confirm_render.mp3` after materialize; hub probe `main.gd:130,147` runs concurrently | Greeting is not hub-driven and not conditioned on the connection; same two clips always play (so no error screen, but also no "connected" greeting). `confirm_render.mp3` is a fixed clip — its wording vs the 3-part demo bracket is **(unverified)** (audio not listened to). |
| 3 | Dark blue holo room, table, Stark palette | PRESENT | `room.gd`, `lab.gd`, `table.gd`, `tokens.gd` | Fidelity gaps → §3. |
| 4 | Atlas present as a voice in the room | PRESENT | `voice.gd:74-78` `AudioStreamPlayer3D` at the panel, unit_size 2.5, max 12 m | Source is the panel, not the table/room centre. |
| 5 | PTT: hold controller button to talk, release sends | PRESENT | `hand.gd:31-37,59-63` left trigger; `ui_panel.gd:129-152` TalkButton; `voice.gd:387-415` | SPEC §5 says "trigger (or A/X)": A/X is **not** bound (`openxr_action_map.tres` defines `ax_button`, nothing reads it). |
| 6 | Chime + orb pulse; orb shows thinking/speaking | PRESENT | `sfx.gd:12-13` wake/end; `hud.gd:174-210` `_animate_mic` | — |
| 7 | Barge-in (PTT cuts Atlas off) | PRESENT | `voice.gd:390-393` | — |
| 8 | Same memory/personality as phone ("new face on same brain") | PRESENT (hub) | `atlas_voice.py:530` calls the same `srv.ask` path | **Known degraded:** `/atlas/ask` ≈ 60 s on the 14B fallback, blows the 25 s `ASK_BUDGET_S` → canned "taking too long" reply (`atlas_voice.py:532-534`). Hub/brain-chain issue, not app. |
| 9 | "Make me a…" → Hermes → build123d → validate → glTF | PRESENT | `atlas_voice.py:123-140,273-313,518-528`; `cad_bench.gd:43-119`; in-app round-trip 501,944 B glb proven (WIP-STATE) | Single-part jobs only exercised (`cad-jobs/0f84d94de2` = 1 part). Serial queue; N64 job blocked it. |
| 10 | Model materializes with scan/build-up; Atlas confirms aloud | PRESENT | `model.gd:303-324`; `cad_bench.gd:109-117` "Here is your X. N parts, A by B by C inches." | Spoken line says "Here is your…" *before* materialize (SPEC example is "Bracket rendered. Four parts."); fine, but text differs. |
| 11 | Follow-up edits ("make the holes bigger") replace the model **in place** (§3 step 6, §7 acceptance) | **MISSING** | Hub `route()` has no edit path: every CAD utterance → `new_job(text)` with no `prev_code`/parent job (`atlas_voice.py:518-528`; `write_code(prompt, prev_code, error)` only uses `prev_code` for repair). App `spawn()` **parks** the old model and adds a new one (`cad_bench.gd:102-105`). | Need: hub keeps last job id per session, edit intent feeds `source.py` back to the writer; app replaces the active model (or keeps old as parked history by explicit choice). |
| 12 | Spoken explanation when a CAD job fails validation (§6) | PARTIAL | `cad_bench.gd:49-55`: `_voice.say("I couldn't get that one to build. Try describing it a little differently.")`; hub *does* send `detail` (`atlas_voice.py:552`, ≤400 chars of runner output) | Generic line only; the real failure reason is logged, never spoken or shown. No on-table/HUD failure state (status just clears). |

### The table (§2 SHIELD model) and manipulation (§4/§5)

| # | Promised item | Status | Evidence | Gap |
|---|---|---|---|---|
| 13 | 8×4 ft titanium table, inset 2.2×1.0, edge strip, leg channels | PRESENT | `table.gd:8-20,94-165` | Concept-04 tapered/angled silhouette only approximated (boxes + wedges). |
| 14 | Etched grid 6 in / 1 ft, rotating idle ring, rising motes | PRESENT | `table.gd:192-215,239-241,258-323`; `grid.gdshader` | Ring is a flat quad; glyph strip along the near edge not present **(unverified — not found in table.gd)**. |
| 15 | Flat blueprint layer under the model, dimension lines + labels, rotates with model | PARTIAL | `model.gd:140-182` (schematic + 2 dim labels as children of the model → rotates with it); `blueprint.gd:9-30` | The outline is the part's **bounding-box rectangle plus a hard-coded 4-bolt-hole pattern and pitch circle**, not the part's real top-down silhouette/holes. For any voice-CAD part the "schematic" is generic decoration. Only X/Z dims, no height dim. |
| 16 | Default work mode = table plane: drag across the surface | **MISSING** | `grabbable.gd:44-54` follows the hand in 3D; no plane projection, no constraint to table height | Only free-space grab exists. |
| 17 | Swipe-spin with inertia | **MISSING** | no angular/linear velocity tracking anywhere (`grabbable.gd`, `hand.gd`) | — |
| 18 | Two-hand stretch on/above surface to scale | PARTIAL | `grabbable.gd:48-54` two-hand scale + rotate, clamp 0.2–6.0 | Works free-space only; not plane-constrained; no snap to 0.5/1/2; clamp doesn't account for `display_scale`. |
| 19 | Lift off table for freehand grab/rotate/scale | PRESENT | `grabbable.gd` + `hand.gd:23-28,65-75` (nearest grabbable in reach) | No in-reach highlight (see S-3). |
| 20 | Released over table → settles back to surface height; released away → stays | **MISSING** | `grabbable.gd:3` "Release = stay where it is"; `end_grab` only `_recapture()` | A released model hangs in mid-air anywhere, including over the table. |
| 21 | Flick slides a design aside / sends it spinning | **MISSING** | no velocity sampling, no friction model | — |
| 22 | Reset gesture/button returns model to table centre | **MISSING** | `RESET FLOOR` (`ui_panel.gd:113-127`, `hand.gd:83-85`) recentres the *player's floor height* via `XrBoot.reset_floor`, not the model | Name collision risk: Jon may press RESET FLOOR expecting model reset. No model reset anywhere. |
| 23 | Objects rest at table height and cast glow onto the surface | PARTIAL | table point light `table.gd:168-174`; model origin at `TOP_Y` | No under-model glow decal (SPEC §2.6 approximation promises one) and no glow column over the active object (§2 "soft glow column"): `grep` finds neither. |
| 24 | Multi-object bench: several designs parked, pulled to centre when selected | PARTIAL | `cad_bench.gd:15,126-147` 4 park slots, max 5; `model.gd:112-124` `park()` | Auto-park of the previous model works. **No select/pull-to-centre**: nothing re-targets panel/HUD/explode to a parked model or animates it back (`_retarget` only called from `spawn`). A parked model can only be free-grabbed, and it keeps its schematic/labels off permanently. |
| 25 | Grab/rotate/scale audible+visual feedback | PARTIAL | `model.gd:132-138` grab tick on grab and release | Sound only: no haptics (`trigger_haptic_pulse` absent), no reach/hover highlight, no light pulse on grab. |

### Panel (§5) and Explode

| # | Promised item | Status | Evidence | Gap |
|---|---|---|---|---|
| 26 | Explode slider 0→1, parts translate along own vector from centroid, labels fade in | PARTIAL | `ui_panel.gd:68-79`; `model.gd:103-108` `_dir = part origin − centroid of origins`, fixed `EXPLODE_DISTANCE 0.25 m` | (a) Direction uses node **origins**, not mesh centres: if the exporter bakes vertices in world space (origins all 0) every part gets `Vector3.UP` and they lift together instead of separating — **(unverified)**, only a 1-part CAD model has ever been exploded (`captures/shot-07`). (b) Labels are always-on after the materialize beat, not tied to explode. (c) Distance ignores part size/`display_scale`. |
| 27 | Scale buttons 0.5× / 1× / 2× | PRESENT | `ui_panel.gd:93-108` → `model.gd:129-130` (instant set) | Snaps instantly (no ease). |
| 28 | **True scale** button/toggle (§3 step 4, §5) | **MISSING** | no such button; `display_scale` (`cad_model.gd:42`) is only used to divide displayed dims back | CAD models spawn at a fixed 0.5 m fit; "1×" is display size, never true size. A true-scale button = scale 1/`display_scale`. |
| 29 | Part list with names on the panel | PARTIAL | `ui_panel.gd:81-88` one `Label` "Parts: A, B, C", `clip_text = true` | A comma string that clips with >2-3 parts; not a list, not selectable, no per-part highlight. |
| 30 | Part names shown on hover/select (§4) | PARTIAL | `model.gd:185-224` tethered labels always on after beat 4 | No hover/select behaviour at all. |
| 31 | Panel status line for Atlas/CAD job progress | PARTIAL | `hud.gd:164-165` CAD status on the world-space status card (`BUILDING n s` / `READY`); `cad_bench.gd:18` | Not on the panel; no progress stages (hub exposes `stage`: writing/repairing/building/fetching, `atlas_voice.py:279-299`, app ignores it); failed state invisible. |
| 32 | Panel table-anchored, comfortable | PARTIAL | `main.tscn:72-73` world-fixed at (1.55, 1.35, −1.15), 0.8×0.6 m, ~1.9 m from origin | Fixed in world, not following Jon; beyond arm's reach (pointer-only, fine) but off to the right of the table end. Layout min-height ≈ 565 px by my sum vs a 480 px SubViewport (`main.tscn:83`) — the bottom row (RESET FLOOR) may clip — **(unverified; check the capture)**. |
| 33 | Panel unfolds with easing; buttons answer with light pulses | PRESENT | `ui_panel.gd:35-40,223-230` | — |

### Keep / print and safety (§1.4, §4, §6)

| # | Promised item | Status | Evidence | Gap |
|---|---|---|---|---|
| 34 | Save-back of `.py` / `.step` / `.glb` to Athena's HA Slicer library | PARTIAL | Athena runner exports to `C:\Users\jon\mediastack\3d-work\out\voicecad\<id>\` (`atlas_voice.py:45,300-302`); hub copies to `~/.local/share/atlas/cad-jobs/<id>/` | Files land in the 3d-work **out/voicecad** folder, not demonstrably the "HA Slicer library" — whether that is the same location is **(unverified, needs Jon/Athena)**. `model.step`/`source.py`/`report.txt` fetch failures are swallowed silently (`atlas_voice.py:303-304`, only glb/manifest raise). No readable name (job-id dirs only). `run_job.py` (Athena side) is not in this repo — not audited. |
| 35 | "Send it to the printer" intent routed | **MISSING** | `atlas_voice.py` has no print verb/route; app has no print code (grep: only the spoken line `cad_bench.gd:117`) | — |
| 36 | Confirmation-gated send-to-print end to end (state part/material/time, wait for explicit yes) | **MISSING** | `ui_panel.gd` has no "Send to printer" button (SPEC §5 lists one); no estimate, no confirm state, no Kobra S1 path | **Safe by omission:** with no print path, voice cannot print. Everything in this row is build work. |
| 37 | No credentials in the app binary (§6) | PARTIAL (documented deviation) | `hub.gd:6,25-31`; SPEC §3 "baked into the APK" | The bearer token is baked into the APK via `hub_secret.cfg`, contradicting §6 "no credentials in the app binary… provisioning from the hub". Accepted in §3 but not reconciled. Repo is clean (gitignored). |
| 38 | CAD scripts in Athena sandbox; failed validation → spoken explanation | PARTIAL | sandbox PRESENT (`atlas_voice.py:290`); explanation = row 12 | see row 12 |
| 39 | Money/send/delete follows Amendment 1; proactive speech limits | PRESENT | no autonomous actions; speech only on entry + job events | Unprompted entry greeting is the only proactive line (allowed by §1). |

### Design language (§2 / §2.6)

| # | Promised item | Status | Evidence | Gap |
|---|---|---|---|---|
| 40 | Cyan-only palette, tokens | PRESENT | `tokens.gd`; grep'd no other colour literals in the files read | — |
| 41 | Bundled tech font | PRESENT | `fonts/Rajdhani-*`, `project.godot` custom_font | — |
| 42 | Concentric-ring/tick/gauge HUD motifs | PRESENT | `ring.gdshader`, `hud.gd:104-115` arcs + explode gauge | — |
| 43 | Subtle scanlines in the air | **MISSING** | no scanline shader/overlay found (`screens.gdshader` is wall displays only) | — |
| 44 | Soft glow on holo elements | PARTIAL | `main.tscn:11-17` env glow (intensity 0.8, hdr threshold 0.8) + emissive | Real post glow is ON in the mobile renderer — SPEC says measure before keeping; never measured (see P-3). |
| 45 | Model materialize beats 1–4 | PRESENT | `model.gd:303-324` | — |
| 46 | Nothing pops in statically | PARTIAL | panel/room/table ease in | Scale buttons, explode slider, model scale, parked/unparked visibility toggles, label/tether visibility flips are instant. |
| 47 | UI tick/blip sounds, generated tones only | PRESENT | `tools/gen_sounds.py`, `sfx.gd:7-16` | Only 6 cues + 2 voice clips; no table hum/ambient bed, no materialize whoosh/scan tone, no explode sweep, no error tone. |
| 48 | Live HUD readouts: connection, brain tier, parts, dims in imperial | PRESENT | `hud.gd:155-166`, `table.gd:242-249`, `model.gd:77-100` | Real values only (deliberate; §2.6 notes). `BRAIN` is "HERMES"/"OFFLINE" from reachability only — the real tier (Claude vs atlas:14b) is not shown, which matters given the known 14B fallback. |
| 49 | XROrigin + two controllers, teleport-free, room-scale optional | PRESENT | `main.tscn:86-110`, `xr_boot.gd` | Floor fix awaiting Jon's retest (SPEC §7 #2). |
| 50 | Home-network-only, LAN→tailnet | PRESENT | `hub.gd:5,43-54` | — |

**Totals (50 rows):** PRESENT 23 · PARTIAL 17 · MISSING 10 (rows 11, 16, 17, 20, 21, 22, 28, 35, 36, 43).
The v1 headline gaps: the entire SHIELD manipulation set, follow-up edit, true scale, and the whole print path.

---

## 2. Smoothness / feel gaps (audit)

- **S-1 No inertia/easing anywhere in manipulation.** Grab follows the hand 1:1 (`grabbable.gd:44-54`); release is a hard stop; scale buttons and `set_model_scale` snap (`model.gd:129`); two-hand scale uses raw hand distance with no smoothing or snap-to-1×.
- **S-2 No haptics.** Zero `trigger_haptic_pulse` calls: grab, release, slider ticks, button hover and PTT have audio only. Cheapest "feels real" win on Quest.
- **S-3 No reach/hover feedback.** `hand.gd:65-75` chooses the nearest grabbable but nothing lights it; the grab radius (0.4 m × scale) is invisible; panel buttons give hover style but the laser has no hit-dot/reticle.
- **S-4 Spawn path hitches the main thread.** `cad_bench.gd:89-119` + `cad_model.gd:29-58`: `GLTFDocument.append_from_buffer` + `generate_scene` + `Blueprint.make` (per-pixel `Image` rasterisation, `blueprint.gd:9`) all run synchronously on the render thread right as the scan effect starts — a visible stutter on Quest 2 for a ~500 KB glb. Same pattern for `_build_tethers`/`Label3D` creation.
- **S-5 Startup CPU texture painting.** Room wall canvases (`room.gd:204-250`), the 256² titanium grain + normal map (`fx.gd:82-137`), dust/floor textures all built with `Image.set_pixel` loops before the first presented frame, so the pre-boot black time is long and unmeasured. Lazy/threaded generation or precomputed `.webp` assets would remove it.
- **S-6 Panel ergonomics.** World-fixed 1.9 m away, right of the table end; not head-aware, no grab-to-reposition; 640×480 viewport; probable overflow (row 32); parts label clips; RESET FLOOR sits in the same stack as everyday controls with a name that collides with "reset model".
- **S-7 Voice latency feedback.** THINKING state is shown, but a 60 s `/atlas/ask` (known hub issue) and a 1–7 min CAD job give no stage progress, no on-table "building" visual, no audible progress cue. The hub already exposes `stage`.
- **S-8 Boot duration.** Planned ≈ 6.0 s to materialize complete + two voice clips (greeting, confirm_render) serialized before the mic opens (`main.gd:137-139`). Matches the storyboard, but there is no skip; the voice can't be used for the first ~10–15 s.
- **S-9 Per-frame work.** Small: `hand.gd:77-99` calls `get_first_node_in_group` + allocates an `InputEventMouseMotion` every frame while the ray is on the panel; `hud.gd:145-153` refreshes text once per second (fine); `voice.gd:233-259` polls the socket + `_sync_mic/_pump_mic` per frame (needed). Real waste: the panel SubViewport re-renders every frame (`main.tscn:84` `render_target_update_mode = 4` = always) though it is static most of the time.

## 3. Stark-fidelity gaps (current build vs `design/concept-target-04.webp` + §2.6), ranked by first-glance impact

Compared `captures/shot-04-materialized.png` / `shot-07` (headless fallback camera) with concept-04.

1. **Hologram presence/scale.** Concept: large, luminous, translucent parts floating well above the table with white-hot cores and a column of light; ours: a tiny wireframe bracket lying on the grid, fills barely visible, no core hotspots, no glow column, no under-model glow decal. This is the biggest first-glance gap and the whole point of the scene. (§2.6 promises the glow column + decal; neither exists.)
2. **Table surface character.** Concept: dark glassy plane with a bright central hotspot, a *dense* etched ring/grid with fine blueprint linework, strong glow bleeding onto the bezel; ours: flat saturated blue plane, thick uniform grid, ring reads as a flat decal. Needs a hot-centre falloff, finer etch, reflection-like bloom on the bezel.
3. **Particles and depth in the air.** Concept: dense rising spark column + floating dust with depth blur; ours: sparse round motes (90 table, 240 room) of uniform size. Needs a rising "emitter column" over the active model, varied size/brightness.
4. **Glow/HDR bloom quality.** Concept: bright bloom on edges and light strips; ours: env glow on, strips read as flat white bars (`shot-07` leg/edge strips are clipped white). Tonemap/HDR threshold tune, softer falloff.
5. **HUD density and motion.** Concept: layered floating panels at depth, live graphs, radial gauges, wrapped arcs. Ours has arcs, gauge, status card (good) but panels are flat, few, and static except arc rotation; wall screens are animated but not tied to anything.
6. **Part labels and callouts.** Concept: thin elbow leader lines with two-line captions (part · material · qty); ours: straight leader + one caption, always on, can overlap when parts cluster.
7. **Metal/materials.** Concept: brushed titanium with soft environment reflections and a floor reflection; ours: procedural grain, no reflections (stated approximation). Lower first-glance priority than 1–4.
8. **Sound.** Concept can't show it, but §2 asks for "light + sound" on every gesture: today 6 blips + 2 voice clips, no ambient bed, no scan/materialize/explode cues, no error tone.

## 4. Performance headroom

- **Measured (headless capture harness, SPEC §2.6 brief #12):** 62 draw calls at rest/exploded, 77–82 worst case with a CAD model/wide pose; 3 lights. Self-imposed budget ≤ 90 → **~8–13 draw calls of spare headroom** in the worst case, ~28 at rest. Frame time on Quest 2 has **never** been measured.
- **Not yet configured:** `project.godot` sets no MSAA, no render scale, no fixed foveated rendering / foveation level, no target refresh rate (72/90 Hz). Quest 2 aliasing on thin cyan lines is likely; foveation is the standard fill-rate lever.
- **Likely fill-rate cost:** environment glow on the mobile renderer (`main.tscn:11-17`), many additive full-screen-ish quads (light shafts, halos, wall screens, HUD arcs/gauge), fog. All overdraw-heavy, none profiled.
- **Rule for rounds 2–3:** any added effect must come out of the ~8-draw worst-case headroom or pay for itself by merging meshes (the room/table already merge by material); add a headset frame-time capture (OVR metrics / `adb shell dumpsys`) before Round 3 spends visual budget. Prefer particles, shader work on existing quads, and merged additive meshes over new Label3D/MeshInstance3D counts (tethers are 2 draws per part: 8 parts = 16 draws).

---

## 5. Prioritized build backlog

Size: **S** ≤ half a day, **M** ≈ 1 day, **L** multi-day / cross-system. Verify: **H** = headless-provable (capture harness `tools/*.gd`, mock hub `tools/mock_hub.py`, unit scripts) · **J** = Jon-in-headset only (feel, audio, frame rate).

### Round 1 — missing v1 features

| ID | Item (feature-table rows) | Size | Verification |
|---|---|---|---|
| R1-1 | **Table-plane manipulation as default**: project grabbed model to table plane (drag across surface), yaw-spin from hand twist, free-lift when hand rises > ~15 cm above the surface; settle-back tween to `TOP_Y` on release over the inset; stays if released elsewhere (16, 18, 20) | M | H: scripted fake-hand transforms assert plane lock, lift threshold, settle target; J: feel |
| R1-2 | **Inertia: swipe-spin + flick-slide** — sample hand/model velocity over last ~100 ms on release, decay with friction, edge-of-inset clamp/bounce (17, 21) | M | H: simulated release velocities → assert decay curve, no escape off the table; J: feel tuning |
| R1-3 | **Reset-to-centre + true scale + rename** — model RESET button (animated return to table centre, scale 1×, yaw 0) distinct from RESET FLOOR (rename to "RE-CENTRE ME"/"FLOOR"); TRUE SCALE button = 1/`display_scale`; add 0.5/1/2 snap points to two-hand stretch (22, 28, 18) | S | H: assert transform/scale values after button press; J: legibility of true scale |
| R1-4 | **Follow-up edit replaces in place** — hub keeps last job per session, routes "make the holes bigger / add a gusset" (edit verbs + existing model) to `write_code(prompt, prev_code=source.py)`; app swaps the active model in place (old one freed or kept as parked-history, Jon's call) (11) | L | H: mock hub + two-step job against the real hub CAD route; assert second `spawn` replaces active; J: edit wording reliability by voice |
| R1-5 | **Spoken + visible validation-failure explanation** — hub condenses runner `error` to one plain sentence (e.g. "the wall was too thin"); app speaks it and shows FAILED on the HUD card/panel status line (12, 31, 38) | S–M | H: mock `cad_failed` with detail → assert `say()` text + status; real failure forced with a bad prompt |
| R1-6 | **Panel completion**: real scrollable/wrapping part list with per-part select → highlights the part + shows its tether; status line with hub `stage` + elapsed + FAILED; fix overflow (bigger SubViewport or tighter layout); confirm bottom row not clipped (29, 30, 31, 32) | M | H: layout capture at 3 and 8 parts, assert no clip; J: reach/legibility |
| R1-7 | **Multi-object bench select/pull-to-centre** — point-and-trigger (or grip-tap) a parked model → current active parks, selected animates to centre, panel/HUD/explode/readouts retarget (24) | M | H: spawn 3 models via mock, select each, assert `_retarget` + positions; J: feel |
| R1-8 | **Confirmation-gated print path** — "Send to printer" panel button + voice intent opens a CONFIRM state (part, material, est. time from the slicer/Kobra S1 lane) with explicit YES / CANCEL on the panel; voice "yes" alone never fires; hub route `POST /atlas/print-request` returns an estimate, `POST /atlas/print-confirm` requires a panel-origin token; Amendment 1 logging (35, 36) | L | H: mock hub asserts no print POST without the confirm token, cancel path, voice-only path blocked; real Kobra call only dry-run until Jon approves; J: end-to-end first physical print |
| R1-9 | **Save-back to the real HA Slicer library** — confirm the library path with Jon, copy `.py/.step/.glb` there with a readable name (`<part>-<date>-<id>`), surface failure of any file (not just glb/manifest), speak "saved" (34) | S–M | H: file presence + sizes on Athena via ssh listing; needs Jon to name the library path |
| R1-10 | **Multi-part voice-CAD explode correctness** — compute explode direction from part **mesh AABB centres** (not node origins), scale distance by assembly size; run a 3-part generated job (e.g. "a hinge, two leaves and a pin") through the capture harness (26) | S | H: capture exploded 3-part model, assert pairwise part distances grow |
| R1-11 | **A/X PTT binding + hover/select part names** — bind `ax_button` as a second PTT; names/captions on hover or select instead of always-on (5, 30) | S | H: action-map unit check; J: ergonomics |
| R1-12 | **Real blueprint from the part** — hub (or app) emits a top-down silhouette/hole set so the surface schematic matches the part, not a bbox + fake bolt holes; add height dimension (15) | M–L | H: schematic render vs known manifest; the CAD runner could export an SVG/outline |

Order: R1-1, R1-2, R1-3 (core interaction) → R1-10, R1-4 → R1-5, R1-6 → R1-7 → R1-9, R1-8 → R1-11, R1-12. R1-8 is the only item needing Jon's sign-off before real hardware is touched.

### Round 2 — smoothness / feel

| ID | Item (gap ref) | Size | Verification |
|---|---|---|---|
| R2-1 | Haptics: grab/release/slider tick/PTT/button hover (S-2) | S | J |
| R2-2 | Reach/hover highlight on grabbables + laser hit-dot on the panel (S-3) | S | H: capture; J |
| R2-3 | Easing: tween scale buttons, explode follow, park/unpark visibility, label fades; two-hand scale smoothing (46, S-1) | S | H: assert tween durations; J |
| R2-4 | Remove spawn hitch: thread/deferred glb parse, chunk `Blueprint.make` or generate at lower res async, pre-create tether pool (S-4) | M | H: frame-gap measurement in capture harness (max frame delta around `spawn`); J |
| R2-5 | Startup: precompute room/grain textures to assets or generate lazily/threaded; measure time-to-first-frame (S-5) | M | H: headless timing; J |
| R2-6 | Panel ergonomics: head-aware or grab-to-reposition panel, larger text, RESET FLOOR relocated behind a "settings" fold, SubViewport `UPDATE_WHEN_DIRTY` (S-6, S-9) | M | H: capture/layout; J |
| R2-7 | Progress/latency feedback: map hub `stage` to an on-table "building" scan visual + soft looping tone; speak the 60 s-brain fallback gracefully (S-7) | M | H: mock stages; J |
| R2-8 | Boot: skippable (trigger press) and allow PTT during the greeting clips; overlap greeting with materialize if hub is connected (S-8) | S | H: boot timing log; J |
| R2-9 | Hub-driven greeting once connected, with an offline fallback line (row 2) | S | H: mock hub up/down |
| R2-10 | Headset frame-time baseline + MSAA/foveation/refresh-rate settings in `project.godot` (P) | S–M | J only (device metrics); H: export config diff |
| R2-11 | Hub brain-chain fix visibility: show real tier on the HUD (BRAIN: HERMES vs LOCAL 14B) (48) | S | H: mock; (fix of the 60 s latency itself belongs to the Atlas side) |

### Round 3 — Stark fidelity (spend only what R2-10's baseline allows)

| ID | Item (fidelity rank) | Size | Verification |
|---|---|---|---|
| R3-1 | Hologram presence: emitter glow column + under-model glow decal (+ white-hot core hotspots in `holo_mesh.gdshader`), larger default display size / float height above the inset (1) | M | H: capture vs concept-04/01; J: first-glance read |
| R3-2 | Table surface: hot-centre falloff, finer etch, bezel light bleed, ring detail (2) | M | H: capture; J |
| R3-3 | Particles: rising spark column over the active model, size/brightness variance, a scan-sweep spark burst on materialize (3) | S–M | H: capture; J |
| R3-4 | Glow/HDR tuning: tonemap, threshold, strip clipping fixes (4) | S | H: captures; J: frame cost |
| R3-5 | HUD depth/density: layered panels at differing depths, live graph data tied to real values (BRAIN/LINK/CAD stage), micro-diagrams; stay within draw headroom by merging into the existing screens mesh (5) | M | H: capture + draw-call count; J |
| R3-6 | Callouts: elbow leader lines, 2-line captions (part · material from manifest · qty), simple overlap avoidance (6) | M | H: capture with 8 parts |
| R3-7 | Sound design: ambient table hum bed, scan/materialize sweep, explode sweep, error tone, spatial UI ticks (8, 47) | M | J only (audio); H: asset generation + cue wiring |
| R3-8 | Scanline/air-shimmer overlay and subtle chromatic edge on holograms (43) | S | H: capture; J: cost |
| R3-9 | Reflection-style floor/table gloss (fake: mirrored low-res glow strip, no SSR) (7) | M | H: capture; J: cost |
| R3-10 | **Explode label de-overlap** — at 100% explode, labels of clustered parts pile up illegibly (seen in `captures/r1-trebuchet-exploded-pinned.png`); needs leader-line spreading / distance fade (backlog only, from Round 1B) | M | H: capture with the 27-part trebuchet at 100% explode, no overlapping label rects; J: legibility |

### Cross-cutting notes
- Everything Jon-only (feel, mic, TTS audibility, frame time) can only be closed by a headset session; the floor-height retest (§7 bug #2) and the first real PTT/CAD run are still outstanding from the combined build and should come first.
- The explode-with-real-multipart risk (R1-10) and the panel overflow (R1-6) are cheap to confirm headlessly and should be checked before any other build work.
- Wake word remains off by design; not part of this backlog.

### Round 2.5 — Parts Library (Jon, 2026-11-20)
| ID | Item | Size | Verification |
|---|---|---|---|
| R2.5-1 DONE 2026-11-20 — | **Parts Library panel**: lists every part Jon has made from the Athena save-back library (`3d-work/out/holodeck/<name>-<job_id>/` — model.py/.step/.glb + manifest per part), served by the hub (list route, additive). Name + dims + date from the manifest. | M | H: mock library; J |
| R2.5-2 DONE 2026-11-20 — | **Fetch on click**: tapping a library entry fetches its .glb (+ script context) from Athena via the hub and materializes it at table centre as the active design (bench rules apply — the current model parks). It also becomes the follow-up-edit target, as if just created. | M | H: exercise vs mock; J |
| R2.5-3 DONE 2026-11-20 — | **Edit action** (icon on each entry): loads the part (as R2.5-2) and puts Atlas in edit mode for it — the next "make it…" utterance revises that design in place (R1-4 machinery). | S | H: exercise; J |
| R2.5-4 DONE 2026-11-20 — | **Delete action** (icon on each entry): deletes the part's library folder on Athena — **confirmation-gated** (a confirm card naming the part; cancel/timeout = nothing deleted; delete is a confirm-class action per Atlas guardrails). Hub route additive + token-gated; the deletion is logged. | M | H: flow test incl. cancel path; J |
| R2.5-5 DONE 2026-11-20 — | **Imported STLs** (Jon, 2026-11-20): STLs Jon saves from other sites (Printables/Thingiverse/etc.) into a drop folder in the Athena 3D tree (`3d-work/library/`) appear in the same Parts Library and render on the table. Hub/worker converts STL -> GLB (cached beside the STL; trimesh on the Athena worker). **Units: STL is unitless — interpret as mm (site standard) and convert exactly; dims shown in inches from the converted bounds.** Entry name from filename; single-part (no named sub-parts, no manifest). Imported entries support fetch/render + send-to-print + delete (same confirm gate), but NOT voice edit-in-place (no build123d source) — the edit icon is shown only for Holodeck-created parts. | M | H: drop a known STL (e.g. a 20 mm calibration cube) -> library lists it at 0.79 in; renders at true size; J |
| R3-11 | **Living lab background** (Jon, 2026-11-20; research DONE same day, report in ~/workspace/research_notes/iron-man-vr-lab-design-20261120-1508/report.md): KEY FINDING — the Iron Man VR game's garage has NO robot arms (Dum-E/U are film-only); its life comes from (a) functions sorted spatially (centre station / left codex table / right spinnable globe), (b) TWO resident hologram AI characters pinned to stations with idle motion + banter, (c) ambient screens + rotating codex holograms, (d) progress visible in the room (slots that fill), (e) purposeless hand toys. Build for Holodeck: ambient hologram activity (rotating schematics, scrolling data panels), a station-pinned Atlas hologram presence at a side station, progress/readout wall tied to REAL data (job history, library count), PLUS Jon's explicit ask from the film language: ONE original-design robot arm on a believable task loop (scan -> tend a side project -> spark/'help' beat) — original design, no Marvel assets/names/likenesses. All inside draw-call/light budget. | M-L | H: captures + draw-call count; J: 'alive' read |
