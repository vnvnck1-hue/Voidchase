## 파츠 몬스터(머리·몸통·팔이 따로인 적: VDRig.PARTS_ART) 애니메이션. 유닛 하나에 인스턴스 하나.
## 통짜 원화를 늘였다 줄이는 대신 파츠가 저마다 다른 박자로 움직여 종이 인형처럼 보이지 않게 한다:
##   아이들  몸이 떠서 오르내리고, 머리·팔이 한 박자씩 늦게 따라온다. 느린 좌우 돌림(yaw)은 팔 폭과 몸통 기울임으로 흉내 낸다.
##   걷기    걸음마다 두 팔이 같은 쪽으로 출렁이고 머리가 살짝 끄덕인다 (몸 전체 튐은 VDUnit._animate_walk).
##   예비    몸을 낮추고 뒤로 젖히며 앞팔을 높이 든다 (VDUnit._wind_glow 를 따라간다).
##   공격    앞팔을 내리찍고 머리·몸이 앞으로 쏠렸다가, 스프링처럼 지나쳤다 돌아온다.
##   피격    머리가 젖혀지고 파츠들이 서로 벌어졌다가 따로따로 흔들리며 제자리로 (세게 맞을수록 크게).
##   기절    팔이 축 처지고 움직임이 잦아든다.
##   사망    파츠가 사방으로 흩어진다 (몸 찌그러짐·사라짐은 KillFx.body_tween).
## 원화는 왼쪽을 본다: 로컬 -x 가 앞(대상 쪽), 회전 + 는 시계 방향. 위치 값은 화면 px 이고 inv 로 텍스처 px 로 바꾼다.
class_name VDPartsAnim
extends RefCounted

const HOVER_SEC := 2.4          # 떠서 오르내리는 주기
const YAW_SEC := 5.6            # 좌우 돌림 주기
const STRIKE_IN := 0.06         # 내리찍는 데 걸리는 시간
const STRIKE_HOLD := 0.07       # 찍은 자세로 버티는 시간

var _parts := {}                # 이름 → {"node": Sprite2D, "pos": Vector2}
var _inv := 1.0                 # 화면 px → 텍스처 px (비주얼 배율의 역수)
var _wind := 0.0                # 예비 자세 가중치 0~1
var _strike_t := 99.0           # 마지막 공격부터 지난 시간
var _hurt_t := 99.0             # 마지막 피격부터 지난 시간
var _hurt_k := 0.0              # 그 피격의 세기 0~1
var _droop := 0.0               # 기절 처짐 0~1
var _scattered := false


func setup(visual: Node2D) -> void:
	_inv = 1.0 / maxf(absf(visual.scale.y), 0.001)
	for c in visual.get_children():
		if c is Sprite2D:
			_parts[str(c.name)] = {"node": c, "pos": c.position}


func strike() -> void:
	_strike_t = 0.0


func hurt(k: float) -> void:
	_hurt_k = clampf(k, 0.0, 1.0)
	_hurt_t = 0.0


## 처음 자세로 (되살아날 때)
func reset() -> void:
	_scattered = false
	_wind = 0.0
	_strike_t = 99.0
	_hurt_t = 99.0
	_droop = 0.0
	for it in _parts.values():
		var n: Sprite2D = it["node"]
		n.position = it["pos"]
		n.rotation = 0.0
		n.scale = Vector2.ONE
		n.skew = 0.0


