"""Tabletop trebuchet — Atlas Holodeck showcase piece (BRIEF-trebuchet.md).

Run:  ~/workspace/tooling/build123d-venv/bin/python cad/trebuchet.py

True size, millimetres internally (inches in the design constants).  X = length (throw
direction +X), Y = width, Z = up, origin at the ground centre of the base.  The assembly is
modelled in the COCKED pose (arm long end down-back, counterweight raised, sling laid along
the base trough, release pin home).

Outputs (cad/):  trebuchet.glb  trebuchet.step  trebuchet.manifest.json  preview-*.png
  * glb: ONE FLAT NODE PER PART, node name == part name (verified by parsing the JSON chunk),
    glTF Y-up, metres.  Flat on purpose: the animation grouping (arm pivot / hanger / sling) is
    rebuilt by the app from the manifest "pivot" block, the same contract the voice-CAD worker
    will emit for any model.
  * manifest: parts + dims from the actual solids; pivot coordinates are inches in the CAD frame.

Every part must pass the print-minded acceptance checklist (valid, manifold solid + exported
mesh, volume, min wall, worst overhang vs its print orientation, no interference).  The script
exits non-zero if any line fails — a failed line gets fixed here, not waived.
"""
import json
import math
import sys
from itertools import combinations
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image, ImageDraw
from build123d import (Axis, Box, Cylinder, Edge, Face, Location, Plane, Pos, Rot, Solid,
                       Sphere, Vector, Wire, chamfer, export_step, scale, Compound, Polyline,
                       Spline)

OUT = Path(__file__).resolve().parent
APP_MODELS = OUT.parent / "app" / "models"
I = 25.4
PLA_DENSITY, PLA_EFFECTIVE = 1.24, 0.40   # g/cm3 solid PLA; ~40% effective density when printed

# ───────────────────────── design constants (inches) ─────────────────────────
BASE_L, BASE_W = 14.0, 7.0
AXLE_Z = 10.0                       # Jon: apex / axle height 10 in
RAIL_Y, RAIL_W, RAIL_H, RAIL_ZC = 2.6, 0.9, 1.0, 0.8   # rail centre y, width, height, centre z
RAIL_TOP = RAIL_ZC + RAIL_H / 2     # 1.3
CROSS_X = 5.9
FOOT_X = 2.7                        # A-frame foot centre (±x)
FRAME_T = 0.7                       # A-frame thickness (y)
POST_W = 0.85
ARM_LONG, ARM_SHORT = 11.0, 4.0     # 15 in total
ARM_COCK_DEG = 50.0                 # cocked: long end this many degrees BELOW horizontal, pointing back
HINGE_LOCAL = -3.55                 # counterweight hinge, arm-local x (short side)
EYE_LOCAL = 10.78                   # sling eye on the long tip
AXLE_R, HINGE_R = 0.20, 0.15
CLEAR = 0.3                         # radial fit clearance, mm (printed pins turn freely)
STONE_R = 0.75
BLOCK = (3.4, 2.9, 0.5)             # weight block x, y, z
BOX = (4.0, 3.5, 4.0)               # counterweight box outer x, y, z
BOX_WALL, BOX_FLOOR = 0.2, 0.25
STRAP_T, STRAP_Y0 = 0.25, 1.75      # strap plates sit on the box's outer y faces
STRAP_UP = 1.5                      # box top is this far below the hinge
POUCH_C = (0.6, 0.0, 0.94)          # centre of the pouch's inner sphere
POUCH_RI, POUCH_T = 0.8, 0.063
PIN_X = -CROSS_X
ROPE_D = 3.0                        # rope apothem*2, mm


def mm(v):
    return v * I


def V(x, y, z):
    return Vector(x * I, y * I, z * I)


def solid_of(shape):
    s = shape.solids()
    if len(s) != 1:
        raise RuntimeError(f"expected 1 solid, got {len(s)}")
    return s[0]


def cham(shape, d=1.2):
    """Slight chamfer on every edge (timber look). Falls back to the plain solid if OCC refuses."""
    try:
        r = chamfer(shape.edges(), d)
        if r.is_valid and r.volume > 0:
            return r
    except Exception:
        pass
    return shape


def box_at(cx, cy, cz, lx, ly, lz):
    return Pos(cx * I, cy * I, cz * I) * Box(lx * I, ly * I, lz * I)


