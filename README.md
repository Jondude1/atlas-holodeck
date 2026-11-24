# Atlas Holodeck

A Meta Quest 2 VR app: talk to **Atlas** inside a Star Trek-style holodeck, describe a
part out loud, and watch a real build123d CAD model materialize on the holo-table —
then grab it, rotate it, zoom it, and pull it apart.

- **Engine:** Godot 4 + OpenXR, exported as a sideloaded Android APK
  (`com.jondude.holodeck`). No Meta store, no account — Developer Mode + USB sideload.
- **Brain:** the same Atlas hub (`:8765` on Obelisk) and Hermes-on-Athena brain the
  phone app uses. This app is a new face on Atlas, not a new assistant.
- **CAD:** voice → Hermes/Claude Code writes build123d → Athena's 3D worker builds and
  exports glTF → the model spawns on the table with named parts and an explode view.
- **Safety:** send-to-print (Kobra S1) is confirmation-gated. A voice command alone
  never starts a print. No credentials live in this repo or the app.

Full product spec: [SPEC.md](SPEC.md)

## Layout

```
app/      Godot 4 project (the holodeck)
builds/   local exported APKs (see builds/README.md)
keystore/ the one permanent release-signing key (committed on purpose)
.github/  CI: build + sign + publish a GitHub Release on every push to main
```

## Updates (no more hand-sideloading)

Every push to `main` makes GitHub Actions export a signed APK (version `0.2.<run>`) and publish it
as a [GitHub Release](https://github.com/Jondude1/atlas-holodeck/releases). In the headset, the
version button beside **ATLAS HOLODECK** on the panel checks the latest release (on its own 20 s
after launch, then every 30 min), turns into **UPDATE TO vX**, downloads, and opens Android's
installer. Android asks once for "Install unknown apps" for Atlas Holodeck; after that each update
is one confirm.

One-time setup on the Quest:
1. Uninstall the old Atlas Holodeck (older builds were signed with a different, debug key).
2. Sideload the latest release APK with SideQuest.
3. Put the hub token on the headset: copy `hub_secret.cfg` (same `[hub] token=` file as before) into
   `Android/data/com.jondude.holodeck/files/Documents/` with SideQuest's file browser (or
   `adb push hub_secret.cfg /sdcard/Android/data/com.jondude.holodeck/files/Documents/`). Release
   APKs are public, so the token is never baked into them. Updates keep the file; an uninstall
   clears it.

## Status

v1 skeleton: holodeck room + holo-table + a grabbable 3-part test assembly with an
explode slider, styled to the Stark design language in SPEC.md §2 (which also defines
the Agents-of-SHIELD table model). Voice link and the live CAD loop wire in next,
per SPEC.md §4.
