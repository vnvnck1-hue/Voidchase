## VOID DEFENSE 전투 카메라 포커스: 전투가 가장 치열한 곳을 따라가고, 전장이 넓으면 살짝 줌아웃·모여 있으면 살짝 줌인한다.
## VDBattle 이 매 프레임 track()(전투 중) 또는 follow()(그 외: 방 중심·이동 중 분대 중심)를 부르고 pos/zoom 을 카메라에 넣는다.
##
## "치열한 곳" = 아군-적 쌍의 중간점을 거리로 가중한 평균(가까이 붙은 쌍일수록 무겁게, 보스는 더 무겁게)
##             + 최근 명중 지점의 열기(add_heat, 서서히 식음) + 전체 유닛 중심을 조금(시야가 너무 좁아지지 않게).
## 줌 = 살아 있는 유닛이 모두 화면(HUD 를 뺀 영역)에 여유 있게 들어오는 배율을 기본 전투 줌의 -7%~+6% 안으로.
## 위치는 방 중심에서 교전 중심 쪽으로 PAN_K 만큼만, 최대 MAX_PAN 까지 간다(전장을 크게 휘젓지 않게).
##
## 튀지 않게 세 단계로 거르되, 굼뜨지 않게 각 단계는 짧게:
##   1) 원시 목표를 RAW_TAU 로 저역 통과 → 순간적인 튐(유닛 하나 돌진, 사망 등) 제거
##   2) 데드존(히스테리시스): 걸러진 목표가 지금 목표에서 DEAD_PX / DEAD_ZOOM 이상 벗어날 때만 목표를 옮긴다
##   3) 카메라는 목표로 smooth damp(임계 감쇠 스프링) → 빠르게 붙되 오버슈트 없이 멈춘다
## 시간은 실제 시간(히트스탑·배속과 무관)으로 흐른다.
extends RefCounted

const ENGAGE_DIST := 200.0 * VDData.TILE_SCALE             # 아군-적 거리가 이만큼이면 가중치 절반 (가까울수록 교전으로 봄)
const BOSS_WEIGHT := 1.6
const CONTEXT := 0.2                    # 전체 유닛 중심을 섞는 비율
const HEAT_DECAY := 1.6                 # 명중 열기가 식는 시간 상수(s)
const HEAT_WEIGHT := 0.6                # 명중 한 번의 무게 (교전 쌍 하나 ≈ 1)
const PAN_K := 0.55                     # 방 중심 → 교전 중심 중 실제로 따라가는 비율
const MAX_PAN := 150.0 * VDData.TILE_SCALE                 # 방 중심에서 벗어날 수 있는 최대 거리(px) — 320 은 전장이 너무 크게 움직였다
const ZOOM_OUT_K := 0.93                # 기본 전투 줌 대비 최대 줌아웃 (전장이 넓을 때)
const ZOOM_IN_K := 1.06                 # 기본 전투 줌 대비 최대 줌인 (모여 있을 때)
const PAD := Vector2(150, 170)          # 유닛 위치(발밑) 둘레 여유: 캐릭터 키·HP바·이름
const HUD_H := 270.0                    # 화면 위아래 HUD 가 가리는 높이 (위 120 + 아래 분대 바 150)
const FILL := 0.85                      # 유닛 묶음이 쓸 수 있는 화면 비율
const RAW_TAU := 0.25                   # 1단계 저역 통과 시간 상수(s)
const DEAD_PX := 18.0 * VDData.TILE_SCALE                  # 2단계 위치 데드존(px) — 방이 작아 교전 중심은 보통 방 중심에서 50~150px 안에서 움직인다
const DEAD_ZOOM := 0.025                # 2단계 줌 데드존(비율)
const MOVE_TIME := 0.38                 # 3단계 위치 smooth damp 시간(s) — 0.9 는 허우적거렸다
const ZOOM_TIME := 0.6                  # 3단계 줌 smooth damp 시간(s)

var pos := Vector2.ZERO                 # 카메라에 넣을 위치
var zoom := 1.0                         # 카메라에 넣을 base_zoom
var _raw_pos := Vector2.ZERO
var _raw_zoom := 1.0
var _goal_pos := Vector2.ZERO
var _goal_zoom := 1.0
var _vel := Vector2.ZERO
var _zvel := 0.0
var _heat: Array[Dictionary] = []       # {p: Vector2, w: float}


## 순간 이동(새 판 시작 등): 모든 단계를 그 자리로 맞춘다.
func reset(p: Vector2, z: float) -> void:
	pos = p
	_raw_pos = p
	_goal_pos = p
	_vel = Vector2.ZERO
	sync_zoom(z)
	_heat.clear()


## 줌을 다른 곳(상태 전환 트윈)이 움직이는 동안 그 값을 따라 둔다. 전투 줌 추적이 그 값에서 이어지게.
func sync_zoom(z: float) -> void:
	zoom = z
	_raw_zoom = z
	_goal_zoom = z
	_zvel = 0.0


## 다른 연출(궁극기 클로즈업)이 카메라를 옮겨 놓은 자리에서 이어 받는다: 위치·줌만 맞추고 목표는 그대로 → 부드럽게 돌아간다.
func hold_at(p: Vector2, z: float) -> void:
	pos = p
	zoom = z
	_vel = Vector2.ZERO
	_zvel = 0.0


