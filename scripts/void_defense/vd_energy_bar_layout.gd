## 생성물 — tools/battle_ui/extract_energy_bar.py 가 화면 컨셉_3.psd 의 '에너지바' 스마트 오브젝트에서 만든다. 손으로 고치지 않는다.
## 분대 카드 위 에너지바: 한 틀 안에 HP(위 띠)와 마나(아래 띠). 텍스처는 PSB 1px = 3 texel.
## class_name 없음: vd_battle_frame.gd 가 preload.

const FRAME := "res://assets/textures/battle_ui/energy_frame.png"
const HP_MASK := "res://assets/textures/battle_ui/energy_hp.png"     # 흰 마스크: 채움 색을 곱해 그린다
const MP_MASK := "res://assets/textures/battle_ui/energy_mp.png"
const TEX_SCALE := 3
const PSB_SIZE := Vector2(186, 74)

# 띠의 가로 범위 (PSB px): 비율만큼 왼쪽부터 잘라 그린다
const HP_X := Vector2(11.00, 173.00)
const MP_X := Vector2(11.00, 173.00)

# 시안 색 (채움 · 바탕). 시안 속 채움 비율: HP 0.59, 마나 0.33
const HP_FILL := Color(0.2980, 0.8941, 0.4000)
const HP_BACK := Color(0.2164, 0.3738, 0.2433)
const MP_FILL := Color(0.1530, 0.4588, 1.0000)
const MP_BACK := Color(0.1916, 0.2624, 0.3875)

# PSB px -> 카드 패널 텍스처 px (네 카드 평균, 카드 간 최대 차이 3.17 px)
const XF := Transform2D(Vector2(1.05647, -0.02555), Vector2(0.00000, 0.89915), Vector2(57.29, -31.94))
