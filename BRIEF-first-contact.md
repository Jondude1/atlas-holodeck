# Claude Code brief #5 — Atlas Holodeck: FIRST-CONTACT chunk

Five fixes on top of brief #4's build, taking the app from internal skeleton to
the first-contact candidate (SPEC §7). Read SPEC.md §1–§3 + §2.6 first. Work in
`~/workspace/atlas-holodeck/app/` (SPEC.md edits at repo root are in scope where
noted). Everything existing (grab/explode, boot, materialize, tokens, sounds,
voice lines, readouts, schematic layer, target-04 table) must keep working.

Environment/build facts: same as briefs #3/#4 (Godot 4.7.2 at
`~/workspace/tooling/godot/`, JDK 17, `GRADLE_USER_HOME=~/workspace/tooling/gradle-home-holodeck`,
debug keystore via `GODOT_ANDROID_KEYSTORE_RELEASE_*` env vars, Gradle IPv4
workaround `-Djava.net.preferIPv4Stack=true`, vendors addon already fetched —
do not re-download). Do NOT commit anything to git.

## 1. Table resize — Jon's 8 ft × 4 ft (he set this in chat, 2026-11-19)

Jon: the table must be big enough to work on multiple items comfortably —
**8 ft × 4 ft**. New tokens (scene metres): top **2.44 × 1.22**, height 0.95
unchanged, slab 0.10 unchanged, tapered silhouette unchanged.

- `table.gd`: overall length 2.44 (body half-X 1.0 → 1.12, taper 0.10 each end
  as now), half-Z 0.60 → 0.61. **INSET → Vector2(2.2, 1.0)** — rim lands at
  12 cm ends / 11 cm sides, keeping the ~85–90% display coverage.
- Scale the supporting pieces with it: apron (~1.94 × 0.92), legs move out
  (top x ±0.80 → ±0.95, z ±0.40 → ±0.42), edge strips already follow body
  half-X (verify they span the new body length). Link screen stays on the
  player-facing rim (z 0.55 is mid-rim now — keep). Ring (0.9 quad) and motes
  stay centered on the inset; widen the motes visibility AABB in X to ±1.05.
- Room fit: check the 2.44 m table still fits the room scene and the UI panel
  placement; nudge only if something actually collides, and say so.
- SPEC §2 table paragraph + §2.6 table grid token: update top to
  **2.44 m × 1.22 m (8 ft × 4 ft)** and inset to **≈2.2 m × 1.0 m**.

## 2. Units — decimal inches everywhere Jon can see (Jon's rule, 2026-11-19)

Jon works in inches and feet, NOT metres/mm. **All user-facing units are
imperial decimal inches** (e.g. `3.5 IN`, `9.45 × 6.3 × 7.87 IN`); at
table scale use feet + inches. Metric stays internal (scene metres, build123d
mm) and is NEVER displayed. Exact conversion: 1 in = 25.4 mm.

- `model.gd` `dims_text()`: convert the AABB size from metres to inches
  (÷ 0.0254), format decimal with up to 2 places, trailing zeros trimmed
  (`3.5` not `3.50`). If a dimension ≥ 24 in, format that dimension as
  `F' R.R"` (whole feet + remaining decimal inches). Suffix the readout `IN`
  for the all-inches form. Update the doc comment (it currently says MM).
- `tokens.gd` grid steps: GRID_MINOR_STEP 0.10 → **0.1524** (6 in),
  GRID_MAJOR_STEP 0.50 → **0.3048** (1 ft). These are scene-unit values; only
  the comment needs to say what they are.
- SPEC text: §1 step 2 example prompt `80 mm wide` → imperial (e.g.
  *"Atlas, make me a bracket, 3.5 in wide, four bolt holes."*); §2 ACT
  "dimensions in mm" → "dimensions in decimal inches (feet + inches at table
  scale) — metric is internal only, never displayed"; §2.6 table grid token
  "minor lines every 10 cm, major lines every 50 cm" → 6 in / 1 ft; §3 data
  flow step 4 "a 80 mm bracket" → "a 3 in bracket". Engineering build tokens
  elsewhere in SPEC stay metric (Godot works in metres) — user-facing
  examples/readouts are what change.
- Grep the whole `app/` tree afterwards: no `MM`/`mm` string may remain in any
  user-facing text (readouts, labels, panel). Internal comments/variable names
  are fine.

## 3. Boot timing — align to the §2.6 storyboard targets

Targets: systems check completes ≈ **2.5 s**, room fade ≈ **1.5 s**,
materialize ≈ **2 s**, then Atlas greets. Current: ~2.7 s total boot, 1.2 s
materialize.

- `main.gd` `_boot()`: ring draw-in 0.4 → 0.6 s; arc fill 1.4 → 1.7 s; pulse
  0.1 → 0.2 s (check total = 2.5 s); room/table fade 0.6 → **1.5 s**.
- `model.gd`: MATERIALIZE_TIME 1.2 → **2.0** and stretch the beats to fill it:
  schematic fade-in 0.3 → 0.5 s; wire 0.25 → 0.35 s; scan sweep 0.6 → 1.1 s
  (delay 0.25 → 0.35); flash settle 0.35 → 0.5 s (delay 0.7 → 1.35);
  labels_beat at 1.0 → 1.75 s; materialized at 2.0 s.
