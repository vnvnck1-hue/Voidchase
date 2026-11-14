"""Extract the stage progress gauge ('진행도 바' group) from the screen mockup PSD.

  python tools/battle_ui/extract_progress_bar.py [path/to/화면 컨셉_3.psd]

The group (id 175) holds only vector shapes and two text layers (layer ids and names are checked):
  145 사각형 3          long frame band              177 사각형 3 복사 3  left tab (below)
  178 사각형 3 복사 2   right tab (above)            167 사각형 5         top plate (number)
  168 사각형 5 복사     bottom plate (percent)       180 사각형 3 복사 5  dark trough
  179 사각형 3 복사 4   red ghost (mockup ~85%)      146 사각형 3 복사    green fill (mockup ~80%)
  166 레이어 19         lime gradient clipped to the fill (sampled from the composite, not rendered)
  190 사각형 4 복사 10  11 notch bars, overlay-clipped to the fill
  165 '60000/60000'     top plate text              161 '100%'           bottom plate text
The group's first drop shadow (black, 100%, spread 74%, hard contour) reads as a 10 px outline around every
frame shape; the second one is a soft dark halo. Both are redrawn here (psd-tools draws shape effects wrongly).

Writes
  assets/textures/battle_ui/stage_progress_frame.png   halo + outline + frame/tabs/plates + trough (no fill, no text)
  scripts/void_defense/vd_stage_progress_layout.gd     generated constants (PSD px, origin = texture top-left)
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from psd_tools import PSDImage
from psd_tools.constants import Tag
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PSD = os.path.join(ROOT, "assets", "컨셉 원화", "화면 컨셉_3.psd")
OUT_TEX = os.path.join(ROOT, "assets", "textures", "battle_ui")
OUT_GD = os.path.join(ROOT, "scripts", "void_defense", "vd_stage_progress_layout.gd")

GROUP = (175, "진행도 바")
LAYERS = {145: "사각형 3", 177: "사각형 3 복사 3", 178: "사각형 3 복사 2", 167: "사각형 5", 168: "사각형 5 복사",
		  180: "사각형 3 복사 5", 179: "사각형 3 복사 4", 146: "사각형 3 복사", 190: "사각형 4 복사 10",
		  165: "60000/60000", 161: "100%"}
FRAME = [145, 177, 178, 167, 168]
SS = 0.5                        # texture px per PSD px (in game the bar is drawn at ~0.46 of the PSD size)
AA = 8                          # supersampling while rasterizing
PAD = 40                        # PSD px around the group bbox (outline + halo)
HALO_SIGMA = 14.0               # PSD px; the mockup's 70 px blur is mostly invisible over the dark field


def paths(layer, size):
	out = []
	for path in layer.vector_mask.paths:
		out.append([(k.anchor[1] * size[0], k.anchor[0] * size[1]) for k in path])
	return out


def fill_col(layer):
	c = layer.tagged_blocks.get_data(Tag.VECTOR_STROKE_CONTENT_DATA)[b"Clr "]
	return (c[b"Rd  "] / 255.0, c[b"Grn "] / 255.0, c[b"Bl  "] / 255.0)


def gd_col(c, a=1.0):
	return "Color(%.4f, %.4f, %.4f, %.4f)" % (c[0], c[1], c[2], a)


def gd_vec(p):
	return "Vector2(%.1f, %.1f)" % p


def gd_rect(r):
	return "Rect2(%.1f, %.1f, %.1f, %.1f)" % r


def main():
	psd = PSDImage.open(sys.argv[1] if len(sys.argv) > 1 else PSD)
	group = None
	for l in psd.descendants():
		if l.layer_id == GROUP[0]:
			group = l
	if group is None or group.name != GROUP[1] or not group.is_group():
		sys.exit("layer %d is not the %r group — the PSD changed, update the ids" % GROUP)
	L = {}
	for l in group:
		if l.layer_id in LAYERS:
			if l.name != LAYERS[l.layer_id]:
				sys.exit("layer %d is %r, expected %r" % (l.layer_id, l.name, LAYERS[l.layer_id]))
			L[l.layer_id] = l
	if len(L) != len(LAYERS):
		sys.exit("layers missing: %s" % sorted(set(LAYERS) - set(L)))

	size = psd.size
	shadows = [e for e in group.effects if e.__class__.__name__ == "DropShadow"]
	outline_px = float(shadows[0].descriptor[b"blur"]) * float(shadows[0].descriptor[b"Ckmt"]) / 100.0 + 0.4   # 13 * 74% ~ 10 px (measured 10)
	hc = shadows[1].descriptor[b"Clr "] if len(shadows) > 1 else {b"Rd  ": 10.8, b"Grn ": 7.1, b"Bl  ": 20.0}
	halo_col = (hc[b"Rd  "] / 255.0, hc[b"Grn "] / 255.0, hc[b"Bl  "] / 255.0)
	halo_a = float(shadows[1].descriptor[b"Opct"]) / 100.0 if len(shadows) > 1 else 0.39

	gx0, gy0 = group.bbox[0], group.bbox[1]
	ox, oy = gx0 - PAD, gy0 - PAD                     # texture origin in PSD px
	tw = int(np.ceil((group.bbox[2] - gx0 + PAD * 2) * SS))
	th = int(np.ceil((group.bbox[3] - gy0 + PAD * 2) * SS))
	s = SS * AA

	def raster(polys):
		im = Image.new("L", (tw * AA, th * AA), 0)
		d = ImageDraw.Draw(im)
		for poly in polys:
			d.polygon([((x - ox) * s, (y - oy) * s) for x, y in poly], fill=255)
		return np.asarray(im) > 127

	def down(m):
		h, w = m.shape
		return m.reshape(h // AA, AA, w // AA, AA).mean(axis=(1, 3))

	def rgba(alpha, c):
		img = np.zeros(alpha.shape + (4,), np.float32)
		img[..., :3] = c
		img[..., 3] = alpha
		return img

	def over(dst, src):
		sa = src[..., 3:4]
		da = dst[..., 3:4]
		oa = sa + da * (1 - sa)
		rgb = (src[..., :3] * sa + dst[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-6)
		return np.concatenate([rgb, oa], axis=-1)

	P = {lid: paths(L[lid], size) for lid in LAYERS if L[lid].kind == "shape"}
	m_frame = raster([p for lid in FRAME for p in P[lid]])
	m_outline = ndimage.distance_transform_edt(~m_frame) <= outline_px * s
	halo = ndimage.gaussian_filter(down(m_outline).astype(np.float32), HALO_SIGMA * SS) * halo_a
	img = rgba(halo, halo_col)
	img = over(img, rgba(down(m_outline), (0.0, 0.0, 0.0)))
	img = over(img, rgba(down(m_frame), fill_col(L[145])))
	img = over(img, rgba(down(raster(P[180])), fill_col(L[180])))
	os.makedirs(OUT_TEX, exist_ok=True)
	Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT_TEX, "stage_progress_frame.png"))

	# geometry in texture-local PSD px
	def loc(poly):
		return [(x - ox, y - oy) for x, y in poly]

	def bbox(poly):
		xs = [p[0] for p in poly]
		ys = [p[1] for p in poly]
		return (min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys))

	trough = loc(P[180][0])
	fill = loc(P[146][0])
	fx0 = min(p[0] for p in fill)
	fx1 = max(p[0] for p in fill)
	tx1 = max(p[0] for p in trough)
	# the fill path's right end (points right of the body) is shifted as a whole to the fill ratio
	tip_from = sorted(p[0] for p in fill)[-4]      # left-most of the 4 right-end points
	notches = sorted(min(p[0] for p in poly) - ox for poly in P[190])
	notch_w = P[190][0][1][0] - P[190][0][0][0]

	# fill colours: base from the shape, lime tip sampled from the composite where 레이어 19 is strongest
	base = fill_col(L[146])
	comp = np.asarray(group.composite().convert("RGB")).astype(np.float32) / 255.0
	gyc = int(round(sum(p[1] for p in P[146][0]) / len(P[146][0]) - gy0))
	gxe = int(round(max(p[0] for p in P[146][0]) - 24 - gx0))
	tip = tuple(float(v) for v in comp[gyc, gxe])
	# where the lime starts to show, as a fraction of the mockup fill length from its right end
	row = comp[gyc, int(fx0 + ox - gx0):gxe]
	diff = np.abs(row - np.array(base)).sum(axis=1)
	start = len(diff) - 1
	while start > 0 and diff[start - 1] > 0.03:       # walk left from the tip while the lime still shows
		start -= 1
	tip_len = float(len(diff) - start + 24)

	def text_info(layer):
		ss = layer.engine_dict["StyleRun"]["RunArray"][0]["StyleSheet"]["StyleSheetData"]
		fc = ss["FillColor"]["Values"]                  # ARGB
		t = layer.transform                             # (xx, xy, yx, yy, tx, ty)
		b = layer.bbox
		return {"rect": (b[0] - ox, b[1] - oy, b[2] - b[0], b[3] - b[1]), "col": (fc[1], fc[2], fc[3]),
				"size": float(ss["FontSize"]), "xx": t[0], "yx": t[2], "yy": t[3]}

	top = text_info(L[165])
	bot = text_info(L[161])
	tstroke = [e for e in L[165].effects if e.__class__.__name__ == "Stroke"][0]
	tsc = tstroke.descriptor[b"Clr "]
	top_stroke = (tsc[b"Rd  "] / 255.0, tsc[b"Grn "] / 255.0, tsc[b"Bl  "] / 255.0)
	glow = [e for e in L[146].effects if e.__class__.__name__ == "OuterGlow"][0].descriptor
	gc = glow[b"Clr "]

	src = "/".join(PSD.replace(ROOT + os.sep, "").split(os.sep))
	lines = [
		"## GENERATED by tools/battle_ui/extract_progress_bar.py from %s ('진행도 바' 그룹) — do not edit." % src,
		"## 스테이지 진행도 게이지 시안 수치. 좌표는 PSD 픽셀, 원점 = stage_progress_frame.png 왼쪽 위 (텍스처는 PSD 의 TEX_SCALE 배).",
		"## class_name 없음: 쓰는 쪽에서 preload.",
		"extends RefCounted",
		"",
		'const FRAME_TEX := "res://assets/textures/battle_ui/stage_progress_frame.png"',
		"const TEX_SCALE := %.2f" % SS,
		"const SIZE := %s            # 텍스처 전체 (PSD 픽셀)" % gd_vec((tw / SS, th / SS)),
		"const GROUP_RECT := %s     # 그룹 bbox (외곽선·그림자 제외)" % gd_rect((gx0 - ox, gy0 - oy, group.bbox[2] - gx0, group.bbox[3] - gy0)),
		"",
		"# 채움: 바닥 홈(TROUGH_POLY) 모양 그대로, 오른쪽 끝 점 4개(x >= FILL_TIP_FROM)를 통째로 채움 끝까지 옮겨 그린다.",
		"const FILL_X0 := %.1f" % fx0,
		"const FILL_X1 := %.1f             # 바가 꽉 찼을 때의 오른쪽 끝 (= 바닥 홈 끝)" % tx1,
		"const FILL_TIP_FROM := %.1f" % (tip_from - (fx1 - tx1)),
		"const FILL_COLOR := %s" % gd_col(base),
		"const FILL_TIP_COLOR := %s   # 끝쪽 연두 (레이어 19 그라데이션)" % gd_col(tip),
		"const FILL_TIP_LEN := %.1f          # 끝에서 이만큼 연두로 번진다" % tip_len,
		"const FILL_GLOW := %s" % gd_col((gc[b"Rd  "] / 255.0, gc[b"Grn "] / 255.0, gc[b"Bl  "] / 255.0), float(glow[b"Opct"]) / 100.0),
		"const GHOST_COLOR := %s   # 깎인 몫 (빨강)" % gd_col(fill_col(L[179])),
		"const TROUGH_COLOR := %s" % gd_col(fill_col(L[180])),
		"const FRAME_COLOR := %s" % gd_col(fill_col(L[145])),
		"",
		"# 채움 위 눈금 (overlay 로 채움을 어둡게)",
		"const NOTCH_X := [%s]" % ", ".join("%.1f" % x for x in notches),
		"const NOTCH_W := %.1f" % notch_w,
		"const NOTCH_COLOR := %s" % gd_col(fill_col(L[190])),
		"",
		"# 글자: 위 명판 숫자 · 아래 명판 퍼센트. rect = 시안 글자 bbox, xx/yx/yy = 글자 변환 (yx < 0 → 기울임)",
		"const TOP_PLATE := %s" % gd_rect(bbox(loc(P[167][0]))),
		"const BOTTOM_PLATE := %s" % gd_rect(bbox(loc(P[168][0]))),
		"const TOP_TEXT_RECT := %s" % gd_rect(top["rect"]),
		"const TOP_TEXT_COLOR := %s" % gd_col(top["col"]),
		"const TOP_TEXT_STROKE := %s" % gd_col(top_stroke),
		"const TOP_TEXT_STROKE_PX := %.1f" % float(tstroke.descriptor[b"Sz  "]),
		"const TOP_TEXT_XFORM := Vector3(%.4f, %.4f, %.4f)" % (top["xx"], top["yx"], top["yy"]),
		"const BOTTOM_TEXT_RECT := %s" % gd_rect(bot["rect"]),
		"const BOTTOM_TEXT_COLOR := %s" % gd_col(bot["col"]),
		"const BOTTOM_TEXT_XFORM := Vector3(%.4f, %.4f, %.4f)" % (bot["xx"], bot["yx"], bot["yy"]),
		"",
		"# 바닥 홈 (웨이브 구획선을 그을 세로 범위)",
		"const TROUGH_POLY := [%s]" % ", ".join(gd_vec(p) for p in trough),
		"",
	]
	with open(OUT_GD, "w", encoding="utf-8", newline="\n") as f:
		f.write("\n".join(lines).replace("\n\t", "\n\t"))
	print("frame tex %dx%d, outline %.1f px, tip %s over %.0f px" % (tw, th, outline_px, str(tuple(round(c, 3) for c in tip)), tip_len))
	print("wrote", OUT_GD)


if __name__ == "__main__":
	main()
