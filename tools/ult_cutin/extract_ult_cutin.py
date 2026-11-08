"""Extract the super-ultimate cut-in pieces from the screen mockup PSD (smart object '궁극기 연출').

  python tools/ult_cutin/extract_ult_cutin.py [path/to/화면 컨셉_2.psd]

Writes
  assets/textures/ult_cutin/*.png                  bands, window mask, nebula, motes, portrait, sparkles, slash
  scripts/void_defense/vd_ult_cutin_layout.gd      generated constants (1920x1080 design coords, centre = (960, 540))

The smart object is a 2233x1299 PSB placed at (-128, -48) in the 1920x1080 mockup, unscaled.
What comes from where (PSB layer ids, names are checked):
  dim            레이어 31  flat black (opacity -> DIM_ALPHA, no texture)
  sparkle field  레이어 35  (lighten -> additive)
  sparkles       레이어 44 / 레이어 44 복사 2
  bands          외곽 라인들: 모양 3 복사 (black jagged band), 사각형 6 복사 (purple frame), 모양 4/5/2/3 (slivers)
  window         사각형 6 — the clip base; the alpha of its composite is the window shape
  window content 레이어 32 (nebula streak), 레이어 33 (dust motes), 그룹 30 (character, embedded png, full res)
  slash          레이어 34  (screen -> additive)
  (컬러감 강조 is a divide-mode grey copy of the whole cut-in; not used)

The PSD only has the mage. The other heroes use their standing art (assets/textures/standing) placed so that
their head is as tall as the mage's and their anchor (eye, or the middle of both eyes) sits where the mage's eye is.
Measured by hand on the source images (px): HEROES below. Eye = where the glint pops.
"""
import io
import os
import sys

from PIL import Image
from psd_tools import PSDImage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PSD = os.path.join(ROOT, "assets", "컨셉 원화", "화면 컨셉_2.psd")
OUT_TEX = os.path.join(ROOT, "assets", "textures", "ult_cutin")
OUT_GD = os.path.join(ROOT, "scripts", "void_defense", "vd_ult_cutin_layout.gd")

L_SMART = (344, "궁극기 연출")
# PSB layer id, expected name, output texture, source ("pixel" raw pixels / "comp" composite / "alpha" white mask)
PIECES = [
	(346, "레이어 35", "sparkle_field", "pixel"),
	(347, "레이어 44", "sparkle_a", "pixel"),
	(348, "레이어 44 복사 2", "sparkle_b", "pixel"),
	(350, "모양 3 복사", "band_black", "comp"),
	(351, "사각형 6 복사", "band_frame", "comp"),
	(352, "모양 4", "sliver_1", "comp"),
	(353, "모양 5", "sliver_2", "comp"),
	(354, "모양 2", "sliver_3", "comp"),
	(355, "모양 3", "sliver_4", "comp"),
	(357, "사각형 6", "window", "alpha"),
	(358, "레이어 32", "nebula", "pixel"),
	(359, "레이어 33", "motes", "pixel"),
	(361, "레이어 34", "slash", "pixel"),
]
L_DIM = (345, "레이어 31")
L_CHAR = (360, "그룹 30")
CHAR_MAX_H = 1400               # portrait texture height cap (shown at ~1080 px, room for the push-in)

# mage portrait.png (after the CHAR_MAX_H resize): visible eye, head top (headdress) and chin
MAGE_EYE = (533, 408)
MAGE_HEAD = (70, 575)
# hero id -> standing image, anchor px (aligned to the mage's eye), glint eye px, head top y, chin y
HEROES = {
	"gunner": ("char_01.png", (865, 485), (865, 485), 58, 678),
	"knight": ("char_07.png", (637, 485), (504, 454), 11, 722),
	"healer": ("char_03.png", (626, 533), (508, 501), 62, 719),
}
STANDING = os.path.join(ROOT, "assets", "textures", "standing")


def find(psd, lid, name):
	for l in psd.descendants():
		if l.layer_id == lid:
			if l.name != name:
				sys.exit("layer %d is %r, expected %r — the PSD changed, update the ids" % (lid, l.name, name))
			return l
	sys.exit("layer %d not found" % lid)


def gd_vec(v):
	return "Vector2(%.1f, %.1f)" % v