- Voice order per SPEC §2.6 boot beats (…materializes → Atlas greets): move
  the greeting so it plays **after** materialize completes, then the
  confirm_render line after the greeting finishes — the two pre-rendered
  voice lines must never overlap. (Await the greeting player's `finished`
  signal or its stream length; add a small helper to `sfx.gd` if needed.)
  The greeting still ALWAYS plays (it is the graceful fallback — hub state
  only changes the LINK readout, never an error screen). Hub check stays
  parallel at boot-complete as now.
- SPEC §2.6: update "Materialize beats (≈1.2 s total)" → ≈2 s, and the boot
  storyboard parenthetical that says aligning timings is a first-contact task
  → note it done in this chunk with the new numbers.

## 4. Voice link — LAN route to the hub (decision made; build the plumbing)

Decision (Helios, verified live 2026-11-19): the Quest is NOT on the tailnet
and v1 is home-network only (SPEC §4 already excludes Tailscale-on-Quest).
Obelisk's hub binds **0.0.0.0:8765** and answers on its wired LAN address —
verified `http://192.168.4.51:8765/atlas/status` → 200 from the LAN side.
So: **LAN primary `http://192.168.4.51:8765`, tailnet
`http://100.65.202.81:8765` as fallback** (free if the Quest ever joins the
tailnet; the phone app's address).

- New tiny `app/hub.gd`: `class_name Hub` with `const CANDIDATES` (the two
  base URLs, LAN first) and `static var base_url := ""` — the winning base,
  for the PTT chunk that follows. No behaviour beyond holding these.
- `main.gd` `_check_hub()`: try candidates in order (2 s timeout each) until
  one returns 2xx from `/atlas/status`; set `Hub.base_url`; LINK readout
  becomes `LINK — HUB OK · LAN` / `LINK — HUB OK · TAILNET` /
  `LINK — LOCAL ONLY`. Failure is still never an error screen.
- **Cleartext HTTP fix (real blocker):** the current APK's manifest has
  INTERNET permission and targetSdk 36 but NO cleartext allowance — Android
  will block `http://` from the Quest. Add a network security config that
  permits cleartext ONLY to `192.168.4.51` and `100.65.202.81`
  (`res/xml/network_security_config.xml` in the Android build tree +
  `android:networkSecurityConfig` on `<application>` in
  `app/android/build/src/main/AndroidManifest.xml`). If the export pipeline
  drops it, fall back to `android:usesCleartextTraffic="true"` and SAY SO in
  your report. **Verify in the exported APK** (aapt2 dump xmltree must show
  the attribute / the xml resource must be in the APK).
- SPEC §3: architecture diagram + components table — hub address becomes
  "LAN primary 192.168.4.51:8765, tailnet fallback 100.65.202.81:8765;
  cleartext permitted to those two hosts only". §8: the STT open question
  stays open (PTT is the NEXT chunk — do not build PTT/mic in this one).

## 5. Titanium tune — it reads near-black in the desktop render

Target 04's titanium is dark but READABLE: seams, bevel and slab edges visible.
Current tokens TITANIUM #33373D, metallic 0.9 / roughness 0.35, one OmniLight
(energy 2.0, range 4.0) read almost black in the desktop fallback render.

- Tune within the palette family (no new hues): lighten TITANIUM one step
  (start #3B4046), roughness 0.35 → 0.42 for broader highlights; raise the
  table OmniLight to energy ~2.6 / range 5.0; if the slab still reads flat,
  add ONE dim fill OmniLight on the player side (holo_primary tint,
  energy ≤ 0.7, no shadows). Hard cap: ≤ 3 lights in the scene total.
- Judge it from the desktop fallback render (headless screenshot or the
  editor's viewport capture if available): slab top, apron and legs must be
  distinguishable from the room background and from each other. Report what
  you changed and your judgement call vs target 04.

## Validation (same bar, plus)

- Headless editor import: no script errors. Headless scene run: no GDScript
  errors; boot + materialize complete on the fallback path (total sequence
  ≈ 2.5 + 1.5 + 2.0 ≈ 6 s — sanity-check the run's wall time / prints).
- Re-export the APK (same preset); verify: apksigner Verifies, package
  `com.jondude.holodeck`, manifest still has `com.oculus.intent.category.VR`
  + `android.hardware.vr.headtracking`, **cleartext/network-config present**
  (see §4), report new APK size.
- Report: every file changed + why, the final table/inset constants, the
  dims_text() output for the demo bracket (compute it), the boot/materialize
  timing constants, scene node count + estimated draw calls (frame budget),
  and anything you had to approximate.

## Rules
- Colours come from Tokens only; no colour literals elsewhere. Emissive/sprite
  glow only, no post-processing. Table stays a handful of boxes (≤ ~30 meshes
  for the table assembly).
- No credentials anywhere. No git commits. Ship the simpler version over
  gold-plating; the first-contact milestone outranks any single detail.
