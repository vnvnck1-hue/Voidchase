# 사이파이 플립북 시트 생성 (2026-11-09). 판타지 시트(VFX연구 마법진·회복 반짝임·낙뢰·포털·에너지 구슬)를
# 같은 격자·프레임 수·크기로 다시 그려 scripts/void_defense/vd_vfx.gd 의 LIB 표와 호출부를 그대로 둔다.
# 모두 흰색~옅은 색으로 그려 modulate(tint)로 물들인다 (add 블렌드).
#   vr_magic_circle.png  1장 1024   홀로그램 타깃 링 (얇은 동심원 + 눈금 + 호 조각 + 육각 격자 + 중심 브래킷)
#   vr_heal_sparkles.png 4x4 512    나노 스캔: 아래서 위로 지나가는 스캔 띠 + 육각 셀 패치 + 위로 뜨는 사각 입자
#   vr_lightning_bolt.png 4x4 512   궤도 빔: 위에서 내리꽂히는 가는 빔이 굵어졌다 가늘어짐 + 바닥 착탄 링 + 조각
#   vr_portal_swirl.png  4x4 512    텔레포트 패드: 도는 점선 링 + 바깥으로 퍼지는 펄스 링 + 육각 윤곽 (루프)
#   vr_energy_orb.png    4x4 512    플라즈마 탄: 흰 코어 + 글로우 + 튀는 아크 (루프)
# 실행: C:/Python314/python.exe tools/vfx/build_scifi_sheets.py   → assets/vfx/void_defense/ 에 덮어쓴다 (원본은 assets/_backup/vfx_fantasy/)
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "vfx", "void_defense")
SS = 2   # 슈퍼샘플


def canvas(size):
    return Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))


def finish(img, size, blur=0.0):
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur * SS))
    return img.resize((size, size), Image.LANCZOS)


def glow_layer(size, cx, cy, radius, color, power=2.0, alpha=1.0, aspect=1.0):
    """중심에서 radius 까지 사그라드는 부드러운 빛 (numpy)."""
    s = size * SS
    y, x = np.mgrid[0:s, 0:s].astype(np.float32)
    d = np.sqrt(((x - cx * SS) / aspect) ** 2 + (y - cy * SS) ** 2) / (radius * SS)
    a = np.clip(1.0 - d, 0.0, 1.0) ** power * alpha
    arr = np.zeros((s, s, 4), np.float32)
    arr[..., 0] = color[0]; arr[..., 1] = color[1]; arr[..., 2] = color[2]
    arr[..., 3] = a
    return Image.fromarray((arr * 255).astype(np.uint8), "RGBA")


def over(base, layer):
    return Image.alpha_composite(base, layer)


def col(c, a=1.0):
    return (int(c[0] * 255), int(c[1] * 255), int(c[2] * 255), int(a * 255))


WHITE = (1.0, 1.0, 1.0)
CYAN = (0.75, 0.95, 1.0)
PALE = (0.9, 0.97, 1.0)


# ---------------------------------------------------------------- 1 홀로그램 타깃 링 (마법진 대체)

