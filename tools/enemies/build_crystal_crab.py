"""공허 수정게: 화면 캡처(tools/enemies/src/crystal_crab_source.png)에서 배경을 걷어 내고 머리·몸통·팔 파츠로 나눈다.

- 파츠 경계는 아래 POLY (원본 px 좌표, 외곽선 바깥으로 1~2px 넉넉히). 바깥쪽 배경은 어두운 외곽선에 닿을 때까지
  폴리곤 가장자리에서 밝은 픽셀을 따라 들어가며 지운다 (FLOOD_PX 까지만: 외곽선이 끊겨도 속까지 새지 않게).
- 원본이 작아(몬스터 약 250px) UPSCALE 배로 키운 뒤 처리한다.
- 출력: assets/void_defense_enemies/crystal_crab/{core,head,arm_l,arm_r,body}.png
        scripts/void_defense/vd_crystal_crab_parts.gd (파츠 위치·피벗: 생성물, 손으로 고치지 않는다)
        docs/crystal_crab/parts_preview.png (검수용)

사용: C:/Python314/python.exe tools/enemies/build_crystal_crab.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/enemies/src/crystal_crab_source.png"
OUT = ROOT / "assets/void_defense_enemies/crystal_crab"
DATA = ROOT / "scripts/void_defense/vd_crystal_crab_parts.gd"
PREVIEW = ROOT / "docs/crystal_crab/parts_preview.png"

UPSCALE = 3
DARK_LUMA = 54        # 이보다 어두우면 외곽선·어두운 면 (배경은 67 이상)
FLOOD_PX = 7          # 폴리곤 가장자리에서 배경을 따라 들어가는 최대 깊이 (원본 px)
PAD = 3               # 잘라낸 파츠 둘레 여백 (출력 px)
CORE_COLOR = (30, 14, 50)

## 머리와 몸통(깃 모양 결정)의 경계: 깃 윗면 외곽선을 따라 왼쪽 → 오른쪽
COLLAR = [(137, 164.5), (153, 168.5), (170, 173.5), (184, 180), (189, 180), (200, 178), (215, 173), (234, 166.5)]

POLY = {
    "head": [(188, 63), (191, 66), (214, 115), (216, 121), (221, 111), (225, 111), (238, 139), (238, 148),
             (234, 154), (234, 166.5)] + COLLAR[::-1][1:-1] + [(153, 168.5), (152, 150), (158, 140), (151, 123), (151, 118)],
    "body": COLLAR + [(238, 169), (237, 186), (229, 198), (216, 205), (206, 226), (202, 225), (199, 214),
                      (189, 240), (186, 242.5), (183.5, 240), (171, 219), (165, 210), (163, 204), (150, 198), (141, 191), (133, 169)],
    "arm_l": [(136, 125), (140, 127), (152, 146), (153, 160), (152, 168), (140, 166), (135, 170), (130, 174), (129, 181),
              (122, 188), (123, 194), (100, 224), (95, 223), (95, 189), (82, 194), (77, 194), (66, 182), (62, 175),
              (72, 165), (84, 159), (98, 151), (106, 146), (113, 149), (116, 146), (115, 142)],
    "arm_r": [(247, 131), (251, 132), (261, 139), (261, 146), (291, 144), (295, 147), (316, 185), (314, 189),
              (291, 200), (287, 197), (266, 220), (262, 219), (263, 190), (246, 184), (238, 172), (234, 160),
              (234, 155), (240, 150), (242, 141)],
}
## 몸통 뒤 어두운 속심: 파츠가 움직여 틈이 벌어질 때 보이는 면. 전체 실루엣 안쪽으로만 채운다.
CORE_POLY = [(154, 146), (236, 146), (238, 172), (222, 192), (200, 202), (172, 202), (153, 190), (151, 172)]
## 폴리곤 안에 갇혀 남는 배경 조각: 이 안의 밝은 픽셀은 지운다 (어두운 외곽선은 남긴다)
ERASE = [[(90, 187), (95, 182.5), (101, 183), (101, 187), (97, 190), (94, 191)]]
## 외곽선이 흐려 배경 지우기가 속까지 파고드는 곳: 이 안은 폴리곤 경계를 그대로 믿는다
KEEP = [[(241, 141), (246, 131), (253, 133), (253, 147), (240, 150)]]
## 파츠 회전·늘임의 중심 (원본 px)
PIVOT = {"core": (187, 186), "head": (187, 178), "body": (187, 186), "arm_l": (148, 160), "arm_r": (240, 160)}
## 발밑: 떠 있는 몸 아래 바닥 그림자의 중심
FOOT = (187, 251)
ORDER = ["core", "head", "arm_l", "arm_r", "body"]


def _mask(poly, size, ss=4) -> np.ndarray:
    """폴리곤 → 0~1 마스크 (ss 배 슈퍼샘플로 가장자리를 부드럽게)."""
    w, h = size
    im = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(im).polygon([(x * UPSCALE * ss, y * UPSCALE * ss) for x, y in poly], fill=255)
    return np.asarray(im.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255.0


def main() -> None:
    src = Image.open(SRC).convert("RGB")
    big = src.resize((src.width * UPSCALE, src.height * UPSCALE), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=2.0, percent=60, threshold=2))
    rgb = np.asarray(big).astype(np.float32)
    luma = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    size = big.size

    masks = {k: _mask(p, size) for k, p in POLY.items()}
    union = np.clip(sum(masks.values()), 0.0, 1.0) > 0.5
    # 배경: 실루엣 폴리곤 바깥에서 밝은 픽셀을 타고 FLOOD_PX 까지 들어간 곳
    bright = ndimage.gaussian_filter(luma, 0.8) > DARK_LUMA
    reach = ndimage.binary_dilation(~union, iterations=FLOOD_PX * UPSCALE, mask=bright | ~union)
    keep = np.zeros_like(union)
    for poly in KEEP:
        keep |= _mask(poly, size) > 0.5
    solid = union & ~(reach & ~keep)
    for poly in ERASE:
        solid &= ~((_mask(poly, size) > 0.5) & (luma > 45))
    solid = ndimage.binary_opening(solid, iterations=2)
    labels, n = ndimage.label(solid)
    if n > 1:
        # 팔·몸이 한 덩어리가 아닐 수 있으므로(틈으로 떨어져 있음) 먼지만 지운다
        sizes = ndimage.sum(solid, labels, range(1, n + 1))
        solid = np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= 400])
    solid = ndimage.binary_fill_holes(solid) | solid
    # 가장자리: 바깥으로 번진 배경색을 한 겹 깎고 부드럽게
    solid_a = ndimage.gaussian_filter(ndimage.binary_erosion(solid, iterations=1).astype(np.float32), 0.9)
    solid_a = np.clip((solid_a - 0.25) / 0.5, 0.0, 1.0)

    core = _mask(CORE_POLY, size) * ndimage.binary_erosion(solid, iterations=4 * UPSCALE)
    core = ndimage.gaussian_filter(core, 1.0)
    parts = {}
    for name in ORDER:
        if name == "core":
            a = core
            col = np.empty_like(rgb)
            col[:] = CORE_COLOR
        else:
            a = masks[name] * solid_a
            col = rgb
        # 가장자리 반투명 픽셀은 배경이 섞여 있으므로 안쪽 색을 끌어다 쓴다
        inner = a > 0.9
        if name != "core":
            idx = ndimage.distance_transform_edt(~inner, return_distances=False, return_indices=True)
            col = col[idx[0], idx[1]]
        ys, xs = np.nonzero(a > 0.02)
        y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, size[1])
        x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, size[0])
        out = np.dstack([col[y0:y1, x0:x1], a[y0:y1, x0:x1, None] * 255.0]).clip(0, 255).astype(np.uint8)
        OUT.mkdir(parents=True, exist_ok=True)
        Image.fromarray(out, "RGBA").save(OUT / f"{name}.png")
        parts[name] = {"origin": (x0, y0), "size": (x1 - x0, y1 - y0)}
        print(f"{name}: {x1 - x0}x{y1 - y0} @ {x0},{y0}")

    _write_data(parts)
    _write_preview(parts, size)


def _write_data(parts: dict) -> None:
    fx, fy = FOOT[0] * UPSCALE, FOOT[1] * UPSCALE
    xs0 = min(p["origin"][0] for p in parts.values())
    xs1 = max(p["origin"][0] + p["size"][0] for p in parts.values())
    top = min(p["origin"][1] for p in parts.values())
    lines = [
        "## 공허 수정게 파츠 배치 — tools/enemies/build_crystal_crab.py 생성물. 손으로 고치지 말고 스크립트를 고쳐 다시 실행한다.",
        "## 좌표는 텍스처 px, 발밑(바닥 그림자 중심)이 원점. pos = 파츠 피벗, offset = 피벗에서 텍스처 왼쪽 위까지.",
        "extends RefCounted",
        "",
        f"const WIDTH := {float(xs1 - xs0)}      # 전체 가로 폭 (px)",
        f"const TOP := {float(top - fy)}       # 맨 위 y (발밑 기준)",
        "## 뒤 → 앞 순서",
        "const PARTS := [",
    ]
    for name in ORDER:
        px, py = PIVOT[name][0] * UPSCALE, PIVOT[name][1] * UPSCALE
        ox, oy = parts[name]["origin"]
        lines.append(
            f'\t{{"name": "{name}", "pos": Vector2({px - fx}, {py - fy}), "offset": Vector2({ox - px}, {oy - py})}},')
    lines += ["]", ""]
    DATA.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(DATA)


def _write_preview(parts: dict, size) -> None:
    """왼쪽: 다시 조립한 모습(체크무늬 위), 오른쪽: 파츠를 벌려 놓은 모습."""
    def checker(w, h):
        yy, xx = np.mgrid[0:h, 0:w]
        c = np.where(((xx // 16) + (yy // 16)) % 2 == 0, 205, 245).astype(np.uint8)
        return Image.fromarray(np.dstack([c, c, c, np.full_like(c, 255)]), "RGBA")
    x0 = min(p["origin"][0] for p in parts.values()) - 30
    y0 = min(p["origin"][1] for p in parts.values()) - 30
    x1 = max(p["origin"][0] + p["size"][0] for p in parts.values()) + 30
    y1 = max(p["origin"][1] + p["size"][1] for p in parts.values()) + 30
    w, h = x1 - x0, y1 - y0
    sheet = checker(w * 2 + 120, h + 80)
    spread = {"core": (0, 0), "head": (0, -34), "arm_l": (-46, 6), "arm_r": (46, 6), "body": (0, 40)}
    for name in ORDER:
        im = Image.open(OUT / f"{name}.png")
        ox, oy = parts[name]["origin"]
        sheet.alpha_composite(im, (ox - x0, oy - y0 + 40))
        dx, dy = spread[name]
        sheet.alpha_composite(im, (w + 60 + ox - x0 + dx, oy - y0 + 40 + dy))
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW)
    print(PREVIEW)


if __name__ == "__main__":
    main()
