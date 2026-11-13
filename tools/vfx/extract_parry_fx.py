"""Extract the parry resources from the boss concept PSD (assets/컨셉 원화/보스몹 컨셉.psd).

  C:/Python314/python.exe tools/vfx/extract_parry_fx.py [path/to/보스몹 컨셉.psd]

The PSD (3440x1440) holds three groups (layer ids and names are checked):

  358 '보스몹'                     boss art: 313 레이어 63 (art, purple outer glow) + 314 / 315 clipped shading
  350 '몬스터 공격 예고 예시'      the parry telegraph on the boss's eye, bottom to top:
        339 모양 1 복사 24   white 4-point star (vector, 512x1028: long vertical needle + short horizontal one),
                             yellow outer glow (255,246,0) 29 px
        334 / 335 레이어 66  purple soft light pillar (linear dodge), stacked twice
        332 타원 1           white core dot (overlay) with a red-orange outer glow (255,48,0) 101 px
  355 '캐릭터 강조 효과 예시'      the parry target highlight on the first squad card:
        347 그룹 292         three yellow-glowing sparkles with horizontal streaks along the card's top edge
        353 레이어 67 복사 2 yellow light column rising above the card (overlay, fades out upward)
        349 / 352 레이어 67  yellow wash over the card (overlay, stacked twice, fades out downward)

Writes
  assets/void_defense_enemies/void_watcher.png          boss (group composite without the outer glow)
  assets/vfx/void_defense/parry/star.png                R = star shape, G = tight glow, B = wide bloom (shader input)
  assets/vfx/void_defense/parry/pillar.png              purple pillar (as painted)
  assets/vfx/void_defense/parry/beam_up.png, beam_low.png   card light column / wash (as painted)
  assets/vfx/void_defense/parry/sparkle_{a,b,c}.png     the three card sparkles, cut apart with feathered seams
  scripts/void_defense/vd_parry_layout.gd               generated constants
  docs/parry/psd_reference.png                          the concept crop, for comparing captures
"""
import os
import sys
import warnings

import numpy as np
from PIL import Image
from scipy import ndimage

warnings.filterwarnings("ignore")
from psd_tools import PSDImage  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PSD = os.path.join(ROOT, "assets", "컨셉 원화", "보스몹 컨셉.psd")
OUT_FX = os.path.join(ROOT, "assets", "vfx", "void_defense", "parry")
OUT_BOSS = os.path.join(ROOT, "assets", "void_defense_enemies", "void_watcher.png")
OUT_GD = os.path.join(ROOT, "scripts", "void_defense", "vd_parry_layout.gd")
OUT_DOC = os.path.join(ROOT, "docs", "parry")

G_BOSS, G_TELE, G_CARD = 358, 350, 355
L_STAR, L_PILLAR, L_CORE = 339, 334, 332
L_SPARK, L_BEAM_UP, L_BEAM_LOW = 347, 353, 349
STAR_PAD = 112                  # room for the glow around the star shape
# The first squad card in this PSD (same layout as 화면 컨셉: design px = psd * 0.75 - (660, 30); VDBattleUILayout.CARD_RECTS[0])
PSD_TO_DESIGN = 0.75
CARD0_DESIGN = (1038.6, 883.6, 220.7, 168.5)
DESIGN_SHIFT = (660.0, 30.0)
PANEL_W = 300.0                 # char panel texture width (VDBattleFrame.PANEL_TEX)
# sparkle centres inside layer 347 (white cores, measured) and the seams between them
SPARKS = [("a", (166, 228)), ("b", (333, 210)), ("c", (440, 200))]
SEAMS = [250, 387]
FEATHER = 26


def find(psd, layer_id, name):
    for layer in psd.descendants():
        if layer.layer_id == layer_id:
            assert layer.name == name, (layer.name, name)
            return layer
    raise SystemExit("layer %d not found" % layer_id)


def rgba(layer):
    return np.array(layer.topil().convert("RGBA")).astype(np.float32)


def save(arr, path):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(path)
    print("  wrote", os.path.relpath(path, ROOT), arr.shape[1], "x", arr.shape[0])


