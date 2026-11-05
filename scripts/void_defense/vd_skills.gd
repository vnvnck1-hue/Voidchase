## VOID DEFENSE 액티브 스킬: 롤토체스처럼 기본 공격으로 마나를 채우면 VDBattle 이 cast() 를 부른다.
## 데모(GridDefenseGame_share.html) executeActiveSkill 의 warrior/ranger/mage 를 기사·건너·마법사로 옮겼다.
##   기사 용맹한 강습: 가장 먼 적 옆으로 도약 → 착지 주변 피해·기절 + 가드
##   건너 다중 사격: 적에게서 먼 쪽으로 한 칸 물러난 뒤 가까운 적 3명에게 강탄
##   마법사 절대 영도: 모든 적 빙결 + 냉기 피해
##   힐러 생명의 축복: 아군 전체 회복
## 수치는 VDData.SKILLS.
class_name VDSkills
extends RefCounted

const LEAP_SEC := 0.34
const LEAP_HEIGHT := 150.0

var b: VDBattle
var cast_count := {}         # 테스트용: 영웅 id 별 시전 횟수


func _init(battle: VDBattle) -> void:
	b = battle


## 시전에 성공하면 true (마나는 호출한 쪽이 비운다). 적이 없으면 시전하지 않는다.
func cast(u: VDUnit) -> bool:
	if not VDData.SKILLS.has(u.id) or _alive(b.enemies).is_empty():
		return false
	var sk: Dictionary = VDData.SKILLS[u.id]
	var ok := false
	match u.id:
		"knight":
			ok = _valiant_assault(u, sk)
		"gunner":
			ok = _multi_shot(u, sk)
		"mage":
			ok = _absolute_zero(u, sk)
		"healer":
			ok = _blessing(u, sk)
	if ok:
		cast_count[u.id] = int(cast_count.get(u.id, 0)) + 1
		print("[VD] skill: %s -> %s" % [u.display_name, sk["name"]])
		u.cast_pulse()
		b.dmg_log.spawn_status(b._chest(u) + Vector2(0, -30), sk["name"] + "!", u.color.lightened(0.35), u)
		b.vfx.spawn("burst", b.fx_root, b._chest(u), 0.4, 0.0, u.color.lightened(0.3))
	return ok


# ---------------------------------------------------------------- knight

func _valiant_assault(u: VDUnit, sk: Dictionary) -> bool:
	var target := _farthest(u, _alive(b.enemies))
	if target == null:
		return false
	var land := _landing_cell(u, target.cell)
	var run := b._run_id
	u.casting = true
	u.guard_timer = float(sk["guard"])
	u.guard_reduce = float(sk["guard_reduce"])
	b.audio.play("knight_attack", 0.05, 2.0)
	b.vfx.spawn("dash", b.ground_fx, u.position, 1.3, 0.0, Color(0.7, 0.85, 1.0), Vector2.ONE, VDData.to_screen(Vector2(land)).x < u.position.x)
	u.leap_to(land, LEAP_SEC, LEAP_HEIGHT)
	_knight_land(u, sk, target, land, run)
	return true


func _knight_land(u: VDUnit, sk: Dictionary, target: VDUnit, land: Vector2i, run: int) -> void:
	await b.get_tree().create_timer(LEAP_SEC).timeout
	u.casting = false
	if not _still_on(run) or not u.alive:
		return
	var foot := VDData.to_screen(Vector2(land))
	b.vfx.spawn("slam", b.fx_root, foot, 1.4, 0.0, Color(0.7, 0.85, 1.0))
	b.vfx.spawn("shockwave", b.ground_fx, foot, 0.75, 0.0, Color(0.55, 0.75, 1.0), Vector2(1.0, 0.5))
	b.vfx.spawn("dust", b.ground_fx, foot, 1.8, 0.0, Color(1, 1, 1, 0.8))
	b.audio.play("knight_hit", 0.05, 3.0)
	b.camera.shake(0.9)
	b.camera.hitstop(0.09)
	var base := floorf(u.atk * float(sk["dmg"]))
	for e in _alive(b.enemies):
		var on_target := e == target
		var near := absi(e.cell.x - land.x) <= 1 and absi(e.cell.y - land.y) <= 1
		if not on_target and not near:
			continue
		var dmg := 0.0
		if on_target:
			var hp_ratio: float = sk["impact_hp_boss"] if e.is_boss else sk["impact_hp"]
			dmg += floorf(e.max_hp * hp_ratio) + floorf(u.atk * float(sk["impact_atk"]))
		if near:
			dmg += base
		e.stun(float(sk["stun"]))
		_hit(e, dmg, "hit_heavy", Color(0.85, 0.92, 1.0), 2.0)


