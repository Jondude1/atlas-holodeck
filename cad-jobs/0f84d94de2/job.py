from build123d import *

IN = 25.4
NAME = "Shelf Bracket"


def soft(shape, r):
    try:
        out = fillet(shape.edges(), r)
        return out if out.is_valid and out.volume > 0 else shape
    except Exception:
        return shape


def build():
    leg = 4.0 * IN          # 4" long on each arm
    thick = 0.25 * IN       # plate thickness
    width = 1.25 * IN       # depth (into the page / screw-axis length)
    reach = leg * 0.5       # how far the diagonal gusset extends

    # Horizontal arm (shelf support), foot on the print bed
    horiz = Box(leg, width, thick, align=(Align.MIN, Align.CENTER, Align.MIN))

    # Vertical arm (wall mount), standing up from the corner
    vert = Box(thick, width, leg, align=(Align.MIN, Align.CENTER, Align.MIN))

    # Diagonal gusset filling the inner right angle for stiffness
    with BuildSketch(Plane.XZ) as gset:
        with BuildLine():
            Polyline((0, 0), (reach, 0), (0, reach), (0, 0))
        make_face()
    gusset = extrude(gset.sketch, amount=width / 2, both=True)

    body = horiz + vert + gusset

    # Two mounting screw holes through the vertical arm, axis along X
    hole_r = 2.75  # ~5.5 mm clearance hole
    hole_len = thick + 4.0
    z1 = leg * 0.22
    z2 = leg * 0.78
    hole1 = Pos(thick / 2, 0, z1) * Rot(Y=90) * Cylinder(
        hole_r, hole_len, align=(Align.CENTER, Align.CENTER, Align.CENTER)
    )
    hole2 = Pos(thick / 2, 0, z2) * Rot(Y=90) * Cylinder(
        hole_r, hole_len, align=(Align.CENTER, Align.CENTER, Align.CENTER)
    )

    bracket = body - hole1 - hole2
    bracket = soft(bracket, 2.0)

    # Recentre on x = 0 (model already sits on z = 0, y already centred)
    bracket = Pos(-leg / 2, 0, 0) * bracket

    return {"Bracket": bracket}
