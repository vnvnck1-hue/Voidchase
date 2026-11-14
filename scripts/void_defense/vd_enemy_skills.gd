## VOID DEFENSE 적 특수 스킬. VDBattle._tick_team 이 적마다 tick() 을 불러 재사용 대기가 차면 시전한다.
##   공허 망루 공허 섬광포: 머리 쌍포에 붉은 빛을 모았다가 1.5초 동안 레이저를 쏘며 10연타
##                          대상이 너무 가까우면 쓰지 않고, 적당히 물러난 뒤에 쓴다 (min_range).
##   공허 망령 공허 촉수 난타: 촉수 7가닥이 뻗어 나와 번갈아 빠르게 찌른다 (VDWraithTentacle 본 사슬 + 셰이더, 타격 VDWraithHitFx)
##   공허 망령 순간이동    : 재사용 대기마다 아군에게서 가장 먼 자리로 옮겨 가 곧바로 쏜다 (스킬과 따로 돈다).
##                          옮긴 뒤 절반 확률로 쏘는 대신 촉수 난타를 쓴다.
##   공허 망령 회피        : 강한 공격(궁극기 등)을 맞는 순간 높은 확률로 순간이동해 피한다 (try_dodge — VDUlts·VDSkills 의 _hit 이 묻는다)
##   공허 군주 공허 강하  : 체력이 가장 낮은 아군 옆으로 순간이동해 위에서 내려찍는다 (대상 기절 + 주변 피해)
## 시전 순간 짧은 강조: 시전자·대상만 남기고 무대가 살짝 어두워지고(궁극기보다 옅게, 전투는 멈추지 않음)
## 스킬 이름 글자·줌 펀치·짧은 슬로모션·흔들림. 수치는 VDData.ENEMY_SKILLS.
class_name VDEnemySkills
extends RefCounted

const DIM := 0.2                  # 강조 때 무대 어둡기 (궁극기 0.38 보다 옅게)
const LASER_COL := Color(1.0, 0.25, 0.42)
const DESCENT_COL := Color(0.72, 0.32, 1.0)
const TENTACLE_COL := Color(0.66, 0.3, 1.0)
const BLINK_SEC := 0.13           # 순간이동: 사라지는 시간 = 나타나는 시간
const VANISH_SEC := 0.14
const DROP_SEC := 0.13
const DROP_HEIGHT := 280.0

var b: VDBattle
var gazer: VDGazerSkills          # 공허 응시자의 공격 패턴 다섯 가지
var cast_count := {}              # 테스트용: 적 id 별 시전 횟수
var laser_hits := 0               # 테스트용: 레이저 명중 수 (누적)
var beam_log: Array[int] = []     # 테스트용: 섬광포 한 번마다 들어간 타수 (기절·대상 없음으로 끊기면 10 미만)
var too_close := 0                # 테스트용: 대상이 너무 가까워 촉수 난타를 미룬 틱 수
var tentacle_hits := 0            # 테스트용: 촉수 난타 명중 수 (누적)
var dodges := 0                   # 테스트용: 강공격 회피 횟수
var force_dodge := -1             # 테스트용: 0 절대 안 피함 · 1 반드시 피함 · -1 확률대로
var force_followup := -1          # 테스트용: 순간이동 뒤 촉수 난타 0 안 씀 · 1 반드시 · -1 확률대로
var followups := 0                # 테스트용: 순간이동 뒤 촉수 난타로 이어진 횟수
var last_blink := {}              # 테스트용: 마지막 순간이동 {from, to, before, after} (before·after = 가장 가까운 아군까지 거리)
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
	gazer = VDGazerSkills.new(battle, self)


