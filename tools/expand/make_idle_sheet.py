"""Turn a white-background idle GIF into a transparent sprite sheet for StandingCharacter.

  python tools/expand/make_idle_sheet.py <gif> <out_name> [--target-height 522] [--keep-head-frac 0.30]

Writes assets/textures/standing/<out_name>.png (grid of frames, all cropped to the union bounding
box so the feet keep one baseline) and <out_name>.json (frame size, grid, count, fps, scale) which
apply_standing.py reads for the STANDING_SHEET entries.

A GIF that already has transparency (any fully transparent pixel in the first frame) is used as is.
Otherwise the white background is removed per frame: everything near-white that touches the image border is background
(flood fill), so white inside the character (eye sparkles, sclera) survives; near-white pockets
enclosed by the character below the head zone (top `keep_head_frac` of the frame) are background
too (gaps between arm and body). Edge pixels get an alpha from their whiteness and their colour
is un-blended from white, so no white fringe remains.
"""
import argparse
import json
import math
import os

import numpy as np
from PIL import Image
from scipy import ndimage

OUT_DIR = "assets/textures/standing/"


def remove_bg(rgba, keep_head_frac):
    a = rgba.astype(np.float32)
    rgb = a[..., :3]
    h, w = rgb.shape[:2]
    dist = np.sqrt(((255.0 - rgb) ** 2).sum(-1))
    hard = dist < 30
    lab, n = ndimage.label(hard)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
    border.discard(0)
    bg = np.isin(lab, list(border))
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        if i in border or sl is None:
            continue
        if sl[0].start >= keep_head_frac * h:
            bg |= lab == i
    ring = ndimage.binary_dilation(bg, iterations=2) & ~bg
    alpha = np.full((h, w), 255.0)
    alpha[bg] = 0
    alpha[ring] = np.clip((dist[ring] - 20.0) / 100.0, 0, 1) * 255
    m = ring & (alpha > 0) & (alpha < 255)
    al = alpha[m][:, None] / 255.0
    fixed = rgb.copy()
    fixed[m] = np.clip((rgb[m] - 255.0 * (1 - al)) / al, 0, 255)
    return np.dstack([fixed, alpha]).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("gif")
    ap.add_argument("out_name")
    ap.add_argument("--target-height", type=float, default=522.0, help="drawn height in world px (char_02 still was 522)")
    ap.add_argument("--keep-head-frac", type=float, default=0.30)
    args = ap.parse_args()

    gif = Image.open(args.gif)
    n = gif.n_frames
    durations = []
    frames = []
    transparent = bool((np.asarray(gif.convert("RGBA"))[..., 3] == 0).any())
    print("source is already transparent" if transparent else "removing white background")
    for i in range(n):
        gif.seek(i)
        durations.append(gif.info.get("duration", 100))
        rgba = np.asarray(gif.convert("RGBA"))
        frames.append(rgba.copy() if transparent else remove_bg(rgba, args.keep_head_frac))
    fps = 1000.0 / (sum(durations) / len(durations))
    print("frames", n, "fps %.2f" % fps, "size", gif.size)

    union = np.zeros(frames[0].shape[:2], bool)
    for f in frames:
        union |= f[..., 3] > 8
    ys, xs = np.where(union)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    fw, fh = x1 - x0, y1 - y0
    cols = int(math.ceil(math.sqrt(n)))
    rows = int(math.ceil(n / cols))
    sheet = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(Image.fromarray(f[y0:y1, x0:x1]), ((i % cols) * fw, (i // cols) * fh))
    png = OUT_DIR + args.out_name + ".png"
    sheet.save(png)
    meta = {
        "source": os.path.basename(args.gif),
        "frame_w": int(fw), "frame_h": int(fh),
        "hframes": cols, "vframes": rows, "count": n,
        "fps": round(fps, 3),
        "scale": round(float(args.target_height) / float(fh), 4),
    }
    with open(OUT_DIR + args.out_name + ".json", "w", encoding="utf-8") as fp:
        json.dump(meta, fp, indent=1)
    print("wrote", png, sheet.size, meta)


if __name__ == "__main__":
    main()
