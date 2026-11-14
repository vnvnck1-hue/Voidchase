## VOID DEFENSE 전투 흐름의 굴곡. VDBattle._physics_process 가 tick() 을, 적 행동 차례에 try_leap() 을 부른다.
##   증원: 웨이브 2부터, 적이 절반 이하로 줄면 방 옆 가장자리에 균열이 열리고 1.4초 뒤 적이 2~4마리 내려앉는다 (웨이브당 한 번)
##   공허 오염: 웨이브 2부터 몇 초마다 아군 근처 바닥 한 칸이 붉게 깜빡이다(1.6초) 공허로 물든다(7초).
##             그 위에 선 영웅은 0.5초마다 최대 체력 4% 피해. 적(공허 생물)은 멀쩡하다. 영웅 AI 는 오염 칸을 피하고 벗어난다.
##   도약: 공허 파편이 3~5칸 떨어진 후열 영웅을 노리면 움츠렸다가 포물선으로 그 등 뒤에 뛰어들어 내려찍는다 (재사용 8초)
class_name VDFlow
extends RefCounted

const REINF_FROM_WAVE := 2
const REINF_WARN := 1.4
const REINF_POOL := ["normal", "fast", "skirmisher", "normal", "fast"]
const VOID_FROM_WAVE := 2
const VOID_EVERY := [5.5, 8.5]   # 다음 오염까지 (초, 무작위)
const VOID_WARN := 1.6
const VOID_LIFE := 7.0
const VOID_MAX := 3
const VOID_TICK := 0.5
const VOID_DMG := 0.04          # 틱마다 최대 체력 비율
const VOID_COL := Color(0.75, 0.15, 0.55)
const LEAP_FIRST := 2.0
const LEAP_CD := 8.0
const LEAP_RANGE := [3, 5]
const LEAP_WIND := 0.45
const LEAP_SEC := 0.38
const LEAP_HEIGHT := 110.0
const LEAP_DMG := 1.6           # 착지 피해 = 공격력 x
const LEAP_COL := Color(0.85, 0.45, 1.0)

var b: VDBattle
var count := {"reinf": 0, "void": 0, "void_hits": 0, "leap": 0}   # 테스트용
var _start_n := 0
var _reinf_done := false
var _reinf_pending := 0
var _void_t := 0.0
var _void_tick := 0.0
var _tiles := {}                # cell -> {"t": 경과, "warn": bool}
var _layer: Node2D
var _leap_ready := {}           # instance id -> 다음 도약 가능 시각
var _clock := 0.0


func _init(battle: VDBattle) -> void:
	b = battle


## 전투 시작: 상태 초기화.
func begin() -> void:
	_start_n = b._alive_count(b.enemies)
	_reinf_done = false
	_reinf_pending = 0
	_void_t = randf_range(VOID_EVERY[0], VOID_EVERY[1])
	_void_tick = 0.0
	_clock = 0.0
	_leap_ready.clear()
	clear_tiles()


## 증원이 오는 중이면 웨이브를 끝내지 않는다.
func pending() -> bool:
	return _reinf_pending > 0


func is_void(c: Vector2i) -> bool:
	var t: Dictionary = _tiles.get(c, {})
	return not t.is_empty() and not bool(t["warn"])


## footprint 중 한 칸이라도 오염(경고 중 포함)이면 true: 길 찾기가 피한다.
func is_hazard(u: VDUnit, at: Vector2i) -> bool:
	for c in u.footprint(at):
		if _tiles.has(c) or (b.field != null and b.field.is_hazard(c)):   # 방전 직전의 격자 칸도 피한다
			return true
	return false


func tick(dt: float) -> void:
	if b.state != VDBattle.State.BATTLE:
		if not _tiles.is_empty():
			clear_tiles()
		return
	_clock += dt
	_tick_reinforce()
	if b.wave >= VOID_FROM_WAVE:
		_tick_void(dt)


