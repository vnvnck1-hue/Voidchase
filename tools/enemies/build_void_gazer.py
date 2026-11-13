"""공허 응시자(첫 보스): 원화 PSD(assets/컨셉 원화/첫 보스.psd)의 레이어를 파츠·본 메시로 만든다.

PSD 레이어 (아래 → 위): 날개 A(먼 쪽 뒷날개) · 날개 B(먼 쪽 앞날개) · 몸통(눈 14개 포함) · 날개 C(가까운 쪽 앞날개) · 날개 D(가까운 쪽 뒷날개).
레이어 이름은 쓰지 않는다: 가장 큰 레이어 = 몸통, 나머지는 쌓인 순서대로 A B C D.

- 눈 14개는 몸통 레이어에서 원(EYES: 중심·외곽선 반지름)으로 떼어 낸다. 눈 하나 = 세 장:
    eye_N.png        눈알 (동공을 지우고 주변 색으로 메운 공). 앞 눈에 가린 곳은 같은 반지름의 색으로 둥글게 채워 온전한 원이 된다.
    eye_N_pupil.png  동공 (붉은 부분). 눈알 안에서 사방으로 굴러다닌다 (눈알 알파로 잘린다).
    eye_N_over.png   외곽선 고리 + 하이라이트. 동공 위에 덮여 동공이 가장자리로 가도 외곽선·광택 밑으로 들어간다.
  몸통 쪽 눈 자리는 눈꺼풀 색으로 메운다 (눈이 움찔거리거나 감겨도 구멍이 안 보이게).
- 날개 네 장은 레이어 그대로 한 장씩 (완전 분리). 저마다 뿌리 → 끝으로 본 사슬을 놓는다 (WINGS).
- 전부 격자 메시 + 본:
    body ─ up0 ─ up1 ─ up2        초승달 위쪽 팔
         ─ lo0 ─ lo1 ─ lo2        초승달 아래쪽 팔 (끝이 돌진에 쓰는 뿔) ─ tail (꼬리 지느러미, lo1 의 자식)
         ─ wa0 ─ wa1 ─ wa2        날개 A      ─ wb0 ─ wb1 ─ wb2   날개 B
         ─ wc0 ─ wc1 ─ wc2 ─ wc3  날개 C      ─ wd0 ─ wd1 ─ wd2   날개 D
  눈은 스프라이트지만 몸통 본에 얹혀 움직인다 (bw: 눈 중심에서의 몸통 본 가중치).
- 출력: assets/void_defense_enemies/void_gazer/*.png
        scripts/void_defense/vd_void_gazer_parts.gd (생성물, 손으로 고치지 않는다)
        docs/void_gazer/{parts_preview,debug_labels}.png (검수용)
- 좌표: 몸통 상수는 처음 원화(1315x872) 기준 그대로 두고 OFF 를 더해 PSD 캔버스 좌표로 옮긴다. 날개 상수는 PSD 좌표.

사용: C:/Python314/python.exe tools/enemies/build_void_gazer.py [--debug]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from psd_tools import PSDImage
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/컨셉 원화/첫 보스.psd"
OUT = ROOT / "assets/void_defense_enemies/void_gazer"
DATA = ROOT / "scripts/void_defense/vd_void_gazer_parts.gd"
PREVIEW = ROOT / "docs/void_gazer/parts_preview.png"
DEBUG = ROOT / "docs/void_gazer/debug_labels.png"

OFF = (438, 202)      # 처음 원화 좌표 → PSD 캔버스 좌표


def _o(p):
    return (p[0] + OFF[0], p[1] + OFF[1]) + tuple(p[2:])


FOOT = _o((430, 965))     # 발밑 (떠 있다: 그림 아래로 띄운 자리)
PAD = 4
OUTLINE_LUMA = 42

## 눈: (중심 x, y, 외곽선 가운데 반지름). 번호 = 파츠 이름 eye_N.
EYES = [_o(e) for e in [(238, 238, 25), (320, 226, 52), (392, 269, 33), (450, 301, 33), (595, 224, 36), (660, 287, 46), (528, 466, 47),
                        (477, 522, 29), (573, 519, 30), (513, 566, 31), (671, 566, 28), (283, 704, 29), (362, 684, 51), (443, 688, 27)]]
EYE_EDGE = 3.5        # 외곽선 가운데 → 바깥 끝
## 눈끼리 겹칠 때 뒤 → 앞
EYE_ORDER = [0, 2, 3, 1, 4, 5, 7, 6, 8, 9, 10, 11, 13, 12]

BODY_C = _o((330.0, 450.0))       # 초승달 속 빈 곳의 가운데 (팔을 따라 도는 각도의 기준)
BODY_BONES = {k: _o(v) for k, v in {"body": (500, 440), "up0": (520, 180), "up1": (285, 180), "up2": (105, 255),
                                    "lo0": (585, 695), "lo1": (330, 775), "lo2": (140, 680), "tail": (245, 800)}.items()}
BODY_PARENT = {"body": "", "up0": "body", "up1": "up0", "up2": "up1", "lo0": "body", "lo1": "lo0", "lo2": "lo1", "tail": "lo1"}
## 각도(도) 구간에서 가중치가 뿌리 → 다음 본으로 넘어간다
UP_RAMPS = [(30, 70), (82, 116), (124, 150)]
LO_RAMPS = [(25, 65), (74, 104), (112, 138)]
TAIL_POLY = [_o(p) for p in [(150, 872), (172, 800), (214, 772), (270, 792), (252, 832), (192, 872)]]
HORN_TIP = _o((52, 606))
BODY_GRID = 38

## 날개 (PSD 좌표): root = 몸에 붙는 뿌리, tip = 가장 긴 깃 끝, n = 본 수. near = 몸 앞쪽(가까운 쪽) 쌍, fore = 앞날개.
## 그리는 순서 = 이 순서에서 near 가 아닌 것 → 몸통·눈 → near 인 것.
WINGS = [
    {"name": "wing_a", "pre": "wa", "root": (925, 355), "tip": (1000, 90), "n": 3, "grid": 26, "near": False, "fore": False},
    {"name": "wing_b", "pre": "wb", "root": (1040, 450), "tip": (1270, 110), "n": 3, "grid": 30, "near": False, "fore": True},
    {"name": "wing_c", "pre": "wc", "root": (1160, 670), "tip": (1740, 280), "n": 4, "grid": 38, "near": True, "fore": True},
    {"name": "wing_d", "pre": "wd", "root": (1100, 838), "tip": (1570, 790), "n": 3, "grid": 32, "near": True, "fore": False},
]


def wing_bones(cfg) -> list:
    r = np.array(cfg["root"], float)
    t = np.array(cfg["tip"], float)
    return [(f'{cfg["pre"]}{k}', tuple(float(c) for c in r + (t - r) * k / cfg["n"])) for k in range(cfg["n"])]


def _smooth(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def _polyline_mask(lines, size, width=3) -> np.ndarray:
    im = Image.new("L", size, 0)
    dr = ImageDraw.Draw(im)
    for ln in lines:
        dr.line(ln, fill=255, width=width)
    return np.asarray(im) > 0


def _poly_mask(poly, size) -> np.ndarray:
    im = Image.new("L", size, 0)
    ImageDraw.Draw(im).polygon(poly, fill=255)
    return np.asarray(im) > 0


def _nearest_fill(col: np.ndarray, known: np.ndarray) -> np.ndarray:
    idx = ndimage.distance_transform_edt(~known, return_distances=False, return_indices=True)
    return col[idx[0], idx[1]]


def _blur3(col, sigma):
    return np.dstack([ndimage.gaussian_filter(col[..., c], sigma) for c in range(3)])


def _layer_rgba(layer, size) -> np.ndarray:
    full = Image.new("RGBA", size, (0, 0, 0, 0))
    full.paste(layer.topil().convert("RGBA"), (layer.bbox[0], layer.bbox[1]))
    return np.asarray(full).astype(np.float32)


def segment():
    psd = PSDImage.open(SRC)
    size = psd.size
    layers = [l for l in psd if l.kind == "pixel" and l.visible]
    if len(layers) != 5:
        raise SystemExit(f"PSD 레이어 5장(날개 4 + 몸통)이어야 한다: {len(layers)}장")
    areas = [(l.bbox[2] - l.bbox[0]) * (l.bbox[3] - l.bbox[1]) for l in layers]
    bi = int(np.argmax(areas))
    arr = _layer_rgba(layers[bi], size)
    wings = {}
    for cfg, l in zip(WINGS, [l for i, l in enumerate(layers) if i != bi]):
        wings[cfg["name"]] = _layer_rgba(l, size)
    rgb, alpha = arr[..., :3].copy(), arr[..., 3] / 255.0
    fg = alpha > 0.5
    rgb = _nearest_fill(rgb, alpha > 0.97)          # 가장자리 반투명 픽셀의 색을 안쪽 색으로
    luma = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    h, w = fg.shape
    yy, xx = np.mgrid[0:h, 0:w]
    # 눈 소유 지도: 앞 눈이 이긴다
    eye_of = np.full((h, w), -1, dtype=np.int16)
    for i in EYE_ORDER:
        cx, cy, r = EYES[i]
        eye_of[(xx - cx) ** 2 + (yy - cy) ** 2 <= (r + EYE_EDGE) ** 2] = i
    return size, rgb, luma, alpha, fg, wings, eye_of


def debug_view(size, rgb, alpha, wings, eye_of) -> None:
    im = Image.new("RGBA", size, (60, 50, 90, 255))
    order = [c["name"] for c in WINGS if not c["near"]] + ["body"] + [c["name"] for c in WINGS if c["near"]]
    for n in order:
        a = np.dstack([rgb, alpha[..., None] * 255.0]) if n == "body" else wings[n]
        im.alpha_composite(Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA"))
    dr = ImageDraw.Draw(im)
    for i, (cx, cy, r) in enumerate(EYES):
        rr = r + EYE_EDGE
        dr.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=(0, 255, 0))
        dr.text((cx - 3, cy - 5), str(i), fill=(255, 255, 255))
    groups = [BODY_BONES] + [dict(wing_bones(c) + [(c["pre"] + "_tip", c["tip"])]) for c in WINGS]
    for group in groups:
        prev = None
        for n, (x, y) in group.items():
            if prev and group is not BODY_BONES:
                dr.line([prev, (x, y)], fill=(255, 220, 0), width=2)
            prev = (x, y)
            dr.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(255, 0, 0))
            dr.text((x + 6, y - 6), n, fill=(255, 255, 0))
    dr.ellipse([HORN_TIP[0] - 5, HORN_TIP[1] - 5, HORN_TIP[0] + 5, HORN_TIP[1] + 5], outline=(0, 255, 255), width=2)
    dr.ellipse([FOOT[0] - 6, FOOT[1] - 6, FOOT[0] + 6, FOOT[1] + 6], outline=(255, 255, 255), width=2)
    DEBUG.parent.mkdir(parents=True, exist_ok=True)
    im.convert("RGB").save(DEBUG)
    print(DEBUG)


def _save(name, col, a, parts) -> None:
    h, w = a.shape
    ys, xs = np.nonzero(a > 0.02)
    y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, h)
    x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, w)
    out = np.dstack([col[y0:y1, x0:x1], a[y0:y1, x0:x1, None] * 255.0]).clip(0, 255).astype(np.uint8)
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out, "RGBA").save(OUT / f"{name}.png")
    parts[name] = {"origin": (int(x0), int(y0)), "size": (int(x1 - x0), int(y1 - y0)), "alpha": a}


def build_eye(i, rgb, luma, alpha, eye_of, parts) -> dict:
    """눈 하나: 눈알(동공 지움) · 동공 · 덮개(외곽선 + 하이라이트)."""
    cx, cy, r = EYES[i]
    R = r + EYE_EDGE
    h, w = luma.shape
    yy, xx = np.mgrid[0:h, 0:w]
    rho = np.hypot(xx - cx, yy - cy)
    disk = rho <= R + 1.5
    vis = (eye_of == i) & (alpha > 0.9)
    col = rgb.copy()
    # 가린 곳: 같은 반지름에서 보이는 픽셀의 평균색 (외곽선 고리도 이어진다)
    hid = disk & ~vis
    if hid.any():
        bins = np.clip(rho.astype(np.int32), 0, int(R) + 3)
        nb = int(R) + 4
        cnt = np.bincount(bins[vis], minlength=nb).astype(np.float32)
        ring = np.zeros((nb, 3), np.float32)
        for c in range(3):
            ring[:, c] = np.bincount(bins[vis], weights=rgb[..., c][vis], minlength=nb) / np.maximum(cnt, 1.0)
        for b in range(1, nb):                       # 빈 반지름은 안쪽 값으로
            if cnt[b] < 3:
                ring[b] = ring[b - 1]
        col[hid] = ring[bins[hid]]
    a = np.clip(R + 0.5 - rho, 0.0, 1.0)
    lum = col @ np.array([0.299, 0.587, 0.114], dtype=np.float32)

    # 동공: 붉은 덩어리 (보이는 쪽에서만 찾는다)
    red = (col[..., 0] > 85) & (col[..., 1] < 34) & (rho < r - 3) & vis
    lab, n = ndimage.label(red)
    if n == 0:
        raise SystemExit(f"eye {i}: pupil not found")
    sizes = ndimage.sum(red, lab, range(1, n + 1))
    pup = ndimage.binary_fill_holes(lab == (1 + int(np.argmax(sizes))))
    pup = ndimage.binary_dilation(pup, iterations=1)
    pys, pxs = np.nonzero(pup)
    pcx, pcy = float(pxs.mean()), float(pys.mean())
    pr = float(np.sqrt(pup.sum() / np.pi))
    pa = np.clip(ndimage.gaussian_filter(pup.astype(np.float32), 0.8) * 1.5 - 0.25, 0.0, 1.0)
    pcol = _nearest_fill(col, ndimage.binary_erosion(pup, iterations=2))
    _save(f"eye_{i}_pupil", pcol, pa, parts)

    # 눈알: 동공 자리를 주변 색으로 메운다
    hole = ndimage.binary_dilation(pup, iterations=4)
    ball = col.copy()
    known = disk & ~hole & (rho < r - 2) & (lum > OUTLINE_LUMA)
    fill = _blur3(_nearest_fill(col, known), 3.0)
    ball[hole] = fill[hole]
    _save(f"eye_{i}", ball, a, parts)

    # 덮개: 외곽선 고리 + 하이라이트(눈에서 가장 밝은 작은 덩어리)
    inside = (rho < r - 4) & ~hole
    grn = col[..., 1]
    lit = float(np.median(grn[inside & (grn > np.median(grn[inside]))]))
    top = float(np.percentile(grn[inside], 99.5))
    hi = (grn > lit + 0.55 * (top - lit)) & inside & (top - lit > 12.0)
    lab, n = ndimage.label(hi)
    if n:
        sizes = ndimage.sum(hi, lab, range(1, n + 1))
        keep = [k + 1 for k, s in enumerate(sizes) if 6 <= s <= 0.16 * np.pi * r * r]
        hi = np.isin(lab, keep)
    hi_a = np.clip(ndimage.gaussian_filter(ndimage.binary_dilation(hi, iterations=1).astype(np.float32), 0.8) * 1.5 - 0.25, 0.0, 1.0)
    edge_a = _smooth((rho - (r - 5.0)) / 2.5) * _smooth((OUTLINE_LUMA + 40.0 - lum) / 40.0)
    oa = np.maximum(hi_a, edge_a) * a
    _save(f"eye_{i}_over", col, oa, parts)
    return {"center": (cx, cy), "r": float(r - EYE_EDGE), "pupil": (pcx, pcy), "pr": pr}


def _grid_mesh(a, grid) -> tuple:
    ys, xs = np.nonzero(a > 0.02)
    x0, x1, y0, y1 = xs.min() - 5, xs.max() + 5, ys.min() - 5, ys.max() + 5
    nx = int(np.ceil((x1 - x0) / grid))
    ny = int(np.ceil((y1 - y0) / grid))
    gx = np.linspace(x0, x1, nx + 1)
    gy = np.linspace(y0, y1, ny + 1)
    index, verts, tris = {}, [], []

    def vid(i, j):
        if (i, j) not in index:
            index[(i, j)] = len(verts)
            verts.append((float(gx[i]), float(gy[j])))
        return index[(i, j)]

    for j in range(ny):
        for i in range(nx):
            cell = a[max(int(gy[j]), 0):int(gy[j + 1]) + 1, max(int(gx[i]), 0):int(gx[i + 1]) + 1]
            if cell.size and cell.max() > 0.02:
                p, q, r, s_ = vid(i, j), vid(i + 1, j), vid(i + 1, j + 1), vid(i, j + 1)
                tris += [(p, q, r), (p, r, s_)]
    return np.array(verts), tris


def body_weights(pts: np.ndarray, tail_soft: np.ndarray) -> dict:
    """몸통 본 가중치 (점 배열 Nx2 → 본 이름별 N 개)."""
    s = np.degrees(np.arctan2(-(pts[:, 1] - BODY_C[1]), pts[:, 0] - BODY_C[0]))
    out = {}
    up = [_smooth((s - a) / (b - a)) for a, b in UP_RAMPS]
    lo = [_smooth((-s - a) / (b - a)) for a, b in LO_RAMPS]
    out["body"] = 1.0 - up[0] - lo[0]
    out["up0"], out["up1"], out["up2"] = up[0] - up[1], up[1] - up[2], up[2]
    out["lo0"], out["lo1"], out["lo2"] = lo[0] - lo[1], lo[1] - lo[2], lo[2]
    h, w = tail_soft.shape
    xi = np.clip(pts[:, 0].round().astype(int), 0, w - 1)
    yi = np.clip(pts[:, 1].round().astype(int), 0, h - 1)
    tw = tail_soft[yi, xi]
    for k in out:
        out[k] = out[k] * (1.0 - tw)
    out["tail"] = tw
    return out


def wing_weights(pts: np.ndarray, cfg: dict) -> dict:
    """날개 본 가중치: 뿌리 → 끝 축에 내린 거리로 본에서 본으로 넘어간다. 뿌리 뒤쪽 조금만 몸통에 붙는다."""
    bones = wing_bones(cfg)
    root = np.array(cfg["root"], dtype=np.float64)
    d = np.array(cfg["tip"], dtype=np.float64) - root
    length = float(np.linalg.norm(d))
    d /= length
    seg = length / cfg["n"]
    p = (pts - root) @ d
    rr = [_smooth((p - (-34.0)) / 44.0)] + [_smooth((p - (k * seg - 0.2 * seg)) / (0.62 * seg)) for k in range(1, cfg["n"])]
    out = {"body": 1.0 - rr[0]}
    for k, (n, _) in enumerate(bones):
        out[n] = rr[k] - (rr[k + 1] if k + 1 < len(rr) else 0.0)
    return out


def build(size, rgb, luma, alpha, fg, wings, eye_of) -> None:
    h, w = fg.shape
    yy, xx = np.mgrid[0:h, 0:w]
    parts, eyes = {}, {}

    for i in range(len(EYES)):
        eyes[i] = build_eye(i, rgb, luma, alpha, eye_of, parts)

    # ── 몸통: 눈 자리는 눈꺼풀 색으로 ──
    body_rgb = rgb.copy()
    a_body = alpha.copy()
    for i, (cx, cy, r) in enumerate(EYES):
        rho = np.hypot(xx - cx, yy - cy)
        around = (rho > r + 7) & (rho < r + 16) & fg & (eye_of < 0) & (luma > 14)
        if around.sum() < 20:
            sock = np.array([40.0, 26.0, 86.0])
        else:
            px = rgb[around]
            lum = px @ np.array([0.299, 0.587, 0.114])
            lo_, hi_ = np.percentile(lum, 25), np.percentile(lum, 65)
            sock = px[(lum >= lo_) & (lum <= hi_)].mean(axis=0) * 0.74          # 감은 눈꺼풀: 둘레 살색을 조금 어둡게
        hole = rho <= r + EYE_EDGE + 1.0
        shade = _smooth((rho - (r - 12.0)) / 14.0)[..., None]          # 가장자리로 갈수록 더 어둡게
        body_rgb = np.where(hole[..., None], sock * (1.0 - 0.5 * shade), body_rgb)
        a_body = np.maximum(a_body, np.clip(r + EYE_EDGE - 1.5 - rho, 0.0, 1.0))
    _save("body", body_rgb, a_body, parts)

    # ── 날개: 레이어 그대로 ──
    for cfg in WINGS:
        arr = wings[cfg["name"]]
        a = arr[..., 3] / 255.0
        _save(cfg["name"], _nearest_fill(arr[..., :3], a > 0.97), a, parts)

    # ── 메시 ──
    tail_soft = ndimage.gaussian_filter(_poly_mask(TAIL_POLY, size).astype(np.float32), 9.0)
    meshes = {}
    v, tris = _grid_mesh(parts["body"]["alpha"], BODY_GRID)
    wts = body_weights(v, tail_soft)
    meshes["body"] = _mesh(v, tris, wts, [(n, BODY_PARENT[n], BODY_BONES[n]) for n in BODY_BONES])
    print(f"  body: {len(v)} verts, {len(tris)} tris")
    for cfg in WINGS:
        name = cfg["name"]
        v, tris = _grid_mesh(parts[name]["alpha"], cfg["grid"])
        wts = wing_weights(v, cfg)
        bones = [("body", "", BODY_BONES["body"])]
        prev = "body"
        for n, at in wing_bones(cfg):
            bones.append((n, prev, at))
            prev = n
        meshes[name] = _mesh(v, tris, wts, bones)
        print(f"  {name}: {len(v)} verts, {len(tris)} tris")

    # 눈이 얹히는 몸통 본 가중치
    centers = np.array([EYES[i][:2] for i in range(len(EYES))], dtype=np.float64)
    ew = body_weights(centers, tail_soft)
    for i in eyes:
        eyes[i]["bw"] = {k: float(ew[k][i]) for k in ew if ew[k][i] > 0.004}
    _write_data(parts, meshes, eyes)
    _write_preview(size, parts, meshes, eyes)


def _mesh(v, tris, wts, bones) -> dict:
    return {"verts": [(float(x), float(y)) for x, y in v], "tris": tris, "bones": bones,
            "weights": [list(np.clip(wts[n], 0.0, 1.0)) for n, _, _ in bones]}


def _nums(vals, nd=1) -> str:
    return "[" + ", ".join(str(round(float(v), nd)) for v in vals) + "]"


def _v2(x, y) -> str:
    return f"Vector2({round(float(x), 1)}, {round(float(y), 1)})"


def _write_data(parts: dict, meshes: dict, eyes: dict) -> None:
    fx, fy = FOOT
    main = ["body"] + [c["name"] for c in WINGS]
    xs0 = min(parts[n]["origin"][0] for n in main)
    xs1 = max(parts[n]["origin"][0] + parts[n]["size"][0] for n in main)
    top = min(parts[n]["origin"][1] for n in main)
    lines = [
        "## 공허 응시자 파츠·메시·본·눈 — tools/enemies/build_void_gazer.py 생성물. 손으로 고치지 말고 스크립트를 고쳐 다시 실행한다.",
        "## 좌표는 텍스처 px, 발밑이 원점. 원화는 왼쪽을 본다 (-x 가 앞).",
        "## mesh: verts·uvs 는 [x0, y0, x1, y1, ...], tris 는 꼭짓점 번호 3개씩, bones 는 [이름, 부모 본 이름(빈 문자열 = 없음), x, y],",
        "##       weights 는 본마다 꼭짓점별 가중치.",
        "## eye : pos = 눈 중심, offset = 중심에서 눈알 텍스처 왼쪽 위까지, r = 눈알 안쪽 반지름, pupil = 동공 중심(눈 중심 기준),",
        "##       pupil_offset·over_offset = 텍스처 왼쪽 위, pr = 동공 반지름, bw = 눈 중심에서의 몸통 본 가중치.",
        "extends RefCounted",
        "",
        f"const WIDTH := {float(xs1 - xs0)}      # 전체 가로 폭 (px, 날개 포함)",
        f"const TOP := {float(top - fy)}       # 맨 위 y (발밑 기준)",
        f"const BODY_CENTER := {_v2(BODY_BONES['body'][0] - fx, BODY_BONES['body'][1] - fy)}      # 몸통 본(초승달 가운데)",
        f"const HORN_TIP := {_v2(HORN_TIP[0] - fx, HORN_TIP[1] - fy)}      # 아래쪽 뿔 끝 (돌진 타점)",
        f"const HORN_BASE := {_v2(BODY_BONES['lo2'][0] - fx, BODY_BONES['lo2'][1] - fy)}",
        "## 날개: bones = 뿌리 → 끝 본 이름, axis = 날개 축 방향(rad, 뿌리 → 끝), len = 길이(px), near = 몸 앞쪽 쌍, fore = 앞날개",
        "const WINGS := [",
    ]
    for c in WINGS:
        d = np.array(c["tip"], float) - np.array(c["root"], float)
        names = ", ".join(f'"{n}"' for n, _ in wing_bones(c))
        lines.append(f'\t{{"name": "{c["name"]}", "bones": [{names}], "axis": {round(float(np.arctan2(d[1], d[0])), 4)}, "len": {round(float(np.hypot(*d)), 1)},'
                     f' "near": {"true" if c["near"] else "false"}, "fore": {"true" if c["fore"] else "false"}}},')
    lines += ["]", "## 뒤 → 앞 순서", "const PARTS := ["]

    def mesh_lines(name):
        m = meshes[name]
        ox, oy = parts[name]["origin"]
        flat = [c for v in m["verts"] for c in (v[0] - fx, v[1] - fy)]
        uvs = [c for v in m["verts"] for c in (v[0] - ox, v[1] - oy)]
        lines.append(f'\t{{"name": "{name}", "kind": "mesh",')
        lines.append(f'\t\t"verts": {_nums(flat)},')
        lines.append(f'\t\t"uvs": {_nums(uvs)},')
        lines.append(f'\t\t"tris": [{", ".join(str(i) for t in m["tris"] for i in t)}],')
        lines.append('\t\t"bones": [' + ", ".join(
            f'["{b[0]}", "{b[1]}", {round(b[2][0] - fx, 1)}, {round(b[2][1] - fy, 1)}]' for b in m["bones"]) + "],")
        lines.append('\t\t"weights": [' + ", ".join(_nums(wt, 3) for wt in m["weights"]) + "]},")

    for c in WINGS:
        if not c["near"]:
            mesh_lines(c["name"])
    mesh_lines("body")
    for i in EYE_ORDER:
        e = eyes[i]
        cx, cy = e["center"]
        ox, oy = parts[f"eye_{i}"]["origin"]
        pox, poy = parts[f"eye_{i}_pupil"]["origin"]
        vox, voy = parts[f"eye_{i}_over"]["origin"]
        px, py = e["pupil"]
        bw = ", ".join(f'"{k}": {round(v, 3)}' for k, v in e["bw"].items())
        lines.append(
            f'\t{{"name": "eye_{i}", "kind": "eye", "pos": {_v2(cx - fx, cy - fy)}, "offset": {_v2(ox - cx, oy - cy)}, "r": {round(e["r"], 1)},'
            f' "pupil": {_v2(px - cx, py - cy)}, "pupil_offset": {_v2(pox - px, poy - py)}, "pr": {round(e["pr"], 1)},'
            f' "over_offset": {_v2(vox - cx, voy - cy)}, "bw": {{{bw}}}}},')
    for c in WINGS:
        if c["near"]:
            mesh_lines(c["name"])
    lines += ["]", ""]
    DATA.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(DATA.name)


def _write_preview(size, parts: dict, meshes: dict, eyes: dict) -> None:
    """위: 다시 조립(메시·본 표시) / 눈알만(동공 없이) 조립.  아래: 눈 파츠를 3배로 늘어놓은 것(눈알 · 동공 · 덮개)."""
    def checker(w, h):
        yy, xx = np.mgrid[0:h, 0:w]
        c = np.where(((xx // 24) + (yy // 24)) % 2 == 0, 120, 160).astype(np.uint8)
        return Image.fromarray(np.dstack([c, c, c, np.full_like(c, 255)]), "RGBA")
    W, H = size
    sheet = checker(W * 2 + 60, H + 40 + 330)
    for col, with_pupil in ((0, True), (1, False)):
        x0 = col * (W + 40) + 10
        for name in [c["name"] for c in WINGS if not c["near"]] + ["body"]:
            sheet.alpha_composite(Image.open(OUT / f"{name}.png"), (x0 + parts[name]["origin"][0], 10 + parts[name]["origin"][1]))
        for i in EYE_ORDER:
            for suffix in ("", "_pupil", "_over"):
                if suffix == "_pupil" and not with_pupil:
                    continue
                n = f"eye_{i}{suffix}"
                sheet.alpha_composite(Image.open(OUT / f"{n}.png"), (x0 + parts[n]["origin"][0], 10 + parts[n]["origin"][1]))
        if col == 0:
            for name in [c["name"] for c in WINGS if c["near"]]:
                sheet.alpha_composite(Image.open(OUT / f"{name}.png"), (x0 + parts[name]["origin"][0], 10 + parts[name]["origin"][1]))
    dr = ImageDraw.Draw(sheet)
    for name, m in meshes.items():
        for t in m["tris"]:
            pts = [(m["verts"][i][0] + 10, m["verts"][i][1] + 10) for i in t]
            dr.line(pts + [pts[0]], fill=(0, 255, 255, 90), width=1)
        for b in m["bones"]:
            bx, by = b[2][0] + 10, b[2][1] + 10
            pb = next((o for o in m["bones"] if o[0] == b[1]), None)
            if pb:
                dr.line([(pb[2][0] + 10, pb[2][1] + 10), (bx, by)], fill=(255, 220, 0, 255), width=3)
            dr.ellipse([bx - 5, by - 5, bx + 5, by + 5], fill=(255, 60, 60, 255))
    x = 10
    for i in range(len(EYES)):
        for suffix in ("", "_pupil", "_over"):
            im = Image.open(OUT / f"eye_{i}{suffix}.png")
            im = im.resize((int(im.width * 1.5), int(im.height * 1.5)), Image.LANCZOS)
            y = H + 40 + {"": 0, "_pupil": 170, "_over": 170}[suffix]
            xo = x + (90 if suffix == "_over" else 0) if suffix else x
            sheet.alpha_composite(im, (xo, y))
        x += 185
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW)
    print(PREVIEW.name)


if __name__ == "__main__":
    seg = segment()
    debug_view(seg[0], seg[1], seg[3], seg[5], seg[6])
    if "--debug" not in sys.argv:
        build(*seg)
