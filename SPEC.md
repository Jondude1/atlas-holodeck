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

Jon puts on the Quest 2 at home and launches Atlas Holodeck. He is standing in a dark
room lit in blue holographic light — grid walls and floor, Stark/JARVIS-style — with a
central holo-table: a pedestal with a glowing disc. Atlas is present as a voice.

1. **Talk:** Jon holds a controller button (push-to-talk) and speaks. Atlas answers out
   loud, with the same memory, personality, and guardrails as the phone app — it is a
   new face on the same brain, not a second assistant.
2. **Create:** Jon says *"Atlas, make me a bracket, 80 mm wide, four bolt holes."*
   The request goes to Hermes, which (via its Claude Code lane) writes a build123d
   Python script. Athena's 3D worker runs it, validates the solid, and exports glTF.
   The finished model **materializes on the holo-table** with a short spawn effect.
3. **Inspect:** Jon grabs the model with either controller, rotates it, scales it
   (two-hand pinch/stretch or a zoom control), and uses the **explode slider** on a
   floating panel to separate the assembly into its named parts along their assembly
   axes — then slides it back together.
4. **Keep / print:** The source `.py`, `.step`, and `.glb` are saved on Athena under
   the HA Slicer library. *"Send it to the printer"* is **confirmation-gated**: Atlas
   states what will print (part, material, estimated time) and waits for an explicit
   yes. A voice command alone never starts a print (material-consuming action).

## 2. Architecture

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

## 3. v1 scope

**In:**
- Holodeck room: dark room, blue holographic grid (floor + walls), central holo-table
  (pedestal + glowing disc), Stark-blue palette throughout.
- XROrigin + two controllers; teleport-free standing/seated play (room-scale optional).
- Grab / rotate / scale for the model on the table; explode slider on a floating UI
  panel; parts keep their build123d names (shown on hover/select).
- Push-to-talk voice link to the hub/Hermes with spoken replies (same TTS path Atlas
  already uses).
- Voice-to-CAD loop as in §2, for single parts and simple assemblies (2–8 parts).
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

## 4. Interaction details

- **Push-to-talk:** hold trigger (or A/X) to talk; release sends. A soft chime + orb
  pulse confirms Atlas is listening; the orb shows thinking/speaking state.
- **Grab:** grip button near the model grabs it; it follows the hand. Release drops it
  (it floats — holodeck physics, no gravity) or snaps back to the table on a "reset"
  gesture/button.
- **Scale:** two-hand grab and stretch, plus panel buttons for 0.5× / 1× / 2× / true scale.
- **Explode:** slider 0→1; each named part translates away from the assembly centroid
  along its own offset vector (computed from part centroids at load), labels fade in.
- **Panel:** one floating UI panel (table-anchored): explode slider, scale buttons,
  part list with names, "Send to printer" (opens the confirmation state, never fires
  directly), status line for Atlas/CAD job progress.

## 5. Safety & guardrails

- Money/send/delete class actions follow Atlas's existing Amendment 1 guardrails;
  send-to-print always confirms first, every time.
- No credentials in the app binary, the repo, or on the Quest: provisioning comes from
  the hub the same way the phone app's does.
- CAD scripts run in Athena's existing worker sandbox; a script that fails validation
  produces an Atlas explanation in the room, not a silent failure.
- Proactive speech rules carry over: the holodeck never speaks unprompted beyond the
  guardrails Atlas already runs under.

## 6. Verification gates

**Skeleton (first build):**
- [ ] Godot project opens and runs headless with no errors; scene loads.
- [ ] Android APK exports headless, is signed (debug signing acceptable for sideload),
      package id `com.jondude.holodeck`.
- [ ] APK contains the holodeck room + table + a 3-part named test assembly with grab
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

## 7. Open questions (park, don't block the skeleton)

- STT path: hub-side transcription of the PTT clip vs. on-device — decide when the
  voice link is wired (skeleton ships without it).
- Display-scale default: fixed display size vs. true-scale-with-minimum — tune with
  Jon's first in-headset session.
- Whether the CAD job rides Hermes delegation or a dedicated hub endpoint — the hub
  lane decides during voice-link work; the app's contract is "POST a job, get a .glb".
