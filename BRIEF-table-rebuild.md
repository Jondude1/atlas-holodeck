# Claude Code brief #4 — Atlas Holodeck: SHIELD metal table rebuild

Replace the skeleton's cylinder pedestal + floating disc with the physical metal
holotable from SPEC.md §2 ("A physical metal table, not a hologram pedestal") and
§2.6, in the Stark-futuristic restyle. Read SPEC §2 + §2.6 and look at
`design/concept-target-04.webp` (current table reference — tapered slab, angled
legs with light channels, continuous edge light strip, dark titanium) and
`design/concept-target-01.webp` (everything above the surface) before starting.
Work in `~/workspace/atlas-holodeck/app/`. Everything from briefs #1–#3
(grab/explode, boot, materialize, tokens, sounds, voice, readouts, schematic
layer) must keep working; this brief only rebuilds the table and re-seats what
sits on it.

Environment/build facts: same as brief #3's header note (Godot 4.7.2, JDK 17,
GRADLE_USER_HOME=~/workspace/tooling/gradle-home-holodeck, debug keystore via
GODOT_ANDROID_KEYSTORE_RELEASE_* env vars, IPv4 workaround, vendors addon at
app/addons/godotopenxrvendors/ already fetched).

## Build the table (all boxes + materials — detail via texture, not geometry)

Dimensions (meters): top **2.2 × 1.2**, surface height **0.95**, slab thickness
**0.10**. Silhouette per target 04: angular **tapered** slab (the ends sweep to
soft points), smooth machined **dark titanium** (albedo ~#33373D, metallic
~0.9, roughness ~0.35, clean — no bolt field; at most a couple of subtle seam
lines), 4 **angled, splayed legs** with glowing channels. Approximate the taper
cheaply: main slab box + two angled end boxes rotated a few degrees in plan, or
a slab box with angled trim boxes beneath the ends — pick the cheapest build
that reads as the target silhouette from a standing viewpoint. Components:

1. **Slab** — as above, top at y=0.95, dark titanium material. A thin under-slab
   apron box, slightly inset and darker, gives the floating machined look.
2. **Legs** — 4 boxes (0.10 × 0.85 × 0.16) angled/splayed ~10° (rotated in the
   vertical plane, feet outward), inset from the corners. On each leg's outer
   face, one thin **emissive light channel** (a 0.015-wide strip box, holo_line)
   running down its length, following the leg angle.
3. **Display inset** — a plane **1.95 × 1.0** centered on the slab top at
   y = 0.951 (1 mm above the slab — no z-fighting), leaving a ~10–12 cm metal
   rim. It carries the existing grid shader (adapt UVs from the disc to the
   plane; grid token: minor 10 cm, major 50 cm brighter) over `table_surface`
   #06283F. The rotating idle ring + particle motes from brief #3 move onto the
   inset, centered. A thin emissive bezel frame (4 thin boxes, `holo_primary`)
   outlines the inset.
4. **Edge light strip** — the signature detail: a **continuous** thin emissive
   strip (holo_line) inset along the slab's long side edges, running the full
   2.2 m length on both sides (2 long thin boxes), plus short returns at the
   ends if cheap.
5. **Bezel readout strip** — move the LINK readout from brief #3 onto a small
   physical slanted display on the player-facing bezel (a thin box + the
   Label3D just above it is fine); PARTS and DIMS readouts stay floating at the
   table edge. (Mix of physical + floating, per the show.)

## Re-seat the scene

- The demo model root sits at the **inset surface height** (y = 0.951), centered
  on the inset; its schematic layer lies on the inset beneath it.
- The grab logic's "settle onto the table" plane becomes y = 0.951.
- Remove the old pedestal/disc/table-light nodes; keep the `HoloTable` group
  name so other scripts' references survive, updating paths as needed.
- Player spawn stays put; check the table (2.2 m wide) fits the room and the
  UI panel doesn't collide with it — nudge panel/spawn only if needed, and say so.

## Validation (same bar)
- Headless editor import: no script errors. Headless scene run: no GDScript
  errors (fallback path exercises boot + materialize on the new table).
- Re-export the APK (Gradle + vendors plugin, same preset); verify apksigner
  Verifies, package id, manifest still contains `com.oculus.intent.category.VR`
  + `android.hardware.vr.headtracking`. Report new size.
- Report the scene node count and estimated draw-call count again (frame budget).

## Rules
- Emissive/sprite glow only; no new post-processing. Keep the table light:
  target ≤ ~30 meshes for the whole table assembly.
- No credentials anywhere. List every file changed and why. Ship simpler
  versions over gold-plating; the APK milestone outranks any single detail.