# ---------------------------------------------------------------- 증원

func _tick_reinforce() -> void:
	if _reinf_done or b.wave < REINF_FROM_WAVE or _start_n < 2:
		return
	var alive := b._alive_count(b.enemies)
	if alive == 0 or alive > ceili(_start_n * 0.5):
		return
	_reinf_done = true
	var n := clampi(2 + b.wave / 4, 2, 4)
	var cells := _edge_cells(n)
	if cells.is_empty():
		return
	count["reinf"] += 1
	_reinf_pending = cells.size()
	b._show_msg("균열 확장 — 공허 증원!", 1.4)
	b.audio.play("boss_roar", 0.05, -6.0, 1.3)
	for c in cells:
		VDSummonFx.play_portal(b.vfx, b.ground_fx, VDData.to_screen(Vector2(c)), false)
	var run := b._run_id
	await b.get_tree().create_timer(REINF_WARN, false).timeout
	if run != b._run_id or b.state != VDBattle.State.BATTLE:
		_reinf_pending = 0
		return
	var mult := VDData.scaling(b.wave)
	for c in cells:
		if b._occupied(c):
			c = b.free_cell_near(c, c)
			if b._occupied(c):
				continue   # 둘레 5칸이 다 차 있으면 겹쳐 내리지 않는다
		var t: String = REINF_POOL[randi() % REINF_POOL.size()]
		var e := b._make_unit(VDData.ENEMIES[t], t, 1, c, mult * 0.7, mult)
		e.casting = true   # 내려앉는 동안은 행동하지 않는다
		var foot := e.position
		e.appear(VDSummonFx.play_impact.bind(b.vfx, b.ground_fx, b.fx_root, b.camera, foot, false))
		b.enemies.append(e)
		b.audio.play("enemy_spawn", 0.12)
		var er: WeakRef = weakref(e)
		b.get_tree().create_timer(VDUnit.appear_duration(), false).timeout.connect(func() -> void:
			var e2 := er.get_ref() as VDUnit
			if e2 != null:
				e2.casting = false)
		await b.get_tree().create_timer(0.12, false).timeout
		if run != b._run_id or b.state != VDBattle.State.BATTLE:
			_reinf_pending = 0
			return
	_reinf_pending = 0


## 방 옆 가장자리(앞뒤 끝 말고 가로 양 끝) 빈 칸 n 개. 영웅에게서 너무 가까운 칸은 뺀다.
func _edge_cells(n: int) -> Array[Vector2i]:
	var lo := 99
	var hi := -99
	for l: Vector2i in b.room["cells"]:
		lo = mini(lo, l.y)
		hi = maxi(hi, l.y)
	var cand: Array[Vector2i] = []
	for l: Vector2i in b.room["cells"]:
		if (l.y != lo and l.y != hi) or l.x < 3 or l.x > int(b.room["len"]) - 2:
			continue
		var c := VDMap.to_world(b.room, l.x, l.y)
		if b._occupied(c) or _near_ally(c, 1):
			continue
		cand.append(c)
	cand.shuffle()
	# 양쪽에서 번갈아 나오게: 한쪽 끝으로 몰리지 않도록 정렬하지 않고 섞은 앞쪽 n 개
	return cand.slice(0, n)


func _near_ally(c: Vector2i, d: int) -> bool:
	for a in b.allies:
		if a.alive and a.dist_to_cell(c) <= d:
			return true
	return false


# ---------------------------------------------------------------- 공허 오염