## 적 하나의 재사용 대기를 돌리고, 차면 시전한다. 시전을 시작했으면 true (그 틱의 이동·공격은 건너뛴다).
func tick(u: VDUnit, dt: float) -> bool:
	if u.id == "gazer":
		return gazer.tick(u, dt)      # 패링 공격 두 가지도 여기서 돌려 쓴다
	if VDData.PARRY.has(u.id) and _parry_tick(u, dt):
		return true
	if not VDData.ENEMY_SKILLS.has(u.id):
		return false
	var sk: Dictionary = VDData.ENEMY_SKILLS[u.id]
	if u.id == "wraith" and _blink_tick(u, sk, dt):
		return true
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
		"wraith":
			ok = _tentacle_barrage(u, sk)
	if not ok:
		return false   # 대상이 없으면 다음 틱에 다시 본다
	u.set_meta("eskill_t", 0.0)
	u.set_meta("eskill_need", float(sk["cd"]))
	cast_count[u.id] = int(cast_count.get(u.id, 0)) + 1
	print("[VD] enemy skill: %s -> %s" % [u.display_name, sk["name"]])
	return true


# ---------------------------------------------------------------- 패링 공격 (VDParry)

## 패링 공격의 재사용 대기 (다른 스킬과 따로 돈다). 차면 살아 있는 아군 하나를 골라 예고를 시작한다.
## 기절해 있지 않은 아군을 먼저 고른다 — 누를 사람이 정신이 있어야 공정하다 (입력은 기절 중에도 받는다).
func _parry_tick(u: VDUnit, dt: float) -> bool:
	var d: Dictionary = VDData.PARRY[u.id]
	var t := float(u.get_meta("parry_t", 0.0)) + dt
	u.set_meta("parry_t", t)
	if t < float(u.get_meta("parry_need", d["first"])) * u.cd_mult() or b.parry.active:
		return false
	var pool: Array[VDUnit] = []
	for a in b.allies:
		if a.alive and a.stun_timer <= 0.0:
			pool.append(a)
	if pool.is_empty():
		for a in b.allies:
			if a.alive:
				pool.append(a)
	if pool.is_empty() or not b.parry.begin(u, pool[randi() % pool.size()], d):
		return false
	u.set_meta("parry_t", 0.0)
	u.set_meta("parry_need", float(d["cd"]))
	cast_count["parry"] = int(cast_count.get("parry", 0)) + 1
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


# ---------------------------------------------------------------- 공허 망령: 순간이동

## 순간이동 재사용 대기. 더 먼 자리가 있으면 옮기고 true.
func _blink_tick(u: VDUnit, sk: Dictionary, dt: float) -> bool:
	var t := float(u.get_meta("blink_t", 0.0)) + dt
	u.set_meta("blink_t", t)
	if t < float(u.get_meta("blink_need", sk["blink_first"])) * u.cd_mult():
		return false
	var before := _ally_gap(u, u.cell)
	var best := _far_spot(u)
	var best_gap := _ally_gap(u, best)
	u.set_meta("blink_t", 0.0)
	if best == u.cell or before >= 99:
		u.set_meta("blink_need", 2.0)   # 갈 곳이 없으면 조금 뒤에 다시 본다
		return false
	u.set_meta("blink_need", float(sk["blink_cd"]))
	last_blink = {"from": u.cell, "to": best, "before": before, "after": best_gap}
	cast_count["wraith_blink"] = int(cast_count.get("wraith_blink", 0)) + 1
	_blink_run(u, best)
	return true


## 아군에게서 가장 먼 자리 (지금보다 멀어지는 곳이 없으면 지금 칸).
func _far_spot(u: VDUnit) -> Vector2i:
	var best := u.cell
	var best_gap := _ally_gap(u, u.cell)
	for local in b.room["cells"]:
		var at: Vector2i = VDMap.to_world(b.room, local.x, local.y)
		if at == u.cell or not b._fits(u, at):
			continue
		var gap := _ally_gap(u, at)
		# 같은 거리면 지금 자리에서 먼 쪽 (같은 구석에서 맴돌지 않게)
		if gap > best_gap or (gap == best_gap and best != u.cell and VDData.manhattan(at, u.cell) > VDData.manhattan(best, u.cell)):
			best_gap = gap
			best = at
	return best


