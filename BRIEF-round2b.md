# BRIEF — Round 2.5: Parts Library (brief #18, 2026-11-20)

Jon's feature (2026-11-20): "a library of the parts I have made, that fetch
from Athena when I click on them, and that icon edit and delete if needed
with confirmation" + "Make it so that the parts I save from other sites as
stls show up and render as well" (shape approved by Jon: "Perfect").

Backlog: R2.5-1..5. Steering: TABLE FUNCTION FIRST (Jon, 2026-11-20) —
this round is pure table capability, no ambience work.

## Facts (verified from code, 2026-11-20)
- Save-back tree (Athena, host path): C:/Users/jon/mediastack/3d-work/out/
  holodeck/<slug>-<job_id>/{model.py, model.step, model.glb, manifest.json,
  job.json} — written by atlas_voice.save_back (R1-9). Container view of
  the same tree: /work/out/holodeck/... in the `build123d` container
  (ATHENA_CONTAINER), which has Python + build123d + trimesh.
- Hub (Obelisk) reaches Athena via srv._run_athena_ssh(cmd, timeout)
  (docker exec ...) and scp (atlas_voice.win() builds host:/path targets).
- Hub job folders live on Obelisk: JOB_DIR/<job_id>/{job.py, model.glb,
  manifest.json, job.json}. The R1-4 edit path keys off a job folder's
  job.py (parent code) + the in-memory latest-job pointer (30 min).
- App spawn path (cad_bench) downloads a glb + manifest and builds a
  CadModel; print dry-run keys off the on-stage model's job id.

## Design — "load makes a job folder"
One unification for hub + app: loading a library entry materializes a hub
job folder from it, so spawn / edit / print reuse Round 1 machinery.

### Hub (atlas_voice.py, additive, token-gated like all CAD routes)
- GET /atlas/library → entries[]:
  {id, kind: "holodeck"|"stl", name, dims_in:[x,y,z], parts:int,
   created: <iso from folder/file mtime>, editable: bool}
  Source: ONE _run_athena_ssh docker-exec python script that walks
  /work/out/holodeck/*/manifest.json and /work/library/*.stl (trimesh
  bounds for STLs; mm→in exact /25.4) and prints JSON. No caching of the
  list itself (called on panel open, not per frame).
- POST /atlas/library/{id}/load → copies the entry into JOB_DIR/<job_id>/
  (holodeck: job.py←model.py, model.glb, manifest.json, job.json via scp;
  stl: converted glb — see below — + synthesized manifest
  {name, parts:[{name: stem}], dims_in, units note}), sets the latest-job
  pointer (so follow-up edits target it), returns the manifest.
  For STL entries the job folder has NO job.py → edit path must refuse
  cleanly ("no source to edit" spoken/shown, existing failure style).
- GET /atlas/library/{id}/model → the glb bytes (from the loaded job
  folder if present, else scp/convert into a hub cache first).
- POST /atlas/library/{id}/delete {confirmed:true} → refuses without
  confirmed:true (same shape as print-job). Holodeck: docker exec
  rm -rf /work/out/holodeck/<folder> (id validated against the listed
  set / strict pattern — no path traversal). STL: delete the .stl and
  its cached .glb. Logged either way. Also drops any loaded job folder.
- STL→GLB: docker exec python (trimesh): load /work/library/<f>.stl,
  scale 0.001 (STL mm → glTF metres — build123d's exporter emits metres,
  the app's true-size math assumes metres), export
  /work/library/.cache/<stem>.glb (cache keyed by file mtime).

### App
- ui_panel.gd: LIBRARY button toggles the list area between PARTS and
  LIBRARY (same scroll machinery as the part list). Row: name, dims,
  date; tap row = fetch+spawn; EDIT glyph-button (holodeck entries
  only); DEL glyph-button → generic confirmation card (reuse the print
  card pattern: names the part, CONFIRM / CANCEL, timeout = cancel) →
  Hub delete → refresh. All content changes through poke() (R2-6 rules).
- cad_bench.gd: spawn_library(entry): POST load → GET manifest+model via
  the library routes → existing spawn path with job context set (job id
  = entry's job id; STL entries get their synthetic id). Bench rules
  unchanged (current model parks, loaded part takes centre stage).
- voice.gd: nothing new; edit utterances after a load hit R1-4 as-is.
  STL-loaded model + edit utterance → hub refuses (no parent code) →
  the app speaks the hub's reason (failure_reason path, R1A).

### Tests
- Hub pytest (mock _run_athena_ssh/scp like existing tests): list shape
  from canned container JSON; load copies + sets pointer; STL load
  synthesizes manifest, no job.py; delete refuses without confirmed,
  refuses unknown id, deletes when confirmed; model route serves bytes.
- App: mock_hub.py gains library routes (2 holodeck entries + 1 STL
  entry, canned glbs); tools/library_test.gd: list renders 3 rows,
  fetch spawns entry on stage, delete without confirm calls nothing,
  confirm calls delete once, STL row has no edit affordance.
- LIVE acceptance (through the deployed hub): the list shows the real
  save-back entries from the Round 1B live test; a 20 mm calibration
  cube STL placed in 3d-work/library/ lists at 0.79 in and its glb
  bounds measure 0.02 m (0.79 in) — units proof.
- Regression: all prior suites + exercise still pass; perf ≤90 with a
  library model on stage.

### Gates (unchanged)
Artifact gates on the export; hub deploy = backup + restart service +
phone routes re-verified; commit message lists what was NOT checked.
Live printing remains Jon-gated (not in this round).
