## 필드 기믹 (2026-11-11): 방 바닥에 깔린 장치 두 가지. 자리는 VDMap._roll_fields 가 방마다 정해 room["fields"] 에 둔다.
##   증폭 패널 (amp)  : 그 칸에 선 영웅은 평타 피해·치유량 +30% (VDUnit.field_bonus). 주로 아군 배치 구역에 있어
##                      "누구를 올려 둘까"가 배치 단계의 선택이 된다. 벗어나면 바로 풀린다.
##   방전 격자 (shock): 가운데 바닥 몇 칸이 SHOCK_IDLE 초마다 SHOCK_WARN 초 깜빡인 뒤 한꺼번에 방전한다.
##                      그 위의 유닛은 편을 가리지 않고 최대 체력 비례 피해 + 짧은 기절. 영웅 AI 는 깜빡이는 동안 피해 다닌다
##                      (VDFlow.is_hazard), 적은 그냥 밟고 지나간다 — 적을 격자 위에서 붙잡아 두면 이득.
## VDBattle 이 전투 중 매 물리 틱 tick() 을 부른다 (전투 연습장 제외). 그림은 ground_fx 의 자식(z 0)이라 유닛 아래에 깔린다.
## class_name 없음: 헤드리스 실행이 전역 클래스 캐시를 갱신하지 않으므로 preload 해서 쓴다.
extends Node2D

const AMP_BONUS := 0.3
const AMP_COL := Color(1.0, 0.72, 0.2)
const SHOCK_IDLE := 4.2
const SHOCK_WARN := 1.2
const SHOCK_FIRST := 2.0          # 전투 시작 때 시계를 이만큼 앞당겨 둔다 (첫 방전이 너무 늦지 않게)
const SHOCK_FLASH := 0.4
const SHOCK_DMG_ENEMY := 0.12     # 최대 체력 비율
const SHOCK_DMG_ELITE := 0.04     # 중급·대형·보스
const SHOCK_DMG_HERO := 0.06
const SHOCK_STUN_ENEMY := 0.7
const SHOCK_STUN_HERO := 0.3
const SHOCK_COL := Color(0.45, 0.72, 1.0)
const SHOCK_HOT := Color(1.0, 0.92, 0.4)

var b: VDBattle
var count := {"amp_on": 0, "shock": 0, "shock_hits": 0, "shock_hero_hits": 0}   # 테스트용
var _t := 0.0             # 방전 주기 시계
var _flash := 0.0         # 방전 섬광 남은 시간
var _warned := false
var _amped := {}          # instance id -> true (지금 증폭 중인 영웅)
var _clock := 0.0         # 그림용


func _ready() -> void:
	z_index = 0   # 올리면 유닛(z 0) 위로 떠 캐릭터를 가린다 (vd-ground-fx-z-order)


## 전투 시작 (스테이지마다).
func begin() -> void:
	_t = SHOCK_FIRST
	_flash = 0.0
	_warned = false
	_clear_amp()


## 전투가 끝났다: 증폭을 풀고 격자를 재운다.
func stop() -> void:
	_t = 0.0
	_flash = 0.0
	_warned = false
	_clear_amp()


func _clear_amp() -> void:
	_amped.clear()
	if b == null:
		return
	for a in b.allies:
		if is_instance_valid(a):
			a.field_bonus = 0.0


func _cells(kind: String) -> Array[Vector2i]:
	if b == null or b.room.is_empty():
		return []
	return VDMap.field_cells(b.room, kind)


func is_amp(c: Vector2i) -> bool:
	return b != null and not b.room.is_empty() and b.room.get("fields", {}).get(VDMap.to_local(b.room, c), "") == "amp"


func is_shock(c: Vector2i) -> bool:
	return b != null and not b.room.is_empty() and b.room.get("fields", {}).get(VDMap.to_local(b.room, c), "") == "shock"


## 방전이 임박했거나 터지는 중인 격자 칸: 영웅 길 찾기가 피한다.
func is_hazard(c: Vector2i) -> bool:
	if b == null or b.state != VDBattle.State.BATTLE or b.sandbox != null:
		return false
	return (warning() or _flash > 0.0) and is_shock(c)


func warning() -> bool:
	return _t >= SHOCK_IDLE


