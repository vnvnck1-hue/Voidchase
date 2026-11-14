"""공허 망령: 원화(tools/enemies/src/void_wraith_source.png)에서 배경을 걷어 내고 파츠·본 메시로 나눈다.

- 배경은 종이색과의 차이로 지운다 (그림 가장자리 + BG_SEEDS 에서 번져 들어감). 바닥 그림자는 SHADOW_Y 아래를 지운다.
- 파츠는 SEEDS(파츠 안쪽에 그은 선·점, 원본 px)에서 워터셰드로 나눈다: 경계가 어두운 외곽선 위에 놓이므로
  씨앗은 대충 그어도 된다. 나눈 뒤 각 파츠를 외곽선 쪽으로 OUTLINE_PX 만큼 넓혀 외곽선을 양쪽이 함께 갖는다.
- 뒤 파츠가 앞 파츠에 가린 곳은 UNDER 규칙으로 가까운 제 색을 끌어다 채운다 (파츠가 움직여도 구멍이 안 보이게).
- 핵(코어 보석)은 후드 속 어두운 구멍에서 밝기로 떼어 내고, 후드 쪽은 주변 색으로 메운다.
- 촉수 3개는 중심선(TENTACLES)을 따라 띠 메시 + 본 사슬, 후드는 격자 메시 + 자락 본 2개.
- 출력: assets/void_defense_enemies/void_wraith/<파츠>.png
        scripts/void_defense/vd_void_wraith_parts.gd (배치·메시·본: 생성물, 손으로 고치지 않는다)
        docs/void_wraith/parts_preview.png (검수용)

사용: C:/Python314/python.exe tools/enemies/build_void_wraith.py [--debug]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/enemies/src/void_wraith_source.png"
OUT = ROOT / "assets/void_defense_enemies/void_wraith"
DATA = ROOT / "scripts/void_defense/vd_void_wraith_parts.gd"
PREVIEW = ROOT / "docs/void_wraith/parts_preview.png"
DEBUG = ROOT / "docs/void_wraith/debug_labels.png"

BG_THRESH = 20        # 종이색과 채널 최대 차이가 이보다 작으면 배경
OUTLINE_LUMA = 34     # 이보다 어두우면 외곽선 (파츠 넓히기는 여기로만)
WALL_LUMA = 60        # 워터셰드 비용: 이보다 밝으면 0, 밝기 10 에서 최대 (외곽선이 가장 높은 벽)
OUTLINE_PX = 5        # 외곽선 쪽으로 넓히는 폭
PAD = 4
FOOT = (640, 986)     # 발밑: 바닥 그림자 중심

## 배경이 외곽선에 갇혀 가장자리에서 닿지 않는 곳 (고리 안쪽, 촉수 사이)
BG_SEEDS = [(560, 180), (900, 160), (690, 790), (1060, 800), (1100, 740), (1000, 880), (760, 900)]
## 바닥 그림자: 이 꺾은선 아래는 전부 지운다 (x, y)
SHADOW_LINE = [(0, 960), (1000, 968), (1130, 962), (1180, 975), (1536, 985)]

## 파츠 씨앗: 이름 → 꺾은선 목록 (원본 px). 뒤 → 앞 순서는 ORDER.
SEEDS = {
    "c_l": [[(540, 97), (470, 160), (468, 215)]],
    "c_tl": [[(690, 75), (625, 150)], [(640, 80), (610, 120)]],
    "c_tr": [[(800, 75), (900, 120)]],
    "c_r": [[(972, 112), (952, 205)]],
    "ring": [[(552, 121), (583, 114)], [(722, 90), (793, 92)], [(842, 195), (903, 178), (930, 163)], [(826, 218), (836, 228)],
             [(487, 187), (500, 212), (548, 231)], [(517, 187), (562, 210)], [(525, 215), (550, 220)]],
    "crest": [[(576, 290), (598, 245), (655, 218), (690, 292), (610, 352), (576, 290)], [(625, 290), (626, 291)]],
    "pendant": [[(615, 645), (616, 652)], [(615, 688), (615, 762)], [(600, 700), (632, 700)]],
    "hood": [[(690, 205), (742, 155), (755, 215)], [(720, 250), (810, 250)], [(820, 205), (850, 320)],
             [(520, 380), (430, 520)], [(700, 380), (860, 520)], [(500, 440), (610, 420), (730, 470)],
             [(610, 470), (610, 620)], [(500, 560), (720, 560)], [(260, 680), (380, 560), (420, 470)],
             [(250, 690), (440, 760), (520, 700)], [(330, 640), (450, 640), (500, 690)],
             [(760, 600), (900, 560), (1050, 660)], [(800, 640), (900, 640), (890, 740)], [(900, 700), (1000, 680)],
             [(740, 680), (800, 690), (850, 720)]],
    "t1": [[(1000, 742), (1060, 752), (1100, 727), (1150, 702), (1190, 696)], [(1215, 695), (1270, 700)]],
    "t2": [[(782, 735), (820, 780), (885, 822), (960, 832), (1035, 815), (1100, 790), (1140, 780)], [(1180, 800), (1240, 810)]],
    "t3": [[(585, 740), (590, 790), (615, 838), (665, 864), (715, 864), (762, 856), (835, 876), (910, 922), (985, 940),
            (1060, 925), (1110, 901), (1165, 884)], [(1215, 915), (1320, 948)]],
}
ORDER = ["t1", "t2", "t3", "ring", "c_l", "c_tl", "c_tr", "c_r", "hood", "core", "pendant", "crest"]

## 뒤 파츠가 앞 파츠 밑으로 이어지는 곳: 이름 → [(가린 파츠들, 번지는 폭 px)]
UNDER = {
    "ring": [(("c_l", "c_tl", "c_tr", "c_r", "hood", "crest"), 0)],      # RING_BAND 를 따라 채운다
    "hood": [(("crest", "pendant"), 400)],
    "t1": [(("hood",), 46)],
    "t2": [(("hood", "pendant"), 40)],
    "t3": [(("hood", "pendant"), 40)],
}
## 고리가 수정 조각·후드 뒤로 지나가는 길 (이 띠 안에서만 가린 곳을 채운다)
RING_BAND = [[(500, 150), (530, 130), (552, 121), (583, 114), (650, 100), (722, 91), (793, 92), (850, 100), (905, 120), (935, 148), (932, 163)],
             [(487, 187), (500, 212), (548, 231), (585, 240)], [(930, 163), (903, 178), (842, 195), (826, 222), (812, 236)]]
RING_BAND_PX = 22
## 핵: 후드 속 구멍에서 밝은 보석·고리만 떼어 낸다
CORE_CENTER = (612, 548)
CORE_RADIUS = 132
CORE_LO, CORE_HI = 78.0, 130.0      # 붉은 채널이 LO → HI 사이에서 알파 0 → 1

## 파츠(스프라이트) 회전 중심
PIVOT = {"ring": (700, 165), "c_l": (495, 160), "c_tl": (655, 115), "c_tr": (850, 100), "c_r": (962, 160),
         "core": (613, 540), "pendant": (616, 634), "crest": (628, 290)}

## 촉수: 뿌리 → 끝 중심선과 띠 반폭. 중심선 점마다 본 하나.
TENTACLES = {
    "t1": {"line": [(915, 705), (965, 722), (1010, 745), (1060, 753), (1102, 728), (1150, 702), (1195, 696), (1240, 697), (1288, 702)],
           "half": [40, 38, 34, 32, 32, 34, 40, 40, 30]},
    "t2": {"line": [(745, 680), (780, 735), (822, 782), (885, 822), (960, 832), (1035, 815), (1100, 790), (1145, 782), (1200, 805), (1256, 811)],
           "half": [52, 50, 48, 50, 50, 46, 42, 46, 48, 30]},
    "t3": {"line": [(590, 690), (586, 745), (592, 795), (617, 838), (665, 864), (715, 864), (762, 856), (835, 876), (910, 922),
                    (985, 940), (1060, 925), (1110, 901), (1165, 886), (1250, 928), (1338, 950)],
           "half": [56, 56, 54, 50, 48, 46, 46, 46, 50, 52, 50, 46, 56, 62, 36]},
}
## 후드 격자 메시와 본 (자락이 따로 펄럭이게)
HOOD_GRID = 44
HOOD_BONES = {"hood": (640, 420), "flap_l": (430, 560), "flap_r": (840, 560)}


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
    """known 이 아닌 픽셀을 가장 가까운 known 픽셀 색으로."""
    idx = ndimage.distance_transform_edt(~known, return_distances=False, return_indices=True)
    return col[idx[0], idx[1]]


def segment():
    src = Image.open(SRC).convert("RGB")
    size = src.size
    rgb = np.asarray(src).astype(np.float32)
    luma = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    paper = np.median(rgb[:40].reshape(-1, 3), axis=0)
    smooth = np.dstack([ndimage.gaussian_filter(rgb[..., c], 1.0) for c in range(3)])
    near = np.abs(smooth - paper).max(axis=2) < BG_THRESH
    # 그림자: 꺾은선 아래 전부
    xs = np.arange(size[0])
    line_y = np.interp(xs, [p[0] for p in SHADOW_LINE], [p[1] for p in SHADOW_LINE])
    shadow = np.arange(size[1])[:, None] > line_y[None, :]
    lab, _ = ndimage.label(near | shadow)
    seeds = {lab[0, 0], lab[0, -1], lab[-1, 0], lab[-1, -1]}
    for x, y in BG_SEEDS:
        if lab[y, x] == 0:
            print(f"!! BG seed {x},{y} is not on paper")
        seeds.add(lab[y, x])
    seeds.discard(0)
    bg = np.isin(lab, list(seeds)) | shadow
    fg = ~bg
    fg = ndimage.binary_opening(fg, iterations=1)
    lab, n = ndimage.label(fg)
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    fg = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= 300])
    fg = ndimage.binary_fill_holes(fg) & ~np.isin(ndimage.label(near | shadow)[0], list(seeds)) | fg

    # 워터셰드: 어두운 외곽선이 높은 벽
    cost = (255.0 * np.clip((WALL_LUMA - ndimage.gaussian_filter(luma, 0.7)) / (WALL_LUMA - 10.0), 0.0, 1.0)).astype(np.uint8)
    names = [n for n in ORDER if n in SEEDS]
    # 실루엣 가장자리의 밝은 테두리(배경과 섞인 픽셀)를 타고 라벨이 새지 않게 안쪽에서만 나눈다
    inner = ndimage.binary_erosion(fg, iterations=3)
    markers = np.zeros(size[::-1], dtype=np.int16)
    markers[~inner] = -1
    for i, name in enumerate(names):
        m = _polyline_mask(SEEDS[name], size) & inner
        if not m.any():
            print(f"!! seed {name} empty")
        markers[m] = i + 1
    labels = ndimage.watershed_ift(cost, markers)
    # 가장자리(와 배경 표식이 번져 들어간 어두운 외곽선)는 가장 가까운 파츠로
    idx = ndimage.distance_transform_edt(labels <= 0, return_distances=False, return_indices=True)
    labels = labels[idx[0], idx[1]]
    labels[bg] = -1
    return src, rgb, luma, fg, labels, names


def debug_view(rgb, labels, names) -> None:
    fixed = {"t1": (255, 0, 0), "t2": (255, 140, 0), "t3": (255, 255, 0), "ring": (0, 200, 0), "c_l": (0, 255, 255),
             "c_tl": (0, 80, 255), "c_tr": (255, 0, 255), "c_r": (160, 160, 160), "hood": (90, 40, 140),
             "pendant": (140, 80, 20), "crest": (160, 255, 80)}
    pal = {i + 1: fixed[n] for i, n in enumerate(names)}
    out = rgb.copy() * 0.4
    for i, c in pal.items():
        out[labels == i] += np.array(c) * 0.6
    out[labels < 0] = (255, 255, 255)
    edge = np.zeros(labels.shape, bool)
    edge[:, 1:] |= labels[:, 1:] != labels[:, :-1]
    edge[1:, :] |= labels[1:, :] != labels[:-1, :]
    out[edge] = (0, 0, 0)
    im = Image.fromarray(out.clip(0, 255).astype(np.uint8))
    dr = ImageDraw.Draw(im)
    for name in names:
        for ln in SEEDS[name]:
            dr.line(ln, fill=(255, 255, 0), width=1)
    for name, t in TENTACLES.items():
        dr.line(t["line"], fill=(0, 255, 255), width=1)
        for (x, y), h in zip(t["line"], t["half"]):
            dr.ellipse([x - 3, y - 3, x + 3, y + 3], outline=(255, 0, 0))
    DEBUG.parent.mkdir(parents=True, exist_ok=True)
    im.save(DEBUG)
    print(DEBUG)


def _smooth(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def build(src, rgb, luma, fg, labels, names) -> None:
    size = src.size
    h, w = labels.shape
    solid_a = ndimage.gaussian_filter(ndimage.binary_erosion(fg, iterations=1).astype(np.float32), 0.9)
    solid_a = np.clip((solid_a - 0.25) / 0.5, 0.0, 1.0)
    # 실루엣 가장자리는 종이색이 섞여 있으므로 안쪽 색을 끌어다 쓴다
    rgb = _nearest_fill(rgb, ndimage.binary_erosion(fg, iterations=2))
    dark = (ndimage.gaussian_filter(luma, 0.6) < OUTLINE_LUMA) & fg
    base = {n: labels == i + 1 for i, n in enumerate(names)}

    # 핵: 후드 속 구멍(어두운 면 + 그 안에 갇힌 밝은 보석)에서 밝은 부분만
    yy, xx = np.mgrid[0:h, 0:w]
    disk = (xx - CORE_CENTER[0]) ** 2 + (yy - CORE_CENTER[1]) ** 2 < CORE_RADIUS ** 2
    lab, _ = ndimage.label((luma < 70) & disk & base["hood"])
    cav = ndimage.binary_fill_holes(lab == lab[CORE_CENTER[1] + 60, CORE_CENTER[0] - 70]) & base["hood"]
    cav = ndimage.binary_erosion(cav, iterations=3)
    core_a = _smooth((rgb[..., 0] - CORE_LO) / (CORE_HI - CORE_LO)) * cav
    core_a = ndimage.gaussian_filter(core_a, 0.8)
    hood_rgb = rgb.copy()
    hole = ndimage.binary_dilation(core_a > 0.01, iterations=4)
    filled = _nearest_fill(rgb, ~hole & cav)
    filled = np.dstack([ndimage.gaussian_filter(filled[..., c], 9.0) for c in range(3)])
    hood_rgb[hole] = filled[hole]

    parts = {}
    for name in ORDER:
        if name == "core":
            col, a = rgb, core_a
        else:
            m = base[name]
            # 외곽선은 맞닿은 파츠가 함께 갖는다
            m = ndimage.binary_dilation(m, iterations=OUTLINE_PX, mask=m | dark)
            col = hood_rgb if name == "hood" else rgb
            for fronts, px in UNDER.get(name, []):
                front = np.zeros_like(m)
                for f in fronts:
                    front |= base[f]
                if name == "ring":
                    grown = m | (_polyline_mask(RING_BAND, size, RING_BAND_PX) & front)
                else:
                    grown = ndimage.binary_dilation(m, iterations=px, mask=m | front)
                if name in TENTACLES:
                    grown &= m | _strip_mask(TENTACLES[name], size, 0.8)
                under = grown & ~m
                if under.any():
                    fill = _nearest_fill(col, base[name] & ~dark)
                    fill = np.dstack([ndimage.gaussian_filter(fill[..., c], 5.0) for c in range(3)])
                    col = np.where(under[..., None], fill, col)
                    m = grown
            a = np.clip(ndimage.gaussian_filter(m.astype(np.float32), 0.7) * 1.6 - 0.3, 0.0, 1.0) * solid_a
        ys, xs = np.nonzero(a > 0.02)
        y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, h)
        x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, w)
        out = np.dstack([col[y0:y1, x0:x1], a[y0:y1, x0:x1, None] * 255.0]).clip(0, 255).astype(np.uint8)
        OUT.mkdir(parents=True, exist_ok=True)
        Image.fromarray(out, "RGBA").save(OUT / f"{name}.png")
        parts[name] = {"origin": (x0, y0), "size": (x1 - x0, y1 - y0), "alpha": a}
        print(f"{name}: {x1 - x0}x{y1 - y0} @ {x0},{y0}")

    meshes = {}
    for name, t in TENTACLES.items():
        meshes[name] = _strip_mesh(name, t)
        cover = _tri_mask(meshes[name], size)
        miss = int(((parts[name]["alpha"] > 0.1) & ~cover).sum())
        print(f"  {name} strip: {len(t['line'])} bones, {miss} px outside the strip")
    meshes["hood"] = _hood_mesh(parts["hood"])
    _write_data(parts, meshes)
    _write_preview(parts, meshes, size)


def _strip_sides(t, k=1.0):
    pts = np.array(t["line"], dtype=np.float64)
    tan = np.gradient(pts, axis=0)
    tan /= np.linalg.norm(tan, axis=1, keepdims=True)
    nor = np.stack([-tan[:, 1], tan[:, 0]], axis=1)
    half = np.array(t["half"], dtype=np.float64)[:, None] * k
    return pts, tan, pts + nor * half, pts - nor * half


def _strip_mask(t, size, k) -> np.ndarray:
    _, _, left, right = _strip_sides(t, k)
    im = Image.new("L", size, 0)
    dr = ImageDraw.Draw(im)
    for i in range(len(left) - 1):
        dr.polygon([tuple(left[i]), tuple(right[i]), tuple(right[i + 1]), tuple(left[i + 1])], fill=255)
    return np.asarray(im) > 0


def _strip_mesh(name, t) -> dict:
    """중심선 점마다 단면(왼쪽·오른쪽 꼭짓점) 하나, 끝에는 덮개 단면 하나 더. 본 i 는 중심선 점 i."""
    pts, tan, left, right = _strip_sides(t)
    n = len(pts)
    cap = pts[-1] + tan[-1] * 14.0
    verts, weights = [], [[] for _ in range(n)]

    def add(p, wmap):
        verts.append((float(p[0]), float(p[1])))
        for b in range(n):
            weights[b].append(wmap.get(b, 0.0))

    for i in range(n):
        wmap = {0: 1.0} if i == 0 else {i - 1: 0.5, i: 0.5}
        add(left[i], wmap)
        add(right[i], wmap)
    add(cap + (left[-1] - pts[-1]) * 0.5, {n - 1: 1.0})
    add(cap + (right[-1] - pts[-1]) * 0.5, {n - 1: 1.0})
    tris = []
    for i in range(n):
        a, b, c, d = 2 * i, 2 * i + 1, 2 * i + 2, 2 * i + 3
        tris += [(a, b, d), (a, d, c)]
    bones = [(f"{name}_{i}", f"{name}_{i - 1}" if i else "hood", float(pts[i][0]), float(pts[i][1])) for i in range(n)]
    return {"verts": verts, "tris": tris, "bones": bones, "weights": weights}


def _hood_mesh(part) -> dict:
    """후드: 격자 메시. 본은 몸통(hood) + 양쪽 자락(flap_l·flap_r), 자락 가중치는 아래·바깥쪽으로 갈수록 커진다."""
    a = part["alpha"]
    ys, xs = np.nonzero(a > 0.02)
    x0, x1, y0, y1 = xs.min() - 6, xs.max() + 6, ys.min() - 6, ys.max() + 6
    nx = int(np.ceil((x1 - x0) / HOOD_GRID))
    ny = int(np.ceil((y1 - y0) / HOOD_GRID))
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
    v = np.array(verts)
    lx = HOOD_BONES["flap_l"][0]
    rx = HOOD_BONES["flap_r"][0]
    down = _smooth((v[:, 1] - 470.0) / 170.0)
    wl = _smooth((lx + 90.0 - v[:, 0]) / 230.0) * down
    wr = _smooth((v[:, 0] - (rx - 90.0)) / 230.0) * down
    bnames = list(HOOD_BONES)
    bones = [(n, "" if n == "hood" else "hood", float(HOOD_BONES[n][0]), float(HOOD_BONES[n][1])) for n in bnames]
    return {"verts": verts, "tris": tris, "bones": bones, "weights": [list(1.0 - wl - wr), list(wl), list(wr)]}


def _tri_mask(mesh, size) -> np.ndarray:
    im = Image.new("L", size, 0)
    dr = ImageDraw.Draw(im)
    for t in mesh["tris"]:
        dr.polygon([mesh["verts"][i] for i in t], fill=255, outline=255)
    return np.asarray(im) > 0


def _nums(vals, nd=1) -> str:
    return "[" + ", ".join(str(round(float(v), nd)) for v in vals) + "]"


def _write_data(parts: dict, meshes: dict) -> None:
    fx, fy = FOOT
    xs0 = min(p["origin"][0] for p in parts.values())
    xs1 = max(p["origin"][0] + p["size"][0] for p in parts.values())
    top = min(p["origin"][1] for p in parts.values())
    hood_x0 = parts["hood"]["origin"][0]
    hood_x1 = hood_x0 + parts["hood"]["size"][0]
    lines = [
        "## 공허 망령 파츠·메시·본 — tools/enemies/build_void_wraith.py 생성물. 손으로 고치지 말고 스크립트를 고쳐 다시 실행한다.",
        "## 좌표는 텍스처 px, 발밑(바닥 그림자 중심)이 원점.",
        "## sprite: pos = 파츠 피벗, offset = 피벗에서 텍스처 왼쪽 위까지.",
        "## mesh: verts·uvs 는 [x0, y0, x1, y1, ...], tris 는 꼭짓점 번호 3개씩, bones 는 [이름, 부모 본 이름(빈 문자열 = 없음), x, y],",
        "##       weights 는 본마다 꼭짓점별 가중치.",
        "extends RefCounted",
        "",
        f"const WIDTH := {float(xs1 - xs0)}      # 전체 가로 폭 (px, 촉수 포함)",
        f"const BODY_WIDTH := {float(hood_x1 - hood_x0)}      # 후드 가로 폭",
        f"const BODY_X := {float((hood_x0 + hood_x1) * 0.5 - fx)}      # 후드 가운데 x",
        f"const TOP := {float(top - fy)}       # 맨 위 y (발밑 기준)",
        "## 뒤 → 앞 순서",
        "const PARTS := [",
    ]
    for name in ORDER:
        ox, oy = parts[name]["origin"]
        if name in meshes:
            m = meshes[name]
            flat = [c for v in m["verts"] for c in (v[0] - fx, v[1] - fy)]
            uvs = [c for v in m["verts"] for c in (v[0] - ox, v[1] - oy)]
            lines.append(f'\t{{"name": "{name}", "kind": "mesh",')
            lines.append(f'\t\t"verts": {_nums(flat)},')
            lines.append(f'\t\t"uvs": {_nums(uvs)},')
            lines.append(f'\t\t"tris": [{", ".join(str(i) for t in m["tris"] for i in t)}],')
            lines.append('\t\t"bones": [' + ", ".join(
                f'["{b[0]}", "{b[1]}", {round(b[2] - fx, 1)}, {round(b[3] - fy, 1)}]' for b in m["bones"]) + "],")
            lines.append('\t\t"weights": [' + ", ".join(_nums(wt, 3) for wt in m["weights"]) + "]},")
        else:
            px, py = PIVOT[name]
            lines.append(
                f'\t{{"name": "{name}", "kind": "sprite", "pos": Vector2({px - fx}, {py - fy}), "offset": Vector2({ox - px}, {oy - py})}},')
    lines += ["]", ""]
    DATA.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(DATA.name)


def _write_preview(parts: dict, meshes: dict, size) -> None:
    """왼쪽: 다시 조립한 모습(체크무늬 위) + 메시·본, 오른쪽: 파츠를 벌려 놓은 모습."""
    def checker(w, h):
        yy, xx = np.mgrid[0:h, 0:w]
        c = np.where(((xx // 24) + (yy // 24)) % 2 == 0, 150, 185).astype(np.uint8)
        return Image.fromarray(np.dstack([c, c, c, np.full_like(c, 255)]), "RGBA")
    x0 = min(p["origin"][0] for p in parts.values()) - 60
    y0 = min(p["origin"][1] for p in parts.values()) - 60
    x1 = max(p["origin"][0] + p["size"][0] for p in parts.values()) + 60
    y1 = max(p["origin"][1] + p["size"][1] for p in parts.values()) + 60
    w, h = x1 - x0, y1 - y0
    sheet = checker(w * 2 + 420, h + 380)
    spread = {"t1": (150, 40), "t2": (150, 150), "t3": (60, 280), "ring": (0, -40), "c_l": (-70, -70), "c_tl": (-20, -110),
              "c_tr": (40, -110), "c_r": (100, -60), "hood": (0, 60), "core": (-380, 60), "pendant": (-330, 250), "crest": (-330, -60)}
    dr = ImageDraw.Draw(sheet)
    for name in ORDER:
        im = Image.open(OUT / f"{name}.png")
        ox, oy = parts[name]["origin"]
        sheet.alpha_composite(im, (ox - x0, oy - y0 + 60))
        dx, dy = spread[name]
        sheet.alpha_composite(im, (w + 330 + ox - x0 + dx, oy - y0 + 120 + dy))
    for name, m in meshes.items():
        for t in m["tris"]:
            pts = [(m["verts"][i][0] - x0, m["verts"][i][1] - y0 + 60) for i in t]
            dr.line(pts + [pts[0]], fill=(0, 255, 255, 255), width=1)
        for b in m["bones"]:
            bx, by = b[2] - x0, b[3] - y0 + 60
            pb = next((o for o in m["bones"] if o[0] == b[1]), None)
            if pb:
                dr.line([(pb[2] - x0, pb[3] - y0 + 60), (bx, by)], fill=(255, 220, 0, 255), width=3)
            dr.ellipse([bx - 5, by - 5, bx + 5, by + 5], fill=(255, 60, 60, 255))
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW)
    print(PREVIEW.name)


if __name__ == "__main__":
    src, rgb, luma, fg, labels, names = segment()
    debug_view(rgb, labels, names)
    if "--debug" not in sys.argv:
        build(src, rgb, luma, fg, labels, names)