## 명중 지점: 잠시 그쪽으로 시선을 끈다.
func add_heat(p: Vector2, w := 1.0) -> void:
	_heat.append({"p": p, "w": w * HEAT_WEIGHT})
	if _heat.size() > 40:
		_heat.pop_front()


## 전투 중: 교전 중심과 필요한 줌을 계산해 부드럽게 따라간다.
func track(dt: float, allies: Array, enemies: Array, room_center: Vector2, view: Vector2, base_zoom: float) -> void:
	var a_pos: Array[Vector2] = []
	var e_pos: Array[Vector2] = []
	var e_boss: Array[bool] = []
	for a in allies:
		if is_instance_valid(a) and a.alive:
			a_pos.append(a.position)
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			e_pos.append(e.position)
			e_boss.append(e.is_boss)
	_decay_heat(dt)
	if a_pos.is_empty() and e_pos.is_empty():
		follow(dt, room_center)
		return
	# 전체 중심
	var all_sum := Vector2.ZERO
	for p in a_pos + e_pos:
		all_sum += p
	var all_c := all_sum / float(a_pos.size() + e_pos.size())
	# 교전 중심: 아군-적 쌍 중간점, 가까울수록 무겁게
	var sum := Vector2.ZERO
	var wsum := 0.0
	for p in a_pos:
		for i in e_pos.size():
			var d := p.distance_to(e_pos[i]) / ENGAGE_DIST
			var w := 1.0 / (1.0 + d * d)
			if e_boss[i]:
				w *= BOSS_WEIGHT
			sum += (p + e_pos[i]) * 0.5 * w
			wsum += w
	for h in _heat:
		sum += (h["p"] as Vector2) * float(h["w"])
		wsum += float(h["w"])
	var fight := all_c if wsum < 0.0001 else sum / wsum
	var target := all_c.lerp(fight, 1.0 - CONTEXT)
	# 맵 밖을 비추지 않게 방 중심 둘레로 제한
	var off := (target - room_center) * PAN_K
	target = room_center + off
	if off.length() > MAX_PAN:
		target = room_center + off.limit_length(MAX_PAN)
	# 줌: 목표 지점 기준으로 모든 유닛이 들어오는 배율
	var half := Vector2.ZERO
	for p in a_pos + e_pos:
		half.x = maxf(half.x, absf(p.x - target.x))
		half.y = maxf(half.y, absf(p.y - target.y))
	half += PAD
	var fit := minf(view.x * FILL / (half.x * 2.0), (view.y - HUD_H) * FILL / (half.y * 2.0))
	var tz := clampf(fit, base_zoom * ZOOM_OUT_K, base_zoom * ZOOM_IN_K)
	_step(dt, target, tz, true)


## 전투 밖: 주어진 지점으로 부드럽게 (줌은 건드리지 않는다). quick 이면 이동 중 분대를 놓치지 않게 빠르게 따라간다.
func follow(dt: float, target: Vector2, quick := false) -> void:
	_step(dt, target, zoom, false, 0.27 if quick else 0.5)
	_zvel = 0.0


func _step(dt: float, target: Vector2, tz: float, dead_zone: bool, move_time := MOVE_TIME) -> void:
	if dead_zone:
		# 1) 저역 통과
		var k := 1.0 - exp(-dt / RAW_TAU)
		_raw_pos = _raw_pos.lerp(target, k)
		_raw_zoom = lerpf(_raw_zoom, tz, k)
		# 2) 데드존: 충분히 벗어났을 때만 목표를 옮긴다
		if _raw_pos.distance_to(_goal_pos) > DEAD_PX:
			_goal_pos = _raw_pos
		if absf(_raw_zoom - _goal_zoom) > DEAD_ZOOM * _goal_zoom:
			_goal_zoom = _raw_zoom
	else:
		# 전투 밖: 정해진 지점(방 중심·분대 중심)이라 거르지 않고 smooth damp 만
		_raw_pos = target
		_raw_zoom = tz
		_goal_pos = target
		_goal_zoom = tz
	# 3) smooth damp
	var r := _damp_v(pos, _goal_pos, _vel, move_time, dt)
	pos = r[0]
	_vel = r[1]
	var rz := _damp_f(zoom, _goal_zoom, _zvel, ZOOM_TIME, dt)
	zoom = rz[0]
	_zvel = rz[1]


func _decay_heat(dt: float) -> void:
	var f := exp(-dt / HEAT_DECAY)
	for h in _heat:
		h["w"] = float(h["w"]) * f
	_heat = _heat.filter(func(h: Dictionary) -> bool: return float(h["w"]) > 0.02)


## 임계 감쇠 스프링 (Unity SmoothDamp 와 같은 식). [새 값, 새 속도]
static func _damp_v(cur: Vector2, goal: Vector2, vel: Vector2, t: float, dt: float) -> Array:
	var omega := 2.0 / maxf(t, 0.0001)
	var x := omega * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - goal
	var temp := (vel + change * omega) * dt
	return [goal + (change + temp) * e, (vel - temp * omega) * e]


static func _damp_f(cur: float, goal: float, vel: float, t: float, dt: float) -> Array:
	var omega := 2.0 / maxf(t, 0.0001)
	var x := omega * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - goal
	var temp := (vel + change * omega) * dt
	return [goal + (change + temp) * e, (vel - temp * omega) * e]
