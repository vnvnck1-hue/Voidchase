"""Extract the relic-slot (유물 성좌판) UI from the screen mockup PSD.

  python tools/relic_ui/extract_relic_ui.py [path/to/화면 컨셉_2.psd]

Writes
  assets/textures/relic_ui/*.png                 hex cell states, relic icons, stars
  scripts/void_defense/relics/vd_relic_layout.gd  generated constants (cell centres, opacities, colours, tooltip style)

Hex cells are shape layers whose stroke effects psd-tools renders wrongly, so they are redrawn here from the
PSD's own vector path, fill colour, stroke size/colour/opacity (signed-distance hexagon, 4x supersampled).
Icons and stars are smart objects / pixel layers and are cut out as they are.
Layers are looked up by layer id and the name is checked, so a re-saved PSD with renamed layers fails loudly.
"""
import math
import os
import sys

import numpy as np
from PIL import Image
from psd_tools import PSDImage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PSD = os.path.join(ROOT, "assets", "컨셉 원화", "화면 컨셉_2.psd")
OUT_TEX = os.path.join(ROOT, "assets", "textures", "relic_ui")
OUT_GD = os.path.join(ROOT, "scripts", "void_defense", "relics", "vd_relic_layout.gd")

# Board cells in VDRelicData.BOARD_CELLS order: (q, r) odd-q, q=0 is the right (higher) column of the mockup,
# q=1 the left one that sits half a cell lower. Value = hex shape layer id at that spot.
CELL_LAYERS = [
	((0, 0), 38), ((1, 0), 39),
	((0, 1), 41), ((1, 1), 42),
	((0, 2), 58), ((1, 2), 59),
	((0, 3), 60), ((1, 3), 61),
	((0, 4), 62), ((1, 4), 63),
]
L_BASE = 41          # plain slot: dark fill, faint outer stroke, opacity 196
L_LOCKED = 60        # locked slot: same look at opacity 84
L_NEXT = 61          # next slot to unlock: opacity 168
L_FIRE = 38          # slot that just fired: extra 12 px cyan outer stroke
L_GAUGE_RING = 39    # charging relic: purple outer stroke
L_GAUGE_FILL = 116   # purple fill masked from the bottom = charge gauge
L_BURST = 58         # cyan filled slot with white stroke = burst flash
L_BADGE = 117        # "+2" on a purple slot
L_BADGE_BURST = 119  # "+2" on the cyan slot
L_BACKDROP = 35      # dark smoky panel behind the board, opacity 179
L_TIP_BOX = 87      # tooltip box (사각형 3 in 정보창 복사)
L_TIP_TITLE = 90
L_TIP_BODY = 88

# Relic icons: layer id -> file name. RELIC_ICON maps the game's relics to them (the mockup has no names for them;
# only thunder (lightning) and essence (skull = death currency) match their meaning, the rest are placeholders).
ICONS = {
	77: "icon_lightning",
	76: "icon_planet",
	93: "icon_skull",
	92: "icon_money_swirl",
	94: "icon_magnet",
	95: "icon_hand_apple",
}
RELIC_ICON = {
	"thunder_shard": "icon_lightning",
	"essence_vial": "icon_skull",
	"star_feather": "icon_planet",
	"frost_crystal": "icon_money_swirl",
	"ember": "icon_hand_apple",
}
STARS = {171: "star", 172: "star_small"}
STAR_LAYERS = [171, 172]       # sparkles that sit on the board (173 belongs to the battlefield hit FX)

PIN_RECT = (1560, 0, 360, 940)  # HUD control rect in 1920x1080, anchored top-right
SS = 4                          # supersampling for redrawn hexes
PAD = 16                        # texture margin around the hex for outer strokes


def find(psd, lid, name):
	for l in psd.descendants():
		if l.layer_id == lid:
			if l.name != name:
				sys.exit("layer %d is %r, expected %r — the PSD changed, update the ids" % (lid, l.name, name))
			return l
	sys.exit("layer %d (%s) not found" % (lid, name))


def col(d, key=b"Clr "):
	c = d[key]
	return (c[b"Rd  "] / 255.0, c[b"Grn "] / 255.0, c[b"Bl  "] / 255.0)


def hex_of(layer):
	"""Centre and circumradius from the shape's vector path (flat-top regular hexagon)."""
	pts = [(k.anchor[1] * PSD_W, k.anchor[0] * PSD_H) for k in layer.vector_mask.paths[0]]
	xs = [p[0] for p in pts]
	ys = [p[1] for p in pts]
	cx, cy = (min(xs) + max(xs)) / 2.0, (min(ys) + max(ys)) / 2.0
	return (cx, cy), (max(xs) - min(xs)) / 2.0