def magic_circle():
    size = 1024
    img = canvas(size)
    d = ImageDraw.Draw(img)
    c = size * SS / 2
    R = size * SS * 0.47
    # 바닥 채움: 아주 옅은 디스크 + 육각 격자
    img = over(img, glow_layer(size, size / 2, size / 2, size * 0.47, CYAN, power=0.6, alpha=0.10))
    d = ImageDraw.Draw(img)
    hr = size * SS * 0.055
    for row in range(-9, 10):
        for q in range(-9, 10):
            x = c + 1.5 * hr * q
            y = c + math.sqrt(3) * hr * (row + 0.5 * (q & 1))
            if math.hypot(x - c, y - c) > R * 0.86:
                continue
            pts = [(x + hr * 0.92 * math.cos(math.pi / 3 * i), y + hr * 0.92 * math.sin(math.pi / 3 * i)) for i in range(6)]
            d.polygon(pts, outline=col(CYAN, 0.16), width=2 * SS)
    # 동심원
    for rr, w, a in [(R, 5, 0.95), (R * 0.93, 2, 0.55), (R * 0.62, 3, 0.8), (R * 0.36, 2, 0.6), (R * 0.12, 3, 0.9)]:
        d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=col(WHITE, a), width=w * SS)
    # 바깥 눈금 (72개, 매 6번째는 길게)
    for i in range(72):
        a = math.tau * i / 72
        l = R * (0.06 if i % 6 == 0 else 0.025)
        x0, y0 = c + (R * 0.93) * math.cos(a), c + (R * 0.93) * math.sin(a)
        x1, y1 = c + (R * 0.93 - l) * math.cos(a), c + (R * 0.93 - l) * math.sin(a)
        d.line([x0, y0, x1, y1], fill=col(WHITE, 0.85 if i % 6 == 0 else 0.5), width=(3 if i % 6 == 0 else 2) * SS)
    # 호 조각 (코드가 통째로 돌리므로 비대칭이어야 회전이 보인다)
    def arc(rr, a0, a1, w, a):
        d.arc([c - rr, c - rr, c + rr, c + rr], a0, a1, fill=col(WHITE, a), width=w * SS)
    arc(R * 0.80, 10, 95, 14, 0.95)
    arc(R * 0.80, 190, 250, 14, 0.95)
    arc(R * 0.80, 300, 330, 14, 0.7)
    arc(R * 0.72, 100, 140, 5, 0.6)
    arc(R * 0.72, 260, 285, 5, 0.6)
    arc(R * 0.48, 0, 70, 7, 0.8)
    arc(R * 0.48, 180, 215, 7, 0.8)
    # 데이터 블록: 호 끝의 작은 사각 묶음
    for a_deg in (95, 250, 330):
        a = math.radians(a_deg)
        for k in range(4):
            rr = R * (0.76 + 0.025 * k)
            x, y = c + rr * math.cos(a + 0.06), c + rr * math.sin(a + 0.06)
            s = R * 0.012
            d.rectangle([x - s, y - s, x + s, y + s], fill=col(WHITE, 0.9 if k % 2 == 0 else 0.5))
    # 중심 브래킷 + 십자
    b = R * 0.22
    for sx in (-1, 1):
        for sy in (-1, 1):
            d.line([c + sx * b, c + sy * b, c + sx * b * 0.6, c + sy * b], fill=col(WHITE, 0.95), width=5 * SS)
            d.line([c + sx * b, c + sy * b, c + sx * b, c + sy * b * 0.6], fill=col(WHITE, 0.95), width=5 * SS)
    d.line([c - R * 0.08, c, c + R * 0.08, c], fill=col(WHITE, 0.9), width=3 * SS)
    d.line([c, c - R * 0.08, c, c + R * 0.08], fill=col(WHITE, 0.9), width=3 * SS)
    # 선 둘레 옅은 글로우: 흐린 사본을 아래에 깐다
    glow = img.filter(ImageFilter.GaussianBlur(6 * SS))
    img = over(glow, img)
    finish(img, size).save(os.path.join(OUT, "vr_magic_circle.png"))


# ---------------------------------------------------------------- 2 나노 스캔 (회복 반짝임 대체)

