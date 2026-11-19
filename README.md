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
builds/   exported APKs (not committed — see builds/README.md)
```

## Status

v1 skeleton: holodeck room + holo-table + a grabbable 3-part test assembly with an
explode slider. Voice link and the live CAD loop wire in next, per SPEC.md §3.