## 대상 바로 옆(방 안, 빈 칸) 중 지금 자리에서 가까운 칸. 없으면 대상에 가장 가까운 빈 칸.
func _landing_cell(u: VDUnit, goal: Vector2i) -> Vector2i:
	var best := u.cell
	var best_score := 1 << 30
	for a in range(-3, 4):
		for c in range(-3, 4):
			var cell := goal + Vector2i(a, c)
			if not VDMap.in_room(b.room, cell) or (b._occupied(cell) and cell != u.cell):
				continue
			var score := VDData.manhattan(cell, goal) * 100 + VDData.manhattan(cell, u.cell)
			if score < best_score:
				best_score = score
				best = cell
	return best


# ---------------------------------------------------------------- gunner

func _multi_shot(u: VDUnit, sk: Dictionary) -> bool:
	u.casting = true
	_multi_shot_run(u, sk, b._run_id)
	return true


func _multi_shot_run(u: VDUnit, sk: Dictionary, run: int) -> void:
	var foes := _alive(b.enemies)
	# 상하좌우 빈 칸 중 가장 가까운 적과 가장 먼 칸으로 한 걸음 물러난다
	var retreat := u.cell
	var best := _min_foe_dist(u.cell, foes)
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nc: Vector2i = u.cell + dir
		if not VDMap.in_room(b.room, nc) or b._occupied(nc):
			continue
		var d := _min_foe_dist(nc, foes)
		if d > best:
			best = d
			retreat = nc
	if retreat != u.cell:
		b.vfx.spawn("dash", b.ground_fx, u.position, 1.0, 0.0, Color.WHITE, Vector2.ONE, VDData.to_screen(Vector2(retreat)).x > u.position.x)
		u.move_to_cell(retreat, 0.16)
		await b.get_tree().create_timer(0.18).timeout
		if not _still_on(run) or not u.alive:
			u.casting = false
			return
	foes.sort_custom(func(x: VDUnit, y: VDUnit) -> bool: return VDData.manhattan(u.cell, x.cell) < VDData.manhattan(u.cell, y.cell))
	var dmg := floorf(u.atk * float(sk["dmg"]))
	for i in mini(int(sk["targets"]), foes.size()):
		var t: VDUnit = foes[i]
		if not is_instance_valid(t) or not t.alive:
			continue
		var from := b._chest(u)
		var to := b._chest(t)
		var dir := (to - from).normalized()
		u.face(to.x - from.x)
		b.vfx.spawn("hit_light", b.fx_root, from + dir * 40.0, 1.8, dir.angle(), Color(1.0, 0.85, 0.4))
		VDFx.tracer(b.fx_root, from + dir * 40.0, to, Color(1.0, 0.8, 0.35))
		b.audio.play("gun", 0.05, 3.0)
		b.camera.shake(0.4)
		_hit(t, dmg, "gun_hit", Color(1.0, 0.9, 0.5), 0.8)
		await b.get_tree().create_timer(0.11).timeout
		if not _still_on(run) or not u.alive:
			break
	u.casting = false


# ---------------------------------------------------------------- mage

