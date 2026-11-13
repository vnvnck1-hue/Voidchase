"""Extract the hand-drawn "lightning close" screen transition from the screen mockup PSD (group '화면 트랜지션').

  C:/Python314/python.exe tools/transition/extract_lightning_transition.py [path/to/화면 컨셉_4.psd]

Writes
  assets/textures/transition/lightning_zig_1.png / _2.png   the two blurry zig-zag bolts (pixel layers, half size)
  scripts/screen_transition_lightning_data.gd               generated key poses (do not edit)

The group holds four smart objects 트랜지션_1..4, each an edited copy of the same 4417x2061 PSB placed unscaled at
(-568, -266) in the 3440x1440 mockup. They are the drawn frames of the gif (assets/컨셉 원화/화면-컨셉_4_트랜지션.gif):
  gif f1 = 트랜지션_1   wedges cross the centre, panels a third of the way in, zig-zag bolt 1
  gif f2 = 트랜지션_2   panels almost shut on the diagonal, zig-zag bolt 2, darker (brightness/contrast)
  gif f3 = 트랜지션_3   shut: panels stretched over the whole screen, wedges gone, dark
  gif f4 = 트랜지션_4   the rewind frame: the same pieces further out than f1 (so it is the pose *before* f1)
Every frame has the same vector shapes (same knot counts), only moved / stretched, so the game keeps the shapes as
polygons and interpolates the vertices between the key poses  K0 = 트랜지션_4 → K1 = _1 → K2 = _2 → K3 = _3.
Colours are sampled from the composite of each frame (so the brightness/contrast layers of _2 / _3 are baked in).
Coordinates: mockup px relative to the mockup centre (1720, 720); the mockup is 3440x1440.
The OuterGlow of 그룹 293 (screen, 31 %, 122 px) is not extracted.
"""
import io
import os
import sys
import warnings

warnings.filterwarnings("ignore")

import numpy as np
from PIL import Image, ImageDraw
from psd_tools import PSDImage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PSD = os.path.join(ROOT, "assets", "컨셉 원화", "화면 컨셉_4.psd")
OUT_TEX = os.path.join(ROOT, "assets", "textures", "transition")
OUT_GD = os.path.join(ROOT, "scripts", "screen_transition_lightning_data.gd")

GROUP = "화면 트랜지션"
KEYS = ["트랜지션_4", "트랜지션_1", "트랜지션_2", "트랜지션_3"]      # K0..K3, in pose order (see above)
MOCK = (3440, 1440)
BEZ_STEPS = 6            # segments per curved knot (ellipses)
ZIG_SCALE = 0.5          # zig-zag bolts are blurred brush strokes: half size is plenty
SAMPLE = 4               # colour sampling works on a 1/4 size id map


def flatten(path, w, h):
	"""psd-tools knots are (y, x) normalised to the PSB canvas. Returns [(x, y)] px."""
	knots = list(path)
	pts = []
	n = len(knots)
	for i in range(n):
		a, b = knots[i], knots[(i + 1) % n]
		p0 = (a.anchor[1] * w, a.anchor[0] * h)
		p1 = (a.leaving[1] * w, a.leaving[0] * h)
		p2 = (b.preceding[1] * w, b.preceding[0] * h)
		p3 = (b.anchor[1] * w, b.anchor[0] * h)
		pts.append(p0)
		if a.leaving != a.anchor or b.preceding != b.anchor:
			for s in range(1, BEZ_STEPS):
				t = s / BEZ_STEPS
				u = 1.0 - t
				pts.append(tuple(u * u * u * p0[k] + 3 * u * u * t * p1[k] + 3 * u * t * t * p2[k] + t * t * t * p3[k] for k in (0, 1)))
	return pts


