## 공허 수정게 파츠 배치 — tools/enemies/build_crystal_crab.py 생성물. 손으로 고치지 말고 스크립트를 고쳐 다시 실행한다.
## 좌표는 텍스처 px, 발밑(바닥 그림자 중심)이 원점. pos = 파츠 피벗, offset = 피벗에서 텍스처 왼쪽 위까지.
extends RefCounted

const WIDTH := 756.0      # 전체 가로 폭 (px)
const TOP := -565.0       # 맨 위 y (발밑 기준)
## 뒤 → 앞 순서
const PARTS := [
	{"name": "core", "pos": Vector2(0, -195), "offset": Vector2(-113, -125)},
	{"name": "head", "pos": Vector2(0, -219), "offset": Vector2(-109, -346)},
	{"name": "arm_l", "pos": Vector2(-117, -273), "offset": Vector2(-253, -100)},
	{"name": "arm_r", "pos": Vector2(159, -273), "offset": Vector2(-22, -88)},
	{"name": "body", "pos": Vector2(0, -195), "offset": Vector2(-166, -68)},
]
