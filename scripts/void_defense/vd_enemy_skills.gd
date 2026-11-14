## VOID DEFENSE 적 특수 스킬. VDBattle._tick_team 이 적마다 tick() 을 불러 재사용 대기가 차면 시전한다.
##   공허 망루 공허 섬광포: 머리 쌍포에 붉은 빛을 모았다가 1.5초 동안 레이저를 쏘며 10연타
##   공허 군주 공허 강하  : 체력이 가장 낮은 아군 옆으로 순간이동해 위에서 내려찍는다 (대상 기절 + 주변 피해)
## 시전 순간 짧은 강조: 시전자·대상만 남기고 무대가 살짝 어두워지고(궁극기보다 옅게, 전투는 멈추지 않음)
## 스킬 이름 글자·줌 펀치·짧은 슬로모션·흔들림. 수치는 VDData.ENEMY_SKILLS.
class_name VDEnemySkills
extends RefCounted

const DIM := 0.2                  # 강조 때 무대 어둡기 (궁극기 0.38 보다 옅게)
const LASER_COL := Color(1.0, 0.25, 0.42)
const DESCENT_COL := Color(0.72, 0.32, 1.0)
const VANISH_SEC := 0.14
const DROP_SEC := 0.13
const DROP_HEIGHT := 280.0

var b: VDBattle
var cast_count := {}              # 테스트용: 적 id 별 시전 횟수
var laser_hits := 0               # 테스트용: 레이저 명중 수 (누적)
var beam_log: Array[int] = []     # 테스트용: 섬광포 한 번마다 들어간 타수 (기절·대상 없음으로 끊기면 10 미만)
var last_descent := {}            # 테스트용: 마지막 공허 강하 {target, hp_rank_ok, land, adjacent}


## 레이저 빔: 바깥 번짐 · 몸통 · 흰 심지 세 겹 + 양 끝 빛 덩어리. follow 가 매 프레임 [시작, 끝] 을 돌려준다.
class Beam extends Node2D:
	var follow: Callable
	var col := Color.RED
	var k := 0.0
	var _from := Vector2.ZERO
	var _to := Vector2.ZERO

	func _process(_d: float) -> void:
		if follow.is_valid():
			var p: Array = follow.call()
			_from = p[0]
			_to = p[1]
		queue_redraw()

	func _draw() -> void:
		if k <= 0.01:
			return
		var flick := 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.06)
		var w := 20.0 * k * flick
		draw_line(_from, _to, Color(col, 0.3 * k), w * 2.0)
		draw_line(_from, _to, Color(col.lightened(0.25), 0.8 * k), w)
		draw_line(_from, _to, Color(1.0, 0.95, 0.97, k), w * 0.32)
		draw_circle(_from, w * 0.95, Color(col.lightened(0.3), 0.8 * k))
		draw_circle(_from, w * 0.42, Color(1, 1, 1, k))
		draw_circle(_to, w * 1.2, Color(col, 0.55 * k))
		draw_circle(_to, w * 0.5, Color(1, 1, 1, k))


func _init(battle: VDBattle) -> void:
	b = battle


## 적 하나의 재사용 대기를 돌리고, 차면 시전한다. 시전을 시작했으면 true (그 틱의 이동·공격은 건너뛴다).
func tick(u: VDUnit, dt: float) -> bool:
	if not VDData.ENEMY_SKILLS.has(u.id):
		return false
	var sk: Dictionary = VDData.ENEMY_SKILLS[u.id]
	var t := float(u.get_meta("eskill_t", 0.0)) + dt
	var need := float(u.get_meta("eskill_need", sk["first"]))
	u.set_meta("eskill_t", t)
	if t < need * u.cd_mult():
		return false
	var ok := false
	match u.id:
		"longneck":
			ok = _void_beam(u, sk)
		"boss":
			ok = _void_descent(u, sk)
	if not ok:
		return false   # 대상이 없으면 다음 틱에 다시 본다
	u.set_meta("eskill_t", 0.0)
	u.set_meta("eskill_need", float(sk["cd"]))
	cast_count[u.id] = int(cast_count.get(u.id, 0)) + 1
	print("[VD] enemy skill: %s -> %s" % [u.display_name, sk["name"]])
	return true


