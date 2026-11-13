# 건너 투사체(에너지 볼트)용 텍스처 4장 생성 (2026-11-12). 비주얼 셰이더 vfx/gun_bolt/gun_bolt.tres 가 겹쳐 쓴다.
# 레퍼런스: 오른쪽 끝이 뾰족한 창날 모양 볼트. 흰 코어 → 분홍·라일락 → 보라 → 남색 꼬리, 뒤로 벗겨지는 불꽃 혀, 떨어져 나간 조각.
#   bolt_shape.png   1024x256  손으로 그린 듯한 실루엣 3겹의 거리장 (0.5 = 가장자리, 1px = 1/128)
#                              R 바깥 몸통(보라·남색)  G 가운데 층(파랑·라일락·분홍)  B 코어(흰색)
#                              거리장이라 셰이더가 문턱값으로 칼같은 셀 경계를 내고, 노이즈로 가장자리를 갉고, 넓게 풀어 후광을 만든다
#   bolt_flow.png    512x256   가로·세로 이어지는 흐름 노이즈.  R 긴 결(굽이·어두운 틈)  G 가는 결(청록 줄)  B 혀 모양 덩어리(갉기)
#   bolt_shards.png  512x256   가로로 이어지는 각진 조각.  R 조각 마스크  G 조각마다 다른 번호(색·깜빡임)
#   bolt_ramp.png    256x4     길이 방향 색 띠 4줄 (왼쪽 꼬리 → 오른쪽 촉).  0 바깥  1 가운데  2 코어  3 후광
# 실행: C:/Python314/python.exe tools/vfx/build_gun_bolt_textures.py   → assets/vfx/void_defense/gun_bolt/
import os, random
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "vfx", "void_defense", "gun_bolt")
W, H = 1024, 256
SS = 2            # 실루엣은 2배로 그려 거리장을 낸 뒤 줄인다
SPREAD = 128.0    # 거리장 범위(px, 최종 해상도): 값 0.5 ± 0.5 가 ±64px
YS = 0.62         # 세로 납작 배율: 레퍼런스처럼 길이:굵기 ≈ 9:1 의 날렵한 창 (아래 좌표는 납작하기 전 값)


def blade(p0, p1, p2, w, a=1.6, b=1.0, n=48):
    """양 끝이 뾰족한 날 한 장. p0(꼬리) → p1(굽이) → p2(촉) 2차 베지어 중심선, 반폭 w (세로 반높이 = 1).
    폭 분포 s^a (1-s)^b : a 가 크면 꼬리가 길고 가늘다. 좌표는 x 0..1, y -1..1 (위가 음수)."""
    p0, p1, p2, w = (p0[0], p0[1] * YS), (p1[0], p1[1] * YS), (p2[0], p2[1] * YS), w * YS
    pts_l, pts_r = [], []
    peak = (a / (a + b)) ** a * (b / (a + b)) ** b
    for i in range(n + 1):
        s = i / n
        x = (1 - s) ** 2 * p0[0] + 2 * s * (1 - s) * p1[0] + s * s * p2[0]
        y = (1 - s) ** 2 * p0[1] + 2 * s * (1 - s) * p1[1] + s * s * p2[1]
        dx = 2 * (1 - s) * (p1[0] - p0[0]) + 2 * s * (p2[0] - p1[0])
        dy = 2 * (1 - s) * (p1[1] - p0[1]) + 2 * s * (p2[1] - p1[1])
        # 픽셀 공간에서 법선 (x 는 W, y 는 H/2 배)
        px, py = dx * W, dy * H * 0.5
        ln = max((px * px + py * py) ** 0.5, 1e-6)
        nx, ny = -py / ln, px / ln
        hw = w * (s ** a) * ((1 - s) ** b) / peak * H * 0.5
        cx, cy = x * W, (y * 0.5 + 0.5) * H
        pts_l.append(((cx + nx * hw) * SS, (cy + ny * hw) * SS))
        pts_r.append(((cx - nx * hw) * SS, (cy - ny * hw) * SS))
    return pts_l + pts_r[::-1]


def straight(x0, y0, x1, y1, w, a=1.6, b=1.0):
    return blade((x0, y0), ((x0 + x1) * 0.5, (y0 + y1) * 0.5), (x1, y1), w, a, b)


