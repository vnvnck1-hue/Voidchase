## 공허 응시자(첫 보스)의 공격 패턴 다섯 가지. 평타(눈 광탄)와 따로 돌며, VDData.GAZER 의 first 초 뒤부터 gap 초 간격으로 하나씩 쓴다.
## 다섯 개를 섞어 한 바퀴 돌고 다시 섞는다 (같은 패턴이 연달아 나오지 않는다).
##   ram     월식 돌진 (패링 1) : 날아올라 물러났다가 뿔로 내리꽂는다 — VDParry (style "ram")
##   beam    만안 섬광 (패링 2) : 제자리에서 눈에 빛을 모았다가 광선을 쏜다. 받아치면 되돌아간다 — VDParry (style "beam")
##   barrage 깃털 폭우          : 날개를 치켜들고 깃털을 연달아 쏜다. 바닥 경고 원이 차오른 뒤 터진다 (피하거나 맞거나)
##   gale    날개 폭풍          : 치켜든 날개를 내리쳐 바람으로 영웅을 전부 띄운다
##   sweep   초승달 선회        : 톱날처럼 돌며 바닥 경고선을 따라 가로지른다. 선 가까이 있으면 피해 + 기절
## VDEnemySkills.tick 이 응시자 틱을 이리로 넘긴다. cast(u, 이름) 은 테스트·연구실이 패턴을 골라 바로 시전할 때 쓴다.
class_name VDGazerSkills
extends RefCounted

const FEATHER_COL := Color(1.0, 0.5, 0.82)
const GALE_COL := Color(0.82, 0.74, 1.0)
const SWEEP_COL := Color(1.0, 0.3, 0.5)
const NAMES := {"ram": "월식 돌진 (패링)", "beam": "만안 섬광 (패링)", "barrage": "깃털 폭우", "gale": "날개 폭풍", "sweep": "초승달 선회"}

var b: VDBattle
var es: VDEnemySkills
var force_next := ""              # 테스트·연구실: 다음에 쓸 패턴을 정한다
var casts := {}                   # 패턴 이름 → 시전 횟수
var feather_hits := 0             # 테스트용
var gale_hits := 0
var sweep_hits := 0
var last := ""


func _init(battle: VDBattle, skills: VDEnemySkills) -> void:
	b = battle
	es = skills


## 재사용 대기를 돌리고, 차면 다음 패턴을 시전한다. 시전을 시작했으면 true.
func tick(u: VDUnit, dt: float) -> bool:
	if u.casting or b.parry.active:
		return false
	var g: Dictionary = VDData.GAZER
	var t := float(u.get_meta("gz_t", 0.0)) + dt
	u.set_meta("gz_t", t)
	if t < float(u.get_meta("gz_need", g["first"])) * u.cd_mult() and force_next == "":
		return false
	var bag: Array = u.get_meta("gz_bag", [])
	if bag.is_empty():
		bag = (g["order"] as Array).duplicate()
		bag.shuffle()
		if bag.size() > 1 and bag[0] == last:
			bag.push_back(bag.pop_front())
	var pick: String = force_next if force_next != "" else String(bag[0])
	if not cast(u, pick):
		return false                  # 대상이 없으면 다음 틱에 다시 본다
	force_next = ""
	bag.erase(pick)
	u.set_meta("gz_bag", bag)
	u.set_meta("gz_t", 0.0)
	var gap: Array = g["gap"]
	u.set_meta("gz_need", randf_range(float(gap[0]), float(gap[1])))
	return true


## 패턴 하나를 바로 시전한다. 시전하지 못하면(대상 없음·이미 시전 중) false.
func cast(u: VDUnit, pattern: String) -> bool:
	if not is_instance_valid(u) or not u.alive or u.casting or u.stun_timer > 0.0 or b.parry.active:
		return false
	var target := _pick_target()
	if target == null:
		return false
	match pattern:
		"ram":
			if not b.parry.begin(u, target, VDData.PARRY["gazer"]):
				return false
			es.cast_count["parry"] = int(es.cast_count.get("parry", 0)) + 1
		"beam":
			if not b.parry.begin(u, target, VDData.GAZER["beam"]):
				return false
			es.cast_count["parry"] = int(es.cast_count.get("parry", 0)) + 1
		"barrage":
			_barrage(u, VDData.GAZER["barrage"], target)
		"gale":
			_gale(u, VDData.GAZER["gale"], target)
		"sweep":
			_sweep(u, VDData.GAZER["sweep"], target)
		_:
			return false
	last = pattern
	casts[pattern] = int(casts.get(pattern, 0)) + 1
	print("[VD] gazer pattern: %s" % pattern)
	return true


