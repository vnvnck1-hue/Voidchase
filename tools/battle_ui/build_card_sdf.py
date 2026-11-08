"""분대 카드 패널의 부호 거리장(SDF) 텍스처를 만든다 — 궁극기 준비 황금 불꽃(shaders/card_ult_flame.gdshader)용.

패널 그림(assets/textures/char_panels/*.png)의 알파 윤곽에서 각 픽셀까지의 거리(텍스처 px)를 재고,
패널보다 PAD 만큼 넓은 캔버스에 담아 8비트 회색조 PNG 로 저장한다.
  값 = 0.5 + 부호거리 / (2 * RANGE)   (윤곽 밖 +, 안 -, RANGE px 에서 0 또는 1 로 포화)
셰이더는 (값 - 0.5) * 2 * RANGE 로 되돌려 쓴다. PAD·RANGE 를 바꾸면 vd_battle_frame.gd 의 FLAME_PAD_TEX·FLAME_RANGE 도 같이 바꾼다.

    C:/Python314/python.exe tools/battle_ui/build_card_sdf.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/textures/char_panels"
OUT = ROOT / "assets/textures/battle_ui/card_sdf"
PANELS = ["panel_01", "new_panel_08", "new_panel_04", "panel_03"]   # vd_battle_frame.gd HERO_PANEL
PAD = (64, 104)     # 패널 밖 여유(텍스처 px): 가로, 세로 (위로 솟는 불 혀가 잘리지 않게)
RANGE = 104.0       # 부호거리 포화 거리(px)


def build(name: str) -> None:
    im = Image.open(SRC / f"{name}.png").convert("RGBA")
    a = np.asarray(im.split()[3], dtype=np.float32) / 255.0
    h, w = a.shape
    canvas = np.zeros((h + PAD[1] * 2, w + PAD[0] * 2), dtype=np.float32)
    canvas[PAD[1]:PAD[1] + h, PAD[0]:PAD[0] + w] = a
    inside = canvas >= 0.5
    d_out = distance_transform_edt(~inside)     # 밖 픽셀 → 가장 가까운 안 픽셀
    d_in = distance_transform_edt(inside)       # 안 픽셀 → 가장 가까운 밖 픽셀
    sd = np.where(inside, -(d_in - 0.5), d_out - 0.5)
    v = np.clip(0.5 + sd / (2.0 * RANGE), 0.0, 1.0)
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray((v * 255.0 + 0.5).astype(np.uint8), "L").save(OUT / f"{name}.png")
    print(f"{name}: {w}x{h} -> {canvas.shape[1]}x{canvas.shape[0]}")


if __name__ == "__main__":
    for n in PANELS:
        build(n)
