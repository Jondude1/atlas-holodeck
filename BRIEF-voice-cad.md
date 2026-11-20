# BRIEF #11 — Voice conversation + voice-to-CAD (Jon's order, 2026-11-19)

Jon, in the headset, on the current build: he tried to talk to it and got
silence — "So that I can talk to it and ask it to make parts." The current
build has NO listening pipeline (greeting/confirms are recordings). Build it.

## PRIORITY ADDENDUM (Jon, 2026-11-19 20:58 ET — BINDING, supersedes the
## wake-word emphasis everywhere below)
"What about a button or gesture to talk instead of a wake word for now?"
- **Push-to-talk is the PRIMARY way to talk in this build.** Wake word
  "Atlas" is secondary/experimental: it must NOT block the APK, the gate,
  or voice verification. If the spotter proves out in scripted test, keep
  it as a bonus; if flaky, ship PTT-only and report that plainly.
- **PTT UX (required):** (a) a big hold-to-talk TALK control on the table
  panel; (b) a controller hold on a button/grip that does NOT conflict
  with grab/rotate/scale or the left-menu long-press RESET FLOOR — state
  which control you chose and why it is conflict-free. Hold = mic live +
  LISTENING indicator + tone; release = the utterance goes through the
  same hub pipeline (STT → Hermes → TTS reply / voice-to-CAD). **The mic
  is never hot outside the hold** (when wake word is off/absent, nothing
  streams until a hold starts).
- **Verification shift:** prove the PTT path end to end in scripted tests
  (hold → transcribed → answered / CAD job created). Report wake-word
  status separately as proven / not proven.

## Ground truth about the hub (verified by reading the code — don't rediscover)
- The hub is the FastAPI app `atlas_server.py` (Obelisk, :8765), source in
  `~/workspace/atlas-overlay-build/repo/obelisk/`. It is LIVE infrastructure
  the phone Atlas app depends on: **additive changes only**, existing routes
  untouched, and re-verify the phone-critical routes after deploy.