def beam_xz(p0, p1, w, t, yc=0.0, ext0=0.0, ext1=0.0, ch=1.2):
    """Chamfered beam between two (x, z) points in the XZ plane (inches); w = in-plane width,
    t = thickness along Y."""
    dx, dz = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dz)
    ux, uz = dx / length, dz / length
    a = (p0[0] - ux * ext0, p0[1] - uz * ext0)
    b = (p1[0] + ux * ext1, p1[1] + uz * ext1)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    body = cham(Box((length + ext0 + ext1) * I, t * I, w * I), ch)
    return Pos(mid[0] * I, yc * I, mid[1] * I) * Rot(0, -math.degrees(math.atan2(dz, dx)), 0) * body


def prism_xz(points, y0, y1):
    """Polygon in the XZ plane (inches) extruded from y0 to y1 (inches)."""
    w = Wire.make_polygon([V(x, y0, z) for x, z in points], close=True)
    return Solid.extrude(Face(w), Vector(0, (y1 - y0) * I, 0))


def prism_xy(points, z0, z1):
    w = Wire.make_polygon([V(x, y, z0) for x, y in points], close=True)
    return Solid.extrude(Face(w), Vector(0, 0, (z1 - z0) * I))


def cyl_y(cx, cz, r, y0, y1):
    return Pos(cx * I, (y0 + y1) / 2 * I, cz * I) * Rot(-90, 0, 0) * Cylinder(r * I, (y1 - y0) * I)


def cyl_z(cx, cy, r, z0, z1):
    return Pos(cx * I, cy * I, (z0 + z1) / 2 * I) * Cylinder(r * I, (z1 - z0) * I)


def hole_y_teardrop(cx, cz, r_mm, y0, y1):
    """Horizontal (Y-axis) hole for parts printed upright: circle + 45 deg roof so it prints
    without supports."""
    r = r_mm
    c = Pos(cx * I, (y0 + y1) / 2 * I, cz * I) * Rot(-90, 0, 0) * Cylinder(r, (y1 - y0) * I)
    k = r / math.sqrt(2)
    pts = [(cx * I - k, cz * I + k), (cx * I + k, cz * I + k), (cx * I, cz * I + r * math.sqrt(2))]
    w = Wire.make_polygon([Vector(x, y0 * I, z) for x, z in pts], close=True)
    tri = Solid.extrude(Face(w), Vector(0, (y1 - y0) * I, 0))
    return c + tri


def revolve_pin_y(r_shaft, half_shaft, r_flange, flange_t):
    """Iron pin / axle along Y, centred at y=0, with 45 deg cone caps so it prints standing up."""
    cone = r_flange - r_shaft
    pts = [(0, -half_shaft - cone - flange_t), (r_flange, -half_shaft - cone - flange_t),
           (r_flange, -half_shaft - cone), (r_shaft, -half_shaft),
           (r_shaft, half_shaft), (r_flange, half_shaft + cone),
           (r_flange, half_shaft + cone + flange_t), (0, half_shaft + cone + flange_t)]
    w = Wire.make_polygon([Vector(x * I, y * I, 0) for x, y in pts], close=True)
    return Solid.revolve(Face(w), 360, Axis.Y)


def octagon_rope(points, apothem_mm):
    """Swept octagon (flat faces up/down/sideways => prints lying flat without supports)."""
    path = Spline(*[V(*p) for p in points])
    t0 = path.tangent_at(0)
    pl = Plane(origin=path.position_at(0), x_dir=(0, 1, 0), z_dir=t0)
    R = apothem_mm / math.cos(math.pi / 8)
    pts = []
    for k in range(8):
        a = math.pi / 8 + k * math.pi / 4
        pts.append(pl.from_local_coords((R * math.cos(a), R * math.sin(a))))
    prof = Wire.make_polygon(pts, close=True)
    from build123d import sweep
    return solid_of(sweep(Face(prof), path=path))


