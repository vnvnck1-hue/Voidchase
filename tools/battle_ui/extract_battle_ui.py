"""Extract the battle HUD pieces (bottom panels, item slots, top bar) from the screen mockup PSD.

  python tools/battle_ui/extract_battle_ui.py [path/to/화면 컨셉_2.psd]

Writes
  assets/textures/battle_ui/*.png                 panels, slot, item icons, top bar pieces
  scripts/void_defense/vd_battle_ui_layout.gd     generated constants (1920x1080 design coords)

What comes from where (layer ids, names are checked):
  bottom-right back panel  캐릭터창 group: 레이어 11/18 복사/18/25(clipped)/사각형 2 composited (the purple/black
                           blobs 레이어 15/24/15 복사 are replaced by the lava-lamp shader; their colours are read here)
  bottom shade             레이어 10 (linear burn band across the bottom)
  squad cards              레이어 5: four sheared character panels -> positions/scale for the char_panels art
  item slot                그룹 270 smart object: three chamfered sheared squares, redrawn from the vector path with
                           their stroke effects (psd-tools draws shape strokes wrongly)
  item icons               ui_icon_projectileheart / 그룹 264 / icon_artifact_death_currency_retention_rate smart objects
                           rendered from the embedded file at native resolution
  bottom-left panel        레이어 28 (dark hill), 타원 1 (floor shadow), 레이어 30 복사 2 (glow streak)
  top bar                  상단ui smart object: left jag + band (stretchable) and the stage plate without its text
"""
import io
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from psd_tools import PSDImage
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PSD = os.path.join(ROOT, "assets", "컨셉 원화", "화면 컨셉_2.psd")
OUT_TEX = os.path.join(ROOT, "assets", "textures", "battle_ui")
OUT_GD = os.path.join(ROOT, "scripts", "void_defense", "vd_battle_ui_layout.gd")
PANEL_DIR = os.path.join(ROOT, "assets", "textures", "char_panels")

G_CHAR = 10                     # 캐릭터창 group
PANEL_LAYERS = {26, 79, 78, 155, 25}  # 레이어 11, 18 복사, 18, 25 (clip), 사각형 2
L_SHADE = 24                    # 레이어 10
L_BLOB_PURPLE = (70, 71)        # 레이어 15, 15 복사
L_BLOB_DARK = 120               # 레이어 24
L_CARDS = 7                     # 레이어 5
L_STRIPS = [144, 152, 153, 154]  # 그룹 270 (+복사): one per card, left to right
L_STRIP_LEFT = 197
L_LEFT_PANEL = 188              # 레이어 28
L_LEFT_SHADOW = 190             # 타원 1
L_LEFT_GLOW = 223               # 레이어 30 복사 2
L_TOP = 292                     # 상단ui
ICON_LAYERS = {201: "item_heart", 200: "item_bloom", 202: "item_skull"}
# mockup's slot contents: (strip layer, slot index) -> icon layer
MOCK_ITEMS = {(152, 0): 201, (152, 1): 200, (153, 0): 202, (197, 0): 199, (197, 1): 198}
RIGHT_SHIFT_Y = -30.0           # the mockup cuts the first card's slots at the screen edge; lift the card row
SLOT_SS = 3                     # slot texture resolution vs the smart object (left strip is 1.54x)


def find(psd, lid, name=None):
	for l in psd.descendants():
		if l.layer_id == lid:
			if name is not None and l.name != name:
				sys.exit("layer %d is %r, expected %r — the PSD changed, update the ids" % (lid, l.name, name))
			return l
	sys.exit("layer %d not found" % lid)


def col(c):
	return (c[b"Rd  "] / 255.0, c[b"Grn "] / 255.0, c[b"Bl  "] / 255.0)


def inner(layer):
	return PSDImage.open(io.BytesIO(layer.smart_object.data))


def box(layer):
	t = layer.smart_object.transform_box
	return (t[0], t[1], t[4], t[5])


def trim(im):
	bb = im.getchannel("A").getbbox()
	return im.crop(bb), bb


def save(im, name):
	im.save(os.path.join(OUT_TEX, name + ".png"))


