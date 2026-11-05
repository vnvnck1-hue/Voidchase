"""Build character-select panels for standing art that has no portrait yet, in the exact style of
the existing panels: the empty panel (frame + fill) is the base, the character's face is composited
inside the fill area with a flat background colour, and the "LV.2" badge is copied from an
existing panel. Output: assets/textures/char_panels/new_panel_XX.png

Usage: python tools/expand/make_portraits.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage

D = "assets/textures/char_panels/"
STAND = "assets/textures/standing/"

# which standing image goes into which (formerly empty) panel, with face framing in source pixels:
# eye_y / chin_y give the vertical scale, cx the horizontal centre; bg = flat background colour.
JOBS = [
    {"out": "new_panel_05.png", "src": "char_06.png", "cx": 515, "eye_y": 560, "chin_y": 740, "bg": (214, 70, 88)},    # bottom-left slot
    {"out": "new_panel_04.png", "src": "char_07.png", "cx": 640, "eye_y": 445, "chin_y": 660, "bg": (247, 196, 66)},   # top-right slot
    # Olivia (the rigged character) rendered by tools/expand/capture_olivia.gd -> replaces the half-cut panel
    {"out": "new_panel_08.png", "src": "olivia_render.png", "cx": 930, "eye_y": 795, "chin_y": 1005, "bg": (255, 104, 101)},
]
EYE_FRAC = 0.47   # eye line position inside the fill area (from its top)
EYE_CHIN_FRAC = 0.30  # eye->chin distance relative to the fill height

base = np.array(Image.open(D + "panel_04.png").convert("RGBA")).astype(np.float64)
H, W = base.shape[:2]
op = base[:, :, 3] == 255
cols, counts = np.unique(base[op][:, :3].astype(int), axis=0, return_counts=True)
order = np.argsort(counts)
fill = cols[order[-1]].astype(float)
border = cols[order[-2]].astype(float)
print("fill", fill, "border", border)
# soft fill weight: 1 on the flat fill, 0 on the border, in between on anti-aliased pixels
d_fill = np.linalg.norm(base[:, :, :3] - fill, axis=2)
d_fb = np.linalg.norm(border - fill)
t = np.clip(1.0 - d_fill / d_fb, 0.0, 1.0) * (base[:, :, 3] / 255.0)
t[d_fill > d_fb * 1.05] = 0.0
hard = t > 0.5
ys, xs = np.where(hard)
# centre column extent of the fill area
col = hard[:, W // 2]
cy0, cy1 = np.where(col)[0].min(), np.where(col)[0].max() + 1
fill_h = cy1 - cy0
print("fill centre column", cy0, cy1, "height", fill_h)

# badge: the "LV.2" tab is a purple rounded rect (same purple as the frame) with white text inside
# the fill area at the bottom-right corner. Take its purple core from panel_03, close the text holes.
p3 = np.array(Image.open(D + "panel_03.png").convert("RGBA")).astype(int)
purple = np.array([164, 117, 230])
core = (np.abs(p3[:, :, :3] - purple).max(axis=2) <= 8) & (p3[:, :, 3] == 255) & hard
core[: H // 2, :] = False
core[:, : W // 2] = False
lab, n = ndimage.label(core)
sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
badge = lab == (np.argmax(sizes) + 1)
# the tab's interior (text) is enclosed by its purple ring plus the frame: fill with the frame counted
ring0 = badge
holes = ndimage.binary_fill_holes(ring0 | ~hard) & ~(ring0 | ~hard)
hl, hn = ndimage.label(holes)
hs = ndimage.sum(np.ones_like(hl), hl, range(1, hn + 1))
inner = np.zeros_like(holes)
for k, sz in enumerate(hs, start=1):
    if sz < 4000:  # the tab interior; the big remaining hole is the rest of the fill area
        inner |= hl == k
badge = ring0 | inner
badge = ndimage.binary_closing(badge, structure=np.ones((3, 3)), iterations=2) & hard
ring = ndimage.binary_dilation(badge, iterations=1) & ~badge
print("badge px", int(badge.sum()))

for job in JOBS:
    src = np.array(Image.open(STAND + job["src"]).convert("RGBA"))
    s = EYE_CHIN_FRAC * fill_h / (job["chin_y"] - job["eye_y"])
    sw, sh = int(round(src.shape[1] * s)), int(round(src.shape[0] * s))
    scaled = Image.fromarray(src).resize((sw, sh), Image.LANCZOS)
    layer = Image.new("RGBA", (W, H), job["bg"] + (255,))
    ox = int(round(W / 2 - job["cx"] * s))
    oy = int(round(cy0 + EYE_FRAC * fill_h - job["eye_y"] * s))
    layer.alpha_composite(scaled, (ox, oy))
    lay = np.array(layer).astype(np.float64)
    out = base.copy()
    out[:, :, :3] = base[:, :, :3] * (1 - t[..., None]) + lay[:, :, :3] * t[..., None]
    # badge on top
    out[badge] = p3[badge]
    out[ring, :3] = out[ring, :3] * 0.5 + np.array([160, 112, 224]) * 0.5
    Image.fromarray(np.clip(np.round(out), 0, 255).astype(np.uint8), "RGBA").save(D + job["out"])
    print("wrote", job["out"], "scale %.3f offset (%d, %d)" % (s, ox, oy))