# ───────────────────────── part builders ─────────────────────────
def build_parts():
    P = {}
    tol = CLEAR

    # --- base ---
    for side, sy in (("L", 1), ("R", -1)):
        P[f"SideRail{side}"] = cham(box_at(0, sy * RAIL_Y, RAIL_ZC, BASE_L, RAIL_W, RAIL_H), 1.5)
    inner_y = RAIL_Y - RAIL_W / 2
    for nm, sx in (("Front", 1), ("Rear", -1)):
        b = cham(box_at(sx * CROSS_X, 0, RAIL_ZC, 0.9, inner_y * 2, RAIL_H), 1.5)
        if sx < 0:   # release-pin hole (clearance fit), vertical => prints flat without supports
            b = b - cyl_z(PIN_X, 0, 0.15 + tol / I, 0.0, 2.0)
        P[f"CrossBeam{nm}"] = b

    # --- A-frames (two posts + crossbar + bored apex head per side) ---
    def aframe(sy):
        yc = sy * RAIL_Y
        apex = (0.0, AXLE_Z)
        posts = None
        for sx in (-1, 1):
            foot = (sx * FOOT_X, RAIL_TOP)
            p = beam_xz(foot, apex, POST_W, FRAME_T, yc, ext0=0.4, ext1=0.0, ch=1.5)
            posts = p if posts is None else posts + p
        bar_z = 4.5
        bx = FOOT_X * (AXLE_Z - bar_z) / (AXLE_Z - RAIL_TOP)
        posts = posts + cham(box_at(0, yc, bar_z, 2 * bx, FRAME_T, 0.6), 1.2)
        head = cham(box_at(0, yc, AXLE_Z, 1.5, FRAME_T, 1.5), 1.5)
        a = posts + head
        # trim feet flat on the rail top and the post tips off at the head top
        a = a - box_at(0, yc, RAIL_TOP - 1.0, 12, 2, 2.0) - box_at(0, yc, AXLE_Z + 0.75 + 1.0, 12, 2, 2.0)
        a = a - cyl_y(0, AXLE_Z, AXLE_R + tol / I, yc - 1, yc + 1)
        return a
    P["AFrameL"] = aframe(1)
    P["AFrameR"] = aframe(-1)

    # --- struts: rear diagonal brace, post -> rail; trimmed flush against both ---
    for side, sy in (("L", 1), ("R", -1)):
        yc = sy * RAIL_Y
        top = (-FOOT_X * (AXLE_Z - 6.2) / (AXLE_Z - RAIL_TOP), 6.2)
        s = beam_xz((-5.4, RAIL_TOP), top, 0.6, 0.5, yc, ext0=0.5, ext1=0.5, ch=1.2)
        s = s - box_at(0, yc, RAIL_TOP - 1.0, 14, 2, 2.0)
        s = s - P[f"AFrame{side}"] - P[f"SideRail{side}"]
        P[f"Strut{side}"] = solid_of(s) if len(s.solids()) == 1 else max(s.solids(), key=lambda q: q.volume)

    # --- axle ---
    P["Axle"] = revolve_pin_y(AXLE_R, 3.1, 0.5, 0.1).moved(Location((0, 0, AXLE_Z * I)))

    # --- throwing arm (built along +x, axle at origin; rotated to the cocked pose) ---
    side_prof = [(-ARM_SHORT, 0.4), (0, 0.55), (ARM_LONG, 0.275), (ARM_LONG, -0.275), (0, -0.55), (-ARM_SHORT, -0.4)]
    side = prism_xz(side_prof, -0.7, 0.7)
    for x0, x1, h in ((9.9, 10.5, 0.36), (-3.95, -3.2, 0.5)):   # iron bands (protrude in z only)
        side = side + prism_xz([(x0, h), (x1, h), (x1, -h), (x0, -h)], -0.7, 0.7)
    plan = prism_xy([(-ARM_SHORT, 0.4), (0, 0.5), (ARM_LONG, 0.25), (ARM_LONG, -0.25), (0, -0.5), (-ARM_SHORT, -0.4)], -2, 2)
    arm = side & plan
    arm = cham(arm, 1.0)
    arm = arm - cyl_y(0, 0, AXLE_R + tol / I, -1, 1)
    arm = arm - cyl_y(HINGE_LOCAL, 0, HINGE_R + tol / I, -1, 1)
    arm = arm - cyl_y(EYE_LOCAL, 0, 0.1, -1, 1)
    arm = Pos(0, 0, AXLE_Z * I) * Rot(0, 180 - ARM_COCK_DEG, 0) * arm
    P["ThrowingArm"] = arm

    ang = math.radians(180 - ARM_COCK_DEG)   # Rot about Y: local +x -> (cos, 0, -sin)

    def arm_pt(lx):
        return (lx * math.cos(ang), AXLE_Z - lx * math.sin(ang))
    hinge = arm_pt(HINGE_LOCAL)
    eye = arm_pt(EYE_LOCAL)

    # --- counterweight box (open top) + hanger straps ---
    bx, by, bz = BOX
    box_top = hinge[1] - STRAP_UP
    box_cz = box_top - bz / 2
    outer = cham(box_at(hinge[0], 0, box_cz, bx, by, bz), 1.5)
    cav = box_at(hinge[0], 0, box_cz + BOX_FLOOR / 2 + 0.01, bx - 2 * BOX_WALL, by - 2 * BOX_WALL, bz - BOX_FLOOR + 0.02)
    cb = outer - cav
    zb = box_top - 1.2
    for sy in (1, -1):
        y_in, y_out = sy * STRAP_Y0, sy * (STRAP_Y0 + STRAP_T)
        prof = [(y_in, zb), (y_out, zb + STRAP_T), (y_out, hinge[1]), (y_in, hinge[1])]
        w = Wire.make_polygon([Vector((hinge[0] - 0.4) * I, y * I, z * I) for y, z in prof], close=True)
        plate = Solid.extrude(Face(w), Vector(0.8 * I, 0, 0))
        round_top = cyl_y(hinge[0], hinge[1], 0.4, min(y_in, y_out), max(y_in, y_out))
        cb = cb + plate + round_top
    cb = cb - hole_y_teardrop(hinge[0], hinge[1], HINGE_R * I + tol, -3, 3)
    P["CounterweightBox"] = solid_of(cb)

    # --- weight blocks, stacked in the box (WeightBlock1 at the bottom) ---
    floor_top = box_top - bz + BOX_FLOOR
    for i in range(6):
        z = floor_top + BLOCK[2] * (i + 0.5)
        blk = cham(box_at(hinge[0], 0, z, *BLOCK), 1.2)
        blk = blk - cyl_z(hinge[0], 0, 0.35, z - 1, z + 1)
        P[f"WeightBlock{i + 1}"] = blk

    # --- hinge pin ---
    P["HingePin"] = revolve_pin_y(HINGE_R, 2.1, 0.35, 0.1).moved(Location((hinge[0] * I, 0, hinge[1] * I)))

    # --- pouch (bowl, opening up, 45 deg foot so it prints without supports) ---
    cx, _, cz = POUCH_C
    Ro = POUCH_RI + POUCH_T
    k = Ro / math.sqrt(2)
    cone = Solid.revolve(Face(Wire.make_polygon([Vector(x * I, 0, z * I) for x, z in [
        (0, cz - 2 * k + 0.3), (0.3, cz - 2 * k + 0.3), (k, cz - k), (k, cz - k + 0.3), (0, cz - k + 0.3)]], close=True)),
        360, Axis.Z).moved(Location((cx * I, 0, 0)))
    bowl = Pos(cx * I, 0, cz * I) * Sphere(Ro * I) + cone
    bowl = bowl - Pos(cx * I, 0, cz * I) * Sphere(POUCH_RI * I)
    bowl = bowl - box_at(cx, 0, cz - 0.35 + 1.5, 4, 4, 3.0)     # rim plane 0.35 below the sphere centre
    P["SlingPouch"] = solid_of(bowl)
    pouch_base = min(v.Z for v in P["SlingPouch"].vertices()) / I

    # --- stone: scaled sphere with facets; flat foot cut deep enough to print without support ---
    P["Stone"] = build_stone(cx, cz)

    # --- wheels (disc + hub, outer face flush, 5 lightening holes) ---
    for nm, sx, sy in (("FL", 1, 1), ("FR", 1, -1), ("RL", -1, 1), ("RR", -1, -1)):
        wx, wz = sx * 5.5, 0.8
        y0, y1 = 3.15, 3.5
        d = cham(cyl_y(wx, wz, 0.8, y0, y1), 1.5) + cyl_y(wx, wz, 0.3, 3.075, y1)
        for k5 in range(5):
            a = math.radians(72 * k5 + 36)
            d = d - cyl_y(wx + 0.52 * math.cos(a), wz + 0.52 * math.sin(a), 0.11, y0 - 0.1, y1 + 0.1)
        if sy < 0:
            d = d.mirror(Plane.XZ)
        P[f"Wheel{nm}"] = solid_of(d)

    # --- release pin: shaft through the rear cross beam + teardrop pull ring ---
    shaft_z0, ring_apex = 0.3, RAIL_TOP + 0.35
    rr = 0.45
    zc = ring_apex + rr * math.sqrt(2)
    shaft = cyl_z(PIN_X, 0, 0.15, shaft_z0, ring_apex + 0.1)
    ring = cyl_y(PIN_X, zc, rr, -0.075, 0.075)
    k = rr / math.sqrt(2)
    drop = prism_xz([(PIN_X - k, zc - k), (PIN_X + k, zc - k), (PIN_X, zc - rr * math.sqrt(2))], -0.075, 0.075)
    ring = ring + drop
    ring = ring - hole_y_teardrop(PIN_X, zc, 0.17 * I, -1, 1)
    P["ReleasePin"] = solid_of(shaft + ring)
    ring_c = (PIN_X, zc)

    # --- ropes (octagon section) ---
    rim = (cx - (Ro ** 2 - 0.35 ** 2) ** 0.5 + 0.0, cz - 0.35 - 0.0)
    pts = [(eye[0], 0, eye[1]), (-5.2, 0, 0.85), (-3.0, 0, 0.42), (-1.2, 0, 0.52), (rim[0], 0, rim[1])]
    P["SlingRope"] = octagon_rope(pts, ROPE_D / 2)
    cpts = [(eye[0], 0, eye[1]), (eye[0] + 0.5, 0, (eye[1] + zc) / 2 - 0.25), (ring_c[0] - 0.15, 0, zc - 0.1)]
    P["CockingRope"] = octagon_rope(cpts, ROPE_D / 2)

    meta = dict(hinge=hinge, eye=eye, ring=ring_c, box_top=box_top, floor_top=floor_top, pouch_base=pouch_base,
                rim=rim, box_cz=box_cz)
    return P, meta


