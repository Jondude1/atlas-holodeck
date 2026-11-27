# BRIEF — TV wall panel with Jellyfin (Antigravity build)

Repo: ~/workspace/atlas-holodeck (Godot 4.7.2 project in app/). Build the R7-1 TV:
a resizable, placeable TV wall panel for the Holodeck room that browses Jon's
Jellyfin library and plays movies/episodes on its screen. Jon's words: "Build
the TV panel now" and "make it look good."

## Governing look reference
design/look-reference-jon-20261124.jpg — dark polished room, architecture dark
and quiet, cyan ONLY as thin accents and in holograms/UI. The TV is furniture
in that room: dark titanium frame, near-black screen, teal UI. Match the wall
panels' framed-display language (wall_panel.gd is the style sibling).

## The playback reality (do not fight it)
Godot 4 on Quest plays ONLY Theora/Vorbis (.ogv) in VideoStreamPlayer — no
MP4/H.264, no WebView, no HLS. So playback goes through a bridge that
transcodes. ffmpeg with libtheora+libvorbis IS installed on this machine.

## Architecture
1. **Bridge** — NEW file tools/jellyfin_bridge.py (Python stdlib http.server +
   ffmpeg subprocess). It reads app/jellyfin_secret.cfg (base_url=, api_key=)
   — that file is a SECRET: read it programmatically, NEVER print, log, or echo
   the key anywhere. Jellyfin 12.4 auth quirk (verified): the API key works
   ONLY in a full header:
   Authorization: MediaBrowser Client="HolodeckBridge", Device="Holodeck",
   DeviceId="holodeck-bridge", Version="1.0", Token="<api_key>"
   (bare X-Emby-Token and ?api_key= both return 401).
   Endpoints (JSON unless noted):
   - GET /jf/libraries → Jellyfin /Library/MediaFolders (name, id, type)
   - GET /jf/items?parent=<id> → /Items?ParentId=<id>&Recursive=true&
     IncludeItemTypes=Movie,Episode,Video&SortBy=SortName&Limit=100
     (name, id, year, runtime, has_poster)
   - GET /jf/poster/<item_id> → proxy /Items/<id>/Images/Primary bytes (cache
     to a temp dir; pass through content type)
   - POST /jf/play/<item_id> → start ffmpeg transcode of Jellyfin's
     /Videos/<id>/stream?static=true into a cache dir as <id>.ogv:
     scale to max 854x480, theora q7, vorbis q4. Accept &max_seconds=<n> for
     tests (ffmpeg -t). If a cached complete file exists, report ready.
   - GET /jf/play_status/<item_id> → {state: none|working|ready|error,
     progress: 0..1} (progress from ffmpeg -progress output or output-file
     duration vs item runtime; approximate is fine, label it).
   - The bridge serves the finished file at GET /jf/file/<item_id> (the app
     downloads it whole, then plays locally — no streaming needed).
   - Proxy support: if env HOLODECK_JF_PROXY is set, route Jellyfin requests
     through it (this VM reaches Jellyfin only via that proxy; on Jon's LAN
     the bridge runs direct with no env). Bind 127.0.0.1:8791 by default,
     host/port overridable by argv.