def render_poly_with_strokes(size, pts, fill, strokes, ss):
	"""Polygon + Photoshop-style strokes (OutF outside, InsF inside) via distance transforms."""
	w, h = size[0] * ss, size[1] * ss
	mask = Image.new("L", (w, h), 0)
	ImageDraw.Draw(mask).polygon([(x * ss, y * ss) for x, y in pts], fill=255)
	inside = np.array(mask) > 127
	d_out = ndimage.distance_transform_edt(~inside) / ss   # distance outside the shape
	d_in = ndimage.distance_transform_edt(inside) / ss     # distance inside
	rgb = np.zeros((h, w, 3))
	a = np.zeros((h, w))

	def over(m, c):
		nonlocal rgb, a
		rgb = rgb * (1 - m[..., None]) + np.array(c) * m[..., None]
		a = a * (1 - m) + m

	over(inside.astype(float), fill)
	for kind, sz, c, op in strokes:
		if kind == b"InsF":
			over(((d_in > 0) & (d_in <= sz)).astype(float) * op, c)
		else:
			over(((d_out > 0) & (d_out <= sz)).astype(float) * op, c)
	pre = np.concatenate([rgb * a[..., None], a[..., None]], axis=-1)
	return Image.fromarray((np.clip(pre, 0, 1) * 255).astype(np.uint8), "RGBA")   # premultiplied, ss x


def unpremultiply(im):
	arr = np.array(im).astype(np.float64) / 255.0
	al = arr[..., 3:4]
	arr[..., :3] = np.where(al > 1e-6, arr[..., :3] / np.maximum(al, 1e-6), 0)
	return Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def gd_vec(v):
	return "Vector2(%.1f, %.1f)" % (v[0], v[1])


def gd_rect(r):
	return "Rect2(%.1f, %.1f, %.1f, %.1f)" % tuple(r)


def gd_color(c, a=1.0):
	return "Color(%.4f, %.4f, %.4f, %.4f)" % (c[0], c[1], c[2], a)