# ---------------------------------------------------------------- 강조 연출

## 시전 순간: 무대 살짝 어둡게(시전자·대상만 밝게) + 스킬 이름 글자 + 줌 펀치 + 짧은 슬로모션 + 바닥 링·몸 빛.
func _announce(u: VDUnit, target: VDUnit, sk: Dictionary, col: Color, hold: float) -> void:
	b.ult.spotlight([u, target], DIM, hold)
	b.juice.pop_world(u.position + Vector2(0, u._top - 46.0), sk["name"] + "!", col.lightened(0.15), 27.0, 0.5)
	b.camera.punch(0.035)
	b.camera.shake(0.3)
	b.camera.slowmo(0.3, 0.5)
	b.focus.add_heat(u.position, 2.5)
	u._cast_glow = 1.0
	b.vfx.spawn("shockwave", b.ground_fx, u.position, 0.55 * u.size, 0.0, Color(col, 0.85), Vector2(1.0, 0.5))
	b.vfx.spawn("burst", b.fx_root, b._chest(u), 0.45, 0.0, col.lightened(0.2))
	b.audio.play("rise", 0.0, 0.0, 0.55)


# ---------------------------------------------------------------- 공허 망루: 공허 섬광포

func _muzzle(u: VDUnit) -> Vector2:
	return u.position + Vector2(u._facing * 18.0, u._top * 0.9)


func _void_beam(u: VDUnit, sk: Dictionary) -> bool:
	var target := _nearest_in(u, int(sk["range"]))
	if target == null:
		return false
	_void_beam_run(u, sk, target)
	return true


func _void_beam_run(u: VDUnit, sk: Dictionary, target: VDUnit) -> void:
	var run := b._run_id
	var charge := float(sk["charge"])
	var dur := float(sk["dur"])
	var hits := int(sk["hits"])
	u.casting = true
	_announce(u, target, sk, LASER_COL, charge + dur + 0.15)
	u.windup(target.position, charge)
	b.juice.telegraph(target, charge, LASER_COL)
	# 충전: 쌍포 사이에 붉은 구슬이 커진다
	var orb := b.vfx.loop("orb", b.fx_root, _muzzle(u), charge + 0.1, 0.06, 0.0, LASER_COL, Vector2.ONE, 0.1, 6.0)
	if orb:
		orb.create_tween().tween_property(orb, "scale", orb.scale * 3.2, charge).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await b.get_tree().create_timer(charge, false).timeout
	if not is_instance_valid(u):
		return
	u.release_windup()
	if not _can_go_on(u, run):
		u.casting = false
		return
	var st := {"t": target}
	if not st["t"].alive:
		st["t"] = _nearest_in(u, int(sk["range"]) + 1)
		if st["t"] == null:
			u.casting = false
			return
	var beam := Beam.new()
	beam.col = LASER_COL
	beam.material = VDVfx.add_material()
	beam.follow = func() -> Array:
		if not is_instance_valid(u):
			return [Vector2.ZERO, Vector2.ZERO]
		var t: VDUnit = st["t"]
		var to: Vector2 = b._chest(t) if is_instance_valid(t) else _muzzle(u)
		return [_muzzle(u), to]
	b.fx_root.add_child(beam)
	beam.create_tween().tween_property(beam, "k", 1.0, 0.08)
	b.vfx.spawn("hit_light", b.fx_root, _muzzle(u), 2.4, 0.0, LASER_COL)
	b.audio.play("lightning", 0.0, 6.0, 0.75)
	b.camera.punch(0.03)
	b.camera.shake(0.35)
	var step := dur / hits
	var landed := 0
	for i in hits:
		if not _can_go_on(u, run):
			break
		var t: VDUnit = st["t"]
		if not is_instance_valid(t) or not t.alive or u.dist_to(t) > int(sk["range"]) + 1:
			t = _nearest_in(u, int(sk["range"]) + 1)
			if t == null:
				break
			st["t"] = t
		u.face(t.position.x - u.position.x)
		_beam_hit(u, t, u.atk * float(sk["dmg"]), i == hits - 1)
		landed += 1
		await b.get_tree().create_timer(step, false).timeout
		if not is_instance_valid(u):
			break
	beam_log.append(landed)
	# 빔이 가늘어지며 꺼진다
	if is_instance_valid(beam):
		var tw := beam.create_tween()
		tw.tween_property(beam, "k", 0.0, 0.16)
		tw.tween_callback(beam.queue_free)
	if is_instance_valid(u):
		u.casting = false
		u.atk_timer = 0.0