def fill_of(layer):
	return col(layer.tagged_blocks.get_data(b"vscg"))


def strokes_of(layer):
	"""[(size, rgb, opacity)] outer strokes, inner first."""
	out = []
	for e in layer.effects:
		v = e.value
		if e.enabled and b"Styl" in v and v[b"Styl"].enum == b"OutF":
			out.append((float(v[b"Sz  "]), col(v), float(v[b"Opct"]) / 100.0))
	return sorted(out, key=lambda s: s[0])


def hex_sdf(size, r):
	"""Signed distance (px) to a flat-top regular hexagon of circumradius r centred in a size x size*? canvas."""
	w, h = size
	ys, xs = np.mgrid[0:h * SS, 0:w * SS].astype(np.float64)
	x = (xs + 0.5) / SS - w / 2.0
	y = (ys + 0.5) / SS - h / 2.0
	# iq 의 sdHexagon 은 그대로 flat-top (평평한 변이 y = ±내접반지름, 꼭짓점이 x 축 위). 축을 바꾸면 pointy-top 이 된다
	px, py = np.abs(x), np.abs(y)
	k = (-0.866025404, 0.5, 0.577350269)
	ri = r * 0.866025404  # inradius
	d = np.minimum(k[0] * px + k[1] * py, 0.0)
	px = px - 2.0 * d * k[0]
	py = py - 2.0 * d * k[1]
	cx = np.clip(px, -k[2] * ri, k[2] * ri)
	dist = np.hypot(px - cx, py - ri) * np.sign(py - ri)
	return dist


def render_hex(r, fill, strokes, fill_alpha=1.0):
	"""RGBA texture: optional fill + concentric outer strokes (Photoshop OutF, rounded outside corners)."""
	w = int(math.ceil(2 * r + 2 * PAD))
	h = int(math.ceil(2 * r * 0.866025404 + 2 * PAD))
	d = hex_sdf((w, h), r)
	rgb = np.zeros(d.shape + (3,))
	a = np.zeros(d.shape)
	# outermost stroke first so inner ones paint over it
	for size, c, op in sorted(strokes, key=lambda s: -s[0]):
		m = ((d > 0.0) & (d <= size)).astype(np.float64) * op
		rgb = rgb * (1 - m[..., None]) + np.array(c) * m[..., None]
		a = a * (1 - m) + m
	if fill is not None:
		m = (d <= 0.0).astype(np.float64) * fill_alpha
		rgb = rgb * (1 - m[..., None]) + np.array(fill) * m[..., None]
		a = a * (1 - m) + m
	# premultiplied box downsample, then unpremultiply
	pre = np.concatenate([rgb * a[..., None], a[..., None]], axis=-1)
	pre = pre.reshape(h, SS, w, SS, 4).mean(axis=(1, 3))
	alpha = pre[..., 3:4]
	out = np.where(alpha > 1e-6, pre[..., :3] / np.maximum(alpha, 1e-6), 0.0)
	img = np.concatenate([out, alpha], axis=-1)
	return Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def cut(layer):
	layer.opacity = 255
	im = layer.composite()
	bb = im.getchannel("A").getbbox()
	return im.crop(bb), (layer.bbox[0] + bb[0], layer.bbox[1] + bb[1])


def text_style(layer):
	fs = layer.resource_dict["FontSet"]
	sd = layer.engine_dict["StyleRun"]["RunArray"][0]["StyleSheet"]["StyleSheetData"]
	t = layer.transform
	scale = math.hypot(t[0], t[1])
	fill = sd["FillColor"]["Values"]
	return {
		"font": str(fs[sd.get("Font", 0)]["Name"]),
		"size": float(sd["FontSize"]) * scale,
		"color": (float(fill[1]), float(fill[2]), float(fill[3])),
		"rot": math.degrees(math.atan2(t[1], t[0])),
		"strokes": strokes_of(layer),
	}


def gd_color(c, a=1.0):
	return "Color(%.4f, %.4f, %.4f, %.4f)" % (c[0], c[1], c[2], a)


def gd_vec(v):
	return "Vector2(%.1f, %.1f)" % (v[0], v[1])