def heal_sparkles():
    size, cols, rows = 512, 4, 4
    sheet = Image.new("RGBA", (size * cols, size * rows), (0, 0, 0, 0))
    rng = random.Random(11)
    # 육각 셀: 가로 7칸에 고르게 하나씩 + 세로는 무작위 (한쪽에 몰리지 않게)
    cells = [(0.33 + 0.34 * (k + rng.uniform(0.15, 0.85)) / 7.0, rng.uniform(0.28, 0.78), rng.uniform(0.0, 1.0)) for k in range(7)]
    cells += [(0.33 + 0.34 * (k + rng.uniform(0.15, 0.85)) / 5.0, rng.uniform(0.3, 0.75), rng.uniform(0.0, 1.0)) for k in range(5)]
    motes = [(rng.uniform(0.32, 0.68), rng.uniform(0.3, 0.9), rng.uniform(0.6, 1.0), rng.choice([1, 2])) for _ in range(14)]
    for i in range(16):
        t = i / 15.0
        img = canvas(size)
        d = ImageDraw.Draw(img)
        s = size * SS
        fade = min(1.0, (1.0 - t) * 3.0)
        # 스캔 띠: 아래(0.78) → 위(0.22) 로 올라간다. 밝은 선 + 아래로 긴 꼬리
        y = (0.78 - 0.56 * t) * s
        x0, x1 = s * 0.30, s * 0.70
        tail = s * 0.12
        for k in range(18):
            yy = y + tail * k / 18
            a = (1 - k / 18) ** 1.6 * 0.45 * fade
            d.line([x0 + k * 1.5 * SS, yy, x1 - k * 1.5 * SS, yy], fill=col(PALE, a), width=int(tail / 18) + 1)
        d.line([x0, y, x1, y], fill=col(WHITE, 0.95 * fade), width=4 * SS)
        d.line([x0 - 8 * SS, y, x0, y], fill=col(WHITE, 0.95 * fade), width=8 * SS)
        d.line([x1, y, x1 + 8 * SS, y], fill=col(WHITE, 0.95 * fade), width=8 * SS)
        # 육각 셀 패치: 띠가 지나간 자리에 잠깐 켜졌다 사라진다
        for (cx, cy, ph) in cells:
            dy = (cy * s - y) / s          # 띠보다 아래(지나간 곳)면 +
            if dy < -0.02:
                continue
            life = max(0.0, 1.0 - dy / 0.28)
            if life <= 0:
                continue
            hr = s * 0.045 * (0.6 + 0.4 * ph)
            pts = [(cx * s + hr * math.cos(math.pi / 3 * k + math.pi / 6), cy * s + hr * math.sin(math.pi / 3 * k + math.pi / 6)) for k in range(6)]
            d.polygon(pts, fill=col(CYAN, 0.22 * life * fade), outline=col(WHITE, 0.9 * life * fade), width=3 * SS)
        # 위로 뜨는 사각 입자
        for (mx, my, sp, kind) in motes:
            yy = (my - t * 0.5 * sp) * s
            if yy < s * 0.12:
                continue
            a = min(1.0, (my - yy / s) * 6 + 0.2) * fade * (1.0 - t * 0.5)
            r = (3 if kind == 1 else 5) * SS
            d.rectangle([mx * s - r, yy - r, mx * s + r, yy + r], fill=col(WHITE, a))
        glow = img.filter(ImageFilter.GaussianBlur(5 * SS))
        img = over(glow, img)
        sheet.paste(finish(img, size), ((i % cols) * size, (i // cols) * size))
    sheet.save(os.path.join(OUT, "vr_heal_sparkles.png"))


# ---------------------------------------------------------------- 3 궤도 빔 (낙뢰 대체)

def lightning_bolt():
    size, cols, rows = 512, 4, 4
    sheet = Image.new("RGBA", (size * cols, size * rows), (0, 0, 0, 0))
    rng = random.Random(5)
    shards = [(rng.uniform(-1, 1), rng.uniform(0.4, 1.0), rng.uniform(0.6, 1.0)) for _ in range(10)]
    for i in range(16):
        t = i / 15.0
        img = canvas(size)
        s = size * SS
        cx = s * 0.5
        ground = s * 0.80
        # 빔 폭 포락선: 0~0.2 가늘게 내려옴 → 0.2~0.45 굵게 → 1.0 까지 가늘어지며 사라짐
        if t < 0.2:
            reach = t / 0.2
            w = 0.012 + 0.02 * reach
            bright = 1.0
        else:
            reach = 1.0
            k = (t - 0.2) / 0.8
            w = (0.07 * (1 - k) ** 1.4) + 0.006
            bright = 1.0 - k ** 2.2
        y_end = ground * reach
        # 빔: 가로 글로우 (numpy) — 중심 흰 코어 + 바깥 옅은 빛, 위쪽은 살짝 더 가늘게
        y, x = np.mgrid[0:s, 0:s].astype(np.float32)
        taper = 0.75 + 0.25 * (y / ground)
        dx = np.abs(x - cx) / (s * w * taper)
        core = np.clip(1.0 - dx / 0.45, 0, 1) ** 1.2
        halo = np.clip(1.0 - dx / 2.2, 0, 1) ** 2.5 * 0.55
        mask = (y <= y_end).astype(np.float32) * np.clip(y / (s * 0.18), 0.0, 1.0) ** 1.5   # 윗끝은 하늘에서 내려오듯 페이드
        a = (core + halo) * mask * bright
        arr = np.zeros((s, s, 4), np.float32)
        arr[..., 0] = np.clip(0.8 + 0.2 * core, 0, 1); arr[..., 1] = np.clip(0.93 + 0.07 * core, 0, 1); arr[..., 2] = 1.0
        arr[..., 3] = np.clip(a, 0, 1)
        img = over(img, Image.fromarray((arr * 255).astype(np.uint8), "RGBA"))
        d = ImageDraw.Draw(img)
        # 빔 안의 가는 세로 주사선 (사이파이 데이터 느낌)
        if t >= 0.2:
            for k in (-1, 1):
                xx = cx + k * s * w * 0.9
                d.line([xx, 0, xx, y_end], fill=col(WHITE, 0.5 * bright), width=2 * SS)
        # 착탄: 납작한 링 + 섬광
        if t >= 0.18:
            k = min(1.0, (t - 0.18) / 0.82)
            rr = s * (0.06 + 0.30 * (1 - (1 - k) ** 2))
            ra = (1 - k) ** 1.3
            d.ellipse([cx - rr, ground - rr * 0.32, cx + rr, ground + rr * 0.32], outline=col(WHITE, 0.95 * ra), width=int((7 - 4 * k) * SS) + 1)
            rr2 = rr * 0.6
            d.ellipse([cx - rr2, ground - rr2 * 0.32, cx + rr2, ground + rr2 * 0.32], outline=col(CYAN, 0.6 * ra), width=3 * SS)
            if k < 0.3:   # 착탄 섬광: 작고 짧게 (크면 부활 대상 캐릭터가 하얗게 묻힌다)
                img = over(img, glow_layer(size, size / 2, ground / SS, size * 0.09 * (1 - k / 0.3) + size * 0.03, WHITE, power=2.0, alpha=0.6 * (1.0 - k / 0.3), aspect=1.8))
                d = ImageDraw.Draw(img)
            # 튀는 조각: 가는 직선 파편
            for (sx, sv, life) in shards:
                kk = k / life
                if kk > 1:
                    continue
                px = cx + sx * s * 0.28 * kk
                py = ground - s * 0.26 * sv * math.sin(kk * math.pi)
                ln = s * 0.03 * (1 - kk)
                d.line([px, py, px + sx * ln, py - ln * 0.6], fill=col(WHITE, 0.9 * (1 - kk)), width=3 * SS)
        glow = img.filter(ImageFilter.GaussianBlur(4 * SS))
        img = over(glow, img)
        sheet.paste(finish(img, size), ((i % cols) * size, (i // cols) * size))
    sheet.save(os.path.join(OUT, "vr_lightning_bolt.png"))


# ---------------------------------------------------------------- 4 텔레포트 패드 (포털 대체, 루프)

def portal_swirl():
    size, cols, rows = 512, 4, 4
    sheet = Image.new("RGBA", (size * cols, size * rows), (0, 0, 0, 0))
    for i in range(16):
        t = i / 16.0   # 루프: 16 프레임이 한 바퀴
        img = canvas(size)
        s = size * SS
        c = s / 2
        R = s * 0.46
        img = over(img, glow_layer(size, size / 2, size / 2, size * 0.40, CYAN, power=0.8, alpha=0.18))
        d = ImageDraw.Draw(img)
        # 바깥 점선 링: 12 조각, 한 바퀴 = 조각 하나 간격(30°)이라 끊김 없이 돈다
        seg = 30.0
        for k in range(12):
            a0 = k * seg + t * seg
            d.arc([c - R, c - R, c + R, c + R], a0, a0 + seg * 0.55, fill=col(WHITE, 0.95), width=9 * SS)
        # 안쪽 반대 방향 가는 점선 링
        R2 = R * 0.78
        for k in range(18):
            a0 = k * 20.0 - t * 20.0
            d.arc([c - R2, c - R2, c + R2, c + R2], a0, a0 + 11.0, fill=col(CYAN, 0.7), width=4 * SS)
        # 고정 링
        d.ellipse([c - R * 0.9, c - R * 0.9, c + R * 0.9, c + R * 0.9], outline=col(WHITE, 0.5), width=2 * SS)
        # 육각 윤곽 (고정) + 안쪽 작은 육각
        for rr, w, a in [(R * 0.56, 6, 0.9), (R * 0.2, 4, 0.8)]:
            pts = [(c + rr * math.cos(math.pi / 3 * k + math.pi / 6), c + rr * math.sin(math.pi / 3 * k + math.pi / 6)) for k in range(6)]
            d.polygon(pts, outline=col(WHITE, a), width=w * SS)
        # 펄스 링: 중심에서 바깥 링까지 퍼지며 사라짐 (두 개, 반 주기 차)
        for ph in (0.0, 0.5):
            k = (t + ph) % 1.0
            rr = R * (0.2 + 0.7 * k)
            d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=col(PALE, 0.85 * (1 - k)), width=int((6 - 4 * k) * SS) + 1)
        # 육각 꼭짓점에서 깜빡이는 점
        for k in range(6):
            a = math.pi / 3 * k + math.pi / 6
            on = 0.5 + 0.5 * math.sin(math.tau * (t + k / 6.0))
            x, y = c + R * 0.56 * math.cos(a), c + R * 0.56 * math.sin(a)
            r = 7 * SS
            d.ellipse([x - r, y - r, x + r, y + r], fill=col(WHITE, 0.4 + 0.6 * on))
        glow = img.filter(ImageFilter.GaussianBlur(6 * SS))
        img = over(glow, img)
        sheet.paste(finish(img, size), ((i % cols) * size, (i // cols) * size))
    sheet.save(os.path.join(OUT, "vr_portal_swirl.png"))


# ---------------------------------------------------------------- 5 플라즈마 탄 (에너지 구슬 대체, 루프)

def energy_orb():
    size, cols, rows = 512, 4, 4
    sheet = Image.new("RGBA", (size * cols, size * rows), (0, 0, 0, 0))
    rng = random.Random(3)
    for i in range(16):
        t = i / 16.0
        img = canvas(size)
        s = size * SS
        c = s / 2
        pulse = 0.92 + 0.08 * math.sin(math.tau * t * 2)
        img = over(img, glow_layer(size, size / 2, size / 2, size * 0.40 * pulse, CYAN, power=2.2, alpha=0.9))
        img = over(img, glow_layer(size, size / 2, size / 2, size * 0.22 * pulse, WHITE, power=1.4, alpha=1.0))
        d = ImageDraw.Draw(img)
        # 겉 껍질 얇은 링 + 튀는 아크 (프레임마다 다른 자리, 루프라 마지막 → 처음 연결은 아크가 짧아 티 안 남)
        R = s * 0.30 * pulse
        d.ellipse([c - R, c - R, c + R, c + R], outline=col(WHITE, 0.55), width=3 * SS)
        for k in range(4):
            a0 = rng.uniform(0, 360)
            d.arc([c - R * 1.08, c - R * 1.08, c + R * 1.08, c + R * 1.08], a0, a0 + rng.uniform(15, 50), fill=col(WHITE, 0.9), width=5 * SS)
        for k in range(3):
            a = rng.uniform(0, math.tau)
            x0, y0 = c + R * 0.9 * math.cos(a), c + R * 0.9 * math.sin(a)
            x1, y1 = c + R * 1.35 * math.cos(a + 0.3), c + R * 1.35 * math.sin(a + 0.3)
            xm, ym = (x0 + x1) / 2 + rng.uniform(-14, 14) * SS, (y0 + y1) / 2 + rng.uniform(-14, 14) * SS
            d.line([x0, y0, xm, ym, x1, y1], fill=col(WHITE, 0.85), width=3 * SS)
        glow = img.filter(ImageFilter.GaussianBlur(5 * SS))
        img = over(glow, img)
        sheet.paste(finish(img, size), ((i % cols) * size, (i // cols) * size))
    sheet.save(os.path.join(OUT, "vr_energy_orb.png"))


if __name__ == "__main__":
    magic_circle(); print("magic_circle")
    heal_sparkles(); print("heal_sparkles")
    lightning_bolt(); print("lightning_bolt")
    portal_swirl(); print("portal_swirl")
    energy_orb(); print("energy_orb")
