"""Slice characters_list.png into one PNG per panel (alpha-connected components), padded so an
outline shader has room. Writes assets/textures/char_panels/panel_XX.png and panels.json.
"""
import json
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

src = sys.argv[1] if len(sys.argv) > 1 else "assets/textures/characters_list.png"
out_dir = sys.argv[2] if len(sys.argv) > 2 else "assets/textures/char_panels"
PADPX = 10

im = np.array(Image.open(src).convert("RGBA"))
H, W = im.shape[:2]
lab, n = ndimage.label(im[:, :, 3] > 0)
comps = []
for i in range(1, n + 1):
    ys, xs = np.where(lab == i)
    comps.append({"id": i, "x0": int(xs.min()), "y0": int(ys.min()), "x1": int(xs.max()) + 1, "y1": int(ys.max()) + 1})
# order: top row first (by y0), then left to right -> reading order
comps.sort(key=lambda c: (c["y0"] // 200, c["x0"]))
meta = []
for k, c in enumerate(comps):
    mask = (lab[c["y0"]:c["y1"], c["x0"]:c["x1"]] == c["id"])
    crop = im[c["y0"]:c["y1"], c["x0"]:c["x1"]].copy()
    crop[~mask] = 0
    h, w = crop.shape[:2]
    padded = np.zeros((h + 2 * PADPX, w + 2 * PADPX, 4), dtype=np.uint8)
    padded[PADPX:PADPX + h, PADPX:PADPX + w] = crop
    # a panel with (almost) only the flat purple fill is an empty slot
    inner = crop[mask]
    sat = (inner[:, :3].max(axis=1).astype(int) - inner[:, :3].min(axis=1).astype(int))
    distinct = len(np.unique((inner[:, :3] // 16).astype(np.int32) @ np.array([1, 16, 256])))
    name = "panel_%02d.png" % (k + 1)
    Image.fromarray(padded, "RGBA").save(f"{out_dir}/{name}")
    meta.append({
        "file": name,
        # centre of the panel in characters_list texture pixels, and the padded sprite size
        "cx": (c["x0"] + c["x1"]) / 2.0, "cy": (c["y0"] + c["y1"]) / 2.0,
        "w": w + 2 * PADPX, "h": h + 2 * PADPX,
        "empty": bool(distinct < 40),
    })
    print(name, c, "distinct colours", distinct, "empty" if meta[-1]["empty"] else "")
json.dump({"src_w": W, "src_h": H, "pad": PADPX, "panels": meta}, open(f"{out_dir}/panels.json", "w"), indent=1)
print("wrote", len(meta), "panels")