func _tick_void(dt: float) -> void:
	_void_t -= dt
	if _void_t <= 0.0:
		_void_t = randf_range(VOID_EVERY[0], VOID_EVERY[1])
		_new_tile()
	var dirty := false
	for c in _tiles.keys():
		var t: Dictionary = _tiles[c]
		t["t"] = float(t["t"]) + dt
		if bool(t["warn"]) and float(t["t"]) >= VOID_WARN:
			t["warn"] = false
			t["t"] = 0.0
			b.vfx.spawn("burst", b.ground_fx, VDData.to_screen(Vector2(c)), 0.5, 0.0, VOID_COL)
		elif not bool(t["warn"]) and float(t["t"]) >= VOID_LIFE:
			_tiles.erase(c)
		dirty = true
	if dirty and _layer:
		_layer.queue_redraw()
	_void_tick += dt
	if _void_tick >= VOID_TICK:
		_void_tick = 0.0
		for a in b.allies:
			if not a.alive:
				continue
			for c in a.footprint():
				if is_void(c):
					count["void_hits"] += 1
					a.last_hit_by = "void"
					var dealt := a.take_damage(a.max_hp * VOID_DMG)
					b.dmg_log.spawn(b._chest(a) + Vector2(0, -16), int(dealt), false, a)
					break


## 아군 근처(2칸 안) 빈 바닥 한 칸을 오염 경고로.
func _new_tile() -> void:
	var live := 0
	for c in _tiles:
		live += 1
	if live >= VOID_MAX:
		return
	var heroes: Array[VDUnit] = []
	for a in b.allies:
		if a.alive:
			heroes.append(a)
	if heroes.is_empty():
		return
	var h: VDUnit = heroes[randi() % heroes.size()]
	var cand: Array[Vector2i] = []
	for l: Vector2i in b.room["cells"]:
		var c := VDMap.to_world(b.room, l.x, l.y)
		if _tiles.has(c) or h.dist_to_cell(c) > 2:
			continue
		cand.append(c)
	if cand.is_empty():
		return
	var c: Vector2i = cand[randi() % cand.size()]
	_tiles[c] = {"t": 0.0, "warn": true}
	count["void"] += 1
	_ensure_layer()
	b.ground_fx.move_child(_layer, b.ground_fx.get_child_count() - 1)   # 바닥 이펙트(체액·균열) 중에서는 맨 위
	b.audio.play("tick", 0.1, -4.0, 0.7)


func clear_tiles() -> void:
	_tiles.clear()
	if _layer:
		_layer.queue_redraw()


func _ensure_layer() -> void:
	if _layer and is_instance_valid(_layer):
		return
	_layer = Node2D.new()
	_layer.z_index = 0   # z 를 올리면 ground_fx 밖의 유닛(z 0)까지 덮어 캐릭터를 가린다 — 순서는 move_child 로만 정한다
	_layer.draw.connect(_draw_tiles)
	b.ground_fx.add_child(_layer)


func _draw_tiles() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	for c: Vector2i in _tiles:
		var t: Dictionary = _tiles[c]
		var p := VDData.to_screen(Vector2(c))
		var outline := VDData.diamond(p, 5.0)   # 닫힌 5점 (테두리용)
		var poly := outline.slice(0, 4)         # 채우기는 꼭짓점 4개만
		if bool(t["warn"]):
			var k := float(t["t"]) / VOID_WARN
			_layer.draw_colored_polygon(poly, Color(1.0, 0.3, 0.5, 0.08 + 0.18 * k * pulse))
			_layer.draw_polyline(outline, Color(1.0, 0.35, 0.55, 0.5 + 0.5 * pulse), 2.0)
		else:
			var fade := clampf((VOID_LIFE - float(t["t"])) / 0.6, 0.0, 1.0)
			if fade <= 0.01:
				continue
			_layer.draw_colored_polygon(poly, Color(VOID_COL.darkened(0.35), (0.55 + 0.15 * pulse) * fade))
			var inner := PackedVector2Array()
			for q in poly:
				inner.append(p + (q - p) * (0.55 + 0.1 * pulse))
			_layer.draw_colored_polygon(inner, Color(0.05, 0.0, 0.08, 0.7 * fade))
			_layer.draw_polyline(outline, Color(VOID_COL.lightened(0.3), 0.8 * fade), 2.0)


# ---------------------------------------------------------------- 도약

