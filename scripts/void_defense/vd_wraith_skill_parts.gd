## 공허 망령 촉수 스킬 타격 VFX 조각 — tools/vfx/extract_wraith_skill.py 생성물 (컨셉: 몬스터 스킬.psd). 손으로 고치지 않는다.
## pos = 무리 중심 기준 위치(텍스처 px), axis = 조각의 긴 축 각도(rad), dark = 섬광 뒤에 깔리는 어두운 조각.
extends RefCounted

const DIR := "res://assets/vfx/void_defense/wraith_skill/"
const PSD_SCALE := 0.5      # 텍스처 px / PSD px (몬스터 원화와 같은 배율의 PSD)
const CLUSTERS := {
	"A": [
		{"tex": "a0", "pos": Vector2(-0.5, 7.8), "axis": -2.410, "dark": true},
		{"tex": "a1", "pos": Vector2(-50.8, 5.2), "axis": -3.035, "dark": true},
		{"tex": "a2", "pos": Vector2(20.2, -81.0), "axis": 1.547, "dark": false},
		{"tex": "a3", "pos": Vector2(-41.8, 72.0), "axis": 2.152, "dark": false},
		{"tex": "a4", "pos": Vector2(60.8, 42.0), "axis": -2.764, "dark": false},
		{"tex": "a5", "pos": Vector2(-39.8, 3.8), "axis": -2.928, "dark": false},
		{"tex": "a6", "pos": Vector2(-0.5, 7.8), "axis": -2.409, "dark": false},
		{"tex": "a7", "pos": Vector2(1.8, 5.2), "axis": 2.125, "dark": false},
		{"tex": "a8", "pos": Vector2(-118.2, -87.8), "axis": -2.393, "dark": false},
		{"tex": "a9", "pos": Vector2(-0.8, 8.2), "axis": 2.536, "dark": false},
	],
	"B": [
		{"tex": "b0", "pos": Vector2(-4.2, 2.2), "axis": 2.766, "dark": false},
		{"tex": "b1", "pos": Vector2(1.8, 0.2), "axis": 2.930, "dark": false},
	],
	"C": [
		{"tex": "c0", "pos": Vector2(3.8, 0.0), "axis": 0.800, "dark": false},
		{"tex": "c1", "pos": Vector2(9.8, 1.8), "axis": 0.876, "dark": false},
	],
}
const DEBRIS := ["debris0", "debris1", "debris2", "debris3", "debris4", "debris5", "debris6", "debris7", "debris8", "debris9", "debris10", "debris11"]
const GROUND := ["ground_back", "ground_front"]
