"""Turn the frame dumps of `TransitionCapture.tscn -- --anim <dir>` into gifs and contact sheets (motion check).

    C:/Python314/python.exe tools/transition/build_anim_gif.py <dir>

Writes docs/transition/anim_<P>.gif (real speed), anim_<P>_slow.gif (1/4 speed) and anim_<P>_sheet.png for presets 3 and 4.
"""
import glob
import os
import sys

from PIL import Image

SRC = sys.argv[1]
DOC = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "transition")
NAMES = {3: "strike", 4: "cut", 5: "warp", 6: "rush"}
os.makedirs(DOC, exist_ok=True)

for preset, name in NAMES.items():
	files = sorted(glob.glob(os.path.join(SRC, "anim_%d_*.png" % preset)))
	if not files:
		continue
	frames = [Image.open(f).convert("RGB") for f in files]
	small = [f.resize((640, 360), Image.LANCZOS) for f in frames]
	pal = [f.quantize(colors=200, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in small]
	hold = [600] + [30] * (len(pal) - 2) + [900]
	pal[0].save(os.path.join(DOC, "anim_%d_%s.gif" % (preset, name)), save_all=True, append_images=pal[1:], duration=hold, loop=0)
	slow = [600] + [130] * (len(pal) - 2) + [900]
	pal[0].save(os.path.join(DOC, "anim_%d_%s_slow.gif" % (preset, name)), save_all=True, append_images=pal[1:], duration=slow, loop=0)
	body = frames[5:-6]
	cols = 6
	rows = (len(body) + cols - 1) // cols
	w, h = 480, 270
	sheet = Image.new("RGB", (cols * w, rows * h), (0, 0, 0))
	for i, f in enumerate(body):
		sheet.paste(f.resize((w, h), Image.LANCZOS), ((i % cols) * w, (i // cols) * h))
	sheet.save(os.path.join(DOC, "anim_%d_%s_sheet.png" % (preset, name)))
	print("preset", preset, "frames", len(frames), "sheet", sheet.size)