## 사망: 파츠가 몸 중심에서 바깥으로 튕겨 나가며 돈다. owner 는 Tween 을 만들 노드.
func scatter(owner: Node) -> void:
	if _parts.is_empty():
		return
	_scattered = true
	var center: Vector2 = _parts["body"]["pos"] if _parts.has("body") else Vector2.ZERO
	var tw := owner.create_tween().set_parallel(true)
	for pname in _parts:
		var n: Sprite2D = _parts[pname]["node"]
		var dir: Vector2 = (_parts[pname]["pos"] as Vector2) - center
		dir = Vector2.UP if dir.length() < 1.0 else dir.normalized()
		if pname == "head":
			dir = Vector2(0.25, -1.0).normalized()
		elif pname == "body" or pname == "core":
			dir = Vector2(0.0, 0.4)
		var to := n.position + (dir * randf_range(22.0, 36.0) + Vector2(0, -6.0)) * _inv
		tw.tween_property(n, "position", to, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "rotation", n.rotation + signf(dir.x + 0.01) * randf_range(0.5, 1.3), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 공격 곡선: 0 → 1 로 내리찍고(STRIKE_IN) 잠깐 버틴 뒤, 반대쪽으로 한 번 지나쳤다가 잦아든다.
func _strike_curve() -> float:
	var a := _strike_t
	if a < STRIKE_IN:
		var k := a / STRIKE_IN
		return 1.0 - (1.0 - k) * (1.0 - k)
	a -= STRIKE_IN
	if a < STRIKE_HOLD:
		return 1.0
	a -= STRIKE_HOLD
	return exp(-a * 7.5) * cos(a * 15.0)


## 매 프레임. t·phase 는 유닛의 아이들 시간과 위상, wind_glow 는 예비 동작 진행도(0~1),
## walk_amt 는 걷는 정도(0~1), step 은 걸음 위상(rad: sin 이 걸음마다 부호를 바꾼다), stunned 는 기절·빙결 중.
func update(delta: float, t: float, phase: float, wind_glow: float, walk_amt: float, step: float, stunned: bool) -> void:
	if _scattered or _parts.is_empty():
		return
	_strike_t += delta
	_hurt_t += delta
	# 예비 자세는 빛이 차는 만큼 따라 올라가고, 풀리면(공격 또는 취소) 빠르게 내려온다
	_wind = maxf(wind_glow, _wind - delta / STRIKE_IN)
	_droop = move_toward(_droop, 1.0 if stunned else 0.0, delta * 5.0)

	var live := 1.0 - 0.8 * _droop                      # 기절 중엔 아이들이 잦아든다
	var w := TAU / HOVER_SEC
	var b := sin(t * w + phase) * live                  # 몸
	var b_head := sin(t * w + phase - 0.9) * live       # 머리: 조금 늦게
	var b_al := sin(t * w + phase - 1.5) * live         # 앞팔: 더 늦게
	var b_ar := sin(t * w + phase - 2.1) * live         # 뒷팔: 가장 늦게
	var yaw := sin(t * TAU / YAW_SEC + phase * 1.7) * live
	var q := _strike_curve() if _strike_t < 2.0 else 0.0
	var wd := _wind
	var hk := _hurt_k * exp(-_hurt_t * 6.5) if _hurt_t < 2.0 else 0.0     # 벌어짐 (진동 없이 잦아듦)
	var hw := hk * cos(_hurt_t * 17.0)                                    # 머리·몸 흔들림
	var ws := sin(step) * walk_amt

	var body_pos := Vector2(-3.0 * q + 2.0 * hw + 1.5 * wd, -3.2 * b + 3.0 * wd + 1.5 * _droop)
	var body_rot := 1.0 * yaw + 3.0 * wd - 5.0 * q + 4.0 * hw
	_pose_part("body", body_pos, body_rot, Vector2(1.0 + 0.02 * b + 0.05 * wd - 0.03 * q, 1.0 - 0.02 * b - 0.06 * wd + 0.04 * q), 0.03 * yaw)
	_pose_part("core", body_pos, body_rot, Vector2.ONE, 0.0)
	_pose_part("head",
		Vector2(2.5 * yaw - 9.0 * q + 7.0 * hw + 3.0 * wd, -3.2 * b_head + 4.0 * wd - 5.0 * hk - 2.5 * absf(ws) + 3.0 * _droop),
		1.6 * sin(t * TAU / 4.4 + phase) * live + 7.0 * wd - 12.0 * q + 13.0 * hw + 2.5 * ws + 5.0 * _droop,
		Vector2(1.0 - 0.012 * b_head - 0.04 * q, 1.0 + 0.012 * b_head + 0.05 * q), 0.0)
	_pose_part("arm_l",
		Vector2(-1.5 * yaw + 4.0 * wd - 8.0 * q - 5.0 * hk, -3.0 * b_al - 5.0 * wd + 4.0 * q - 2.0 * hk),
		4.5 * b_al + 36.0 * wd - 52.0 * q + 16.0 * hk * cos(_hurt_t * 14.0 + 0.6) + 10.0 * ws - 15.0 * _droop,
		Vector2(1.0 + 0.05 * yaw, 1.0), 0.0)
	_pose_part("arm_r",
		Vector2(-1.5 * yaw + 5.0 * wd - 4.0 * q + 5.0 * hk, -3.0 * b_ar - 3.0 * wd - 2.0 * hk),
		-4.5 * b_ar - 22.0 * wd + 24.0 * q - 14.0 * hk * cos(_hurt_t * 12.0 + 1.1) + 10.0 * ws + 15.0 * _droop,
		Vector2(1.0 - 0.05 * yaw, 1.0), 0.0)


## 파츠 하나: 기준 위치 + off(화면 px), 회전(도), 배율, 기울임(rad).
func _pose_part(pname: String, off: Vector2, rot_deg: float, scale: Vector2, skew: float) -> void:
	if not _parts.has(pname):
		return
	var it: Dictionary = _parts[pname]
	var n: Sprite2D = it["node"]
	n.position = (it["pos"] as Vector2) + off * _inv
	n.rotation = deg_to_rad(rot_deg)
	n.scale = scale
	n.skew = skew
