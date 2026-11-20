import numpy as np, trimesh, os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
mesh = trimesh.load(os.path.join(HERE, "model.stl"))
print("watertight:", mesh.is_watertight, "| volume cm3:", round(mesh.volume / 1000, 2),
      "| bounds in:", [round(v / 25.4, 2) for v in (mesh.bounds[1] - mesh.bounds[0])])

tris = mesh.triangles  # (n,3,3)
normals = mesh.face_normals
center = mesh.bounds.mean(axis=0)
scale_r = np.linalg.norm(mesh.bounds[1] - mesh.bounds[0]) / 2

def render(cam_dir, up_hint, fname, size=880):
    cam = np.array(cam_dir, float); cam /= np.linalg.norm(cam)
    up = np.array(up_hint, float)
    right = np.cross(up, cam); right /= np.linalg.norm(right)
    true_up = np.cross(cam, right)
    rel = tris - center
    # camera looks along -cam toward origin; depth = rel . cam (bigger = closer)
    x = rel @ right; y = rel @ true_up; d = rel @ cam
    persp = 1.0 / (1.0 + 0.18 * (1 - d / scale_r))  # mild perspective
    x, y = x * persp, y * persp
    ext = max(np.abs(x).max(), np.abs(y).max()) * 1.12
    px = (x / ext * 0.5 + 0.5) * size; py = (0.5 - y / ext * 0.5) * size
    depth = d.mean(axis=1)
    light = np.array([0.45, -0.55, 0.72]); light /= np.linalg.norm(light)
    shade = 0.32 + 0.68 * np.clip(normals @ light, 0, 1)
    img = Image.new("RGB", (size, size), (16, 20, 28))
    dr = ImageDraw.Draw(img)
    for i in np.argsort(depth):
        s = shade[i]
        col = (int(70 + 120 * s), int(110 + 110 * s), int(150 + 105 * s))
        pts = [(px[i, j], py[i, j]) for j in range(3)]
        dr.polygon(pts, fill=col)
    img.save(os.path.join(HERE, fname))
    print("wrote", fname)

# front: viewer stands in the room (+Y) looking at the wall (-Y); model Z up
render((0, 1, 0.02), (0, 0, 1), "n64-front.png")
# side: from +X
render((1, 0.15, 0.05), (0, 0, 1), "n64-side.png")
# perspective: front-right-above
render((0.85, 1.15, 0.6), (0, 0, 1), "n64-perspective.png")
