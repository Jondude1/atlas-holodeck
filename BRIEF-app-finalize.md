# BRIEF — Finalize the app build (trebuchet PARKED by Jon's order, 2026-11-19)

Jon's order: "just get the app built, we can worry about the trebuchet later."
The trebuchet app-integration run was killed mid-work. The tree contains
PARTIAL trebuchet integration. Your job: preserve that work, remove it from
the app, and ship the verified app build (briefs #5 + #6 behaviour) clean.

## Step 1 — Park the trebuchet work (lose nothing)
Create `parked/trebuchet-app-20261119/` in the repo and copy into it:
- `app/trebuchet.gd` (+ .uid), `app/holo_mesh.gdshader` (+ .uid),
  `tools/exercise.gd` (if present), `app/models/` (whole folder),
  `BRIEF-trebuchet-app.md`, `BRIEF-trebuchet.md`.
- Also save a copy of the CURRENT (trebuchet-edited) versions of
  `app/main.gd`, `app/model.gd`, `app/ui_panel.gd`, `app/hand.gd`,
  `app/main.tscn`, `app/fx.gd`, `SPEC.md` into
  `parked/trebuchet-app-20261119/edited-files/` so the partial integration
  can be resumed later exactly where it stopped.
The `cad/` folder stays where it is (finished, verified CAD — not part of
the app).

## Step 2 — Restore the app to the verified brief-#6 behaviour
Remove ALL trebuchet integration from the app code and scene:
- The demo object is the build123d bracket again: it materializes at table
  centre over its flat schematic during the boot sequence, exactly as
  briefs #5/#6 had it (boot storyboard timing, greeting after materialize,
  confirm tone, decimal-inch DIMS/SCALE readouts).
- Panel returns to the standard control set (no COCK/FIRE/WT controls).
- No trebuchet nodes in main.tscn, no trebuchet references in any app/*.gd.
- Delete `app/trebuchet.gd`, `app/holo_mesh.gdshader`, `app/models/`,
  `tools/exercise.gd` from the app tree (copies live in parked/).
- SPEC.md: showcase section describes the bracket demo again; REMOVE any
  trebuchet-showcase text added by the killed run. KEEP: table dimensions
  (2.44 × 1.22 m), imperial-units rules, the §3 CAD quality standard, and
  everything from briefs #5/#6. Add one line noting the trebuchet showcase
  is parked in `parked/trebuchet-app-20261119/` with finished CAD in `cad/`.

## Step 3 — Validate (all of it, report each)
- Headless run: clean boot, "boot complete" + "materialize complete",
  no errors, no trebuchet strings in the log.
- `grep -ri trebuchet app/` returns nothing.
- Captures: regenerate captures/shot-01..04 with tools/capture.gd.
- Draw calls at rest within the brief-#6 numbers (~90 cap), lights = 3.
- APK export with the established pipeline (Godot 4.7.2 binary in
  ~/workspace/tooling/godot/, JDK 17 on PATH for apksigner,
  GRADLE_USER_HOME=~/workspace/tooling/gradle-home-holodeck, debug keystore
  env vars, Gradle IPv4 workaround): report APK path + size, apksigner
  verify result, package name, VR manifest entries, networkSecurityConfig
  present.

## Rules
- No git commits. Colours from Tokens only. Do not touch cad/ or parked/
  contents after Step 1. If restoring a file's #6 behaviour is ambiguous,
  prefer the behaviour described in BRIEF-first-contact.md and
  BRIEF-visual-polish.md (both in repo root).
- Final report: parked inventory, files changed + why, validation results
  (each item), APK size + verification, capture list.