def read_frame(layer):
	"""-> dict: size, origin, shapes [(key, name, group, pts)] bottom→top, zig (image, bbox) or None, dim, comp"""
	so = layer.smart_object
	origin = (so.transform_box[0], so.transform_box[1])
	sub = PSDImage.open(io.BytesIO(so.data))
	w, h = sub.size
	shapes, zig, dim = [], None, None
	seen = {}

	def walk(g, gname):
		nonlocal zig, dim
		for l in g:                                   # bottom → top
			if l.is_group():
				walk(l, l.name)
			elif l.kind == "shape":
				base = "%s/%s" % (gname, l.name)
				seen[base] = seen.get(base, 0) + 1
				key = "%s#%d" % (base, seen[base])       # 타원 copies share names: number them in stack order
				paths = l.vector_mask.paths
				if len(paths) != 1:
					sys.exit("%s: %d sub-paths, expected 1" % (key, len(paths)))
				shapes.append((key, l.name, gname, flatten(paths[0], w, h)))
			elif l.kind == "pixel":
				if l.bbox == (-origin[0], -origin[1], -origin[0] + MOCK[0], -origin[1] + MOCK[1]) or (l.width == MOCK[0] and l.height == MOCK[1]):
					im = l.topil().convert("RGBA")
					dim = (im.getpixel((im.width // 2, im.height // 2))[:3], l.opacity / 255.0)
				else:
					zig = (l.topil().convert("RGBA"), l.bbox, l.opacity / 255.0)

	walk(sub, "")
	comp = sub.composite(force=True).convert("RGBA")
	return {"size": (w, h), "origin": origin, "shapes": shapes, "zig": zig, "dim": dim, "comp": comp}


def sample_colours(fr):
	"""Median composite colour of the visible part of every shape (None when fully hidden)."""
	w, h = fr["size"]
	sw, sh = w // SAMPLE, h // SAMPLE
	ids = Image.new("I", (sw, sh), 0)
	d = ImageDraw.Draw(ids)
	for i, (_key, _n, _g, pts) in enumerate(fr["shapes"]):
		d.polygon([(x / SAMPLE, y / SAMPLE) for x, y in pts], fill=i + 1)
	ids = np.asarray(ids)
	comp = np.asarray(fr["comp"].resize((sw, sh), Image.NEAREST))
	free = np.ones((sh, sw), bool)
	if fr["zig"]:
		zim, bbox, _op = fr["zig"]
		za = Image.new("L", (w, h), 0)
		za.paste(zim.getchannel("A"), (bbox[0], bbox[1]))
		free = np.asarray(za.resize((sw, sh), Image.BILINEAR)) == 0
	# erode the id map a little so anti-aliased edges are not sampled
	inner = ids.copy()
	for dy, dx in ((0, 2), (0, -2), (2, 0), (-2, 0)):
		inner[np.roll(ids, (dy, dx), (0, 1)) != ids] = 0
	out = {}
	for i, (key, _n, _g, _pts) in enumerate(fr["shapes"]):
		m = (inner == i + 1) & free & (comp[..., 3] == 255)
		out[key] = tuple(int(v) for v in np.median(comp[m][:, :3], axis=0)) if m.sum() >= 12 else None
	return out


def gd_pts(pts, origin):
	ox = origin[0] - MOCK[0] / 2.0
	oy = origin[1] - MOCK[1] / 2.0
	return "[%s]" % ", ".join("Vector2(%.1f, %.1f)" % (x + ox, y + oy) for x, y in pts)


def gd_col(c):
	return "Color(%.4f, %.4f, %.4f)" % (c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)


def main():
	psd = PSDImage.open(sys.argv[1] if len(sys.argv) > 1 else PSD)
	if psd.size != MOCK:
		sys.exit("mockup is %s, expected %s" % (psd.size, MOCK))
	group = [l for l in psd if l.is_group() and l.name == GROUP]
	if not group:
		sys.exit("group %r not found" % GROUP)
	frames = []
	for name in KEYS:
		ls = [l for l in group[0] if l.name == name]
		if not ls:
			sys.exit("smart object %r not found in %r — the PSD changed" % (name, GROUP))
		frames.append(read_frame(ls[0]))
		print("%s: %d shapes, zig %s, dim %s" % (name, len(frames[-1]["shapes"]), frames[-1]["zig"][1] if frames[-1]["zig"] else None, frames[-1]["dim"]))

	# piece list (stack order) from K1, the fullest frame
	order = [(key, name, grp) for key, name, grp, _p in frames[1]["shapes"]]
	cols = [sample_colours(f) for f in frames]
	# the ellipse flecks are tiny (few clean pixels, some sit under the bolt): they all share one fill, so give every
	# fleck the most common sampled fleck colour of its frame
	for c in cols:
		keys = [k for k in c if "/타원" in k]
		got = [c[k] for k in keys if c[k] is not None]
		if got:
			mode = max(set(got), key=got.count)
			for k in keys:
				c[k] = mode
	lines = [
		"## GENERATED by tools/transition/extract_lightning_transition.py from assets/컨셉 원화/화면 컨셉_4.psd (그룹 '화면 트랜지션') — do not edit.",
		"## 번개 닫힘 화면 전환의 키 포즈 K0..K3 (= 트랜지션_4 → _1 → _2 → _3). 좌표: 시안(3440x1440) px, 시안 중심 기준.",
		"## class_name 없음: 쓰는 쪽에서 preload.",
		"extends RefCounted",
		"",
		"const MOCK_SIZE := Vector2(%d, %d)" % MOCK,
		'const KEY_NAMES := ["%s"]' % '", "'.join(KEYS),
		"",
		"# 아래에서 위로 쌓이는 순서 (const 는 상수식이어야 해서 Vector2 배열 리터럴: 쓰는 쪽에서 PackedVector2Array 로 바꾼다). pts[k] 가 빈 배열이면 그 키 포즈에는 없는 조각(K3 의 번개 쐐기): 직전 포즈 모양으로 사라진다.",
		"# kind: 0 어두운 판(왼쪽 위 무리) · 1 어두운 판(오른쪽 아래 무리) · 2 번개 쐐기·줄기 · 3 타원 파편",
		"const PIECES := [",
	]
	for key, name, grp in order:
		kind = 3 if name.startswith("타원") else (2 if grp == "그룹 293" else (0 if grp.endswith("복사") else 1))
		pts_k, col_k = [], []
		for fi, f in enumerate(frames):
			hit = [s for s in f["shapes"] if s[0] == key]
			if hit and len(hit[0][3]) != len([s for s in frames[1]["shapes"] if s[0] == key][0][3]):
				sys.exit("%s: vertex count differs in %s" % (key, KEYS[fi]))
			pts_k.append(gd_pts(hit[0][3], f["origin"]) if hit else "[]")
			col_k.append(cols[fi].get(key) if hit else None)
		# hidden / missing in a frame: borrow the nearest frame that has a colour
		for i in range(len(col_k)):
			if col_k[i] is None:
				near = sorted((abs(j - i), j) for j in range(len(col_k)) if col_k[j] is not None)
				col_k[i] = col_k[near[0][1]] if near else (48, 14, 113)
		lines.append('\t{"name": "%s", "kind": %d,' % (key, kind))
		lines.append("\t\t\"pts\": [%s]," % ",\n\t\t\t".join(pts_k))
		lines.append("\t\t\"col\": [%s]}," % ", ".join(gd_col(c) for c in col_k))
		print("%-24s kind %d cols %s" % (key, kind, col_k))
	lines += ["]", ""]

	# dim plate under everything: flat colour, opacity per key (K2/K3 are also darkened by the adjustment layers:
	# sample what the composite shows through the plate alone is not possible when panels cover it, so the colour stays)
	lines.append("# 화면 전체 딤(레이어 62/63): [색, 불투명도] × 키 포즈")
	lines.append("const DIM := [%s]" % ", ".join("[%s, %.4f]" % (gd_col(f["dim"][0]), f["dim"][1]) for f in frames))
	# darkest colour of the shut frame: backing plate at 'covered'
	dark = min((c for c in (cols[3][k] for k, _n, _g in order if cols[3].get(k)) if c), key=lambda c: sum(c))
	lines.append("const COVER_COLOR := %s    # 닫힌 프레임(K3)에서 가장 어두운 판 색: 다 덮였을 때의 바탕" % gd_col(dark))
	lines.append("")

	os.makedirs(OUT_TEX, exist_ok=True)
	lines.append("# 지그재그 번개(픽셀 레이어): [키 포즈 번호, 텍스처, 시안 중심 기준 사각형(위치, 크기)]")
	lines.append("const ZIGS := [")
	n = 0
	for fi, f in enumerate(frames):
		if not f["zig"]:
			continue
		n += 1
		im, bbox, op = f["zig"]
		small = im.resize((round(im.width * ZIG_SCALE), round(im.height * ZIG_SCALE)), Image.LANCZOS)
		path = os.path.join(OUT_TEX, "lightning_zig_%d.png" % n)
		small.save(path)
		x = bbox[0] + f["origin"][0] - MOCK[0] / 2.0
		y = bbox[1] + f["origin"][1] - MOCK[1] / 2.0
		lines.append('\t[%d, "res://assets/textures/transition/lightning_zig_%d.png", Rect2(%.1f, %.1f, %d, %d), %.4f],' % (fi, n, x, y, im.width, im.height, op))
		print("zig %d (K%d) %dx%d -> %s" % (n, fi, small.width, small.height, path))
	lines += ["]", ""]
	with open(OUT_GD, "w", encoding="utf-8", newline="\n") as fo:
		fo.write("\n".join(lines))
	print("wrote", OUT_GD)


if __name__ == "__main__":
	main()
