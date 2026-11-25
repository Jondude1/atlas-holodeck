"""Suit prep (dev tool): trim the TRELLIS display disc, decimate to ~25k
faces with meshoptimizer's attribute-aware simplifier (UVs + normals and the
PBR textures survive), feet to y=0, height to 1.78 m.
Run: ~/workspace/tooling/suit-venv/bin/python tools/decimate_suits.py
Source GLBs stay in design/suits3d/."""
import numpy as np, trimesh, meshoptimizer as mo

JOBS = [
    ("design/suits3d/suit-01-hero.glb", "app/suits/suit_hero.glb"),
    ("design/suits3d/suit-04-heroine.glb", "app/suits/suit_heroine.glb"),
]
TARGET_FACES = 25000
DISC_CUT = -0.44      # face-centroid y below this = display disc (measured)
HEIGHT_M = 1.78

for src, dst in JOBS:
    scene = trimesh.load(src)
    m = scene.dump(concatenate=True)
    print(src, "in:", len(m.faces), "faces; visual:", type(m.visual).__name__)
    keep = m.triangles_center[:, 1] >= DISC_CUT
    m.update_faces(keep)
    m.remove_unreferenced_vertices()
    print("  after disc trim:", len(m.faces))

    pos = np.ascontiguousarray(m.vertices, dtype=np.float32)
    nrm = np.ascontiguousarray(m.vertex_normals, dtype=np.float32)
    uv = np.ascontiguousarray(m.visual.uv, dtype=np.float32)
    attrs = np.ascontiguousarray(np.hstack([nrm, uv]), dtype=np.float32)
    weights = np.array([1, 1, 1, 2, 2], dtype=np.float32)
    idx = np.ascontiguousarray(m.faces.flatten(), dtype=np.uint32)
    dest = np.empty_like(idx)
    # NOTE: simplify_with_attributes() hits a ctypes conversion bug in the
    # installed binding (arg 13). Plain simplify is index-only — surviving
    # vertices keep their exact original normals/UVs — so attributes stay
    # valid; only the collapse metric is position-only.
    n = mo.simplify(dest, idx, pos,
                    target_index_count=TARGET_FACES * 3,
                    target_error=10.0)
    idx2 = dest[:n]
    print("  decimated faces:", n // 3)
    # compact the vertex buffers to only what the new index uses
    remap = np.empty(len(pos), dtype=np.uint32)
    nv = mo.generate_vertex_remap(remap, idx2, vertices=pos)
    idx3 = np.empty_like(idx2)
    mo.remap_index_buffer(idx3, idx2, remap=remap)
    def _remap(buf):
        outb = np.empty_like(buf)
        mo.remap_vertex_buffer(outb, buf, remap=remap)
        return outb[:nv]
    pos2, nrm2, uv2 = _remap(pos), _remap(nrm), _remap(uv)

    out = trimesh.Trimesh(vertices=pos2, faces=idx3.reshape(-1, 3),
                          vertex_normals=nrm2, process=False)
    out.visual = trimesh.visual.TextureVisuals(uv=uv2, material=m.visual.material)
    # trimesh re-encodes textures as PNG on export; cap them at 1024 so the
    # pair of suits stays ~2-3 MB instead of 13 MB (originals were 2048 webp).
    from PIL import Image
    mat = out.visual.material
    for attr in ("baseColorTexture", "metallicRoughnessTexture"):
        img = getattr(mat, attr, None)
        if img is not None and img.size[0] > 1024:
            setattr(mat, attr, img.resize((1024, 1024), Image.LANCZOS))
    lo, hi = out.bounds
    out.apply_translation([0, -lo[1], 0])
    out.apply_scale(HEIGHT_M / (hi[1] - lo[1]))
    print("  final bounds:", out.bounds, "faces:", len(out.faces))
    out.export(dst)
    chk = trimesh.load(dst)
    cm = chk.dump(concatenate=True)
    print("  wrote", dst, "-> reload faces:", len(cm.faces),
          "uv:", getattr(cm.visual, "uv", None) is not None,
          "material:", type(getattr(cm.visual, "material", None)).__name__)