2. **App TV panel** — NEW app/tv_panel.gd (class_name TvPanel extends Node3D):
   - Frame: one merged dark-titanium slab (MeshBuilder/Fx patterns from the
     repo) + thin cyan emissive edge line + screen quad. 16:9 always.
   - Screen = ONE SubViewport (like wall_panel.gd) whose texture the screen
     quad shows. Inside: a Control UI with two layers — (a) browser UI
     (library list → item list with poster thumbnails, Rajdhani, near-black
     teal styling matching wall_panel.gd's framed display), (b) a
     VideoStreamPlayer filling the screen for playback.
   - Placement: behaves like a WallPanel (grab to slide along its wall, snap
     on release) + two-hand stretch resize (width clamp 0.8–2.6 m, height
     follows 16:9). Reuse the Prop/WallPanel interaction patterns and the
     hand contract (group "grabbable" etc.) — read wall_panel.gd, prop.gd,
     hand.gd first and follow their conventions.
   - Default placement: FRONT wall (the wall behind the spawn view), so the
     North Star composition (opening, suits, table) is never cluttered.
   - Bridge base URL: resolve like hub.gd does (env HOLODECK_BRIDGE override,
     else http://192.168.4.51:8791 — the hub host on Jon's LAN).
   - Browser flow: on summon/boot, GET libraries; tapping a library lists
     items (poster + name + year); tapping an item POSTs play, polls status
     with a progress bar on screen ("Preparing… 42%"), downloads the .ogv to
     user://tv_cache/, plays it. A STOP/BACK control returns to the browser.
     All network failures show a plain error line on screen, never a crash.
   - UIPanel: add a TV toggle button beside the BOARD button (ui_panel.gd
     tools row) that shows/hides the TV.
   - main.gd: build the TV after WallWidgets, like the other room furniture.

## Budget law (hard)
Resting scene is currently 87 draw calls / exactly 3 lights (tools/suit_perf.gd
measures). Your TV must keep resting draw calls ≤ 90 and lights at exactly 3
(no new lights, ever). Measure SUITPERF before and after. If the resting TV
pushes past 90, make the TV default-HIDDEN (summoned via the UIPanel toggle)
and say so in the report.

## Look bar ("make it look good")
- Idle screen: the Stark library UI — near-black-teal, thin teal rules and
  borders, Rajdhani type, poster grid with a teal selection frame; a subtle
  waveform deco like the wall panels is welcome.
- Playing: video fills the screen edge to edge; controls vanish.
- Frame reads as one machined object with the room's tables/benches (same
  titanium family), not a floating rectangle.
- Take windowed captures (tools/shot.gd pattern, xvfb) of: TV on its wall
  (room view), browser UI close-up, playback running the test clip. Compare
  against the reference's language and fix obvious misses once.

## Verification (all SEQUENTIAL — parallel godot runs corrupt timing here)
1. After adding the class_name script: godot --headless --path app --import
   (stale class cache otherwise). Import must end with 0 SCRIPT ERRORs.
2. Existing suites touched by your wiring: panel, wall_widgets, props, rig —
   and since main.gd/ui_panel.gd are shared, run the full headless gate
   (panel, interaction, explode, silhouette, failure, print_flow, rig, props,
   solidify, tools, responds, labels, park_labels, wall_widgets, wall_live,
   spill, boot_fade). All must PASS.
3. NEW tools/tv_test.gd: panel spawns, resize clamps hold 16:9, placement
   snap works, browser UI populates from injected fake data, state machine
   (browse → preparing → playing → back) transitions. PASS required.
4. NEW tools/bridge_smoke.py: run the bridge with HOLODECK_JF_PROXY set to
   the :3130 tailnet proxy (compute it as ${HTTPS_PROXY%:*}:3130) and verify
   against the REAL Jellyfin: libraries return Movies/TV Shows, items list
   non-empty, a poster returns image bytes, and a &max_seconds=15 transcode
   reaches ready and the .ogv probes as theora/vorbis via ffprobe.
5. Playback proof: a windowed test (tools/tv_play_test.gd) that plays the
   smoke test's .ogv (or a locally ffmpeg-generated 3 s clip) on the TV
   screen and asserts the player is playing and frames advance.
6. SUITPERF before/after numbers in the report.

## Codebase gotchas (learned the hard way — obey)
- GDScript: := cannot infer from Variant/Dictionary values — type locals.
- String(x) throws when x is null — use str() or a null guard.
- BaseMaterial3D.texture_repeat is a BOOL in 4.7.2 (= true enables tiling).
- render_priority is NOT a MeshInstance3D property.
- Tokens.FONT_REGULAR/FONT_BOLD are String paths — load() them for fonts.
- Captures run WINDOWED under xvfb (xvfb-run -a, --resolution 1280x720);
  headless captures time out on this scene.
- Frame-count waits lie under load — wait on Time.get_ticks_msec().

## Hard rules
- NO commits. Do not edit existing files under tools/ (adding new files is
  fine). Never read out or log the Jellyfin API key or hub token values.
- No function changes to existing features — this chunk ADDS the TV and its
  one UIPanel button; everything else keeps behaving exactly as before.
- No Marvel assets/names/likenesses. No new lights. No personalization.
- If the playback path fails twice, ship the panel + browser UI with playback
  cleanly stubbed behind the bridge contract and say exactly that in the
  report — never fake a pass.

## Deliverable
The code + tools/bridge_smoke.py results + captures in captures/ (names
shot-tv-*.png) + a report at TV-REPORT.md: what was built, the playback proof,
budget before/after, suite results, capture paths, honest residuals.