def main():
	src = sys.argv[1] if len(sys.argv) > 1 else PSD
	psd = PSDImage.open(src)
	os.makedirs(OUT_TEX, exist_ok=True)
	L = []

	# ------------------------------------------------ bottom-right back panel
	group = find(psd, G_CHAR, "캐릭터창")
	ids = PANEL_LAYERS
	members = [l for l in group.descendants() if l.layer_id in ids]
	x0 = min(l.bbox[0] for l in members)
	y0 = min(l.bbox[1] for l in members)
	x1 = max(l.bbox[2] for l in members)
	panel = group.composite(viewport=(x0, y0, x1, 1080), layer_filter=lambda l: l.layer_id in ids or l.is_group(), force=True)
	panel, bb = trim(panel)
	save(panel, "panel_right")
	panel_rect = (x0 + bb[0], y0 + bb[1], panel.width, panel.height)
	shade = find(psd, L_SHADE, "레이어 10")
	shade_op = shade.opacity / 255.0
	shade.opacity = 255
	sh, _ = trim(shade.composite())
	save(sh, "bottom_shade")
	shade_rect = (shade.bbox[0], shade.bbox[1], sh.width, sh.height)

	def blob_color(lid):
		l = find(psd, lid)
		arr = np.array(l.composite().convert("RGBA")).reshape(-1, 4).astype(float)
		w = arr[:, 3:4]
		return tuple((arr[:, :3] * w).sum(axis=0) / max(w.sum(), 1e-6) / 255.0), l.opacity / 255.0

	purple, purple_op = blob_color(L_BLOB_PURPLE[0])
	dark, dark_op = blob_color(L_BLOB_DARK)

	# ------------------------------------------------ squad cards (레이어 5)
	cards_l = find(psd, L_CARDS, "레이어 5")
	ca = np.array(cards_l.composite().convert("RGBA"))[..., 3] > 20
	lab, n = ndimage.label(ca)
	objs = sorted(ndimage.find_objects(lab), key=lambda s: s[1].start)
	pa = np.array(Image.open(os.path.join(PANEL_DIR, "panel_01.png")))[..., 3] > 20
	ys, xs = np.nonzero(pa)
	p_bb = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
	card_rects = []
	for s in objs:
		bx, by = s[1].start + cards_l.bbox[0], s[0].start + cards_l.bbox[1]
		bw, bh = s[1].stop - s[1].start, s[0].stop - s[0].start
		scale = bw / float(p_bb[2] - p_bb[0])
		# rect of the whole 300x229 panel texture (its alpha bbox lands on the mockup card)
		card_rects.append((bx - p_bb[0] * scale, by - p_bb[1] * scale + RIGHT_SHIFT_Y, 300 * scale, 229 * scale))

	# ------------------------------------------------ item slot (그룹 270)
	strip_in = inner(find(psd, L_STRIPS[0], "그룹 270"))
	slot_shapes = [c for c in strip_in.descendants() if c.kind == "shape"]
	slot_shapes.sort(key=lambda c: c.bbox[0])
	sw, sh_ = strip_in.width, strip_in.height
	paths = [[(k.anchor[1] * sw, k.anchor[0] * sh_) for k in c.vector_mask.paths[0]] for c in slot_shapes]
	centers = [(sum(p[0] for p in ps) / len(ps), sum(p[1] for p in ps) / len(ps)) for ps in paths]
	ref = strip_in.composite()
	fill = tuple(v / 255.0 for v in ref.getpixel((int(centers[0][0]), int(centers[0][1])))[:3])
	strokes = []
	for e in slot_shapes[0].effects:
		v = e.descriptor
		if e.enabled and b"Styl" in v:
			strokes.append((v[b"Styl"].enum, float(v[b"Sz  "]), col(v[b"Clr "]), float(v[b"Opct"]) / 100.0))
	strokes.sort(key=lambda s: -s[1])
	pad = 8
	ps0 = paths[0]
	mx, my = min(p[0] for p in ps0), min(p[1] for p in ps0)
	local = [(x - mx + pad, y - my + pad) for x, y in ps0]
	size = (int(math.ceil(max(p[0] for p in local) + pad)), int(math.ceil(max(p[1] for p in local) + pad)))
	slot = render_poly_with_strokes(size, local, fill, [s for s in strokes if s[0] != b"InsF"] + [s for s in strokes if s[0] == b"InsF"], SLOT_SS * 2)
	slot = unpremultiply(slot.resize((size[0] * SLOT_SS, size[1] * SLOT_SS), Image.LANCZOS))
	save(slot, "item_slot")
	slot_center_in_tex = (centers[0][0] - mx + pad, centers[0][1] - my + pad)

	def strip_slots(lid):
		l = find(psd, lid)
		b = box(l)
		k = (b[2] - b[0]) / float(sw)
		return [(b[0] + c[0] * k, b[1] + c[1] * k) for c in centers], k

	right_slots = []
	for lid in L_STRIPS:
		ss, k = strip_slots(lid)
		right_slots.append([(x, y + RIGHT_SHIFT_Y) for x, y in ss])
	left_slots, left_k = strip_slots(L_STRIP_LEFT)

	# ------------------------------------------------ item icons
	icon_size = {}
	for lid, name in ICON_LAYERS.items():
		l = find(psd, lid)
		im, _ = trim(inner(l).composite())
		save(im, name)
		b = box(l)
		icon_size[name] = (b[2] - b[0], b[3] - b[1])   # on-screen size on a 1x strip (bounding box incl. margin)
	mock = {}
	for (strip, slot_i), lid in MOCK_ITEMS.items():
		key = ICON_LAYERS.get(lid) or {199: "item_heart", 198: "item_bloom"}[lid]
		mock[(strip, slot_i)] = key

	# ------------------------------------------------ bottom-left
	lp = find(psd, L_LEFT_PANEL, "레이어 28")
	lp_im, lbb = trim(lp.composite())
	save(lp_im, "panel_left")
	lp_rect = (lp.bbox[0] + lbb[0], lp.bbox[1] + lbb[1], lp_im.width, lp_im.height)
	shd = find(psd, L_LEFT_SHADOW, "타원 1")
	shd_fill = col(shd.tagged_blocks.get_data(b"vscg")[b"Clr "]) if b"vscg" in shd.tagged_blocks else (0.15, 0.1, 0.3)
	shd_rect = shd.bbox
	ell = Image.new("L", ((shd_rect[2] - shd_rect[0]) * 4, (shd_rect[3] - shd_rect[1]) * 4), 0)
	ImageDraw.Draw(ell).ellipse((0, 0, ell.width - 1, ell.height - 1), fill=255)
	ell = ell.resize((shd_rect[2] - shd_rect[0], shd_rect[3] - shd_rect[1]), Image.LANCZOS)
	ell_im = Image.new("RGBA", ell.size, tuple(int(v * 255) for v in shd_fill) + (0,))
	ell_im.putalpha(ell)
	save(ell_im, "left_shadow")
	glow = find(psd, L_LEFT_GLOW, "레이어 30 복사 2")
	gl_im, gbb = trim(glow.composite())
	save(gl_im, "left_glow")
	gl_rect = (glow.bbox[0] + gbb[0], glow.bbox[1] + gbb[1], gl_im.width, gl_im.height)

	# ------------------------------------------------ top bar (상단ui)
	top = find(psd, L_TOP, "상단ui")
	tb = box(top)
	tq = inner(top)
	k_top = (tb[2] - tb[0]) / float(tq.width)
	plate_ids = {c.layer_id for c in tq.descendants() if c.kind == "shape" and c.name == "다각형 1 복사 4"}
	text = next(c for c in tq.descendants() if c.kind == "type")
	full_no_text = tq.composite(layer_filter=lambda c: c.is_visible() and c.kind != "type", force=True)
	bar = tq.composite(layer_filter=lambda c: c.is_visible() and c.kind != "type" and c.layer_id not in plate_ids, force=True)
	adjust = {c.layer_id for c in tq.descendants() if c.kind in ("brightnesscontrast", "colorbalance", "levels", "curves", "huesaturation")}
	plate = tq.composite(layer_filter=lambda c: c.layer_id in plate_ids or c.layer_id in adjust or c.is_group(), force=True)
	plate, pbb = trim(plate)
	save(bar, "top_bar")
	save(plate, "top_plate")
	full_no_text.save(os.path.join(OUT_TEX, "_top_ref.png"))
	sd = text.engine_dict["StyleRun"]["RunArray"][0]["StyleSheet"]["StyleSheetData"]
	t = text.transform
	tsize = float(sd["FontSize"]) * math.hypot(t[0], t[1]) * k_top
	tfill = sd["FillColor"]["Values"]
	# stretchable part: right of every bar layer except the long band itself (the left jag and the spike end there)
	band = max((c for c in tq.descendants() if c.kind == "shape" and c.layer_id not in plate_ids), key=lambda c: c.bbox[2] - c.bbox[0])
	jag_right = max(c.bbox[2] for c in tq.descendants() if not c.is_group() and c.kind != "type" and c.layer_id not in plate_ids
		and c.layer_id != band.layer_id and c.bbox[2] > c.bbox[0]) + 16

	# ------------------------------------------------ write layout
	L.append("## GENERATED by tools/battle_ui/extract_battle_ui.py from assets/컨셉 원화/화면 컨셉_2.psd — do not edit.")
	L.append("## 전투 HUD 시안 수치 (1920x1080 디자인 좌표). class_name 없음: 쓰는 쪽에서 preload.")
	L.append("extends RefCounted")
	L.append("")
	L.append("const DIR := \"res://assets/textures/battle_ui/\"")
	L.append("")
	L.append("# 우측 하단 뒷패널 (+ 아래 그림자 띠). 라바램프 방울 색은 시안의 방울 레이어에서 뽑았다.")
	L.append("const PANEL_RIGHT_RECT := %s" % gd_rect(panel_rect))
	L.append("const SHADE_RECT := %s" % gd_rect(shade_rect))
	L.append("const SHADE_OPACITY := %.4f      # 시안은 선형 번(linear burn)" % shade_op)
	L.append("const LAVA_COLOR := %s" % gd_color(purple, purple_op))
	L.append("const LAVA_DARK := %s" % gd_color(dark, dark_op))
	L.append("const RIGHT_SHIFT_Y := %.1f      # 시안은 첫 카드 슬롯이 화면 밖으로 잘려 카드 줄 전체를 올렸다" % RIGHT_SHIFT_Y)
	L.append("")
	L.append("# 분대 카드: char_panels 의 300x229 패널 텍스처를 놓을 사각형 (왼쪽부터 HERO_ORDER 순)")
	L.append("const CARD_RECTS := [%s]" % ", ".join(gd_rect(r) for r in card_rects))
	L.append("")
	L.append("# 아이템 슬롯: item_slot.png 는 시안 1배의 %d배 해상도. 슬롯 중심이 텍스처의 SLOT_PIVOT(1배 기준)" % SLOT_SS)
	L.append("const SLOT_TEX_SCALE := %d" % SLOT_SS)
	L.append("const SLOT_PIVOT := %s" % gd_vec(slot_center_in_tex))
	L.append("const CARD_SLOTS := [")
	for ss in right_slots:
		L.append("\t[%s]," % ", ".join(gd_vec(c) for c in ss))
	L.append("]")
	L.append("const LEFT_SLOTS := [%s]" % ", ".join(gd_vec(c) for c in left_slots))
	L.append("const LEFT_SLOT_SCALE := %.3f" % left_k)
	L.append("const ITEM_ICON_SIZE := {%s}   # 1배 슬롯 위 아이콘 크기" % ", ".join("\"%s\": %s" % (k, gd_vec(v)) for k, v in icon_size.items()))
	L.append("## 시안에 그려진 예시 아이템: 카드 i(0~3) 또는 \"left\" 의 슬롯 j")
	L.append("const MOCK_ITEMS := {")
	strip_key = {152: 1, 153: 2, 154: 3, 144: 0, 197: "\"left\""}
	for (strip, si), name in mock.items():
		L.append("\t[%s, %d]: \"%s\"," % (strip_key[strip], si, name))
	L.append("}")
	L.append("")
	L.append("# 좌측 하단: 어두운 언덕 패널(라바램프), 바닥 그림자 타원, 빛줄기(선형 닷지)")
	L.append("const PANEL_LEFT_RECT := %s" % gd_rect(lp_rect))
	L.append("const LEFT_SHADOW_RECT := %s" % gd_rect((shd_rect[0], shd_rect[1], shd_rect[2] - shd_rect[0], shd_rect[3] - shd_rect[1])))
	L.append("const LEFT_GLOW_RECT := %s" % gd_rect(gl_rect))
	L.append("")
	L.append("# 상단 바: top_bar.png 를 TOP_RECT 에 (가로로 늘릴 땐 x %d 이후 띠만 늘인다), 스테이지 명판은 오른쪽에 붙인다" % round(jag_right * k_top))
	L.append("const TOP_RECT := %s" % gd_rect((tb[0], tb[1], tb[2] - tb[0], tb[3] - tb[1])))
	L.append("const TOP_STRETCH_FROM := %d     # top_bar.png 픽셀 x (이 오른쪽은 단순한 띠)" % jag_right)
	L.append("const TOP_PLATE_RECT := %s" % gd_rect((tb[0] + pbb[0] * k_top, tb[1] + pbb[1] * k_top, plate.width * k_top, plate.height * k_top)))
	L.append("const STAGE_TEXT_POS := %s      # 글자 기준선 왼쪽 (시안 'W1-S1')" % gd_vec((tb[0] + t[4] * k_top, tb[1] + t[5] * k_top)))
	L.append("const STAGE_TEXT_SIZE := %d" % round(tsize))
	L.append("const STAGE_TEXT_COLOR := %s" % gd_color((float(tfill[1]), float(tfill[2]), float(tfill[3]))))
	L.append("const STAGE_FONT := \"res://assets/fonts/Sarina-Regular.ttf\"   # 시안 글꼴. 없으면 굵은 기울임 대체")
	open(OUT_GD, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
	print("panel", panel_rect, "cards", len(card_rects), "slot tex", slot.size, "jag_right", jag_right)
	print("wrote", OUT_GD)


if __name__ == "__main__":
	main()