## 강한 공격을 맞기 직전에 묻는다: 피했으면 true (피해 없음). strong = 궁극기처럼 언제나 강한 공격, 아니면 피해량으로 가린다.
## 한 번 피하면 그 공격의 남은 타격(연타 궁극기)도 잠깐 동안 전부 피하고, 못 피했으면 그 공격이 끝날 때까지는 다시 굴리지 않는다.
func try_dodge(e: VDUnit, dmg: float, strong: bool) -> bool:
	if not is_instance_valid(e) or not e.alive or not VDData.ENEMY_SKILLS.has(e.id):
		return false
	var sk: Dictionary = VDData.ENEMY_SKILLS[e.id]
	if not sk.has("dodge") or (not strong and dmg < e.max_hp * float(sk["dodge_ratio"])):
		return false
	var now := Time.get_ticks_msec()
	if now < int(e.get_meta("dodge_grace", 0)):
		return true
	if now < int(e.get_meta("dodge_lock", 0)) or e.stun_timer > 0.0 or e.casting or e.has_meta("blinking"):
		return false
	var roll := randf() < float(sk["dodge"]) if force_dodge < 0 else force_dodge == 1
	if not roll:
		e.set_meta("dodge_lock", now + 1500)
		return false
	e.set_meta("dodge_grace", now + 900)
	dodges += 1
	b.dmg_log.spawn_status(b._chest(e) + Vector2(0, -30), "회피!", Color(0.85, 0.7, 1.0), e)
	e.set_meta("blink_t", 0.0)
	var land := _far_spot(e)
	last_blink = {"from": e.cell, "to": land, "before": _ally_gap(e, e.cell), "after": _ally_gap(e, land), "dodge": true}
	_blink_run(e, land, 0.5)
	return true


## at 에 섰을 때 가장 가까운 살아 있는 아군까지의 거리 (아군이 없으면 99).
func _ally_gap(u: VDUnit, at: Vector2i) -> int:
	var gap := 99
	for a in b.allies:
		if a.alive:
			gap = mini(gap, VDData.rect_dist(at, u.size, a.cell, a.size))
	return gap