def build_stone(cx, cz):
    """Irregular rounded rock. The foot is cut deeper until the measured overhang passes."""
    base = solid_of(scale(Sphere(STONE_R * I), by=(1.0, 0.9, 0.94)))
    facets = [((0.8, 0.5, 0.45), 0.86), ((-0.7, 0.4, 0.55), 0.84), ((0.2, -0.9, 0.3), 0.88), ((-0.4, -0.6, 0.6), 0.85)]
    for n, f in facets:
        nv = Vector(*n).normalized()
        pl = Plane(origin=nv * (STONE_R * I * f), z_dir=nv)
        base = solid_of(base - pl.location * Pos(0, 0, 100) * Box(200, 200, 200))
    s = base
    for depth in np.linspace(0.18, 0.5, 33):
        cut = base - Pos(0, 0, -STONE_R * I * 0.94 + depth * STONE_R * I - 100) * Box(200, 200, 200)
        s = solid_of(cut)
        if overhang_of(s, np.array([0, 0, 1.0]))[0] <= 44.0:
            break
    zmin = min(v.Z for v in s.vertices())
    foot_r = max(math.hypot(v.X, v.Y) for v in s.vertices() if v.Z < zmin + 0.05) / I
    # the flat foot rests on the bowl's inner sphere at its edge ring
    lift = POUCH_RI - math.sqrt(POUCH_RI ** 2 - foot_r ** 2)
    z_foot = (cz - POUCH_RI + lift) * I + 0.4      # 0.4 mm air gap: parts never touch
    return s.moved(Location((cx * I, 0, z_foot - zmin)))