func _absolute_zero(u: VDUnit, sk: Dictionary) -> bool:
	u.casting = true
	b.audio.play("mage_cast", 0.03, 3.0)
	b.vfx.loop("magic_circle", b.ground_fx, u.position, 0.6, 0.28, 0.0, Color(0.5, 0.8, 1.0), Vector2(1.0, 0.5), 0.3, 2.0)
	b.vfx.spawn("shockwave", b.ground_fx, u.position, 2.2, 0.0, Color(0.55, 0.85, 1.0), Vector2(1.0, 0.5), false, 0.8)
	_absolute_zero_hit(u, sk, b._run_id)
	return true


func _absolute_zero_hit(u: VDUnit, sk: Dictionary, run: int) -> void:
	await b.get_tree().create_timer(0.3).timeout
	u.casting = false
	if not _still_on(run):
		return
	b.audio.play("mage_hit", 0.03, 3.0)
	b.camera.shake(0.7)
	b.camera.hitstop(0.07)
	var dmg := floorf(u.atk * float(sk["dmg"]))
	for e in _alive(b.enemies):
		e.stun(float(sk["freeze"]), true)
		b.vfx.spawn("lightning", b.fx_root, e.position + Vector2(0, e._top * 0.6), 0.35, 0.0, Color(0.6, 0.85, 1.0))
		_hit(e, dmg, "burst", Color(0.6, 0.85, 1.0), 0.45)


# ---------------------------------------------------------------- healer

func _blessing(u: VDUnit, sk: Dictionary) -> bool:
	b.audio.play("heal", 0.03, 3.0)
	b.vfx.loop("magic_circle", b.ground_fx, u.position, 0.8, 0.32, 0.0, Color(0.6, 1.0, 0.7), Vector2(1.0, 0.5), 0.35, 1.5)
	for a in _alive(b.allies):
		var amount := floorf(a.max_hp * float(sk["heal_hp"]) + u.atk * float(sk["heal_atk"]))
		var before := a.hp
		a.heal(amount)
		b.vfx.spawn("heal", b.fx_root, b._chest(a), 0.65, 0.0, Color(0.8, 1.0, 0.8))
		b.vfx.loop("magic_circle", b.ground_fx, a.position, 0.5, 0.16, 0.0, Color(0.6, 1.0, 0.7), Vector2(1.0, 0.5), 0.3, 2.0)
		var gain := int(a.hp - before)
		if gain > 0:
			b.dmg_log.spawn_status(b._chest(a), "+%d" % gain, Color(0.55, 1.0, 0.6), a)
	return true


# ---------------------------------------------------------------- helpers

## 피해 + 명중 연출 + 숫자 (스킬 피해는 언제나 큰 숫자).
func _hit(e: VDUnit, dmg: float, fx: String, tint: Color, fx_scale: float) -> void:
	if not is_instance_valid(e) or not e.alive or dmg <= 0.0:
		return
	var at := b._chest(e)
	var dealt := e.take_damage(dmg)
	b.vfx.spawn(fx, b.fx_root, at, fx_scale, randf() * TAU, tint)
	b.dmg_log.spawn(at + Vector2(0, -16), int(dealt), true, e)


func _still_on(run: int) -> bool:
	return run == b._run_id and b.state == VDBattle.State.BATTLE


func _alive(list: Array[VDUnit]) -> Array[VDUnit]:
	var out: Array[VDUnit] = []
	for x in list:
		if x.alive:
			out.append(x)
	return out


func _farthest(u: VDUnit, foes: Array[VDUnit]) -> VDUnit:
	var best: VDUnit = null
	var best_d := -1
	for f in foes:
		var d := VDData.manhattan(u.cell, f.cell)
		if d > best_d:
			best_d = d
			best = f
	return best


func _min_foe_dist(cell: Vector2i, foes: Array[VDUnit]) -> int:
	var m := 1 << 30
	for f in foes:
		m = mini(m, VDData.manhattan(cell, f.cell))
	return m
