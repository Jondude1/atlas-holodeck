"""N64 controller wall mount — designed by Helios directly (hub CAD job 9871393bc4
failed at the writer stage on attempt 2, 2026-11-19).

Design reasoning (controller: 160 W x 152 H x 67 D mm, three-prong trident):
- Flat back plate against the wall, two countersunk screw holes on the centerline
  (countersink on the FRONT face — screws drive front-to-wall).
- Two cradle prongs support the controller under its outer grips; the 74 mm gap
  between them leaves the center grip hanging free.
- Front lips + outer corner stops keep it from tipping/sliding off, positioned at
  the prongs (below the face) so nothing presses the analog stick or buttons.
- Top-center notch in the plate gives the cable an exit path.
- Print orientation: back face (y=0) flat on the bed, prongs grow upward —
  no unsupported overhangs except the shallow countersink cones.
All dims mm. Quality bar: single valid solid, >=6 mm walls, rounded plate corners.
"""
from build123d import *
import json

PLATE_W, PLATE_H, PLATE_T = 150, 118, 6
PLATE_Z0 = 8                      # plate bottom edge height
TOP = PLATE_Z0 + PLATE_H          # 126

# --- back plate with rounded vertical corners ---
plate = Pos(0, PLATE_T / 2, PLATE_Z0 + PLATE_H / 2) * Box(PLATE_W, PLATE_T, PLATE_H)
plate = fillet(plate.edges().filter_by(Axis.Z), radius=2.5)

# --- cable notch, top center: 26 wide, 16 deep ---
plate -= Pos(0, PLATE_T / 2, TOP - 8 + 0.5) * Box(26, PLATE_T + 2, 17)

# --- screw holes: two, centerline, countersunk from the front face ---
for hz in (30, 104):
    plate -= Pos(0, PLATE_T / 2, hz) * Rot(90, 0, 0) * Cylinder(radius=2.3, height=PLATE_T + 2)
    # cone: small r at wall side, 5.0 r at front face, 3 deep from front
    plate -= Pos(0, PLATE_T - 1.5, hz) * Rot(-90, 0, 0) * Cone(bottom_radius=2.3, top_radius=5.0, height=3.2)

mount = plate

# --- cradle prongs under the outer grips ---
for sx in (-52, 52):
    arm = Pos(sx, 27, 15) * Box(30, 54, 14)            # y 0..54, z 8..22 support ledge
    lip = Pos(sx, 50, 30) * Box(30, 8, 16)             # front lip z 22..38
    stop = Pos(sx + (12 if sx > 0 else -12), 42, 30) * Box(6, 24, 16)  # outer corner stop
    mount += arm + lip + stop

# --- gentle fillets on prong vertical corners (cosmetic; never fatal) ---
try:
    mount = fillet(mount.edges().filter_by(Axis.Z).group_by(Axis.X)[-1], radius=1.5)
except Exception as e:
    print("corner fillet skipped:", e)

assert mount.is_valid, "invalid solid"
solids = mount.solids()
assert len(solids) == 1, f"expected 1 solid, got {len(solids)}"
bb = mount.bounding_box()
dims_mm = (bb.max.X - bb.min.X, bb.max.Y - bb.min.Y, bb.max.Z - bb.min.Z)
print("valid single solid, volume cm3:", round(mount.volume / 1000, 2))
print("dims mm:", [round(d, 1) for d in dims_mm], "-> in:", [round(d / 25.4, 2) for d in dims_mm])

import os
os.makedirs(os.path.dirname(os.path.abspath(__file__)), exist_ok=True)
base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "model")
export_stl(mount, base + ".stl")
export_step(mount, base + ".step")
try:
    export_gltf(mount, base + ".glb")
    print("glb exported")
except Exception as e:
    print("gltf export failed:", e)
json.dump({"name": "N64 Controller Wall Mount (Helios direct build)",
           "dims_in": [round(d / 25.4, 2) for d in dims_mm],
           "volume_cm3": round(mount.volume / 1000, 2)},
          open(base + "-manifest.json", "w"), indent=1)
print("done")