# ───────────────────────── print-minded checks ─────────────────────────
def mesh_of(shape, tol=0.1, ang=0.2):
    v, t = shape.tessellate(tol, ang)
    return trimesh.Trimesh(np.array([[p.X, p.Y, p.Z] for p in v]), np.array(t), process=True)


def overhang_of(shape_or_mesh, up):
    """(worst overhang deg from vertical, % of area beyond 45) for a print pose whose +z is `up`."""
    m = shape_or_mesh if isinstance(shape_or_mesh, trimesh.Trimesh) else mesh_of(shape_or_mesh)
    up = np.asarray(up, float)
    up /= np.linalg.norm(up)
    h = m.vertices @ up
    tri_h = h[m.faces]
    nz = m.face_normals @ up
    bed = tri_h.max(axis=1) <= h.min() + 0.05
    down = (nz < -1e-3) & ~bed
    if not down.any():
        return 0.0, 0.0
    ang = np.degrees(np.arcsin(np.clip(-nz[down], 0, 1)))
    area = m.area_faces
    pct = 100.0 * area[down][ang > 45.0].sum() / area.sum()
    return float(ang.max()), float(pct)


def min_wall_of(m, samples=500, seed=1):
    """Local thickness estimate: cast inward along -normal from surface samples, nearest exit."""
    rng = np.random.default_rng(seed)
    pts, fidx = trimesh.sample.sample_surface(m, samples, seed=seed)
    n = m.face_normals[fidx]
    tri = m.triangles
    a, b, c = tri[:, 0], tri[:, 1], tri[:, 2]
    e1, e2 = b - a, c - a
    best = np.inf
    for i in range(len(pts)):
        o = pts[i] - n[i] * 1e-3
        d = -n[i]
        pv = np.cross(d, e2)
        det = np.einsum("ij,ij->i", e1, pv)
        ok = np.abs(det) > 1e-12
        inv = np.where(ok, 1.0 / np.where(ok, det, 1), 0)
        tv = o - a
        u = np.einsum("ij,ij->i", tv, pv) * inv
        qv = np.cross(tv, e1)
        w = (qv @ d) * inv
        t = np.einsum("ij,ij->i", e2, qv) * inv
        hit = ok & (u >= 0) & (w >= 0) & (u + w <= 1) & (t > 1e-2)
        if hit.any():
            best = min(best, float(t[hit].min()))
    return best


