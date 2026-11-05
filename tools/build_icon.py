"""Make the game's exe / window icon from a character face.

  python tools/build_icon.py [source.png] [--crop x0 y0 x1 y1]

Default source: spine_parts_maid_v2/setup-pose.png (the maid v2 setup pose, 1325x1790, transparent), face crop
chosen so the headpiece, fringe and chin fit a square. The crop is scaled onto a rounded square (dark purple
like the showcase background with a soft lighter centre) and written as
  icon_game.png  256x256 (project.godot config/icon: editor + window icon)
  icon_game.ico  256/128/64/48/32/24/16 (export preset application/icon + config/windows_native_icon)
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZES = [256, 128, 64, 48, 32, 24, 16]
BG_EDGE = (46, 34, 74)      # dark purple
BG_CENTRE = (96, 70, 146)   # lighter centre
OUT_PNG = os.path.join(ROOT, "icon_game.png")
OUT_ICO = os.path.join(ROOT, "icon_game.ico")


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return m


def background(size):
    # radial gradient: lighter centre -> darker edge
    big = size * 2
    bg = Image.new("RGB", (big, big), BG_EDGE)
    d = ImageDraw.Draw(bg)
    steps = 48
    for i in range(steps, 0, -1):
        k = i / steps
        col = tuple(int(BG_EDGE[c] + (BG_CENTRE[c] - BG_EDGE[c]) * (1 - k)) for c in range(3))
        r = big * 0.75 * k
        d.ellipse((big / 2 - r, big * 0.42 - r, big / 2 + r, big * 0.42 + r), fill=col)
    return bg.filter(ImageFilter.GaussianBlur(big / 20)).resize((size, size), Image.LANCZOS)


def build(src, crop, size=256):
    face = Image.open(src).convert("RGBA").crop(crop)
    # the crop is square; let the art bleed to the edges (hair runs off the rounded square like an avatar)
    face = face.resize((size, size), Image.LANCZOS)
    icon = background(size).convert("RGBA")
    icon.alpha_composite(face)
    icon.putalpha(rounded_mask(size, int(size * 0.22)))
    return icon


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", nargs="?", default=os.path.join(ROOT, "spine_parts_maid_v2", "setup-pose.png"))
    ap.add_argument("--crop", type=int, nargs=4, default=[150, 110, 910, 870], metavar=("X0", "Y0", "X1", "Y1"))
    args = ap.parse_args()
    x0, y0, x1, y1 = args.crop
    assert x1 - x0 == y1 - y0, "crop must be square"
    master = build(args.source, (x0, y0, x1, y1), 256)
    master.save(OUT_PNG)
    frames = [master.resize((s, s), Image.LANCZOS) if s != 256 else master for s in SIZES]
    frames[0].save(OUT_ICO, format="ICO", sizes=[(s, s) for s in SIZES], append_images=frames[1:])
    print("wrote", OUT_PNG, "and", OUT_ICO, "sizes", SIZES)


if __name__ == "__main__":
    main()