func _beam_hit(u: VDUnit, t: VDUnit, dmg: float, last: bool) -> void:
	laser_hits += 1
	t.last_hit_by = u
	var dealt := t.take_damage(dmg)
	var at := b._chest(t) + Vector2(randf_range(-10, 10), randf_range(-12, 8))
	b.vfx.spawn("hit_light", b.fx_root, at, 1.5 if last else 1.1, randf() * TAU, LASER_COL.lightened(0.2))
	b.dmg_log.spawn(at + Vector2(0, -16), int(dealt), last, t)
	if dealt > 0.0:
		b.hurt_glitch.kick(0.6 if last else 0.3, t.id)
	b.audio.play("enemy_hit", 0.15, -4.0, 1.35)
	if last:
		# 마지막 한 방: 폭발 + 그을음 + 조금 더 센 흔들림
		b.vfx.spawn("burst", b.fx_root, at, 0.55, 0.0, LASER_COL)
		b.juice.scorch(t.position + Vector2(randf_range(-8, 8), 4), LASER_COL, 28.0)
		b.camera.shake(0.45)
		b.audio.play("explode", 0.05, 0.0, 1.1)
	else:
		b.camera.shake(0.12)


# ---------------------------------------------------------------- 공허 군주: 공허 강하

func _void_descent(u: VDUnit, sk: Dictionary) -> bool:
	var target := _weakest()
	if target == null:
		return false
	_void_descent_run(u, sk, target)
	return true


func _void_descent_run(u: VDUnit, sk: Dictionary, target: VDUnit) -> void:
	var run := b._run_id
	var charge := float(sk["charge"])
	var hang := float(sk["hang"])
	u.casting = true
	_announce(u, target, sk, DESCENT_COL, charge + VANISH_SEC + hang + DROP_SEC + 0.35)
	b.nebula_tuner.danger_flash()
	b.audio.play("boss_roar", 0.0, -5.0, 1.3)
	u.windup(target.position, charge)
	b.juice.telegraph(target, charge + VANISH_SEC + hang + DROP_SEC, DESCENT_COL)
	b.vfx.loop("portal", b.ground_fx, u.position, charge + VANISH_SEC, 0.45, 0.0, Color(0.55, 0.25, 1.0), Vector2(1.0, 0.5), 0.12, 4.0)
	await b.get_tree().create_timer(charge, false).timeout
	if not is_instance_valid(u):
		return
	u.release_windup()
	if not _can_go_on(u, run):
		u.casting = false
		return
	if not target.alive:
		target = _weakest()
		if target == null:
			u.casting = false
			return
	var land := b.skills._landing_cell(u, target)
	var land_foot := u.foot_at(land)
	# 사라짐: 제자리 섬광 + 휙. 내려앉을 자리에 균열이 먼저 열린다
	b.vfx.spawn("burst", b.fx_root, b._chest(u), 0.6, 0.0, DESCENT_COL)
	b.vfx.spawn("lightning", b.fx_root, u.position + Vector2(0, u._top * 0.9), 0.5, 0.0, DESCENT_COL.lightened(0.3))
	b.audio.play("whoosh", 0.03, 3.0, 0.6)
	b.vfx.loop("portal", b.ground_fx, land_foot, VANISH_SEC + hang + DROP_SEC + 0.1, 0.55, 0.0, Color(0.85, 0.4, 1.0), Vector2(1.0, 0.5), 0.1, -5.0)
	last_descent = {"target": target.id, "target_hp": target.hp, "land": land,
		"adjacent": target.dist_to_cell(land) <= 1, "weakest": _weakest() == target}
	u.teleport_drop(land, target.position.x, VANISH_SEC, hang, DROP_SEC, DROP_HEIGHT, _descent_land.bind(u, sk, target, land, run))
	await b.get_tree().create_timer(VANISH_SEC + hang + DROP_SEC + 0.25, false).timeout
	if is_instance_valid(u):
		u.casting = false
		u.atk_timer = 0.0