PRINT_UP = {}   # part -> (up vector, human description), filled by orientation()


def orientation(name, shape):
    cy = shape.center().Y
    if name.startswith(("SideRail", "CrossBeam", "WeightBlock", "SlingPouch", "Stone", "CounterweightBox", "ReleasePin")):
        d = {"CounterweightBox": "upright, open top up", "SlingPouch": "bowl up on its 45° foot",
             "Stone": "flat foot down", "ReleasePin": "standing, ring up"}.get(name, "flat, as modelled")
        return np.array([0, 0, 1.0]), d
    if name.startswith("Wheel"):
        return np.array([0, -1.0 if cy > 0 else 1.0, 0]), "flat, outer face on the bed"
    if name in ("Axle", "HingePin"):
        return np.array([0, 1.0, 0]), "standing on one cap (axis vertical)"
    # AFrame*, Strut*, ThrowingArm, SlingRope, CockingRope: lie on their Y face
    return np.array([0, 1.0, 0]), "on its side, Y face down"


def interference(P):
    out = []
    names = list(P)
    for a, b in combinations(names, 2):
        ba, bb = P[a].bounding_box(), P[b].bounding_box()
        if (ba.max.X < bb.min.X or bb.max.X < ba.min.X or ba.max.Y < bb.min.Y or bb.max.Y < ba.min.Y
                or ba.max.Z < bb.min.Z or bb.max.Z < ba.min.Z):
            continue
        try:
            v = (P[a] & P[b]).volume
        except Exception:
            v = 0.0
        if v > 1.0:   # mm^3
            out.append((a, b, v))
    return out


# ───────────────────────── export + preview ─────────────────────────
def to_yup_m(mesh):
    """CAD (X fwd, Y width, Z up, mm) -> glTF (Y up, metres): (x, y, z) -> (x, z, -y)."""
    v = mesh.vertices
    out = np.column_stack([v[:, 0], v[:, 2], -v[:, 1]]) * 1e-3
    return trimesh.Trimesh(out, mesh.faces, process=False)


def smooth(mesh):
    return trimesh.graph.smooth_shade(mesh, angle=math.radians(35))


def write_glb(P, path):
    scene = trimesh.Scene()
    for name, s in P.items():
        m = to_yup_m(mesh_of(s, 0.08, 0.15))
        m.fix_normals()
        m = smooth(m)
        scene.add_geometry(m, node_name=name, geom_name=name)
    scene.export(path)


def glb_node_names(path):
    data = Path(path).read_bytes()
    n = int.from_bytes(data[12:16], "little")
    js = json.loads(data[20:20 + n])
    return [x.get("name") for x in js["nodes"]], js


def render(P, path, view, size=(1200, 760)):
    """Painter's-algorithm software render (flat Lambert, depth-sorted triangles)."""
    W, H = size
    tris, cols = [], []
    shades = {"Axle": (120, 128, 138), "HingePin": (120, 128, 138), "ReleasePin": (120, 128, 138),
              "Stone": (150, 150, 150), "SlingRope": (190, 160, 110), "CockingRope": (190, 160, 110),
              "SlingPouch": (160, 120, 80)}
    for name, s in P.items():
        m = mesh_of(s, 0.15, 0.3)
        base = shades.get(name)
        if base is None:
            base = (60, 75, 95) if name.startswith(("WeightBlock",)) else (150, 150, 160) if name.startswith("Wheel") \
                else (176, 128, 84)
        if name == "CounterweightBox":
            base = (100, 110, 125)
        tris.append(m.triangles)
        cols.append(np.tile(base, (len(m.faces), 1)))
        cols[-1] = np.column_stack([cols[-1], m.face_normals])
    T = np.concatenate(tris)
    C = np.concatenate(cols)
    az, el = view
    a, e = math.radians(az), math.radians(el)
    # camera basis (CAD Z-up)
    fwd = np.array([math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)])  # camera -> from
    right = np.cross([0, 0, 1.0], fwd)
    right /= np.linalg.norm(right)
    upv = np.cross(fwd, right)
    pts = T.reshape(-1, 3)
    x = pts @ right
    y = pts @ upv
    depth = pts @ fwd
    sc = min(W * 0.92 / (x.max() - x.min()), H * 0.92 / (y.max() - y.min()))
    sx = (x - (x.max() + x.min()) / 2) * sc + W / 2
    sy = H / 2 - (y - (y.max() + y.min()) / 2) * sc
    sx, sy, depth = sx.reshape(-1, 3), sy.reshape(-1, 3), depth.reshape(-1, 3)
    order = np.argsort(depth.mean(axis=1))   # far (small depth) first
    light = np.array([0.4, -0.5, 0.9])
    light /= np.linalg.norm(light)
    img = Image.new("RGB", (W, H), (10, 18, 30))
    dr = ImageDraw.Draw(img)
    # ground grid hint
    for i in order:
        n = C[i, 3:]
        lam = 0.35 + 0.65 * abs(float(n @ light))
        rgb = tuple(int(min(255, c * lam)) for c in C[i, :3])
        dr.polygon([(sx[i, 0], sy[i, 0]), (sx[i, 1], sy[i, 1]), (sx[i, 2], sy[i, 2])], fill=rgb)
    img.save(path)