func tick(dt: float) -> void:
	_tick_amp()
	var shock := _cells("shock")
	if shock.is_empty():
		return
	_flash = maxf(0.0, _flash - dt)
	_t += dt
	if warning() and not _warned:
		_warned = true
		b.audio.play("tick", 0.05, -5.0, 0.6)
	if _t >= SHOCK_IDLE + SHOCK_WARN:
		_t = 0.0
		_warned = false
		_discharge(shock)


# ---------------------------------------------------------------- 증폭 패널

func _tick_amp() -> void:
	var amp := _cells("amp")
	if amp.is_empty():
		return
	for a in b.allies:
		var on := false
		if a.alive:
			for c in a.footprint():
				if amp.has(c):
					on = true
					break
		var key := a.get_instance_id()
		if on == _amped.has(key):
			continue
		if on:
			_amped[key] = true
			a.field_bonus = AMP_BONUS
			count["amp_on"] += 1
			b.vfx.spawn("burst", b.fx_root, b._chest(a), 0.4, 0.0, AMP_COL)
			b.dmg_log.spawn_status(b._chest(a) + Vector2(0, -20), "증폭!", AMP_COL, a)
			b.audio.play("chime", 0.05, -8.0, 1.3)
		else:
			_amped.erase(key)
			a.field_bonus = 0.0


# ---------------------------------------------------------------- 방전 격자

func _discharge(cells: Array[Vector2i]) -> void:
	count["shock"] += 1
	_flash = SHOCK_FLASH
	b.audio.play("lightning", 0.05, -2.0, 1.2)
	for c in cells:
		var p := VDData.to_screen(Vector2(c))
		b.vfx.spawn("burst", b.fx_root, p + Vector2(0, -20), 0.45, 0.0, SHOCK_HOT)
		b.vfx.spawn("shockwave", b.ground_fx, p, 0.35, 0.0, SHOCK_COL, Vector2(1.0, 0.5))
	var hit_any := false
	for list in [b.enemies, b.allies]:
		for u: VDUnit in list.duplicate():   # 쓰러지며 분열체가 끼어들 수 있다
			if not is_instance_valid(u) or not u.alive:
				continue
			var on := false
			for c in u.footprint():
				if cells.has(c):
					on = true
					break
			if not on:
				continue
			hit_any = true
			var hero := u.team == 0
			var ratio := SHOCK_DMG_HERO
			if not hero:
				var elite := u.is_boss or u.size > 1 or int(VDData.ENEMIES.get(u.id, {}).get("tier", 0)) >= 1
				ratio = SHOCK_DMG_ELITE if elite else SHOCK_DMG_ENEMY
			count["shock_hero_hits" if hero else "shock_hits"] += 1
			u.last_hit_by = "field"
			var dealt := u.take_damage(u.max_hp * ratio, "번개")
			b.dmg_log.spawn(b._chest(u) + Vector2(0, -16), int(dealt), not hero, u)
			if u.alive:
				u.stun(SHOCK_STUN_HERO if hero else SHOCK_STUN_ENEMY)
	if hit_any:
		b.camera.shake(0.2)


# ---------------------------------------------------------------- 그림

func _process(delta: float) -> void:
	_clock += delta
	if b == null or b.sandbox != null or b.room.is_empty():
		return
	queue_redraw()


func _draw() -> void:
	if b == null or b.sandbox != null or b.room.is_empty():
		return
	var label := b.state == VDBattle.State.PLACEMENT
	_draw_room(b.room, 1.0, label)
	# 갈림길: 다음 방의 장치도 미리 보인다 (길 고르는 근거)
	if b.state == VDBattle.State.CHOOSE_PATH or b.state == VDBattle.State.TRAVEL:
		for ex: Dictionary in b.exits:
			_draw_room(b.map.rooms[ex["room_id"]], 0.75, b.state == VDBattle.State.CHOOSE_PATH)


func _draw_room(room: Dictionary, alpha: float, label: bool) -> void:
	var fields: Dictionary = room.get("fields", {})
	var current: bool = int(room.get("id", -1)) == int(b.room.get("id", -2))
	for l: Vector2i in fields:
		var cell := VDMap.to_world(room, l.x, l.y)
		var p := VDData.to_screen(Vector2(cell))
		if fields[l] == "amp":
			_draw_amp(p, alpha, current and b._unit_at(cell, b.allies) != null)
		else:
			_draw_shock(p, alpha, current)
		if label:
			var text: String = VDMap.FIELD_NAMES[fields[l]]
			var col: Color = AMP_COL if fields[l] == "amp" else SHOCK_COL
			draw_string_outline(VDData.font(), p + Vector2(-60, 6), text, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 18, 6, Color(0.06, 0.04, 0.1, 0.85 * alpha))
			draw_string(VDData.font(), p + Vector2(-60, 6), text, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 18, Color(col.lightened(0.45), alpha))