## k: 걸리는 시간 배율 (회피는 0.5 로 더 빨리).
func _blink_run(u: VDUnit, land: Vector2i, k := 1.0) -> void:
	var run := b._run_id
	var sec := BLINK_SEC * k
	u.casting = true
	u.set_meta("blinking", true)
	var from := b._chest(u)
	b.vfx.spawn("hit_light", b.fx_root, from, 2.4, 0.0, TENTACLE_COL.lightened(0.3))
	b.vfx.loop("portal", b.ground_fx, u.position, sec + 0.15, 0.5, 0.0, TENTACLE_COL, Vector2(1.0, 0.5), 0.1, 6.0)
	b.audio.play("whoosh", 0.03, 2.0, 0.7)
	if u._anim_tween:
		u._anim_tween.kill()
	u._anim_tween = u.create_tween()
	u._anim_tween.tween_property(u, "scale", Vector2(0.1, 1.7), sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	u._anim_tween.parallel().tween_property(u, "modulate:a", 0.0, sec)
	await b.get_tree().create_timer(sec + 0.02, false).timeout
	if not is_instance_valid(u):
		return
	if not u.alive or run != b._run_id:
		u.remove_meta("blinking")
		u.casting = false
		return
	if not b._fits(u, land):
		land = u.cell   # 그새 누가 들어섰으면 제자리에 다시 나타난다
	u.cell = land
	u.position = u.foot_at(land)
	if u.floating:
		b.float_move.warp(u, u.position)
	var foe := _nearest_in(u, 99)
	if foe:
		u.face(foe.position.x - u.position.x)
	var to := b._chest(u)
	VDFx.tracer(b.fx_root, from, to, TENTACLE_COL.lightened(0.3))   # 옮겨 간 자취
	b.vfx.loop("portal", b.ground_fx, u.position, 0.35, 0.6, 0.0, TENTACLE_COL.lightened(0.2), Vector2(1.0, 0.5), 0.1, -6.0)
	b.vfx.spawn("hit_light", b.fx_root, to, 2.4, 0.6, TENTACLE_COL.lightened(0.3))
	b.audio.play("whoosh", 0.03, 0.0, 0.9)
	u.scale = Vector2(0.1, 1.7)
	u._anim_tween = u.create_tween()
	u._anim_tween.tween_property(u, "scale", Vector2.ONE, sec * 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	u._anim_tween.parallel().tween_property(u, "modulate:a", 1.0, sec)
	await b.get_tree().create_timer(sec * 1.6, false).timeout
	if not is_instance_valid(u):
		return
	u.remove_meta("blinking")
	u.casting = false
	u.move_timer = 0.0
	if not _can_go_on(u, run):
		return
	# 멀리 옮긴 뒤: 절반은 촉수 난타로 이어 가고, 나머지는 곧바로 쏜다
	var sk: Dictionary = VDData.ENEMY_SKILLS[u.id]
	var follow := randf() < float(sk.get("blink_skill", 0.0)) if force_followup < 0 else force_followup == 1
	if follow and not b.ult.active and _tentacle_barrage(u, sk):
		followups += 1
		u.set_meta("eskill_t", 0.0)
		u.set_meta("eskill_need", float(sk["cd"]))
		cast_count[u.id] = int(cast_count.get(u.id, 0)) + 1
	else:
		u.atk_timer = u.atk_cd * 2.0   # 나타나자마자 쏜다


# ---------------------------------------------------------------- 공허 망령: 공허 촉수 난타

## 대상이 너무 가까우면(min_range 칸 미만) 쓰지 않는다: 떠다니는 이동에 물러나라고 지시하고 false → 다음 틱에 다시 본다.
## 재사용 대기는 찬 채로 남아 있으므로 적당히 벌어지는 순간 바로 쓴다.
func _tentacle_barrage(u: VDUnit, sk: Dictionary) -> bool:
	var target := _nearest_in(u, int(sk["range"]))
	if target == null:
		return false
	var min_range := int(sk.get("min_range", 0))
	if min_range > 0 and u.dist_to(target) < min_range:
		if u.floating:
			b.float_move.back_off(u, min_range)
		too_close += 1
		return false
	_tentacle_run(u, sk, target)
	return true


func _tentacle_run(u: VDUnit, sk: Dictionary, target: VDUnit) -> void:
	var run := b._run_id
	var charge := float(sk["charge"])
	var n := int(sk["tentacles"])
	var jabs := int(sk["jabs"])
	var gap := 0.055                                   # 가닥 사이 출발 간격
	var dur := gap * n + VDWraithTentacle.FAN_SEC + VDWraithTentacle.OUT_SEC + (jabs - 1) * (VDWraithTentacle.HOLD_SEC + VDWraithTentacle.BACK_SEC + VDWraithTentacle.OUT_SEC) + 0.1
	u.casting = true
	_announce(u, target, sk, TENTACLE_COL, charge + dur + 0.2)
	u.windup(target.position, charge)
	b.juice.telegraph(target, charge + 0.15, TENTACLE_COL)
	await b.get_tree().create_timer(charge, false).timeout
	if not is_instance_valid(u):
		return
	u.release_windup()
	if not _can_go_on(u, run):
		u.casting = false
		_retry_soon(u)   # 예비 동작 중에 기절로 끊겼다: 재사용 대기를 통째로 날리지 않고 곧 다시 시도한다
		return
	var st := {"t": target, "hits": 0, "total": n * jabs}
	if not target.alive:
		st["t"] = _nearest_in(u, int(sk["range"]) + 1)
		if st["t"] == null:
			u.casting = false
			_retry_soon(u)
			return
	u.face(st["t"].position.x - u.position.x)
	u.attack_anim(st["t"].position)
	_set_frenzy(u, 1.0)   # 촉수를 휘두르는 동안 몸이 격렬하게 요동친다
	b.audio.play("whoosh", 0.05, 4.0, 1.5)
	# 촉수는 시전자 뒤(후드 밑)에서 나온다: 시전자의 자식으로, 부모보다 먼저 그린다
	var holder := Node2D.new()
	holder.name = "Tentacles"
	holder.show_behind_parent = true
	u.add_child(holder)
	# 스킬 동안은 다른 유닛 위에 그린다 (촉수가 길을 막은 유닛에 가려 안 보이지 않게)
	var z_before := u.z_index
	u.z_index = z_before + 30
	var order := range(n)
	order.shuffle()
	for k in n:
		var i: int = order[k]
		var f := float(i) / maxf(n - 1, 1.0)           # 0 맨 위 가닥 ~ 1 맨 아래 가닥
		var tent := VDWraithTentacle.new()
		tent.delay = gap * k
		tent.jabs = jabs
		var up := lerpf(-1.0, 1.0, f)
		var root_off := Vector2(randf_range(-0.04, 0.1), lerpf(0.72, 0.2, f))   # 후드 폭·키 비율
		tent.root_fn = func() -> Vector2:
			return Vector2(-u._facing * root_off.x * 200.0, u._top * root_off.y)
		tent.target_fn = func() -> Vector2:
			var t: VDUnit = st["t"]
			return (b._chest(t) if is_instance_valid(t) else u.position + Vector2(u._facing * 200.0, -40.0)) - u.position
		tent.alive_fn = func() -> bool:
			return _can_go_on(u, run) and st["t"] != null
		tent.on_hit = func(tip: Vector2, _last: bool) -> void:
			_tentacle_hit(u, sk, st, u.position + tip)
		# 위 가닥은 위로, 아래 가닥은 아래로 퍼져 나갔다가 대상에서 모인다 (바라보는 쪽에 따라 뒤집는다)
		tent.launch = (up * randf_range(1.3, 1.95) + randf_range(-0.2, 0.2)) * -u._facing
		tent.side = (1.0 if up < 0.0 else -1.0) * -u._facing
		holder.add_child(tent)
	await b.get_tree().create_timer(dur, false).timeout
	if is_instance_valid(holder):
		holder.create_tween().tween_callback(holder.queue_free).set_delay(VDWraithTentacle.END_SEC + 0.1)
	if is_instance_valid(u):
		_set_frenzy(u, 0.0)
		u.create_tween().tween_callback(func() -> void: u.z_index = z_before).set_delay(VDWraithTentacle.END_SEC + 0.1)
		u.casting = false
		u.atk_timer = 0.0


func _set_frenzy(u: VDUnit, k: float) -> void:
	if is_instance_valid(u) and u._parts is VDWraithAnim:
		(u._parts as VDWraithAnim).frenzy = k


## 촉수가 나오기도 전에 끊긴 시전: 2초 뒤(기절이 풀리면) 다시 쓸 수 있게 재사용 대기를 거의 채워 둔다.
func _retry_soon(u: VDUnit) -> void:
	if is_instance_valid(u) and u.alive:
		u.set_meta("eskill_t", maxf(float(u.get_meta("eskill_need", 0.0)) - 2.0, 0.0))


func _tentacle_hit(u: VDUnit, sk: Dictionary, st: Dictionary, at: Vector2) -> void:
	if not is_instance_valid(u):
		return
	var t: VDUnit = st["t"]
	if not is_instance_valid(t) or not t.alive:
		t = _nearest_in(u, int(sk["range"]) + 1)
		st["t"] = t
		if t == null:
			return
	st["hits"] += 1
	tentacle_hits += 1
	if st["hits"] % 3 == 0 and u._parts:
		u._parts.strike()   # 찌를 때마다 몸이 앞으로 움찔 쏠린다
	var last: bool = st["hits"] >= st["total"]
	var dir := (t.position - u.position).normalized()
	t.last_hit_by = u
	var dealt := t.take_damage(u.atk * float(sk["dmg"]) * (1.6 if last else 1.0), "정수", 1.0 if last else 0.4)   # 비전(자홍) 피격 색: 연타에 흰 섬광이 겹쳐 화면이 날아가지 않게
	VDWraithHitFx.spawn(b.fx_root, at - dir * 12.0, dir, last)   # 섬광이 대상 몸에 묻히지 않게 조금 앞에서
	b.dmg_log.spawn(at + Vector2(0, -16), int(dealt), last, t)
	if dealt > 0.0:
		b.hurt_glitch.kick(0.7 if last else 0.28, t.id)
	b.audio.play("enemy_hit", 0.2, -5.0, 1.5)
	if last:
		VDWraithHitFx.ground(b.ground_fx, t.position, dir)
		b.shockwave.add(at, "heavy")
		b.camera.shake(0.5)
		b.camera.hitstop(0.06)
		b.audio.play("explode", 0.05, -3.0, 1.3)
	else:
		b.camera.shake(0.1)
		if st["hits"] % 5 == 1:
			VDWraithHitFx.ground(b.ground_fx, t.position, dir, 0.6)


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