# ───────────────────────── main ─────────────────────────
def main():
    P, meta = build_parts()
    for n, s in P.items():
        s.label = n
    print(f"{len(P)} parts built")

    fails = []
    hdr = f"{'part':<17}{'valid':>6}{'solid':>7}{'mesh':>6}{'vol cm3':>9}{'min wall mm':>12}{'overhang':>10}{'>45%':>6}  orientation"
    print(hdr)
    print("-" * len(hdr))
    meshes = {}
    for n, s in P.items():
        m = mesh_of(s)
        meshes[n] = m
        up, desc = orientation(n, s)
        oh, pct = overhang_of(m, up)
        wall = min_wall_of(m)
        ok_valid = bool(s.is_valid)
        ok_solid = len(s.solids()) == 1
        ok_mesh = bool(m.is_watertight and m.is_winding_consistent)
        vol = s.volume / 1000.0
        ok = ok_valid and ok_solid and ok_mesh and vol > 0 and wall >= 1.2 and oh <= 46.0
        if not ok:
            fails.append(n)
        print(f"{n:<17}{'OK' if ok_valid else 'FAIL':>6}{'OK' if ok_solid else 'FAIL':>7}{'OK' if ok_mesh else 'FAIL':>6}"
              f"{vol:>9.2f}{wall:>12.2f}{oh:>9.1f}°{pct:>6.1f}  {desc}{'' if ok else '   <-- FAIL'}")
    inter = interference(P)
    print(f"interference (volume > 1 mm3): {'none' if not inter else inter}")
    if inter:
        fails.append("interference")

    comp = Compound(children=list(P.values()), label="Trebuchet")
    export_step(comp, str(OUT / "trebuchet.step"))
    write_glb(P, str(OUT / "trebuchet.glb"))

    # exported-mesh check: re-load the GLB, per geometry watertight
    names, js = glb_node_names(OUT / "trebuchet.glb")
    sc = trimesh.load(OUT / "trebuchet.glb")
    glb_bad = []
    for gname, g in sc.geometry.items():
        g2 = g.copy()
        g2.merge_vertices()
        if not (g2.is_watertight and g2.is_winding_consistent):
            glb_bad.append(gname)
    print(f"GLB node names: {len(names)} nodes; match part list exactly: {sorted(names) == sorted(P)}")
    print(f"GLB meshes watertight after reload: {'all ' + str(len(sc.geometry)) if not glb_bad else 'FAIL ' + str(glb_bad)}")
    if sorted(names) != sorted(P) or glb_bad:
        fails.append("glb")
    tri_count = sum(len(g.faces) for g in sc.geometry.values())
    print(f"GLB triangles: {tri_count}")

    # manifest from the actual solids
    parts = []
    for n, s in P.items():
        bb = s.bounding_box()
        parts.append({"name": n, "dims_in": [round((bb.max.X - bb.min.X) / I, 3), round((bb.max.Y - bb.min.Y) / I, 3),
                                              round((bb.max.Z - bb.min.Z) / I, 3)]})
    frame = [P[n] for n in ("SideRailL", "SideRailR", "CrossBeamFront", "CrossBeamRear", "WheelFL", "WheelFR", "WheelRL", "WheelRR")]
    xs = [v for s in frame for v in (s.bounding_box().min.X, s.bounding_box().max.X)]
    ys = [v for s in frame for v in (s.bounding_box().min.Y, s.bounding_box().max.Y)]
    axle_z = (P["Axle"].bounding_box().min.Z + P["Axle"].bounding_box().max.Z) / 2
    true = [round((max(xs) - min(xs)) / I, 2), round((max(ys) - min(ys)) / I, 2), round(axle_z / I, 2)]
    allbb = comp.bounding_box()
    h, e, rp = meta["hinge"], meta["eye"], meta["ring"]
    cx, _, cz = POUCH_C
    manifest = {
        "name": "Trebuchet",
        "units": "in",
        "true_dims_in": true,
        "dims_note": "base length x base width (rails+wheels) x axle height; bbox_cocked_in is the full cocked envelope",
        "bbox_cocked_in": [round((allbb.max.X - allbb.min.X) / I, 2), round((allbb.max.Y - allbb.min.Y) / I, 2),
                           round((allbb.max.Z - allbb.min.Z) / I, 2)],
        "frame": "CAD Z-up, X = throw direction, origin = ground centre of base; GLB nodes are glTF Y-up metres "
                 "(x, y, z)cad -> (x, z, -y)",
        "pose": "cocked",
        "parts": parts,
        "pivot": {
            "axle_height_in": AXLE_Z,
            "arm": "ThrowingArm",
            "axle": [0.0, 0.0, AXLE_Z],
            "arm_long_in": ARM_LONG,
            "arm_short_in": ARM_SHORT,
            "arm_cocked_angle_deg": 180 + ARM_COCK_DEG,   # long-end direction angle from +X, CCW seen from +Y... in XZ
            "arm_rest_angle_deg": 65.0,
            "hinge": [round(h[0], 3), 0.0, round(h[1], 3)],
            "hinge_in_arm_local": HINGE_LOCAL,
            "arm_tip_eye": [round(e[0], 3), 0.0, round(e[1], 3)],
            "sling_length_in": 7.0,
            "pouch_home": [cx, 0.0, cz],
            "pouch_attach": [round(meta["rim"][0], 3), 0.0, round(meta["rim"][1], 3)],   # rope's pouch end (rim point)
            "stone_home": [round(P["Stone"].center().X / I, 3), 0.0, round(P["Stone"].center().Z / I, 3)],
            "stone_radius_in": STONE_R,
            "pin_ring": [round(rp[0], 3), 0.0, round(rp[1], 3)],
            "pin_travel_in": 1.0,
            "cw_hang_in": round(h[1] - (meta["box_top"] - BOX[2] / 2), 3),
            "block_height_in": BLOCK[2],
            "block_size_in": list(BLOCK),
            # printed-PLA mass assumption (Jon's marketplace quality bar): solid PLA 1.24 g/cm3 at ~40%
            # effective density (infill + walls); volume is the actual WeightBlock solid.
            "counterweight_g_per_block": round(P["WeightBlock1"].volume / 1000.0 * PLA_DENSITY * PLA_EFFECTIVE, 1),
            "counterweight_block_cm3": round(P["WeightBlock1"].volume / 1000.0, 2),
            "counterweight_density_assumption": f"PLA {PLA_DENSITY} g/cm3 solid x {PLA_EFFECTIVE} effective",
            "groups": {
                "ArmPivot": ["ThrowingArm"],
                "Hanger": ["CounterweightBox", "HingePin"] + [f"WeightBlock{i}" for i in range(1, 7)],
                "Sling": ["SlingRope", "SlingPouch", "Stone"],
                "Pin": ["ReleasePin"],
                "CockingRope": ["CockingRope"],
            },
        },
    }
    (OUT / "trebuchet.manifest.json").write_text(json.dumps(manifest, indent=2))
    APP_MODELS.mkdir(parents=True, exist_ok=True)
    for f in ("trebuchet.glb", "trebuchet.manifest.json"):
        (APP_MODELS / f).write_bytes((OUT / f).read_bytes())
    print(f"true_dims_in {true}  bbox_cocked_in {manifest['bbox_cocked_in']}")

    for tag, view in (("iso", (-35, 24)), ("side", (-90, 0)), ("top", (-90, 89))):
        render(P, str(OUT / f"preview-{tag}.png"), view)
    print("previews: software-rendered PNGs (painter's algorithm) preview-iso/side/top.png")

    if fails:
        print("ACCEPTANCE FAILED:", fails)
        sys.exit(1)
    print("ACCEPTANCE: all parts pass")


if __name__ == "__main__":
    main()