## 적 행동 차례: 도약했으면 true (이번 차례는 소비).
func try_leap(u: VDUnit, foes: Array[VDUnit]) -> bool:
	if VDTactics.role_of(u) != "flank" or b.ult.active:
		return false
	var id := u.get_instance_id()
	if not _leap_ready.has(id):
		_leap_ready[id] = _clock + LEAP_FIRST
	if _clock < float(_leap_ready[id]):
		return false
	var prey: VDUnit = null
	for f in foes:
		if not f.alive or not VDTactics.is_backline(f):
			continue
		var d := u.dist_to(f)
		if d >= LEAP_RANGE[0] and d <= LEAP_RANGE[1] and (prey == null or f.hp < prey.hp):
			prey = f
	if prey == null:
		return false
	var land := _landing(u, prey)
	if land.x == -999:
		return false
	_leap_ready[id] = _clock + LEAP_CD
	count["leap"] += 1
	_leap(u, prey, land)
	return true


## prey 옆 빈 칸: prey 가 노리는 쪽의 반대편(등 뒤)을 먼저.
func _landing(u: VDUnit, prey: VDUnit) -> Vector2i:
	var faced := b.tactics.target_of(prey)
	var look := Vector2(faced.cell - prey.cell).normalized() if faced != null else Vector2.ZERO
	var best := Vector2i(-999, -999)
	var best_s := INF
	for dir: Vector2i in VDTactics.DIRS:
		var c: Vector2i = prey.cell + dir
		if not b._fits(u, c) or is_hazard(u, c):
			continue
		var s := look.dot(Vector2(dir))   # 등 뒤일수록 작다
		if s < best_s:
			best_s = s
			best = c
	return best


func _leap(u: VDUnit, prey: VDUnit, land: Vector2i) -> void:
	var run := b._run_id
	u.windup(prey.position, LEAP_WIND)
	b.juice.telegraph(prey, LEAP_WIND + LEAP_SEC, LEAP_COL)
	b.dmg_log.spawn_status(b._chest(u), "도약", LEAP_COL, u)
	await b.get_tree().create_timer(LEAP_WIND, false).timeout
	if not is_instance_valid(u):
		return
	u.release_windup()
	if run != b._run_id or not u.alive or u.stun_timer > 0.0 or b.state != VDBattle.State.BATTLE:
		return
	if not b._fits(u, land):
		return
	b.vfx.spawn("dash", b.ground_fx, u.position, 0.9, 0.0, LEAP_COL, Vector2.ONE, VDData.to_screen(Vector2(land)).x < u.position.x, 1.8)
	b.audio.play("whoosh", 0.05)
	u.winding = true   # 공중에선 행동하지 않는다
	u.leap_to(land, LEAP_SEC, LEAP_HEIGHT)
	await b.get_tree().create_timer(LEAP_SEC, false).timeout
	if not is_instance_valid(u):
		return
	u.winding = false
	if run != b._run_id or not u.alive:
		return
	b.vfx.spawn("dust", b.ground_fx, u.position, 1.4, 0.0, Color(1, 1, 1, 0.8))
	b.vfx.spawn("shockwave", b.ground_fx, u.position, 0.5, 0.0, LEAP_COL, Vector2(1.0, 0.5))
	b.camera.shake(0.3)
	if is_instance_valid(prey) and prey.alive and u.dist_to(prey) <= 1:
		u.attack_anim(prey.position)
		prey.last_hit_by = u
		var dealt := prey.take_damage(u.atk * LEAP_DMG)
		b.dmg_log.spawn(b._chest(prey) + Vector2(0, -16), int(dealt), true, prey)
		b.hurt_glitch.kick(0.6, prey.id)
		b.audio.voice(prey.id, "hurt")
		b.shockwave.add(b._chest(prey), "light")
	u.atk_timer = u.atk_cd * u.cd_mult()   # 착지하자마자 이어서 친다
