"""Extend main_BG_2.png (720x1280 portrait) sideways so it fills a landscape view.

The original stays pixel-identical in the middle; the new strips continue the three regions
(dark top, diagonal purple band, dark-purple bottom) with their edge lines and gradients.
Usage: python tools/expand/extend_bg.py [src] [dst] [pad]
"""
import sys
import numpy as np
from PIL import Image

src = sys.argv[1] if len(sys.argv) > 1 else "assets/textures/main_BG_2.png"
dst = sys.argv[2] if len(sys.argv) > 2 else "assets/textures/main_BG_2_wide.png"
PAD = int(sys.argv[3]) if len(sys.argv) > 3 else 840

im = np.array(Image.open(src).convert("RGBA")).astype(np.float64)
H, W = im.shape[:2]
rgb = im[:, :, :3]

# --- band edge lines (fit on the "red > 95" transition per column, excluding the arrow area) ---
xs = np.arange(W)
tops = np.array([np.where(rgb[:, x, 0] > 95)[0].min() for x in xs], dtype=float)
bots = np.array([np.where(rgb[:, x, 0] > 95)[0].max() for x in xs], dtype=float) + 1.0
clean = (xs > 80) & (xs < 640)  # arrows sit near both edges of the band
top_a, top_b = np.polyfit(xs[clean] + 0.5, tops[clean], 1)
bot_a, bot_b = np.polyfit(xs[clean] + 0.5, bots[clean], 1)
print("top line: y = %.4f x + %.2f" % (top_a, top_b))
print("bot line: y = %.4f x + %.2f" % (bot_a, bot_b))


def top_y(x):
    return top_a * x + top_b


def bot_y(x):
    return bot_a * x + bot_b


# --- per-region robust polynomial colour model in (u = x/W, v = relative height in region) ---
yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
xc, yc = xx + 0.5, yy + 0.5
ty, by = top_y(xc), bot_y(xc)
region = np.where(yc < ty, 0, np.where(yc < by, 1, 2))


def rel_v(r, xc, yc):
    ty, by = top_y(xc), bot_y(xc)
    if r == 0:
        return yc / ty
    if r == 1:
        return (yc - ty) / (by - ty)
    return (yc - by) / (H - by)


def basis(u, v):
    return np.stack([np.ones_like(u), u, v, u * v, u * u, v * v, u * u * v, u * v * v, v * v * v], axis=-1)


models = {}
for r in range(3):
    m = region == r
    # keep away from the anti-aliased edges and the dark seam on the right edge
    m &= (np.abs(yc - ty) > 3) & (np.abs(yc - by) > 3) & (xc < W - 4)
    u = xc[m] / W
    v = rel_v(r, xc[m], yc[m])
    A = basis(u, v)
    col = rgb[m]
    w = np.ones(len(u))
    coef = None
    for it in range(6):
        Aw = A * w[:, None]
        coef, *_ = np.linalg.lstsq(Aw, col * w[:, None], rcond=None)
        res = np.abs(A @ coef - col).max(axis=1)
        thr = max(4.0, np.percentile(res, 70))
        w = (res < thr).astype(float)  # drop silhouette / arrows / lines
    print("region %d: fitted on %d px, final median residual %.2f" % (r, int(w.sum()), np.median(res[w > 0])))
    models[r] = coef


def model_color(r, xc, yc):
    """Colour for an (extended) pixel: horizontal extrapolation eases out beyond the original."""
    L = 320.0
    xe = np.where(xc < 0, -L * (1 - np.exp(xc / L)), np.where(xc > W, W + L * (1 - np.exp(-(xc - W) / L)), xc))
    u = xe / W
    v = rel_v(r, xc, yc)
    return basis(u, v) @ models[r]


# --- locate the < > arrows (pixels that deviate from the band model near both edges) ---
band_model = model_color(1, xc, yc)
dev = (np.abs(rgb - band_model).max(axis=2) > 10) & (region == 1)
near_edge = (np.abs(yc - ty) < 2.5) | (np.abs(yc - by) < 2.5)
dev_soft = (np.abs(rgb - band_model).max(axis=2) > 3) & (region == 1) & ~near_edge
for name, m in (("left", dev & (xc < 110)), ("right", dev & (xc > 610))):
    ys_, xs_ = np.where(m)
    print("arrow %s: x %d..%d  y %d..%d  centre (%.1f, %.1f)" % (name, xs_.min(), xs_.max(), ys_.min(), ys_.max(), (xs_.min() + xs_.max()) / 2, (ys_.min() + ys_.max()) / 2))

# --- fade the silhouette lines out towards the right edge so the band continues cleanly ---
# (only pixels that deviate from the smooth band model are touched; the > arrow is kept)
FADE_X0 = 560.0
arrow_box = (xc > 600) & (xc < 700) & (yc > 450) & (yc < 580)
t = np.clip((xc - FADE_X0) / (W - FADE_X0), 0, 1)
t = t * t * (3 - 2 * t)
blend = np.where(dev_soft & ~arrow_box, t, 0.0)
im[:, :, :3] = rgb * (1 - blend[..., None]) + band_model * blend[..., None]
rgb = im[:, :, :3]

# --- compose ---
NW = W + 2 * PAD
out = np.zeros((H, NW, 4), dtype=np.float64)
out[:, :, 3] = 255.0
out[:, PAD:PAD + W] = im
# fix the 1-px dark seam on the original's right edge (last column) by refitting it
seam_x = np.array([W - 1], dtype=float)
for x in range(W - 1, W):
    xcc = np.full(H, x + 0.5)
    ycc = np.arange(H) + 0.5
    tyy, byy = top_y(xcc), bot_y(xcc)
    for r in range(3):
        c = model_color(r, xcc, ycc)
        cov = np.clip(np.where(r == 0, tyy - ycc + 0.5, np.where(r == 1, np.minimum(ycc + 0.5 - tyy, byy - ycc + 0.5), ycc + 0.5 - byy)), 0, 1)
        if r == 0:
            acc = c * cov[:, None]
            wsum = cov.copy()
        else:
            acc += c * cov[:, None]
            wsum += cov
    out[:, PAD + x, :3] = acc / np.maximum(wsum, 1e-6)[:, None]

for side in ("left", "right"):
    if side == "left":
        ext_x = np.arange(-PAD, 0)
    else:
        ext_x = np.arange(W, W + PAD)
    gy, gx = np.mgrid[0:H, 0:len(ext_x)].astype(np.float64)
    xcc = ext_x[gx.astype(int)] + 0.5
    ycc = gy + 0.5
    tyy, byy = top_y(xcc), bot_y(xcc)
    # coverage of each region inside the pixel (edges have small slopes -> vertical coverage is enough)
    cov0 = np.clip(tyy - (ycc - 0.5), 0, 1)
    cov2 = np.clip((ycc + 0.5) - byy, 0, 1)
    cov1 = np.clip(1 - cov0 - cov2, 0, 1)
    acc = np.zeros(xcc.shape + (3,))
    for r, cov in ((0, cov0), (1, cov1), (2, cov2)):
        acc += model_color(r, xcc, ycc) * cov[..., None]
    # mild grain like the source (std ~1)
    rng = np.random.default_rng(7 if side == "left" else 11)
    acc += rng.normal(0, 0.6, acc.shape)
    dst_x0 = 0 if side == "left" else PAD + W
    out[:, dst_x0:dst_x0 + len(ext_x), :3] = acc

out = np.clip(np.round(out), 0, 255).astype(np.uint8)
Image.fromarray(out, "RGBA").save(dst)
print("saved", dst, out.shape)