## 기절해 있지 않은 아군을 먼저 고른다.
func _pick_target() -> VDUnit:
	var pool: Array[VDUnit] = []
	for a in b.allies:
		if a.alive and a.stun_timer <= 0.0:
			pool.append(a)
	if pool.is_empty():
		for a in b.allies:
			if a.alive:
				pool.append(a)
	return null if pool.is_empty() else pool[randi() % pool.size()]


func _ok(u: VDUnit, run: int) -> bool:
	return is_instance_valid(u) and u.alive and u.stun_timer <= 0.0 and run == b._run_id and b.state == VDBattle.State.BATTLE


func _end(u: VDUnit) -> void:
	if not is_instance_valid(u):
		return
	if u._parts != null and u._parts.has_method("cast_cancel"):
		u._parts.cast_cancel()
	u.casting = false
	u.atk_timer = 0.0


func _wait(sec: float) -> Signal:
	return b.get_tree().create_timer(sec, false).timeout


func _hurt(u: VDUnit, a: VDUnit, dmg: float, big: bool, col: Color) -> void:
	a.last_hit_by = u
	var dealt := a.take_damage(dmg)
	var at := b._chest(a)
	b.vfx.spawn("hit_light", b.fx_root, at, 2.6 if big else 1.6, randf() * TAU, col.lightened(0.25))
	b.dmg_log.spawn(at + Vector2(0, -16), int(dealt), big, a)
	if dealt > 0.0:
		b.hurt_glitch.kick(0.9 if big else 0.45, a.id)


## 날개 어름 (깃털이 나오는 자리).
func _wing_at(u: VDUnit) -> Vector2:
	return u.position + Vector2(-u._facing * 0.3 * absf(u._top), u._top * 0.75 - VDParry.lift_of(u))


# ---------------------------------------------------------------- 깃털 폭우

func _barrage(u: VDUnit, sk: Dictionary, target: VDUnit) -> void:
	var run := b._run_id
	var charge := float(sk["charge"])
	var shots := int(sk["shots"])
	u.casting = true
	u.face(target.position.x - u.position.x)
	es._announce(u, target, sk, FEATHER_COL, charge + shots * float(sk["gap"]) + 0.3)
	u._parts.cast_spread(true)
	u._parts.aim(target.position - u.position, charge + shots * float(sk["gap"]))
	await _wait(charge)
	if not _ok(u, run):
		_end(u)
		return
	for i in shots:
		if not _ok(u, run):
			break
		var a := _pick_target()
		if a == null:
			break
		# 세 발에 한 발은 정확히 발밑, 나머지는 그 둘레에 흩뿌린다
		var spot := a.position
		if i % 3 != 0:
			spot += Vector2(randf_range(-150.0, 150.0), randf_range(-70.0, 70.0))
		_feather(u, spot, sk, run)
		u._parts.aim(spot - u.position, 0.3)
		b.audio.play("whoosh", 0.1, -6.0, 1.5)
		await _wait(float(sk["gap"]))
	await _wait(0.25)
	_end(u)


