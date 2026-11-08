"""흰 배경 몬스터 원화 → 투명 PNG.

테두리에서 이어진 흰색(가까운 색)만 지운다 (외곽선 안쪽 하이라이트는 남는다).
경계 1px 은 흰 정도에 따라 반투명으로 풀어 흰 테두리(헤일로)를 없애고, 여백을 잘라 낸다.

사용: C:/Python314/python.exe tools/enemies/cutout_white.py <원본> <출력.png> [최대 변 px]
"""
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

WHITE_TOL = 40      # 255 에서 이만큼까지 흰 배경으로 본다
PAD = 4


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    max_side = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    source = Image.open(src).convert("RGBA")
    if np.asarray(source)[..., 3].min() < 255:
        # 이미 투명 배경이면 그대로 쓰고 여백만 자른다
        _save(np.asarray(source), dst, max_side)
        return
    im = np.asarray(source.convert("RGB")).astype(np.int16)
    whiteness = im.min(axis=2)                      # 가장 어두운 채널: 흰색일수록 255
    near_white = whiteness >= 255 - WHITE_TOL
    labels, _ = ndimage.label(near_white)
    edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    bg = np.isin(labels, edge[edge > 0])
    alpha = np.where(bg, 0, 255).astype(np.float32)
    # 배경에 닿은 가장자리 픽셀: 흰 정도만큼 투명하게, 색은 흰빛을 걷어낸다
    rim = ~bg & ndimage.binary_dilation(bg)
    a = np.clip((255 - whiteness) / float(WHITE_TOL * 3), 0.0, 1.0)
    alpha[rim] = 255 * a[rim]
    rgb = im.astype(np.float32)
    k = np.maximum(alpha / 255.0, 1e-3)[..., None]
    rgb = np.where(rim[..., None], np.clip((rgb - 255 * (1 - k)) / k, 0, 255), rgb)
    _save(np.dstack([rgb, alpha]).astype(np.uint8), dst, max_side)


def _save(out: np.ndarray, dst: str, max_side: int) -> None:
    alpha = out[..., 3]
    ys, xs = np.nonzero(alpha > 8)
    y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, out.shape[0])
    x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, out.shape[1])
    img = Image.fromarray(out[y0:y1, x0:x1], "RGBA")
    if max_side and max(img.size) > max_side:
        s = max_side / max(img.size)
        img = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    img.save(dst)
    print(f"{dst}: {img.size}")


if __name__ == "__main__":
    main()
