# Antigravity follow-up — complete the verification suites (Atlas Holodeck)

Your earlier polish pass (BRIEF-antigravity-polish.md) was INTERRUPTED while its
verification was running. Your presentation edits are in the working tree
(17 files). The POLISH-ANTIGRAVITY.md report was never written. This task:
finish the verification, fix only your own polish regressions, and write the
report.

## Hard rules (unchanged from the polish brief)
- PRESENTATION ONLY. Never edit anything under `tools/` (the tests are the
  judge, not a negotiation). Never change behaviour/interaction/hub/voice/CAD
  logic. Never read or modify `app/hub_secret.cfg`. Do not commit to git.
- If a failure is functional or pre-existing (not caused by your polish edits),
  document it in the report and leave the code alone.

## Run, in this order
1. Import check:
   `~/workspace/tooling/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path app --import`
   → must report 0 SCRIPT ERRORs.
2. All 14 headless suites (from repo root; each prints a PASS/FAIL line):
   panel_test, interaction_test, explode_test, silhouette_test, failure_test,
   print_flow_test, rig_test, props_test, solidify_test, tools_test,
   responds_test, labels_test, park_labels_test, wall_widgets_test
   Command shape: `~/workspace/tooling/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path app --script ../tools/<name>.gd`
   Run them ONE AT A TIME (this VM has 1.5 shared CPUs; parallel godot runs
   corrupt each other's timing and produce false failures).
3. The end-to-end exercise (windowed, needs the mock hub):
   - Start the hub EXACTLY like this — the `--edit-assets` flag is MANDATORY;
     without it the hub silently skips the scripted edit/print turns and the
     exercise false-fails (this exact mistake burned an hour earlier today):
     `python3 tools/mock_hub.py --port 8794 --assets cad-jobs/0f84d94de2 --edit-assets cad-jobs/edit-bracket-tall`
   - Then: `HOLODECK_HUB=http://127.0.0.1:8794 xvfb-run -a ~/workspace/tooling/godot/Godot_v4.7.2-stable_linux.x86_64 --path app --resolution 1280x720 --script ../tools/round1b_exercise.gd`
   - Record the ROUND1B_EXERCISE verdict and the EX PERF line (draw calls /
     lights; ceilings: draw calls ≤ 95, lights ≤ 3). Kill the hub afterwards.
4. If you change any code to fix a polish regression, re-run the affected
   suites AND re-take the two captures (windowed, same shapes as the polish
   brief): shot-agy1 (entrance) and shot-agy2 (close table).

## Deliverable — POLISH-ANTIGRAVITY.md in the repo root
- Summary of the polish changes (file, what, which named target from the
  polish brief).
- Full verification results: import verdict, every suite's PASS/FAIL line,
  the exercise verdict + EX PERF numbers.
- Any failure you documented but did not fix, with your evidence for why it is
  not a polish regression.
Leave the working tree dirty; review and commit happen outside your pass.