func _descent_land(u: VDUnit, sk: Dictionary, target: VDUnit, land: Vector2i, run: int) -> void:
	if not _can_go_on(u, run):
		return
	var foot := u.position
	b.vfx.spawn("slam", b.fx_root, foot, 1.9, 0.0, DESCENT_COL.lightened(0.2))
	b.vfx.spawn("shockwave", b.ground_fx, foot, 1.0, 0.0, Color(DESCENT_COL, 0.9), Vector2(1.0, 0.45))
	b.shockwave.add(foot, "slam", 1.2)
	b.vfx.spawn("dust", b.ground_fx, foot, 2.2, 0.0, Color(0.9, 0.8, 1.0, 0.9))
	b.vfx.spawn("burst", b.ground_fx, foot, 0.22, 0.0, Color(1.0, 0.8, 1.0, 0.85), Vector2(1.6, 0.5))
	b.juice.scorch(foot, DESCENT_COL, 46.0)
	b.audio.play("boss_slam", 0.03, 2.0, 0.75)
	b.audio.play("explode", 0.05, -2.0, 0.8)
	b.camera.shake(0.85)
	b.camera.hitstop(0.1)
	b.camera.punch(0.05)
	for a in b.allies:
		if not a.alive:
			continue
		var on_target := a == target
		var gap := VDData.rect_gap(a.cell, a.size, land, u.size)
		if not on_target and (gap.x > 1 or gap.y > 1):
			continue
		var dmg := u.atk * float(sk["dmg"] if on_target else sk["splash"])
		a.last_hit_by = u
		var dealt := a.take_damage(dmg)
		var at := b._chest(a)
		b.vfx.spawn("hit_light", b.fx_root, at, 3.0, randf() * TAU, DESCENT_COL.lightened(0.3))
		b.dmg_log.spawn(at + Vector2(0, -16), int(dealt), true, a)
		if dealt > 0.0:
			b.hurt_glitch.kick(1.0 if on_target else 0.6, a.id)
		if on_target and a.alive:
			a.stun(float(sk["stun"]))
			b.dmg_log.spawn_status(at + Vector2(0, -50), "기절!", Color(1.0, 0.85, 0.4), a)


# ---------------------------------------------------------------- helpers

func _can_go_on(u: VDUnit, run: int) -> bool:
	return is_instance_valid(u) and u.alive and u.stun_timer <= 0.0 and run == b._run_id and b.state == VDBattle.State.BATTLE


func _nearest_in(u: VDUnit, reach: int) -> VDUnit:
	var best: VDUnit = null
	var best_d := reach + 1
	for a in b.allies:
		if not a.alive:
			continue
		var d := u.dist_to(a)
		if d < best_d:
			best_d = d
			best = a
	return best


## 체력(현재 값)이 가장 낮은 살아 있는 아군.
func _weakest() -> VDUnit:
	var best: VDUnit = null
	for a in b.allies:
		if a.alive and (best == null or a.hp < best.hp):
			best = a
	return best
