## VOID DEFENSE 영웅 파츠 자세: 머리·몸통·무기 3조각 리그에 숨쉬기 위로 더하는 직업별 키 포즈.
## VDUnit 이 포즈마다 가중치(0~1)를 트윈하고, 가중치 × 아래 값을 파츠에 더한다.
##   wind   공격 예비 동작 (무기를 뒤로 당기거나 들어 올린다)
##   strike 타격 순간 (휘두름·반동·내리찍기) — 끝나면 TRANS_BACK 으로 살짝 지나쳤다 돌아온다(여운)
##   cast   액티브 스킬 시전 자세
##   hurt   피격 (고개가 젖혀지고 몸이 뒤로)
## 값: lean = 발밑 기준 몸 전체 기울기(도, + 앞으로), rot = 파츠 회전(도), pos = 파츠 이동(원화 px, 비주얼 로컬).
## 비주얼 로컬은 영웅이 오른쪽(+x)을 바라보는 기준이다. 뒤집기는 부모 배율이 맡는다.
## 파츠 방향: 기사 칼은 손잡이 피벗에서 칼날이 아래-뒤(-x, +y)로, 권총 총구는 +x, 지팡이는 손잡이 피벗에서 위로 선다.
class_name VDHeroPose
extends RefCounted

const POSES := {
	"knight": {
		"wind":   {"lean": -7.0, "head": {"rot": -8.0, "pos": Vector2(-4, 2)},
			"weapon_sword": {"rot": 70.0, "pos": Vector2(-6, -22)}, "weapon_shield": {"rot": -8.0, "pos": Vector2(-8, 4)}},
		"strike": {"lean": 10.0, "head": {"rot": 7.0, "pos": Vector2(4, 2)},
			"weapon_sword": {"rot": -80.0, "pos": Vector2(40, 4)}, "weapon_shield": {"rot": 6.0, "pos": Vector2(10, 0)}},
		"cast":   {"lean": -4.0, "head": {"rot": -10.0, "pos": Vector2(0, -4)},
			"weapon_sword": {"rot": 150.0, "pos": Vector2(46, -66)}, "weapon_shield": {"rot": -14.0, "pos": Vector2(6, -6)}},
		"hurt":   {"lean": -8.0, "head": {"rot": -14.0, "pos": Vector2(-5, 0)},
			"weapon_sword": {"rot": 18.0, "pos": Vector2(-4, 0)}, "weapon_shield": {"rot": -10.0, "pos": Vector2(-6, 0)}},
	},
	"gunner": {
		"wind":   {"lean": 2.0, "head": {"rot": 4.0, "pos": Vector2(2, 2)},
			"weapon_pistol": {"rot": -4.0, "pos": Vector2(10, -4)}},
		"strike": {"lean": -6.0, "head": {"rot": -7.0, "pos": Vector2(-3, -1)},
			"weapon_pistol": {"rot": -22.0, "pos": Vector2(-12, -6)}},
		"cast":   {"lean": -3.0, "head": {"rot": -6.0, "pos": Vector2(0, -3)},
			"weapon_pistol": {"rot": -70.0, "pos": Vector2(-6, -30)}},
		"hurt":   {"lean": -8.0, "head": {"rot": -14.0, "pos": Vector2(-5, 0)},
			"weapon_pistol": {"rot": 22.0, "pos": Vector2(-6, 6)}},
	},
	"mage": {
		"wind":   {"lean": -6.0, "head": {"rot": -7.0, "pos": Vector2(-3, 0)},
			"weapon_staff": {"rot": -30.0, "pos": Vector2(-10, -30)}},
		"strike": {"lean": 8.0, "head": {"rot": 6.0, "pos": Vector2(4, 2)},
			"weapon_staff": {"rot": 42.0, "pos": Vector2(20, -6)}},
		"cast":   {"lean": -4.0, "head": {"rot": -12.0, "pos": Vector2(0, -4)},
			"weapon_staff": {"rot": -8.0, "pos": Vector2(-4, -52)}},
		"hurt":   {"lean": -8.0, "head": {"rot": -14.0, "pos": Vector2(-5, 0)},
			"weapon_staff": {"rot": -16.0, "pos": Vector2(-6, 4)}},
	},
	"healer": {
		"wind":   {"lean": -3.0, "head": {"rot": -6.0, "pos": Vector2(0, -2)},
			"weapon_staff": {"rot": -12.0, "pos": Vector2(-4, -30)}},
		"strike": {"lean": 6.0, "head": {"rot": 5.0, "pos": Vector2(3, 0)},
			"weapon_staff": {"rot": 24.0, "pos": Vector2(12, -14)}},
		"cast":   {"lean": -2.0, "head": {"rot": -14.0, "pos": Vector2(0, -6)},
			"weapon_staff": {"rot": 0.0, "pos": Vector2(0, -56)}},
		"hurt":   {"lean": -8.0, "head": {"rot": -14.0, "pos": Vector2(-5, 0)},
			"weapon_staff": {"rot": -16.0, "pos": Vector2(-6, 4)}},
	},
}
const POSE_NAMES := ["wind", "strike", "cast", "hurt"]

## 영웅 기본 공격의 예비 동작 시간(초). VDBattle 이 이만큼 기다린 뒤 판정한다.
const WINDUP := {"knight": 0.14, "gunner": 0.07, "mage": 0.14}

## 지연 추종(머리·무기가 몸보다 늦게 따라오는 스프링)
const LAG_K := 140.0           # 복원력
const LAG_DAMP := 11.0         # 감쇠
const LAG_GAIN := 0.012        # 몸 가속도(px/s²) → 지연 오프셋
const LAG_MAX := 14.0          # 오프셋 한계(px) — 순간이동·스냅에 튀지 않게
