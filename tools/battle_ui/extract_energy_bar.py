"""Extract the squad-card energy bar (HP + mana in one frame) from the screen mockup PSD.

  python tools/battle_ui/extract_energy_bar.py [path/to/화면 컨셉_3.psd]

The mockup places four copies of one smart object ('에너지바' layers 3-6 -> 그룹 279.psb) above the squad cards.
Inside the PSB (186x74, layer ids are checked):
  332 사각형 8 복사 5   frame: fill + 5px outside stroke
  333 사각형 8          base (clip base for everything below)
  334 사각형 8 복사 3   mana back      335 사각형 8 복사 2   mana fill (mockup ~33%)
  336 사각형 8 복사 4   HP back        337 사각형 8 복사     HP fill (mockup ~58%)
The shapes are straight 4-point paths, redrawn here at SS x resolution (psd-tools draws shape strokes wrongly).

Writes
  assets/textures/battle_ui/energy_frame.png   frame + base + both back colours (empty bar)
  assets/textures/battle_ui/energy_hp.png      white mask of the visible HP band (tint in game)
  assets/textures/battle_ui/energy_mp.png      white mask of the visible mana band
  scripts/void_defense/vd_energy_bar_layout.gd generated constants: colours, band x ranges, PSB -> card panel transform
"""
import io
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw
from psd_tools import PSDImage
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PSD = os.path.join(ROOT, "assets", "컨셉 원화", "화면 컨셉_3.psd")
OUT_TEX = os.path.join(ROOT, "assets", "textures", "battle_ui")
OUT_GD = os.path.join(ROOT, "scripts", "void_defense", "vd_energy_bar_layout.gd")
UI_LAYOUT = os.path.join(ROOT, "scripts", "void_defense", "vd_battle_ui_layout.gd")

BAR_LAYERS = [3, 4, 5, 6]       # '에너지바' x4, left to right card
INNER = {332: "사각형 8 복사 5", 333: "사각형 8", 334: "사각형 8 복사 3", 335: "사각형 8 복사 2",
		 336: "사각형 8 복사 4", 337: "사각형 8 복사"}
SS = 3                          # texture px per PSB px
AA = 4                          # extra supersampling while rasterizing
PANEL_TEX = (300.0, 229.0)      # char_panels texture size (vd_battle_frame.PANEL_TEX)
# The mockup's background is a 3440x1440 game screenshot: UI is 1920x1080 design scaled by 1440/1080, the card row
# pinned to the bottom-right corner.
SCREEN = (3440.0, 1440.0)
K = 1440.0 / 1080.0


def to_design(p):
	return (1920.0 - (SCREEN[0] - p[0]) / K, 1080.0 - (SCREEN[1] - p[1]) / K)


def quad(layer, size):
	pts = []
	for path in layer.vector_mask.paths:
		for k in path:
			pts.append((k.anchor[1] * size[0], k.anchor[0] * size[1]))
	return pts


def raster(pts, size, grow=0.0):
	s = SS * AA
	im = Image.new("L", (size[0] * s, size[1] * s), 0)
	ImageDraw.Draw(im).polygon([(x * s, y * s) for x, y in pts], fill=255)
	m = np.asarray(im) > 127
	if grow > 0:
		r = int(round(grow * s))
		yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
		m = ndimage.binary_dilation(m, structure=(xx * xx + yy * yy) <= r * r)
	return m


