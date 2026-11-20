from build123d import *

IN = 25.4
NAME = "Shelf Bracket"
# EDIT of cad-jobs/0f84d94de2/job.py: "make it two inches taller and add two holes in the base"
# (vertical arm 4 in -> 6 in; two 5.5 mm screw holes through the horizontal base, axis Z)


def soft(shape, r):
    try:
        out = fillet(shape.edges(), r)
        return out if out.is_valid and out.volume > 0 else shape
    except Exception:
        return shape


def build():
    leg = 4.0 * IN
    tall = 6.0 * IN
    thick = 0.25 * IN
    width = 1.25 * IN
    reach = leg * 0.5
    horiz = Box(leg, width, thick, align=(Align.MIN, Align.CENTER, Align.MIN))
    vert = Box(thick, width, tall, align=(Align.MIN, Align.CENTER, Align.MIN))
    with BuildSketch(Plane.XZ) as gset:
        with BuildLine():
            Polyline((0, 0), (reach, 0), (0, reach), (0, 0))
        make_face()
    gusset = extrude(gset.sketch, amount=width / 2, both=True)
    body = horiz + vert + gusset
    hole_r = 2.75
    h1 = Pos(leg * 0.55, 0, 0) * Cylinder(hole_r, thick * 3, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    h2 = Pos(leg * 0.88, 0, 0) * Cylinder(hole_r, thick * 3, align=(Align.CENTER, Align.CENTER, Align.CENTER))
    m1 = Pos(thick / 2, 0, tall * 0.2) * Rot(Y=90) * Cylinder(hole_r, thick + 4.0)
    m2 = Pos(thick / 2, 0, tall * 0.8) * Rot(Y=90) * Cylinder(hole_r, thick + 4.0)
    bracket = soft(body - h1 - h2 - m1 - m2, 2.0)
    bracket = Pos(-leg / 2, 0, 0) * bracket
    return {"Bracket": bracket}
