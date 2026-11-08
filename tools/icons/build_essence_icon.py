"""공허 정수(재화) 아이콘 생성: 보랏빛 공허 결정 하나 + 안쪽 소용돌이 빛 + 반짝임.
게임 톤(짙은 남보라 외곽선, 카툰 3톤 면, 하이라이트)에 맞춘다. 4배로 그려 줄여서 가장자리를 부드럽게 한다.

    C:/Python314/python.exe tools/icons/build_essence_icon.py

출력: assets/textures/ui/essence_icon.png (128x128, 투명 배경)
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 128
SS = 4                      # 슈퍼샘플링
S = SIZE * SS
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures", "ui", "essence_icon.png")

OUTLINE = (34, 10, 52, 255)
DARK = (92, 34, 150, 255)       # 그늘 면
MID = (150, 72, 225, 255)       # 본 면
LIGHT = (205, 140, 255, 255)    # 빛 받는 면
HOT = (255, 236, 255, 255)      # 하이라이트
GLOW = (190, 110, 255)


def p(x, y):
    """0..1 좌표 → 슈퍼샘플 픽셀"""
    return (x * S, y * S)


def main():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # 1) 뒤 광채: 부드러운 보라 원
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    r = 0.36 * S
    gd.ellipse([S / 2 - r, S / 2 - r + 0.02 * S, S / 2 + r, S / 2 + r + 0.02 * S], fill=GLOW + (120,))
    glow = glow.filter(ImageFilter.GaussianBlur(0.07 * S))
    img.alpha_composite(glow)

    # 2) 결정: 위가 뾰족하고 아래가 짧은 길쭉한 육각 보석, 살짝 기울임
    top, upper_l, upper_r = (0.53, 0.10), (0.27, 0.36), (0.78, 0.38)
    lower_l, lower_r, bottom = (0.31, 0.70), (0.74, 0.72), (0.50, 0.92)
    waist = (0.52, 0.56)            # 앞면 가운데 꼭짓점 (면을 나누는 점)
    outline = [top, upper_r, lower_r, bottom, lower_l, upper_l]

    d = ImageDraw.Draw(img)
    # 외곽선: 같은 다각형을 두껍게 먼저
    d.polygon([p(*v) for v in outline], fill=OUTLINE)
    d.line([p(*v) for v in outline + [outline[0]]], fill=OUTLINE, width=int(0.075 * S), joint="curve")

    # 면 (안쪽으로 살짝 줄여 외곽선이 보이게)
    def shrink(v, k=0.92):
        cx, cy = 0.52, 0.52
        return (cx + (v[0] - cx) * k, cy + (v[1] - cy) * k)

    t, ur, lr, b, ll, ul, w = (shrink(v) for v in (top, upper_r, lower_r, bottom, lower_l, upper_l, waist))
    d.polygon([p(*t), p(*ul), p(*w)], fill=LIGHT)        # 왼쪽 위: 가장 밝음
    d.polygon([p(*t), p(*w), p(*ur)], fill=MID)          # 오른쪽 위
    d.polygon([p(*ul), p(*ll), p(*w)], fill=MID)         # 왼쪽 아래
    d.polygon([p(*ur), p(*w), p(*lr)], fill=DARK)        # 오른쪽 아래: 그늘
    d.polygon([p(*ll), p(*b), p(*w)], fill=DARK)
    d.polygon([p(*w), p(*b), p(*lr)], fill=(70, 22, 118, 255))
    # 면 경계선
    for a in (t, ul, ur, ll, lr, b):
        d.line([p(*w), p(*a)], fill=(60, 18, 98, 200), width=int(0.012 * S))

    # 3) 안쪽 공허 소용돌이: 가운데 어두운 눈 + 밝은 호
    eye = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ed = ImageDraw.Draw(eye)
    cx, cy, er = 0.51 * S, 0.54 * S, 0.11 * S
    ed.ellipse([cx - er * 0.8, cy - er * 0.72, cx + er * 0.8, cy + er * 0.72], fill=(28, 6, 48, 220))
    for i in range(3):
        a0 = i * 120 + 20
        ed.arc([cx - er * 1.25, cy - er * 1.1, cx + er * 1.25, cy + er * 1.1], a0, a0 + 70, fill=(250, 210, 255, 255), width=int(0.03 * S))
    eye = eye.filter(ImageFilter.GaussianBlur(0.004 * S))
    img.alpha_composite(eye)

    # 4) 하이라이트: 왼쪽 위 모서리를 따라 흰 띠 + 점
    d = ImageDraw.Draw(img)
    d.line([p(0.47, 0.20), p(0.33, 0.37)], fill=HOT, width=int(0.035 * S))
    d.ellipse([*p(0.36, 0.42), *p(0.40, 0.46)], fill=HOT)

    # 5) 반짝임 별 (오른쪽 위)
    def star(cx, cy, r, col):
        pts = []
        for k in range(8):
            ang = math.pi / 4 * k - math.pi / 2
            rr = r if k % 2 == 0 else r * 0.28
            pts.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
        d.polygon(pts, fill=col)

    star(0.80 * S, 0.20 * S, 0.11 * S, OUTLINE)
    star(0.80 * S, 0.20 * S, 0.08 * S, HOT)

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