def down(m):
	h, w = m.shape
	return m.reshape(h // AA, AA, w // AA, AA).mean(axis=(1, 3))


def col(layer):
	c = layer.tagged_blocks.get_data(b"SoCo")[b"Clr "]
	return (c[b"Rd  "] / 255.0, c[b"Grn "] / 255.0, c[b"Bl  "] / 255.0)


def card_rects():
	src = open(UI_LAYOUT, encoding="utf-8").read()
	line = re.search(r"const CARD_RECTS := \[(.*)\]", src).group(1)
	return [tuple(float(v) for v in m) for m in re.findall(r"Rect2\(([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+)\)", line)]


def main():
	psd = PSDImage.open(sys.argv[1] if len(sys.argv) > 1 else PSD)
	bars = {l.layer_id: l for l in psd if l.layer_id in BAR_LAYERS}
	for lid in BAR_LAYERS:
		if lid not in bars or bars[lid].name != "에너지바" or bars[lid].kind != "smartobject":
			sys.exit("layer %d is not the '에너지바' smart object — the PSD changed, update the ids" % lid)
	inner = PSDImage.open(io.BytesIO(bars[BAR_LAYERS[0]].smart_object.data))
	size = inner.size
	L = {}
	for x in inner.descendants():
		if x.layer_id in INNER:
			if x.name != INNER[x.layer_id]:
				sys.exit("PSB layer %d is %r, expected %r" % (x.layer_id, x.name, INNER[x.layer_id]))
			L[x.layer_id] = x
	if len(L) != len(INNER):
		sys.exit("PSB layers missing: %s" % sorted(set(INNER) - set(L)))

	stroke = [e for e in L[332].effects if e.__class__.__name__ == "Stroke"][0]
	sc = stroke.color
	stroke_col = (sc[b"Rd  "] / 255.0, sc[b"Grn "] / 255.0, sc[b"Bl  "] / 255.0)
	q = {lid: quad(L[lid], size) for lid in INNER}
	m_frame = raster(q[332], size)
	m_stroke = raster(q[332], size, float(stroke.size))
	m_base = raster(q[333], size)
	m_hp = raster(q[336], size) & m_base
	m_mp = raster(q[334], size) & m_base & ~m_hp

	def layer_rgba(mask, c):
		a = down(mask)
		img = np.zeros(a.shape + (4,), np.float32)
		img[..., :3] = c
		img[..., 3] = a
		return img

	def over(dst, src):
		sa = src[..., 3:4]
		da = dst[..., 3:4]
		oa = sa + da * (1 - sa)
		rgb = (src[..., :3] * sa + dst[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-6)
		return np.concatenate([rgb, oa], axis=-1)

	frame = layer_rgba(m_stroke, stroke_col)
	# mana back runs under the HP back (as in the PSB) so the shared edge has no dark seam
	for mask, c in ((m_frame, col(L[332])), (m_base, col(L[333])), (raster(q[334], size) & m_base, col(L[334])), (m_hp, col(L[336]))):
		frame = over(frame, layer_rgba(mask, c))
	os.makedirs(OUT_TEX, exist_ok=True)
	Image.fromarray((np.clip(frame, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT_TEX, "energy_frame.png"))
	for name, mask in (("energy_hp.png", m_hp), ("energy_mp.png", m_mp)):
		Image.fromarray((np.clip(layer_rgba(mask, (1, 1, 1)), 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT_TEX, name))

	# band x ranges (PSB px) and the mockup's fill ratios
	def xr(pts):
		xs = [p[0] for p in pts]
		return min(xs), max(xs)
	hp_x = xr(q[336])
	mp_x = xr(q[334])
	base_x = xr(q[333])
	hp_x = (max(hp_x[0], base_x[0]), min(hp_x[1], base_x[1]))
	mp_x = (max(mp_x[0], base_x[0]), min(mp_x[1], base_x[1]))
	mock_hp = (xr(q[337])[1] - hp_x[0]) / (hp_x[1] - hp_x[0])
	mock_mp = (xr(q[335])[1] - mp_x[0]) / (mp_x[1] - mp_x[0])

	# PSB px -> card panel texture px, averaged over the four cards
	rects = card_rects()
	xfs = []
	for i, lid in enumerate(BAR_LAYERS):
		t = bars[lid].smart_object.transform_box   # TL, TR, BR, BL in PSD px
		tl, tr, bl = to_design(t[0:2]), to_design(t[2:4]), to_design(t[6:8])
		rx, ry, rw, rh = rects[i]
		k = (PANEL_TEX[0] / rw, PANEL_TEX[1] / rh)
		p = lambda d: ((d[0] - rx) * k[0], (d[1] - ry) * k[1])
		o, a, b = p(tl), p(tr), p(bl)
		xfs.append(((a[0] - o[0]) / size[0], (a[1] - o[1]) / size[0], (b[0] - o[0]) / size[1], (b[1] - o[1]) / size[1], o[0], o[1]))
	xf = np.mean(np.array(xfs), axis=0)
	spread = np.max(np.abs(np.array(xfs) - xf), axis=0)

	def c(v):
		return "Color(%.4f, %.4f, %.4f)" % v

	G = []
	G.append("## 생성물 — tools/battle_ui/extract_energy_bar.py 가 화면 컨셉_3.psd 의 '에너지바' 스마트 오브젝트에서 만든다. 손으로 고치지 않는다.")
	G.append("## 분대 카드 위 에너지바: 한 틀 안에 HP(위 띠)와 마나(아래 띠). 텍스처는 PSB 1px = %d texel." % SS)
	G.append("## class_name 없음: vd_battle_frame.gd 가 preload.")
	G.append("")
	G.append('const FRAME := "res://assets/textures/battle_ui/energy_frame.png"')
	G.append('const HP_MASK := "res://assets/textures/battle_ui/energy_hp.png"     # 흰 마스크: 채움 색을 곱해 그린다')
	G.append('const MP_MASK := "res://assets/textures/battle_ui/energy_mp.png"')
	G.append("const TEX_SCALE := %d" % SS)
	G.append("const PSB_SIZE := Vector2(%d, %d)" % size)
	G.append("")
	G.append("# 띠의 가로 범위 (PSB px): 비율만큼 왼쪽부터 잘라 그린다")
	G.append("const HP_X := Vector2(%.2f, %.2f)" % hp_x)
	G.append("const MP_X := Vector2(%.2f, %.2f)" % mp_x)
	G.append("")
	G.append("# 시안 색 (채움 · 바탕). 시안 속 채움 비율: HP %.2f, 마나 %.2f" % (mock_hp, mock_mp))
	G.append("const HP_FILL := " + c(col(L[337])))
	G.append("const HP_BACK := " + c(col(L[336])))
	G.append("const MP_FILL := " + c(col(L[335])))
	G.append("const MP_BACK := " + c(col(L[334])))
	G.append("")
	G.append("# PSB px -> 카드 패널 텍스처 px (네 카드 평균, 카드 간 최대 차이 %.2f px)" % float(np.max(spread)))
	G.append("const XF := Transform2D(Vector2(%.5f, %.5f), Vector2(%.5f, %.5f), Vector2(%.2f, %.2f))" % tuple(xf))
	open(OUT_GD, "w", encoding="utf-8", newline="\n").write("\n".join(G) + "\n")
	print("wrote", OUT_GD)
	print("xf", xf, "spread", spread)


if __name__ == "__main__":
	main()