def sdf(add, sub=()):
    img = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(img)
    for poly in add:
        d.polygon(poly, fill=255)
    for poly in sub:
        d.polygon(poly, fill=0)
    m = np.asarray(img) > 127
    dist = ndimage.distance_transform_edt(m) - ndimage.distance_transform_edt(~m)
    dist = dist / SS                                   # 최종 해상도 px
    v = np.clip(0.5 + dist / SPREAD, 0.0, 1.0)
    v = v.reshape(H, SS, W, SS).mean(axis=(1, 3))      # 2배 → 1배
    return v


_wob = random.Random(5)     # 혀마다 다른 굵기 흔들림 (손으로 그린 듯 불규칙하게)


def lick(pts, w, a=0.75, b=1.1, n=56, wob=0.22):
    """불꽃 혀 한 장: 점들을 지나는 스플라인(캣멀롬) 중심선. pts[0] = 자유로운 끝(뾰족), pts[-1] = 몸통 속 뿌리.
    끝 쪽 점을 가파르게 올리면 끝이 위로 말려 올라간 갈고리가 된다. 좌표는 blade 와 같다 (납작하기 전 값)."""
    P = [(x, y * YS) for x, y in pts]
    w = w * YS
    P = [P[0]] + P + [P[-1]]
    segs = len(P) - 3
    peak = (a / (a + b)) ** a * (b / (a + b)) ** b
    cl = []
    for i in range(n + 1):
        u = i / n * segs
        k = min(int(u), segs - 1)
        t = u - k
        p0, p1, p2, p3 = P[k], P[k + 1], P[k + 2], P[k + 3]
        pos, tan = [], []
        for c in (0, 1):
            pos.append(0.5 * ((2 * p1[c]) + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t * t + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t ** 3))
            tan.append(0.5 * ((-p0[c] + p2[c]) + 2 * (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t + 3 * (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t * t))
        cl.append((pos, tan))
    left, right = [], []
    f1, f2, ph1, ph2 = _wob.uniform(5, 9), _wob.uniform(11, 17), _wob.uniform(0, 6.28), _wob.uniform(0, 6.28)
    lean = _wob.uniform(-0.35, 0.35)      # 한쪽 가장자리만 더 부풀린다 (좌우 비대칭)
    for i, (pos, tan) in enumerate(cl):
        sv = i / n
        px, py = tan[0] * W, tan[1] * H * 0.5
        ln = max((px * px + py * py) ** 0.5, 1e-6)
        nx, ny = -py / ln, px / ln
        hw = w * (sv ** a) * ((1 - sv) ** b) / peak * H * 0.5
        k1 = 1.0 + wob * (0.6 * np.sin(sv * f1 + ph1) + 0.4 * np.sin(sv * f2 + ph2))
        k2 = 1.0 + wob * (0.6 * np.sin(sv * f1 * 1.3 + ph2) + 0.4 * np.sin(sv * f2 * 0.8 + ph1))
        cx, cy = pos[0] * W, (pos[1] * 0.5 + 0.5) * H
        left.append(((cx + nx * hw * k1 * (1 + lean)) * SS, (cy + ny * hw * k1 * (1 + lean)) * SS))
        right.append(((cx - nx * hw * k2 * (1 - lean)) * SS, (cy - ny * hw * k2 * (1 - lean)) * SS))
    return left + right[::-1]


def twig(pts, dx, dy, k=0.8):
    """곁가지: 혀의 끝 쪽 절반을 비켜 놓은 작은 혀 (큰 혀에 겹쳐 덩어리가 불규칙해진다)."""
    m = len(pts) // 2 + 1
    return [(x + dx * (1 - i / (m - 1)) , y + dy * (1 - i / (m - 1)) * k) for i, (x, y) in enumerate(pts[:m])] + [pts[m] if m < len(pts) else pts[-1]]


def inset(pts, k):
    """혀의 끝을 뿌리 쪽으로 k 만큼 당긴 안쪽 층용 점들."""
    root = pts[-1]
    return [(x + (root[0] - x) * k * (1 - i / (len(pts) - 1)), y + (root[1] - y) * k * (1 - i / (len(pts) - 1))) for i, (x, y) in enumerate(pts)]


def build_shape():
    # 혀: 몸통에서 뒤로 벗겨져 끝이 바깥으로 말려 올라간다 (레퍼런스의 갈고리 모양 불꽃). 위 4장, 아래 4장
    T1 = [(0.43, -0.80), (0.50, -0.54), (0.64, -0.40), (0.80, -0.26), (0.92, -0.07)]
    T2 = [(0.69, -0.95), (0.735, -0.62), (0.82, -0.40), (0.90, -0.20), (0.952, -0.04)]
    T3 = [(0.22, -0.62), (0.31, -0.40), (0.48, -0.33), (0.66, -0.26), (0.80, -0.15)]
    T4 = [(0.565, -1.00), (0.615, -0.72), (0.71, -0.53), (0.84, -0.28)]
    # 아래쪽은 짧고 납작하게: 레퍼런스는 덩어리가 위쪽에 몰리고 아래는 평평하다 (위아래 비대칭)
    B1 = [(0.56, 0.50), (0.64, 0.40), (0.74, 0.33), (0.85, 0.24), (0.93, 0.09)]
    B2 = [(0.76, 0.62), (0.80, 0.44), (0.86, 0.31), (0.92, 0.17), (0.955, 0.06)]
    B3 = [(0.33, 0.40), (0.44, 0.31), (0.58, 0.28), (0.70, 0.24), (0.82, 0.17)]
    B4 = [(0.66, 0.66), (0.70, 0.50), (0.78, 0.40), (0.87, 0.27)]
    # ---- 바깥 몸통: 큰 창날 + 꼬리 쪽 긴 결 + 혀
    outer = [
        straight(0.10, 0.00, 0.972, 0.02, 0.29, 2.6, 1.3),            # 큰 창날 (가장 넓은 곳 ≈ 0.68)
        # 꼬리 결: 곧은 날 대신 완만하게 휘어 흐르는 띠 (끝이 살짝 들리거나 처진다)
        lick([(0.02, -0.30), (0.20, -0.16), (0.45, -0.10), (0.80, -0.11)], 0.10, 1.2, 1.1, wob=0.18),
        lick([(0.00, 0.30), (0.18, 0.18), (0.42, 0.12), (0.76, 0.13)], 0.09, 1.1, 1.2, wob=0.18),
        lick([(0.12, -0.46), (0.30, -0.30), (0.56, -0.20), (0.86, -0.15)], 0.075, 1.3, 1.0, wob=0.2),
        lick([(0.18, 0.46), (0.36, 0.33), (0.58, 0.22), (0.82, 0.17)], 0.07, 1.2, 1.0, wob=0.2),
        lick([(0.04, 0.10), (0.22, 0.03), (0.40, 0.02), (0.60, 0.02)], 0.07, 1.0, 1.3, wob=0.15),
        lick(T1, 0.19), lick(T2, 0.125), lick(T3, 0.115), lick(T4, 0.085),
        lick(B1, 0.10), lick(B2, 0.07), lick(B3, 0.065), lick(B4, 0.04),
        lick([(0.30, -0.78), (0.40, -0.56), (0.56, -0.46), (0.74, -0.36)], 0.10),          # 위쪽 어두운 껍질을 이루는 큰 혀
        # 곁가지: 큰 혀에 비켜 겹친 작은 혀
        lick(twig(T1, -0.05, -0.16), 0.07), lick(twig(T2, 0.03, -0.14), 0.05), lick(twig(T3, -0.06, 0.10), 0.05),
        lick(twig(B1, -0.05, 0.08), 0.04), lick(twig(T4, -0.05, -0.10), 0.045),
    ]
    # 몸통 속 어두운 틈 (배경이 비치는 가는 칼집) + 혀와 몸통 사이 틈
    slits = [
        lick([(0.26, -0.30), (0.40, -0.25), (0.54, -0.215), (0.70, -0.17)], 0.075, 0.9, 1.5, wob=0.12),   # 큰 어두운 쐐기
        straight(0.33, 0.185, 0.62, 0.15, 0.02, 1.0, 1.5),
        lick([(0.50, -0.36), (0.62, -0.31), (0.74, -0.25), (0.85, -0.17)], 0.04, 1.0, 1.3),
        lick([(0.54, 0.38), (0.65, 0.34), (0.76, 0.27), (0.86, 0.19)], 0.035, 1.0, 1.3),
    ]
    # ---- 가운데 층: 더 짧고 가는 창날 + 파란 줄 + 안쪽 혀
    mid = [
        straight(0.22, 0.01, 0.96, 0.02, 0.215, 2.0, 1.3),
        straight(0.17, -0.045, 0.78, -0.07, 0.055, 1.2, 1.2),          # 가운데를 가르는 파란 줄
        straight(0.24, 0.085, 0.74, 0.10, 0.045, 1.2, 1.2),
        lick(inset(T1, 0.22), 0.095), lick(inset(T2, 0.25), 0.06), lick(inset(T3, 0.35), 0.045),
        lick(inset(B1, 0.22), 0.055), lick(inset(B2, 0.25), 0.04),
    ]
    # ---- 코어: 촉 쪽에 몰린 흰 불꽃 + 뒤로 뻗는 가는 심 + 갈고리 불꽃
    core = [
        straight(0.52, 0.012, 0.95, 0.02, 0.15, 2.0, 1.3),
        straight(0.40, 0.035, 0.74, 0.02, 0.016, 1.0, 1.2),            # 가는 심
        lick([(0.635, -0.42), (0.69, -0.26), (0.79, -0.15), (0.90, -0.03)], 0.05),
        lick([(0.75, -0.46), (0.79, -0.27), (0.865, -0.13), (0.93, -0.02)], 0.034),
        lick([(0.655, 0.34), (0.71, 0.23), (0.80, 0.15), (0.905, 0.06)], 0.04),
        lick([(0.44, -0.20), (0.54, -0.13), (0.66, -0.08), (0.78, -0.03)], 0.04),          # 뒤로 길게 빠지는 흰 결
    ]
    # 흰 코어 속을 파낸 무늬: 가운데 층(분홍)이 소용돌이처럼 비친다
    swirls = [
        lick([(0.70, 0.075), (0.75, 0.045), (0.80, 0.05), (0.85, 0.035)], 0.016, 0.8, 1.2, wob=0.3),
        lick([(0.80, -0.055), (0.84, -0.025), (0.875, -0.01), (0.905, 0.005)], 0.012, 0.8, 1.2, wob=0.3),
    ]
    rgb = np.stack([sdf(outer, slits), sdf(mid), sdf(core, swirls)], axis=-1)
    save(rgb, "bolt_shape.png")


def tile_noise(rng, sx, sy, w=512, h=256):
    n = ndimage.gaussian_filter(rng.random((h, w)), sigma=(sy, sx), mode="wrap")
    lo, hi = np.percentile(n, 1), np.percentile(n, 99)
    return np.clip((n - lo) / (hi - lo), 0.0, 1.0)


def build_flow():
    rng = np.random.default_rng(7)
    r = tile_noise(rng, 70, 4) * 0.65 + tile_noise(rng, 30, 2.0) * 0.35       # 긴 결
    g = tile_noise(rng, 45, 1.3) * 0.7 + tile_noise(rng, 20, 0.9) * 0.3        # 가는 결
    b = tile_noise(rng, 48, 4.5) * 0.65 + tile_noise(rng, 20, 2.2) * 0.35            # 혀 덩어리
    save(np.stack([r, g, b], axis=-1), "bolt_flow.png")


def build_shards():
    rnd = random.Random(11)
    w, h = 512, 256
    s = 4
    mask = Image.new("L", (w * s, h * s), 0)
    ids = Image.new("L", (w * s, h * s), 0)
    dm, di = ImageDraw.Draw(mask), ImageDraw.Draw(ids)
    for _ in range(34):
        cx, cy = rnd.uniform(0, w), rnd.uniform(8, h - 8)
        ln, th = rnd.uniform(10, 34), rnd.uniform(3.0, 8.5)
        ang = rnd.uniform(-0.45, 0.45)
        ca, sa = np.cos(ang), np.sin(ang)
        skew = rnd.uniform(-0.5, 0.5) * ln
        # 뾰족한 평행사변형: 앞뒤가 날카롭다
        local = [(-ln, 0), (skew * 0.3, -th), (ln, rnd.uniform(-0.3, 0.3) * th), (skew * 0.3 - ln * 0.2, th * 0.7)]
        idv = rnd.randint(20, 255)
        for ox in (-w, 0, w):
            poly = [((cx + ox + x * ca - y * sa) * s, (cy + x * sa + y * ca) * s) for x, y in local]
            dm.polygon(poly, fill=255)
            di.polygon(poly, fill=idv)
    m = np.asarray(mask.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255.0
    i = np.asarray(ids.resize((w, h), Image.NEAREST), dtype=np.float64) / 255.0
    i = ndimage.grey_dilation(i, size=(3, 3))          # 가장자리 보간 때 번호가 0 으로 새지 않게
    save(np.stack([m, i, np.zeros_like(m)], axis=-1), "bolt_shards.png")


def ramp(stops, n=256):
    xs = np.linspace(0, 1, n)
    px = [s[0] for s in stops]
    cols = np.array([[int(s[1][k:k + 2], 16) / 255.0 for k in (0, 2, 4)] for s in stops])
    return np.stack([np.interp(xs, px, cols[:, c]) for c in range(3)], axis=-1)


def build_ramp():
    rows = [
        # 바깥: 짙은 남색 → 파랑 섞인 남보라 → 보라 → 자홍 → 분홍
        ramp([(0.0, "161a52"), (0.25, "1f2380"), (0.48, "372cb8"), (0.66, "6a3ae6"), (0.80, "a040f0"), (0.90, "e044ee"), (1.0, "ff58d8")]),
        # 가운데: 파랑 → 연보라 → 라일락 → 분홍
        ramp([(0.0, "2a3ab4"), (0.22, "4660e0"), (0.38, "8f92fa"), (0.55, "c4b4ff"), (0.70, "e2b0ff"), (0.82, "ff8ef0"), (0.92, "ff70e6"), (1.0, "ff86dc")]),
        # 코어: 청록 줄 → 옅은 하늘 → 흰색 → 분홍빛 흰색
        ramp([(0.0, "49d8d0"), (0.40, "7fe9ea"), (0.58, "dff1ff"), (0.72, "ffffff"), (0.92, "fff4fb"), (1.0, "ffd9f3")]),
        # 후광: 꼬리는 파랑, 촉은 분홍
        ramp([(0.0, "141a58"), (0.40, "222a8c"), (0.65, "5a2ccc"), (0.85, "d040e8"), (1.0, "ff58c8")]),
    ]
    save(np.stack([r for r in rows], axis=0), "bolt_ramp.png")


def save(arr, name):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((np.clip(arr, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, name))
    print("[gun_bolt]", name, arr.shape)


if __name__ == "__main__":
    build_shape()
    build_flow()
    build_shards()
    build_ramp()


# ---------------------------------------------------------------- 총구 섬광·명중 스파크 (볼트 색으로 다시 칠한 시트)
# 원본 시트는 주황·노랑이라 modulate 로는 보라가 되지 않는다 → 색상(H)만 옮겨 따로 저장한다 (vd_vfx.gd LIB "gun_flash" · "gun_hit").
#   gun_flash.png        td_hit_spark_light.png 의 주황 별 → 분홍빛 흰 코어 + 자홍·보라 가장자리
#   gun_hit_violet.png   hx_hit_spark_sheet.png 의 노란 고리·후광 → 남보라~파랑 (자홍 별은 그대로)
def recolor(src, dst, hue_fn):
    import colorsys
    im = Image.open(os.path.join(OUT, "..", src)).convert("RGBA")
    a = np.asarray(im, dtype=np.float64) / 255.0
    out = a.copy()
    h, w, _ = a.shape
    for y in range(h):
        for x in range(w):
            r, g, b, al = a[y, x]
            if al <= 0.0:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r, g, b)
            out[y, x, :3] = colorsys.hsv_to_rgb(*hue_fn(hh * 360.0, ss, vv))
    Image.fromarray((np.clip(out, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, dst))
    print("[gun_bolt]", dst, out.shape)


def flash_hue(h, s, v):
    # 주황 계열 전부 → 밝을수록 분홍(315°), 어두울수록 보라(270°)
    return ((270.0 + 45.0 * v) / 360.0, s * 0.85, min(1.0, v * 1.08))


def hit_hue(h, s, v):
    if 8.0 <= h <= 80.0:                       # 노랑·주황 고리와 후광 → 남보라~파랑
        return ((262.0 - (h - 8.0) / 72.0 * 30.0) / 360.0, min(1.0, s * 0.95), v)
    return (h / 360.0, s, v)


if __name__ == "__main__":
    recolor("td_hit_spark_light.png", "gun_flash.png", flash_hue)
    recolor("hx_hit_spark_sheet.png", "gun_hit_violet.png", hit_hue)