## 깃털 한 발: 바닥 경고 원이 fall 초 동안 차오르고, 깃털이 날아와 꽂히며 터진다.
func _feather(u: VDUnit, spot: Vector2, sk: Dictionary, run: int) -> void:
	var fall := float(sk["fall"])
	var radius := float(sk["radius"])
	# 경고 원 (바닥 원근: 세로로 납작)
	var ring := Node2D.new()
	ring.position = spot
	var st := {"k": 0.0}
	ring.draw.connect(func() -> void:
		var pts := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			var p := Vector2(cos(a), sin(a) * 0.5) * radius
			pts.append(p)
			inner.append(p * float(st["k"]))
		ring.draw_colored_polygon(pts, Color(FEATHER_COL, 0.24))
		ring.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(FEATHER_COL.lightened(0.2), 0.95), 4.5)
		if float(st["k"]) > 0.03:
			ring.draw_colored_polygon(inner, Color(FEATHER_COL.lightened(0.3), 0.4 + 0.35 * float(st["k"]))))
	b.ground_fx.add_child(ring)
	var rt := ring.create_tween()
	rt.tween_method(func(v: float) -> void:
		st["k"] = v
		ring.queue_redraw(), 0.0, 1.0, fall)
	rt.tween_property(ring, "modulate:a", 0.0, 0.15)
	rt.tween_callback(ring.queue_free)
	# 깃털: 날개에서 솟아올라 포물선으로 떨어진다
	var f := _feather_node()
	var from := _wing_at(u) + Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 20.0))
	f.position = from
	b.fx_root.add_child(f)
	b.juice.trail(f, FEATHER_COL, 16.0)
	var top := (from + spot) * 0.5 + Vector2(0, -randf_range(170.0, 250.0))
	var ft := f.create_tween()
	ft.tween_method(func(v: float) -> void:
		var p := from.lerp(top, v).lerp(top.lerp(spot, v), v)
		var d := p - f.position
		if d.length() > 0.5:
			f.rotation = d.angle()
		f.position = p, 0.0, 1.0, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ft.tween_callback(func() -> void:
		f.queue_free()
		_feather_land(u, spot, sk, run))


func _feather_node() -> Node2D:
	var n := Node2D.new()
	n.z_index = 30
	# 깃 모양: 어두운 테두리 + 분홍 깃 + 흰 깃대 (오른쪽이 앞)
	var shape := PackedVector2Array([Vector2(34, 0), Vector2(8, -11), Vector2(-26, -7), Vector2(-38, 0), Vector2(-26, 7), Vector2(8, 11)])
	for i in 3:
		var p := Polygon2D.new()
		var k: float = [1.0, 0.8, 0.0][i]
		if i == 2:
			p.polygon = PackedVector2Array([Vector2(30, 0), Vector2(-30, -2), Vector2(-30, 2)])
		else:
			var pts := PackedVector2Array()
			for v in shape:
				pts.append(v * (1.0 if i == 0 else k) * (1.18 if i == 0 else 1.0))
			p.polygon = pts
		p.color = [Color("1b0b38"), FEATHER_COL, Color(1, 0.94, 0.98)][i]
		n.add_child(p)
	n.scale = Vector2(2.1, 2.1)
	return n


func _feather_land(u: VDUnit, spot: Vector2, sk: Dictionary, run: int) -> void:
	if run != b._run_id or b.state != VDBattle.State.BATTLE:
		return
	var radius := float(sk["radius"])
	b.vfx.spawn("burst", b.ground_fx, spot, 0.3, 0.0, FEATHER_COL, Vector2(1.4, 0.6))
	b.vfx.spawn("dust", b.ground_fx, spot, 1.1, 0.0, Color(1.0, 0.85, 0.95, 0.8))
	b.juice.scorch(spot, FEATHER_COL, 22.0)
	b.shockwave.add(spot, "light")
	b.camera.shake(0.12)
	b.audio.play("enemy_hit", 0.15, -5.0, 1.3)
	if not is_instance_valid(u):
		return
	for a in b.allies:
		if not a.alive:
			continue
		var d := a.position - spot
		if Vector2(d.x, d.y * 2.0).length() <= radius + 14.0:
			feather_hits += 1
			_hurt(u, a, u.atk * float(sk["dmg"]), false, FEATHER_COL)


# ---------------------------------------------------------------- 날개 폭풍

func _gale(u: VDUnit, sk: Dictionary, target: VDUnit) -> void:
	var run := b._run_id
	var charge := float(sk["charge"])
	u.casting = true
	u.face(target.position.x - u.position.x)
	es._announce(u, target, sk, GALE_COL, charge + 0.6)
	u._parts.cast_spread(true)
	u._parts.aim(target.position - u.position, charge + 0.4)
	# 바람이 닿을 영웅 발밑에 경고
	for a in b.allies:
		if a.alive and u.dist_to(a) <= int(sk["range"]):
			b.juice.telegraph(a, charge, GALE_COL)
	await _wait(charge)
	if not _ok(u, run):
		_end(u)
		return
	u._parts.gale_release()
	var dir := Vector2(float(u._facing), 0.0)
	var from := b._chest(u)
	# 바람: 보스에서 영웅 쪽으로 쓸려 가는 빛줄기와 먼지
	for i in 16:
		var ln := Line2D.new()
		var y := randf_range(-150.0, 120.0)
		var len := randf_range(90.0, 220.0)
		ln.points = PackedVector2Array([Vector2.ZERO, dir * len])
		ln.width = randf_range(3.0, 8.0)
		ln.default_color = Color(GALE_COL.lightened(0.3), 0.8)
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		ln.z_index = 30
		ln.position = from + Vector2(dir.x * randf_range(0.0, 120.0), y)
		b.fx_root.add_child(ln)
		var tw := ln.create_tween()
		tw.tween_interval(randf_range(0.0, 0.12))
		tw.tween_property(ln, "position", ln.position + dir * randf_range(620.0, 900.0), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ln, "modulate:a", 0.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(ln.queue_free)
	for i in 5:
		var puff: Node2D = b.vfx.spawn("dust", b.ground_fx, u.position + Vector2(dir.x * 60.0 * i, randf_range(-30.0, 30.0)), 1.6 + 0.2 * i, 0.0, Color(0.88, 0.82, 1.0, 0.75))
		if puff != null:
			puff.create_tween().tween_property(puff, "position", puff.position + dir * 260.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	b.vfx.spawn("shockwave", b.ground_fx, u.position, 1.5, 0.0, Color(GALE_COL, 0.8), Vector2(1.0, 0.5))
	b.shockwave.add(from, "slam", 1.1)
	b.camera.shake(0.7)
	b.camera.punch(0.04)
	b.camera.hitstop(0.06)
	b.audio.play("whoosh", 0.0, 6.0, 0.55)
	b.audio.play("boss_slam", 0.03, -3.0, 1.2)
	for a in b.allies:
		if not a.alive or u.dist_to(a) > int(sk["range"]):
			continue
		gale_hits += 1
		_hurt(u, a, u.atk * float(sk["dmg"]), true, GALE_COL)
		if a.alive:
			a.knock_up(float(sk["air"]))
			b.dmg_log.spawn_status(b._chest(a) + Vector2(0, -50), "띄움!", GALE_COL.lightened(0.2), a)
	await _wait(0.5)
	_end(u)


# ---------------------------------------------------------------- 초승달 선회

func _sweep(u: VDUnit, sk: Dictionary, target: VDUnit) -> void:
	var run := b._run_id
	var charge := float(sk["charge"])
	var dash := float(sk["dash"])
	var width := float(sk["width"])
	u.casting = true
	u.face(target.position.x - u.position.x)
	es._announce(u, target, sk, SWEEP_COL, charge + dash + 0.3)
	u._parts.spin(true)
	# 경고선: 지금 자리에서 대상을 꿰뚫고 reach 만큼 더
	var from := u.position
	var dir := (target.position - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(float(u._facing), 0.0)
	var to := target.position + dir * float(sk["reach"])
	var lane := Node2D.new()
	var st := {"k": 0.0}
	var nrm := Vector2(-dir.y, dir.x) * width * 0.5
	lane.draw.connect(func() -> void:
		var k: float = st["k"]
		var quad := PackedVector2Array([from - nrm, to - nrm, to + nrm, from + nrm])
		lane.draw_colored_polygon(quad, Color(SWEEP_COL, 0.1 + 0.05 * sin(Time.get_ticks_msec() * 0.03)))
		lane.draw_polyline(quad + PackedVector2Array([quad[0]]), Color(SWEEP_COL, 0.8), 2.5)
		if k > 0.03:
			var head := from.lerp(to, k)
			lane.draw_colored_polygon(PackedVector2Array([from - nrm, head - nrm, head + nrm, from + nrm]), Color(SWEEP_COL.lightened(0.2), 0.3)))
	b.ground_fx.add_child(lane)
	var lt := lane.create_tween()
	lt.tween_method(func(v: float) -> void:
		st["k"] = v
		lane.queue_redraw(), 0.0, 1.0, charge)
	lt.tween_interval(dash)
	lt.tween_property(lane, "modulate:a", 0.0, 0.2)
	lt.tween_callback(lane.queue_free)
	await _wait(charge)
	if not _ok(u, run):
		_end(u)
		return
	# 가로지르기
	if u._anim_tween:
		u._anim_tween.kill()
	u._anim_tween = u.create_tween()
	u._anim_tween.tween_property(u, "position", to, dash).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	u._anim_tween.tween_interval(0.3)
	b.audio.play("whoosh", 0.0, 5.0, 0.6)
	b.camera.punch(0.03)
	var hit := {}
	var t := 0.0
	var dust_t := 0.0
	while t < dash and _ok(u, run):
		await b.get_tree().process_frame
		var dt := b.get_process_delta_time()
		t += dt
		dust_t -= dt
		if not is_instance_valid(u):
			break
		if dust_t <= 0.0:
			dust_t = 0.05
			b.vfx.spawn("dust", b.ground_fx, u.position, 1.5, 0.0, Color(1.0, 0.8, 0.9, 0.7))
			b.vfx.spawn("hit_light", b.fx_root, u.position + Vector2(0, u._top * 0.45), 2.4, randf() * TAU, SWEEP_COL)
		for a in b.allies:
			if not a.alive or hit.has(a):
				continue
			var d := a.position - u.position
			if Vector2(d.x, d.y * 1.6).length() <= width:
				hit[a] = true
				sweep_hits += 1
				_hurt(u, a, u.atk * float(sk["dmg"]), true, SWEEP_COL)
				b.shockwave.add(b._chest(a), "heavy")
				b.camera.shake(0.45)
				b.camera.hitstop(0.05)
				b.audio.play("clash", 0.0, -2.0, 0.8)
				if a.alive:
					a.stun(float(sk["stun"]))
	if is_instance_valid(u):
		u._parts.spin(false)
		u.face(-dir.x)                      # 지나친 뒤 돌아본다
		await _wait(0.3)
	if is_instance_valid(u):
		if u._anim_tween:
			u._anim_tween.kill()
		if u.floating:
			b.float_move.warp(u, u.position)
	_end(u)
