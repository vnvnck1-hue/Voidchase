"""Side-by-side check of the lightning transition: gif frame (top) vs game capture at the same key pose (bottom).

  C:/Python314/python.exe tools/transition/build_compare_sheet.py

Needs docs/transition/wipe_2_NN_wide.png from
  Godot --path . --screen 1 --position 4380,80 --resolution 1680x720 res://tools/test/TransitionCapture.tscn -- --tag wide
Writes docs/transition/compare_lightning.png
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GIF = os.path.join(ROOT, "assets", "컨셉 원화", "화면-컨셉_4_트랜지션.gif")
DOC = os.path.join(ROOT, "docs", "transition")
# gif frame index -> capture (progress*100): f1 = K1, f2 = K2, f3 = K3, f4 = K0 on the rewind
PAIRS = [(1, 16), (2, 28), (3, 37), (4, 93)]
W = 860

gif = Image.open(GIF)
h = round(W * gif.size[1] / gif.size[0])
sheet = Image.new("RGB", (W * len(PAIRS), h * 2), (30, 30, 30))
for i, (fi, p) in enumerate(PAIRS):
	gif.seek(fi)
	sheet.paste(gif.convert("RGB").resize((W, h), Image.LANCZOS), (i * W, 0))
	cap = Image.open(os.path.join(DOC, "wipe_2_%02d_wide.png" % p)).convert("RGB")
	ch = round(W * cap.height / cap.width)
	sheet.paste(cap.resize((W, ch), Image.LANCZOS), (i * W, h))
sheet.save(os.path.join(DOC, "compare_lightning.png"))
print("wrote compare_lightning.png", sheet.size)