def main():
    psd = PSDImage.open(sys.argv[1] if len(sys.argv) > 1 else PSD)
    os.makedirs(OUT_FX, exist_ok=True)
    os.makedirs(OUT_DOC, exist_ok=True)
    g_boss, g_tele, g_card = find(psd, G_BOSS, "보스몹"), find(psd, G_TELE, "몬스터 공격 예고 예시"), find(psd, G_CARD, "캐릭터 강조 효과 예시")

    # ---- boss: group composite (layer effects are not drawn, so the outer glow stays out), cropped to the art
    boss_bb = g_boss.bbox
    boss = np.array(g_boss.composite().convert("RGBA")).astype(np.float32)
    ys, xs = np.where(boss[..., 3] > 8)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    boss = boss[y0:y1, x0:x1]
    # stray specks under the art (a few px of the mask) – keep only the biggest blob
    lab, n = ndimage.label(boss[..., 3] > 8)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 400])
        boss[..., 3] *= keep
        ys, xs = np.where(boss[..., 3] > 8)
        cx0, cx1, cy0, cy1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        boss = boss[cy0:cy1, cx0:cx1]
        x0, y0 = x0 + cx0, y0 + cy0
    save(boss, OUT_BOSS)
    boss_org = (boss_bb[0] + x0, boss_bb[1] + y0)

    # ---- telegraph star: vector shape rasterised by psd-tools (white, alpha = coverage)
    star_l = find(psd, L_STAR, "모양 1 복사 24")
    sa = rgba(star_l)[..., 3] / 255.0
    sa = np.pad(sa, STAR_PAD)
    tight = np.clip(ndimage.gaussian_filter(sa, 9.0) * 2.6, 0, 1)     # outer glow 29 px, choke 6 %
    tight = np.maximum(tight, np.clip(ndimage.gaussian_filter(sa, 3.0) * 1.6, 0, 1))
    wide = np.clip(ndimage.gaussian_filter(sa, 34.0) * 5.0, 0, 1)
    star = np.dstack([sa, tight, wide, np.ones_like(sa)]) * 255.0
    save(star, os.path.join(OUT_FX, "star.png"))
    sb = star_l.bbox
    star_center = ((sb[0] + sb[2]) * 0.5, (sb[1] + sb[3]) * 0.5)

    pillar_l = find(psd, L_PILLAR, "레이어 66")
    save(rgba(pillar_l), os.path.join(OUT_FX, "pillar.png"))
    core_l = find(psd, L_CORE, "타원 1")
    cb = core_l.bbox

    # ---- card highlight
    up_l, low_l, sp_l = find(psd, L_BEAM_UP, "레이어 67 복사 2"), find(psd, L_BEAM_LOW, "레이어 67"), find(psd, L_SPARK, "그룹 292")
    save(rgba(up_l), os.path.join(OUT_FX, "beam_up.png"))
    save(rgba(low_l), os.path.join(OUT_FX, "beam_low.png"))
    sp = rgba(sp_l)
    w = sp.shape[1]
    xs = np.arange(w, dtype=np.float32)
    edges = [-1e6] + SEAMS + [1e6]
    spark_meta = []
    for i, (tag, (cx, cy)) in enumerate(SPARKS):
        lo, hi = edges[i], edges[i + 1]
        mask = np.clip((xs - (lo - FEATHER)) / (2 * FEATHER), 0, 1) * np.clip(((hi + FEATHER) - xs) / (2 * FEATHER), 0, 1)
        piece = sp.copy()
        piece[..., 3] *= mask[None, :]
        ys_, xs_ = np.where(piece[..., 3] > 3)
        px0, px1, py0, py1 = xs_.min(), xs_.max() + 1, ys_.min(), ys_.max() + 1
        piece = piece[py0:py1, px0:px1]
        save(piece, os.path.join(OUT_FX, "sparkle_%s.png" % tag))
        spark_meta.append((tag, (sp_l.bbox[0] + cx, sp_l.bbox[1] + cy), (cx - px0, cy - py0)))

    # ---- layout (card pieces in char-panel texture px: origin = card top-left, 300 px wide)
    card_psd = ((CARD0_DESIGN[0] + DESIGN_SHIFT[0]) / PSD_TO_DESIGN, (CARD0_DESIGN[1] + DESIGN_SHIFT[1]) / PSD_TO_DESIGN)
    k = PANEL_W / (CARD0_DESIGN[2] / PSD_TO_DESIGN)      # psd px -> panel px

    def panel(p):
        return ((p[0] - card_psd[0]) * k, (p[1] - card_psd[1]) * k)

    L = ["## 패링 연출 배치 (생성물: tools/vfx/extract_parry_fx.py — 손으로 고치지 말 것).",
         "## 원본: assets/컨셉 원화/보스몹 컨셉.psd 의 '몬스터 공격 예고 예시' · '캐릭터 강조 효과 예시' · '보스몹' 그룹.",
         "extends RefCounted",
         "",
         'const DIR := "res://assets/vfx/void_defense/parry/"',
         "## 보스 원화(void_watcher.png) px",
         "const BOSS_SIZE := Vector2(%d, %d)" % (boss.shape[1], boss.shape[0]),
         "const BOSS_EYE := Vector2(%.1f, %.1f)        # 예고 별이 놓이는 눈 (원화 px)" % (star_center[0] - boss_org[0], star_center[1] - boss_org[1]),
         "## 예고 (보스 원화 px 단위: 원화 1px = 별 텍스처 1px)",
         "const STAR_PAD := %d                         # star.png 가장자리 여백 (R 모양 · G 좁은 빛 · B 넓은 빛)" % STAR_PAD,
         "const STAR_SIZE := Vector2(%d, %d)            # 여백 뺀 별 크기" % (sb[2] - sb[0], sb[3] - sb[1]),
         "const PILLAR_SIZE := Vector2(%d, %d)" % (pillar_l.bbox[2] - pillar_l.bbox[0], pillar_l.bbox[3] - pillar_l.bbox[1]),
         "const PILLAR_OFFSET := Vector2(%.1f, %.1f)     # 빛기둥 중심 - 별 중심" % ((pillar_l.bbox[0] + pillar_l.bbox[2]) * 0.5 - star_center[0], (pillar_l.bbox[1] + pillar_l.bbox[3]) * 0.5 - star_center[1]),
         "const CORE_RADIUS := %.1f                     # 흰 핵 반지름" % ((cb[2] - cb[0]) * 0.5),
         "const CORE_OFFSET := Vector2(%.1f, %.1f)" % ((cb[0] + cb[2]) * 0.5 - star_center[0], (cb[1] + cb[3]) * 0.5 - star_center[1]),
         "const CORE_GLOW := 101.0                     # 붉은 외부 광선 크기",
         "const COL_STAR_GLOW := Color(1.0, 0.965, 0.0)",
         "const COL_CORE_GLOW := Color(1.0, 0.188, 0.0)",
         "const COL_PILLAR := Color(0.357, 0.0, 0.478)",
         "## 카드 강조 (캐릭터 패널 텍스처 px: 원점 = 카드 왼쪽 위, 폭 300). 텍스처 1px = PANEL_K 패널 px",
         "const PANEL_K := %.4f" % k,
         "const BEAM_UP_POS := Vector2(%.1f, %.1f)       # 위로 솟는 빛기둥 왼쪽 위" % panel((up_l.bbox[0], up_l.bbox[1])),
         "const BEAM_UP_SIZE := Vector2(%d, %d)" % (up_l.bbox[2] - up_l.bbox[0], up_l.bbox[3] - up_l.bbox[1]),
         "const BEAM_LOW_POS := Vector2(%.1f, %.1f)      # 카드를 덮는 빛 왼쪽 위" % panel((low_l.bbox[0], low_l.bbox[1])),
         "const BEAM_LOW_SIZE := Vector2(%d, %d)" % (low_l.bbox[2] - low_l.bbox[0], low_l.bbox[3] - low_l.bbox[1]),
         "## 반짝이 [파일, 중심(패널 px), 텍스처 안 중심(px)]",
         "const SPARKLES := ["]
    for tag, c_psd, pivot in spark_meta:
        p = panel(c_psd)
        L.append('\t["sparkle_%s.png", Vector2(%.1f, %.1f), Vector2(%.1f, %.1f)],' % (tag, p[0], p[1], pivot[0], pivot[1]))
    L.append("]")
    with open(OUT_GD, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    print("  wrote", os.path.relpath(OUT_GD, ROOT))

    ref = psd.composite().crop((2000, 0, 3440, 1440))
    ref.save(os.path.join(OUT_DOC, "psd_reference.png"))
    print("  wrote docs/parry/psd_reference.png")


if __name__ == "__main__":
    main()
