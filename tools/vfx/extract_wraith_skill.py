"""공허 망령 촉수 스킬 컨셉(assets/컨셉 원화/몬스터 스킬.psd)에서 타격 VFX 리소스를 뽑는다.

PSD 레이어(그룹 포함, 위에서부터 0 번)를 조각별 PNG 로 저장하고, 컨셉에서의 배치(무리 중심 기준 위치·긴 축 각도)를 적는다.
  A  별 모양 섬광 (그룹 2): 흰 바늘 8 + 어두운 조각 2
  B  아래 긴 섬광 두 줄,  C  오른쪽 발톱 섬광 두 줄
  debris  튀는 파편 (레이어 37 을 덩어리별로)
  ground  바닥 발톱 자국 (뒤 어두운 보라 + 앞 밝은 연보라)
- 출력: assets/vfx/void_defense/wraith_skill/*.png (PSD 의 SCALE 배)
        scripts/void_defense/vd_wraith_skill_parts.gd (생성물, 손으로 고치지 않는다)
        docs/void_wraith/skill_parts.png (검수용)
촉수 자체는 텍스처가 아니라 셰이더(tools/shaders/build_wraith_tentacle.gd)로 그린다 — 색은 이 PSD 의 모양 1 그라데이션에서 따왔다.

사용: C:/Python314/python.exe tools/vfx/extract_wraith_skill.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from psd_tools import PSDImage
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
PSD = ROOT / "assets/컨셉 원화/몬스터 스킬.psd"
OUT = ROOT / "assets/vfx/void_defense/wraith_skill"
DATA = ROOT / "scripts/void_defense/vd_wraith_skill_parts.gd"
PREVIEW = ROOT / "docs/void_wraith/skill_parts.png"
SCALE = 0.5

## 무리: 이름 → (중심 PSD px, [레이어 번호])
CLUSTERS = {
    "A": ((1735, 905), [19, 23, 20, 21, 22, 24, 25, 28, 29, 30]),
    "B": ((1580, 1225), [32, 33]),
    "C": ((2100, 1100), [35, 36]),
}
DARK = {19, 23}                 # 흰 섬광 뒤에 깔리는 어두운 조각
DEBRIS_LAYER = 37
GROUND = {"ground_back": 7, "ground_front": 8}


def _layers(psd):
    out = []
    def walk(group):
        for layer in group:
            out.append(layer)
            if layer.is_group():
                walk(layer)
    walk(psd)
    return out


def _full(layer, size) -> np.ndarray:
    """레이어를 문서 크기 RGBA 로."""
    im = layer.composite().convert("RGBA")
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.paste(im, (layer.bbox[0], layer.bbox[1]))
    return np.asarray(canvas)


def _save(arr: np.ndarray, name: str):
    """알파 있는 영역만 잘라 SCALE 배로 저장. (중심 PSD px, 긴 축 각도 rad, 크기) 를 돌려준다."""
    ys, xs = np.nonzero(arr[..., 3] > 8)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    crop = Image.fromarray(arr[y0:y1, x0:x1], "RGBA")
    size = (max(2, round(crop.width * SCALE)) + 4, max(2, round(crop.height * SCALE)) + 4)
    small = crop.resize((size[0] - 4, size[1] - 4), Image.LANCZOS)
    pad = Image.new("RGBA", size, (0, 0, 0, 0))
    pad.paste(small, (2, 2))
    OUT.mkdir(parents=True, exist_ok=True)
    pad.save(OUT / f"{name}.png")
    # 긴 축: 알파 픽셀의 주성분
    pts = np.stack([xs - xs.mean(), ys - ys.mean()])
    w, v = np.linalg.eigh(np.cov(pts))
    axis = v[:, np.argmax(w)]
    return ((x0 + x1) * 0.5, (y0 + y1) * 0.5), float(np.arctan2(axis[1], axis[0])), size


def main() -> None:
    psd = PSDImage.open(PSD)
    layers = _layers(psd)
    size = psd.size
    lines = [
        "## 공허 망령 촉수 스킬 타격 VFX 조각 — tools/vfx/extract_wraith_skill.py 생성물 (컨셉: 몬스터 스킬.psd). 손으로 고치지 않는다.",
        "## pos = 무리 중심 기준 위치(텍스처 px), axis = 조각의 긴 축 각도(rad), dark = 섬광 뒤에 깔리는 어두운 조각.",
        "extends RefCounted",
        "",
        'const DIR := "res://assets/vfx/void_defense/wraith_skill/"',
        f"const PSD_SCALE := {SCALE}      # 텍스처 px / PSD px (몬스터 원화와 같은 배율의 PSD)",
        "const CLUSTERS := {",
    ]
    sheet_items = []
    for cname, (center, ids) in CLUSTERS.items():
        lines.append(f'\t"{cname}": [')
        for k, i in enumerate(ids):
            name = f"{cname.lower()}{k}"
            c, axis, sz = _save(_full(layers[i], size), name)
            pos = ((c[0] - center[0]) * SCALE, (c[1] - center[1]) * SCALE)
            lines.append(f'\t\t{{"tex": "{name}", "pos": Vector2({pos[0]:.1f}, {pos[1]:.1f}), "axis": {axis:.3f}, "dark": {"true" if i in DARK else "false"}}},')
            sheet_items.append(name)
        lines.append("\t],")
    lines.append("}")
    # 파편: 덩어리별
    arr = _full(layers[DEBRIS_LAYER], size)
    lab, n = ndimage.label(arr[..., 3] > 40)
    names = []
    for i in range(1, n + 1):
        m = lab == i
        if m.sum() < 500:
            continue
        piece = arr.copy()
        piece[~m] = 0
        name = f"debris{len(names)}"
        _save(piece, name)
        names.append(name)
    lines.append("const DEBRIS := [" + ", ".join(f'"{n}"' for n in names) + "]")
    sheet_items += names
    for name, i in GROUND.items():
        _save(_full(layers[i], size), name)
        sheet_items.append(name)
    lines.append('const GROUND := ["ground_back", "ground_front"]')
    lines.append("")
    DATA.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    # 검수 시트
    ims = [Image.open(OUT / f"{n}.png") for n in sheet_items]
    w = sum(im.width + 12 for im in ims)
    sheet = Image.new("RGBA", (min(w, 2400), 900), (92, 92, 92, 255))
    x = y = 6
    row_h = 0
    for im in ims:
        if x + im.width > sheet.width:
            x, y, row_h = 6, y + row_h + 10, 0
        sheet.alpha_composite(im, (x, y))
        x += im.width + 12
        row_h = max(row_h, im.height)
    sheet.crop((0, 0, sheet.width, min(900, y + row_h + 10))).save(PREVIEW)
    print(f"{len(sheet_items)} pieces, debris {len(names)}")


if __name__ == "__main__":
    main()
