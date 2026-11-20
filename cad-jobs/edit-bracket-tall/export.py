"""Local stand-in for the Athena runner's export (dev fixture only): job.py -> model.glb (Y-up metres, one node per part)
+ manifest.json (decimal inches). Same frame as the hub's real outputs: glTF (x, y, z) = CAD (x, z, -y) / 1000."""
import json, sys, importlib.util, numpy as np, trimesh
spec = importlib.util.spec_from_file_location("job", "job.py"); job = importlib.util.module_from_spec(spec); spec.loader.exec_module(job)
parts = job.build()
scene = trimesh.Scene()
lo = np.full(3, 1e9); hi = np.full(3, -1e9); pm = []
for name, shape in parts.items():
    v, t = shape.tessellate(0.05, 0.2)
    v = np.array([[p.X, p.Y, p.Z] for p in v]); t = np.array(t)
    bb = shape.bounding_box()
    lo = np.minimum(lo, [bb.min.X, bb.min.Y, bb.min.Z]); hi = np.maximum(hi, [bb.max.X, bb.max.Y, bb.max.Z])
    g = np.stack([v[:, 0], v[:, 2], -v[:, 1]], 1) / 1000.0
    scene.add_geometry(trimesh.Trimesh(g, t, process=False), node_name=name, geom_name=name)
    pm.append({"name": name, "dims_in": [round((bb.max.X - bb.min.X) / 25.4, 3), round((bb.max.Y - bb.min.Y) / 25.4, 3), round((bb.max.Z - bb.min.Z) / 25.4, 3)]})
open("model.glb", "wb").write(scene.export(file_type="glb"))
d = [round(float(x), 3) for x in (hi - lo) / 25.4]
json.dump({"name": job.NAME, "units": "in", "true_dims_in": d, "parts": pm, "checks": "dev fixture export"}, open("manifest.json", "w"), indent=1)
print("OK", d)