## 증폭 패널: 호박빛 마름모 + 위로 흐르는 갈매기 무늬. 영웅이 서 있으면 더 밝다.
func _draw_amp(p: Vector2, alpha: float, occupied: bool) -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * 3.2)
	var outline := VDData.diamond(p, 6.0)
	var k := 1.0 if occupied else 0.8
	draw_colored_polygon(outline.slice(0, 4), Color(AMP_COL, (0.26 + 0.12 * pulse) * k * alpha))
	draw_polyline(outline, Color(AMP_COL.lightened(0.25), (0.55 + 0.35 * pulse) * k * alpha), 2.5)
	var inner := PackedVector2Array()
	for q in outline:
		inner.append(p + (q - p) * 0.55)
	draw_polyline(inner, Color(AMP_COL, 0.45 * k * alpha), 1.5)
	# 갈매기 무늬 둘이 아래에서 위로 흘러 올라간다
	for i in 2:
		var u := fposmod(_clock * (1.3 if occupied else 0.7) + i * 0.5, 1.0)
		var y := 9.0 - 18.0 * u
		var a := sin(u * PI) * k * alpha
		draw_polyline(PackedVector2Array([p + Vector2(-11, y + 5), p + Vector2(0, y - 1), p + Vector2(11, y + 5)]), Color(1.0, 0.93, 0.7, 0.9 * a), 2.5)


## 방전 격자: 평소엔 푸른 격자, 방전 직전엔 노랗게 빠르게 깜빡이고, 터지는 순간 흰 섬광과 번개 줄기.
func _draw_shock(p: Vector2, alpha: float, live: bool) -> void:
	var outline := VDData.diamond(p, 6.0)
	var poly := outline.slice(0, 4)
	var warn := live and b.state == VDBattle.State.BATTLE and warning()
	var charge := clampf(_t / SHOCK_IDLE, 0.0, 1.0) if live and b.state == VDBattle.State.BATTLE else 0.0
	if warn:
		var k := clampf((_t - SHOCK_IDLE) / SHOCK_WARN, 0.0, 1.0)
		var blink := 0.5 + 0.5 * sin(_clock * (14.0 + 22.0 * k))
		draw_colored_polygon(poly, Color(SHOCK_HOT, (0.12 + 0.4 * k * blink) * alpha))
		draw_polyline(outline, Color(SHOCK_HOT, (0.6 + 0.4 * blink) * alpha), 3.0)
	else:
		draw_colored_polygon(poly, Color(SHOCK_COL, (0.2 + 0.12 * charge) * alpha))
		draw_polyline(outline, Color(SHOCK_COL.lightened(0.2), (0.75 + 0.25 * charge) * alpha), 2.5)
	# 격자 줄: 마름모를 3등분하는 선
	var grid_col := Color(SHOCK_HOT if warn else SHOCK_COL, (0.6 if warn else 0.5) * alpha)
	for f in [1.0 / 3.0, 2.0 / 3.0]:
		draw_line(poly[0].lerp(poly[1], f), poly[3].lerp(poly[2], f), grid_col, 1.5)
		draw_line(poly[0].lerp(poly[3], f), poly[1].lerp(poly[2], f), grid_col, 1.5)
	# 네 귀퉁이 전극: 충전될수록 밝아진다
	for q in poly:
		draw_circle(p + (q - p) * 0.82, 3.0, Color(SHOCK_HOT if warn else SHOCK_COL.lightened(0.4), (0.45 + 0.55 * maxf(charge, float(warn))) * alpha))
	if live and _flash > 0.0:
		var f := _flash / SHOCK_FLASH
		draw_colored_polygon(poly, Color(1, 1, 1, 0.75 * f * alpha))
		for i in 3:
			var pts := PackedVector2Array()
			var x := randf_range(-22.0, 22.0)
			for s in 6:
				pts.append(p + Vector2(x + randf_range(-9.0, 9.0) * float(s < 5), -110.0 + 22.0 * s))
			draw_polyline(pts, Color(SHOCK_HOT.lightened(0.5), f * alpha), 2.5)