- Existing pieces to reuse: `POST /atlas/transcribe` (audio → faster-whisper
  base.en text), `POST /atlas/ask` (token-gated; text → brain reply via the
  hub's `_chat`), `/atlas/log`, `/atlas/status`. There is NO websocket and
  NO TTS route in the hub today — find how the phone gets Kokoro TTS (search
  the phone repo under `~/workspace/atlas-overlay-build/repo/app/` for its
  voice/TTS provider config) and mirror that service address.
- Token auth: several routes use `require_token`. Mirror how the phone app
  provisions its token (check its Hub config) — the token must NOT be
  committed to this (public) repo; bake it from a gitignored local file at
  export time, and say in your report exactly how you provisioned it.
- Hub deploy: find the mechanism already used for this server (deploy
  helpers live in `~/workspace/ha-slicer-ai/deploy/`, incl. obelisk.py and
  athena.py) and use it. Restart only the hub service, never the machine.

## Part A — Hub additions (Obelisk)
1. **WebSocket `/atlas/voice-stream`** (token-authenticated like /atlas/ask):
   - Client streams PCM16 16 kHz mono mic audio.
   - Server runs **sherpa-onnx keyword spotting** for "Atlas" on the stream
     (install sherpa-onnx on Obelisk if absent; use the phone spotter's
     keyword/model family where practical).
   - On spot: send the client a `{"event":"wake"}` message; keep receiving;
     detect utterance end by VAD/silence (~1.2 s); transcribe with the
     EXISTING faster-whisper model; send `{"event":"transcript","text":...}`;
     route the text through the same ask path as /atlas/ask; send
     `{"event":"reply","text":...}`. Client may also send
     `{"event":"ptt_start"}` / `{"event":"ptt_end"}` to bypass spotting
     (push-to-talk uses the same pipeline from ptt_start to ptt_end).
   - Log every session (wake source, transcript, reply) via the hub's
     existing logging conventions.
2. **TTS route if needed:** if the phone's Kokoro service is directly
   reachable by the headset on the LAN, the app may call it the same way;
   otherwise add `POST /atlas/speak` {text} → audio bytes proxying that
   service. State which you did.
3. **CAD jobs:** `POST /atlas/cad-job` {prompt} → {job_id};
   `GET /atlas/cad-job/<id>` → status + manifest when done;
   `GET /atlas/cad-job/<id>/model` → the glTF binary.
   - Pipeline: Hermes/Claude Code writes build123d from the prompt (the
     hub's brain chain decides part vs conversation — a "make me a ..."
     request becomes a CAD job; state how intent is routed) → build runs on
     **Athena in the live build123d container via docker exec** (the HA
     Slicer worker is gone post-restore; the JupyterLab build123d container
     is the live path — verify with athena.py, and state the exact path you
     used). CAD follows the standing quality standard (SPEC §3 + the
     local-printable-stl skill's dfm/community/guardrails references):
     watertight, tolerances, named parts.
   - Output manifest format = the existing one (see
     `cad/trebuchet.manifest.json`): name, parts[] with names, dims in
     DECIMAL INCHES. Files save to Athena per spec.
4. **Hub-side tests (required):** a scripted client from this VM that
   connects the socket, plays a synthesized/recorded "Atlas" + request
   clip, and shows wake → transcript → reply events; plus a CAD job
   round-trip producing a real glb + manifest. If the wake-word leg cannot
   be validated end-to-end from the sandbox, say so plainly in the report
   and ship PTT as the proven path with the wake path code-complete —
   never claim a spotter works that wasn't heard working.

## Part B — App additions (Godot)
1. **Mic:** AudioStreamMicrophone + AudioEffectCapture on a dedicated bus;
   stream PCM to the hub socket whenever the app is in voice-armed state.
   Android: add `android.permission.RECORD_AUDIO` (manifest + export
   config) and request the permission at runtime before first use.
2. **Indication (Atlas standing rule — explicit, indicated, logged):** a
   persistent MIC LIVE indicator in the HUD whenever audio is streaming;
   on wake: LISTENING state (visible change) + earcon; on utterance end: a
   distinct end tone; while Atlas replies: a SPEAKING state. A panel
   control mutes voice entirely (mic stream stops, indicator off). No
   ambiguity about whether the mic is hot — ever.
3. **PTT backup:** holding the right trigger opens an utterance directly
   (ptt_start → stream → release = ptt_end), same pipeline, same tones.
4. **Conversation:** replies play as TTS audio (Kokoro voice, same as the
   phone) through a spatial player at the panel; spoken numbers in decimal
   inches per the units rule.
5. **Voice-to-CAD:** on CAD job completion, download glb + manifest and
   materialize on the table with the EXISTING language: wireframe-scan over
   the flat schematic, named parts, tethered labels, explode, grab/rotate/
   scale. Reuse the runtime GLB loader built for the trebuchet — it is in
   `parked/trebuchet-app-20261119/` (loader + fresnel mesh shader); promote
   what you need into the app. The new model takes centre stage (park the
   demo bracket aside per the multi-object bench behaviour). Spoken
   confirmation: what was made + its dimensions, before/after materialize.
   **Send-to-print stays behind explicit confirmation — voice alone never
   prints.**
6. **Failure behaviour:** if the hub is unreachable, voice features degrade
   to the current build's behaviour (recorded greeting, in-character line)
   — never an error screen, never a hang.

## Constraints (unchanged)
≤90 draw calls / 3 lights (voice UI is minimal HUD), Tokens colours,
imperial units in all spoken/displayed text, boot storyboard unchanged,
home-network only (LAN primary / tailnet fallback via hub.gd as today).

## Validation (report each)
- Hub: deploy proof (service restarted, /atlas/status + /atlas/ask +
  /atlas/transcribe still answer), socket test transcript, CAD round-trip
  (job id, manifest contents, glb size).
- App: headless run clean; captures regenerated (LISTENING state visible in
  at least one); APK the brief #9 way — `--xr_mode_openxr` in
  `assets/_cl_`, `libopenxr_loader.so` present, apksigner verify, package,
  AND the RECORD_AUDIO permission present in the manifest dump.
- builds/README.md row; SPEC.md updated (voice architecture + the
  indication/logging rules + any approximation).
- No git commits. Final report: files changed (hub + app) + why, the exact
  Athena build path used, how the token was provisioned, test evidence,
  what is proven vs what still needs Jon's headset, APK facts.