def main():
	global PSD_W, PSD_H
	src = sys.argv[1] if len(sys.argv) > 1 else PSD
	psd = PSDImage.open(src)
	PSD_W, PSD_H = psd.width, psd.height
	os.makedirs(OUT_TEX, exist_ok=True)

	cells = []
	radius = None
	for qr, lid in CELL_LAYERS:
		layer = next(l for l in psd.descendants() if l.layer_id == lid)
		c, r = hex_of(layer)
		radius = r if radius is None else radius
		cells.append((qr, c, layer.opacity / 255.0))
	n = lambda lid, name: find(psd, lid, name)

	# 벌집 격자로 맞추기: 시안의 칸들은 손으로 놓아 행 간격이 116.6~119.4 로 조금씩 어긋난다. 간격 S 는
	# "이웃 칸의 바깥 획(6px)끼리 딱 맞닿는" 값 R + 획/cos30 (시안 평균 간격과 0.1px 차이)으로 고정하고,
	# 원점만 최소제곱으로 맞춘다. 중심(q, r) = O + (-1.5 S q, √3 S (r + q/2)) — q=0 이 오른쪽(위) 열.
	stroke_w = strokes_of(n(L_BASE, "다각형 1 복사 2"))[0][0]
	S = radius + stroke_w / math.cos(math.radians(30))
	A = np.array([[1.0, 0.0, -1.5 * q] for (q, r), _, _ in cells] + [[0.0, 1.0, math.sqrt(3) * (r + 0.5 * q)] for (q, r), _, _ in cells])
	bvec = np.array([c[0] for _, c, _ in cells] + [c[1] for _, c, _ in cells])
	fit = np.linalg.lstsq(A, bvec, rcond=None)[0]
	O = (np.mean([c[0] + 1.5 * S * q for (q, r), c, _ in cells]), np.mean([c[1] - math.sqrt(3) * S * (r + 0.5 * q) for (q, r), c, _ in cells]))
	print("honeycomb: free-fit spacing %.2f, used %.2f (stroke-touching); origin %.1f, %.1f" % (fit[2], S, O[0], O[1]))
	snapped = []
	for (q, r), c, op in cells:
		g = (O[0] - 1.5 * S * q, O[1] + math.sqrt(3) * S * (r + 0.5 * q))
		print("  cell (%d,%d) psd %.1f,%.1f -> %.1f,%.1f" % (q, r, c[0], c[1], g[0], g[1]))
		snapped.append(((q, r), g, op))
	cells = snapped

	base = n(L_BASE, "다각형 1 복사 2")
	fire = n(L_FIRE, "다각형 1")
	gring = n(L_GAUGE_RING, "다각형 1 복사")
	gfill = n(L_GAUGE_FILL, "다각형 1 복사 6")
	burst = n(L_BURST, "다각형 1 복사 3")
	base_strokes = strokes_of(base)
	fire_strokes = strokes_of(fire)
	ring_only = [s for s in fire_strokes if s not in base_strokes]

	textures = {
		"hex_base": render_hex(radius, fill_of(base), base_strokes),
		"hex_ring_fire": render_hex(radius, None, ring_only),
		"hex_ring_gauge": render_hex(radius, None, strokes_of(gring)),
		"hex_fill_gauge": render_hex(radius, fill_of(gfill), strokes_of(gfill)),
		"hex_burst": render_hex(radius, fill_of(burst), strokes_of(burst)),
		"hex_mask": render_hex(radius, (1.0, 1.0, 1.0), []),
		# 기본 칸의 바깥 획만 불투명하게: 게임 배경이 시안보다 어두워 벌집 윤곽을 드러낼 때 쓴다
		"hex_edge": render_hex(radius, None, [(sz, c, 1.0) for sz, c, _ in base_strokes]),
	}
	for name, im in textures.items():
		im.save(os.path.join(OUT_TEX, name + ".png"))
	hex_size = textures["hex_base"].size

	# 검사: 그린 육각형이 PSD 벡터 경로와 같은 모양인가 (평평한 윗변 폭 = R, 가로 = 2R, 세로 = √3 R)
	m = np.array(textures["hex_mask"])[..., 3] > 127
	ys_, xs_ = np.nonzero(m)
	top_w = np.count_nonzero(m[ys_.min()])
	got = (xs_.max() - xs_.min() + 1, ys_.max() - ys_.min() + 1, top_w)
	want = (2 * radius, math.sqrt(3) * radius, radius)
	if any(abs(g - w) > 3 for g, w in zip(got, want)):
		sys.exit("hex texture shape %s != PSD flat-top hexagon %s (w, h, top edge)" % (got, tuple(round(v, 1) for v in want)))

	# gauge fill: the mask hides everything above its top edge -> how full the mockup's gauge is
	gauge_ratio = 0.0
	if gfill.mask is not None:
		gc, _ = hex_of(gfill)
		top, bot = gc[1] - radius * 0.866, gc[1] + radius * 0.866
		gauge_ratio = (bot - gfill.mask.bbox[3]) / (bot - top)

	icon_info = {}
	for lid, name in ICONS.items():
		layer = next(l for l in psd.descendants() if l.layer_id == lid)
		im, pos = cut(layer)
		im.save(os.path.join(OUT_TEX, name + ".png"))
		icon_info[name] = (im.size, (pos[0] + im.width / 2.0, pos[1] + im.height / 2.0))
	# 보드 뒤 어두운 구름 패널 (사각형 4): 흐린 잠긴 칸이 보이는 건 이 배경 덕분
	backdrop = n(L_BACKDROP, "사각형 4")
	bd_alpha = backdrop.opacity / 255.0
	bd_im, bd_pos = cut(backdrop)
	bd_im.save(os.path.join(OUT_TEX, "board_backdrop.png"))
	star_info = []
	for lid in STAR_LAYERS:
		layer = next(l for l in psd.descendants() if l.layer_id == lid)
		im, pos = cut(layer)
		im.save(os.path.join(OUT_TEX, STARS[lid] + ".png"))
		star_info.append((STARS[lid], (pos[0] + im.width / 2.0, pos[1] + im.height / 2.0)))

	badge = text_style(n(L_BADGE, "+2"))
	badge_burst = text_style(n(L_BADGE_BURST, "+2 복사"))
	bl = n(L_BADGE, "+2")
	badge_center = ((bl.bbox[0] + bl.bbox[2]) / 2.0, (bl.bbox[1] + bl.bbox[3]) / 2.0)
	badge_cell = cells[1][1]  # the "+2" sits on the purple (1, 0) slot

	box = n(L_TIP_BOX, "사각형 3")
	box_shadow = next(e for e in box.effects if e.__class__.__name__ == "DropShadow").value
	sh_ang = math.radians(float(box_shadow[b"lagl"]))
	sh_dist = float(box_shadow[b"Dstn"])
	title = text_style(n(L_TIP_TITLE, "기기 페어링"))
	body = text_style(next(l for l in psd.descendants() if l.layer_id == L_TIP_BODY))
	tail, outline = box.vector_mask.paths[0], box.vector_mask.paths[1]
	tail_pts = [(k.anchor[1] * PSD_W, k.anchor[0] * PSD_H) for k in tail]
	tip = min(tail_pts, key=lambda p: p[1])
	box_pts = [(k.anchor[1] * PSD_W, k.anchor[0] * PSD_H) for k in outline]
	box_w = math.hypot(box_pts[0][0] - box_pts[1][0], box_pts[0][1] - box_pts[1][1]) + 12.0
	box_left = min(p[0] for p in box_pts)
	tail_frac = (tip[0] - box_left) / box_w

	ox, oy = PIN_RECT[0], PIN_RECT[1]
	L = []
	L.append("## GENERATED by tools/relic_ui/extract_relic_ui.py from assets/컨셉 원화/화면 컨셉_2.psd — do not edit.")
	L.append("## 유물 성좌판 시안 수치. 좌표는 HUD 로컬(1920x1080 기준 PIN_RECT 의 왼쪽 위가 0,0).")
	L.append("## class_name 없음: 헤드리스 실행이 전역 클래스 캐시를 갱신하지 않으므로 쓰는 쪽에서 preload 한다.")
	L.append("extends RefCounted")
	L.append("")
	L.append("const DIR := \"res://assets/textures/relic_ui/\"")
	L.append("const PIN_RECT := Rect2(%d, %d, %d, %d)" % PIN_RECT)
	L.append("const HEX_R := %.2f                 # flat-top 외접 반지름 (PSD 벡터 경로)" % radius)
	L.append("const HEX_TEX_SIZE := Vector2(%d, %d)   # hex_*.png 크기, 칸 중심 = 텍스처 중심" % hex_size)
	L.append("## VDRelicData.BOARD_CELLS 순서의 칸 중심")
	L.append("const CELL_CENTERS := {")
	for qr, c, _ in cells:
		L.append("\tVector2i(%d, %d): %s," % (qr[0], qr[1], gd_vec((c[0] - ox, c[1] - oy))))
	L.append("}")
	L.append("const OPACITY_OPEN := %.4f       # 칸·테두리 레이어 투명도 (발동 테두리·게이지 테두리도 같은 값)" % (base.opacity / 255.0))
	L.append("const OPACITY_NEXT := %.4f       # 다음에 열릴 칸" % (n(L_NEXT, "다각형 1 복사 4").opacity / 255.0))
	L.append("const OPACITY_LOCKED := %.4f" % (n(L_LOCKED, "다각형 1 복사 4").opacity / 255.0))
	L.append("const OPACITY_GAUGE_FILL := %.4f  # 충전 게이지 보라 채움 (시안 %.0f%% 충전 상태)" % (gfill.opacity / 255.0, gauge_ratio * 100))
	L.append("const BACKDROP_RECT := Rect2(%d, %d, %d, %d)   # board_backdrop.png" % (bd_pos[0] - ox, bd_pos[1] - oy, bd_im.width, bd_im.height))
	L.append("const OPACITY_BACKDROP := %.4f" % bd_alpha)
	L.append("const RELIC_ICON := {")
	for rid, name in RELIC_ICON.items():
		L.append("\t\"%s\": \"%s\"," % (rid, name))
	L.append("}")
	L.append("const ICON_SIZE := {")
	for name, (sz, _) in icon_info.items():
		L.append("\t\"%s\": Vector2(%d, %d)," % (name, sz[0], sz[1]))
	L.append("}")
	L.append("const STARS := [")
	for name, p in star_info:
		L.append("\t{\"tex\": \"%s\", \"pos\": %s}," % (name, gd_vec((p[0] - ox, p[1] - oy))))
	L.append("]")
	L.append("## \"+N\" 배지: 칸 중심 기준 위치, ARCO, 흰 글자 + 바깥 획")
	L.append("const BADGE_OFFSET := %s" % gd_vec((badge_center[0] - badge_cell[0], badge_center[1] - badge_cell[1])))
	L.append("const BADGE_FONT_SIZE := %d" % round(badge["size"]))
	L.append("const BADGE_OUTLINE := %d          # Godot outline_size (= PS 바깥 획 x2)" % round(badge["strokes"][0][0] * 2))
	L.append("const BADGE_OUTLINE_COLOR := %s" % gd_color(badge["strokes"][0][1]))
	L.append("const BADGE_OUTLINE_COLOR_BURST := %s" % gd_color(badge_burst["strokes"][0][1]))
	L.append("## 툴팁 (정보창): 보라 박스 + 진한 테두리 + 그림자, 살짝 기울어짐, 위로 향한 말꼬리")
	L.append("const TIP_FILL := %s" % gd_color(fill_of(box)))
	ts = strokes_of(box)[0]
	L.append("const TIP_BORDER := %d" % round(ts[0]))
	L.append("const TIP_BORDER_COLOR := %s" % gd_color(ts[1], ts[2]))
	L.append("const TIP_SHADOW_COLOR := %s" % gd_color(col(box_shadow), float(box_shadow[b"Opct"]) / 100.0))
	L.append("const TIP_SHADOW_OFFSET := %s" % gd_vec((-math.cos(sh_ang) * sh_dist, math.sin(sh_ang) * sh_dist)))
	L.append("const TIP_ROT_DEG := %.2f" % title["rot"])
	L.append("const TIP_TAIL := [%s]   # 말꼬리 꼭짓점, 끝점 기준" % ", ".join(gd_vec((p[0] - tip[0], p[1] - tip[1])) for p in tail_pts))
	L.append("const TIP_TAIL_FRAC := %.3f        # 박스 폭 대비 말꼬리 x 위치" % tail_frac)
	L.append("const TIP_TITLE_COLOR := %s" % gd_color(title["color"]))
	L.append("const TIP_TITLE_SIZE := %d          # 시안 글꼴 %s (미설치 → 굵은 고딕)" % (round(title["size"]), title["font"]))
	L.append("const TIP_BODY_COLOR := %s" % gd_color(body["color"]))
	L.append("const TIP_BODY_SIZE := %d           # 시안 %.1fpx %s — 설명이 길어 한 단계 키움" % (round(body["size"]) + 1, body["size"], body["font"]))
	bs = body["strokes"][0]
	L.append("const TIP_BODY_OUTLINE_COLOR := %s" % gd_color(bs[1], bs[2]))
	open(OUT_GD, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")

	print("cells", len(cells), "R=%.2f" % radius, "hex tex", hex_size, "gauge %.0f%%" % (gauge_ratio * 100))
	print("icons", sorted(icon_info), "stars", [s[0] for s in star_info])
	print("wrote", OUT_GD)


if __name__ == "__main__":
	main()
