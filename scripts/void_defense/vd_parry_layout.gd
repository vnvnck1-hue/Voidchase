## 패링 연출 배치 (생성물: tools/vfx/extract_parry_fx.py — 손으로 고치지 말 것).
## 원본: assets/컨셉 원화/보스몹 컨셉.psd 의 '몬스터 공격 예고 예시' · '캐릭터 강조 효과 예시' · '보스몹' 그룹.
extends RefCounted

const DIR := "res://assets/vfx/void_defense/parry/"
## 보스 원화(void_watcher.png) px
const BOSS_SIZE := Vector2(1162, 770)
const BOSS_EYE := Vector2(573.0, 242.0)        # 예고 별이 놓이는 눈 (원화 px)
## 예고 (보스 원화 px 단위: 원화 1px = 별 텍스처 1px)
const STAR_PAD := 112                         # star.png 가장자리 여백 (R 모양 · G 좁은 빛 · B 넓은 빛)
const STAR_SIZE := Vector2(512, 1028)            # 여백 뺀 별 크기
const PILLAR_SIZE := Vector2(341, 960)
const PILLAR_OFFSET := Vector2(3.5, 17.0)     # 빛기둥 중심 - 별 중심
const CORE_RADIUS := 40.0                     # 흰 핵 반지름
const CORE_OFFSET := Vector2(8.0, 8.0)
const CORE_GLOW := 101.0                     # 붉은 외부 광선 크기
const COL_STAR_GLOW := Color(1.0, 0.965, 0.0)
const COL_CORE_GLOW := Color(1.0, 0.188, 0.0)
const COL_PILLAR := Color(0.357, 0.0, 0.478)
## 카드 강조 (캐릭터 패널 텍스처 px: 원점 = 카드 왼쪽 위, 폭 300). 텍스처 1px = PANEL_K 패널 px
const PANEL_K := 1.0195
const BEAM_UP_POS := Vector2(10.4, -268.3)       # 위로 솟는 빛기둥 왼쪽 위
const BEAM_UP_SIZE := Vector2(280, 273)
const BEAM_LOW_POS := Vector2(11.4, -26.6)      # 카드를 덮는 빛 왼쪽 위
const BEAM_LOW_SIZE := Vector2(280, 244)
## 반짝이 [파일, 중심(패널 px), 텍스처 안 중심(px)]
const SPARKLES := [
	["sparkle_a.png", Vector2(18.6, -0.1), Vector2(128.0, 179.0)],
	["sparkle_b.png", Vector2(188.8, -18.5), Vector2(108.0, 97.0)],
	["sparkle_c.png", Vector2(297.9, -28.7), Vector2(78.0, 192.0)],
]