def main():
	psd = PSDImage.open(sys.argv[1] if len(sys.argv) > 1 else PSD)
	smart = find(psd, *L_SMART)
	t = smart.smart_object.transform_box
	origin = (t[0], t[1])                       # PSB (0,0) in mockup coords
	ult = PSDImage.open(io.BytesIO(smart.smart_object.data))
	os.makedirs(OUT_TEX, exist_ok=True)

	def centre(bbox, size):
		# texture centre in design coords relative to the screen centre
		return (origin[0] + bbox[0] + size[0] / 2.0 - 960.0, origin[1] + bbox[1] + size[1] / 2.0 - 540.0)

	rows = []
	for lid, name, out, src in PIECES:
		l = find(ult, lid, name)
		if src == "pixel":
			im = l.topil().convert("RGBA")
		else:
			im = l.composite().convert("RGBA")
			if src == "alpha":
				a = im.getchannel("A")
				im = Image.new("RGBA", im.size, (255, 255, 255, 255))
				im.putalpha(a)
		im.save(os.path.join(OUT_TEX, out + ".png"))
		rows.append((out, centre(l.bbox, im.size), l.opacity / 255.0))
		print("%-14s %4dx%-4d  centre %s  opacity %.2f" % (out, im.size[0], im.size[1], gd_vec(rows[-1][1]), rows[-1][2]))

	dim = find(ult, *L_DIM)
	char = find(ult, *L_CHAR)
	ct = char.smart_object.transform_box
	cim = Image.open(io.BytesIO(char.smart_object.data)).convert("RGBA")
	shown = (ct[4] - ct[0], ct[5] - ct[1])
	if cim.height > CHAR_MAX_H:
		cim = cim.resize((round(cim.width * CHAR_MAX_H / cim.height), CHAR_MAX_H), Image.LANCZOS)
	cim.save(os.path.join(OUT_TEX, "portrait.png"))
	char_centre = (origin[0] + (ct[0] + ct[4]) / 2.0 - 960.0, origin[1] + (ct[1] + ct[5]) / 2.0 - 540.0)
	char_scale = shown[1] / cim.height
	print("portrait       %dx%d  centre %s  scale %.4f" % (cim.width, cim.height, gd_vec(char_centre), char_scale))

	def local(px, size):
		return (px[0] - size[0] / 2.0, px[1] - size[1] / 2.0)

	mage_eye_local = local(MAGE_EYE, cim.size)
	mage_eye = (char_centre[0] + mage_eye_local[0] * char_scale, char_centre[1] + mage_eye_local[1] * char_scale)
	head_design = (MAGE_HEAD[1] - MAGE_HEAD[0]) * char_scale
	portraits = [("mage", "portrait", char_centre, char_scale, mage_eye_local)]
	for hid, (src, anchor, eye, top, chin) in HEROES.items():
		him = Image.open(os.path.join(STANDING, src)).convert("RGBA")
		k = 1.0
		if him.height > CHAR_MAX_H:
			k = CHAR_MAX_H / him.height
			him = him.resize((round(him.width * k), CHAR_MAX_H), Image.LANCZOS)
		anchor = (anchor[0] * k, anchor[1] * k)
		eye = (eye[0] * k, eye[1] * k)
		sc = head_design / ((chin - top) * k)
		a = local(anchor, him.size)
		centre = (mage_eye[0] - a[0] * sc, mage_eye[1] - a[1] * sc)
		name = "portrait_" + hid
		him.save(os.path.join(OUT_TEX, name + ".png"))
		portraits.append((hid, name, centre, sc, local(eye, him.size)))
		print("%-14s %dx%d  centre %s  scale %.4f" % (name, him.width, him.height, gd_vec(centre), sc))

	lines = [
		"## GENERATED by tools/ult_cutin/extract_ult_cutin.py from assets/컨셉 원화/화면 컨셉_2.psd (궁극기 연출) — do not edit.",
		"## 초궁극기 컷인 시안 수치: 1920x1080 디자인 좌표, 화면 중심 (960, 540) 기준의 텍스처 중심. class_name 없음: 쓰는 쪽에서 preload.",
		"extends RefCounted",
		"",
		'const DIR := "res://assets/textures/ult_cutin/"',
		"const DIM_ALPHA := %.4f       # 레이어 31: 검은 딤" % (dim.opacity / 255.0),
		"",
		"# name -> [중심, 불투명도]",
		"const PIECES := {",
	]
	for out, c, op in rows:
		lines.append('\t"%s": [%s, %.4f],' % (out, gd_vec(c), op))
	lines += [
		"}",
		"",
		"# 캐릭터: window 로 잘려 얼굴만 보인다. 마법사는 그룹 30 스마트 오브젝트 원본, 나머지는 스탠딩 원화를 머리 크기·눈 위치를 맞춰 놓는다.",
		"# 영웅 id -> [텍스처, 중심, 배율, 눈(텍스처 중심 기준 px, 반짝 위치)]",
		"const PORTRAITS := {",
	]
	for hid, name, centre, sc, eye in portraits:
		lines.append('\t"%s": ["%s", %s, %.4f, %s],' % (hid, name, gd_vec(centre), sc, gd_vec(eye)))
	lines += ["}", ""]
	with open(OUT_GD, "w", encoding="utf-8", newline="\n") as f:
		f.write("\n".join(lines))
	print("wrote", OUT_GD)


if __name__ == "__main__":
	main()
