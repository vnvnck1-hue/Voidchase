## VOID DEFENSE 궁극기: 궁극기 게이지가 찬 영웅의 카드를 플레이어가 탭하면 VDBattle 이 연출(VDUltCinematic.intro) 뒤 cast() 를 부른다.
## 세명이 오리라(TrioChess) skills.gd 의 ULTIMATES 를 옮기고, 힐러 것은 새로 만들었다.
##   기사 충격파:       모든 적 피해 + 한 칸 밀어내기 + 기절
##   건너 집중 포화:    조준한 방향 부채꼴에 1초간 난사, 안의 적마다 hits 회 피해
##   마법사 체인 라이트닝: 고른 적에서 시작해 가까운 적으로 튕기는 번개, 마지막 적은 하늘 번개 + 감전(기절)
##   힐러 부활의 기도:   가장 먼저 쓰러진 아군 부활 (없으면 전원 회복)
## 수치는 VDData.ULTS. 조준 기하(부채꼴 판정·체인 경로)는 조준 화면(VDUltAim) 미리보기도 같이 쓴다.
class_name VDUlts
extends RefCounted

const CHAIN_STEP := 0.1          # 번개가 다음 적으로 튀는 간격(초)
const CHAIN_REACH := 4           # 다음 적을 찾는 거리(칸)
const SKY_STRIKE_BEAT := 0.08    # 마지막 하늘 번개 전 한 박자 (TrioChess)

var b: VDBattle
var cast_count := {}             # 테스트용: 영웅 id 별 궁극기 시전 횟수


func _init(battle: VDBattle) -> void:
	b = battle


## aim: 건너 = 조준한 월드 좌표(Vector2), 마법사 = 첫 대상(VDUnit), 그 외 null. 시전하면 true.
func cast(u: VDUnit, aim: Variant) -> bool:
	if not VDData.ULTS.has(u.id):
		return false
	var ud: Dictionary = VDData.ULTS[u.id]
	var ok := false
	match u.id:
		"knight":
			ok = _shockwave(u, ud)
		"gunner":
			ok = _barrage(u, ud, aim if aim is Vector2 else b._chest(u) + Vector2(200, 0))
		"mage":
			ok = _chain(u, ud, aim as VDUnit if aim is VDUnit else null)
		"healer":
			ok = _prayer(u, ud)
	if ok:
		cast_count[u.id] = int(cast_count.get(u.id, 0)) + 1
		print("[VD] ultimate: %s -> %s" % [u.display_name, ud["name"]])
		u.cast_pulse()
		b.audio.voice(u.id, "skill")
	return ok


# ---------------------------------------------------------------- knight

func _shockwave(u: VDUnit, ud: Dictionary) -> bool:
	var foes := _alive(b.enemies)
	if foes.is_empty():
		return false
	b.ult._punch(u, Vector2(1.5, 0.55), 0.5)
	b.vfx.spawn("slam", b.fx_root, u.position, 2.2, 0.0, Color(1.0, 0.85, 0.6))
	b.vfx.spawn("shockwave", b.ground_fx, u.position, 3.4, 0.0, Color(1.6, 1.3, 0.6), Vector2(1.0, 0.5), false, 0.8)
	b.shockwave.add(u.position, "slam", 1.4)
	b.vfx.spawn("dust", b.ground_fx, u.position, 2.4, 0.0, Color(1, 1, 1, 0.8))
	b.audio.play("boss_slam", 0.03, 1.0, 0.8)
	b.camera.shake(1.0)
	b.camera.hitstop(0.1)
	var dmg := floorf(u.atk * float(ud["dmg"]))
	for e in foes:
		e.stun(float(ud["stun"]))
		_push_away(e, u.cell)
		_hit(e, dmg, "hit_heavy", Color(1.0, 0.85, 0.55), 2.2)
	return true


## 시전자에게서 먼 쪽으로 한 칸 (막혀 있으면 그대로). 대형 적은 밀리지 않는다.
func _push_away(e: VDUnit, from: Vector2i) -> void:
	if e.size > 1 or e.is_boss:
		return
	var d := e.cell - from
	var step := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
	if step == Vector2i.ZERO:
		return
	var to := e.cell + step
	if b._fits(e, to):
		e.move_to_cell(to, 0.16)


# ---------------------------------------------------------------- gunner

func _barrage(u: VDUnit, ud: Dictionary, aim: Vector2) -> bool:
	u.casting = true
	u.face(aim.x - u.position.x)
	_barrage_run(u, ud, aim, b._run_id)
	return true


func _barrage_run(u: VDUnit, ud: Dictionary, aim: Vector2, run: int) -> void:
	var hits := int(ud["hits"])
	var step := float(ud["channel"]) / hits
	var dmg := floorf(u.atk * float(ud["tick_dmg"]))
	var dir := cone_dir(u, aim)
	for k in hits:
		if not _still_on(run) or not u.alive:
			break
		var from := b._chest(u)
		# 부채꼴 안 무작위 방향으로 탄 몇 발 (맞든 안 맞든 난사하는 느낌)
		for s in 3:
			var ang := dir.angle() + randf_range(-1.0, 1.0) * float(ud["half_angle"])
			var far := VDData.to_screen(cell_f(u) + Vector2.from_angle(ang) * float(ud["length"]) * randf_range(0.6, 1.0))
			far.y += u._top * 0.45
			VDFx.tracer(b.fx_root, from, far, Color(1.0, 0.85, 0.4))
		b.vfx.spawn("hit_light", b.fx_root, from + (VDData.to_screen(cell_f(u) + dir) - u.position).normalized() * 40.0, 1.6, randf() * TAU, Color(1.0, 0.85, 0.4))
		b.audio.play("gun", 0.08, 3.0)
		b.camera.shake(0.18)
		for e in in_cone(u, aim, ud):
			_hit(e, dmg, "gun_hit", Color(1.0, 0.9, 0.5), 0.7)
		await b.get_tree().create_timer(step, false).timeout
	if is_instance_valid(u):
		u.casting = false


## 시전자 칸 좌표(실수). 대형이 아니라 셀 = 위치.
static func cell_f(u: VDUnit) -> Vector2:
	return screen_to_cell_f(u.position)


static func screen_to_cell_f(p: Vector2) -> Vector2:
	var a := p.x / (VDData.TILE_W * 0.5)
	var c := p.y / (VDData.TILE_H * 0.5)
	return Vector2((a + c) * 0.5, (c - a) * 0.5)


## 조준 방향 (칸 공간, 단위 벡터).
static func cone_dir(u: VDUnit, aim: Vector2) -> Vector2:
	var d := screen_to_cell_f(aim) - cell_f(u)
	return d.normalized() if d.length() > 0.01 else Vector2(1, 0)


## 부채꼴 안의 살아 있는 적 (칸 공간에서 거리·각도로 판정, 대형 적은 footprint 중심).
func in_cone(u: VDUnit, aim: Vector2, ud: Dictionary) -> Array[VDUnit]:
	var out: Array[VDUnit] = []
	var o := cell_f(u)
	var dir := cone_dir(u, aim)
	for e in _alive(b.enemies):
		var v := Vector2(e.cell) + Vector2.ONE * (e.size - 1) * 0.5 - o
		if v.length() > float(ud["length"]) + 0.5 * e.size:
			continue
		if v.length() < 0.5 or absf(dir.angle_to(v)) <= float(ud["half_angle"]) + 0.12:
			out.append(e)
	return out


## 미리보기용 부채꼴 다각형 (화면 좌표).
static func cone_polygon(u: VDUnit, aim: Vector2, ud: Dictionary) -> PackedVector2Array:
	var o := cell_f(u)
	var dir := cone_dir(u, aim)
	var pts := PackedVector2Array([u.position])
	var n := 14
	for i in n + 1:
		var ang := dir.angle() + lerpf(-1.0, 1.0, float(i) / n) * float(ud["half_angle"])
		pts.append(VDData.to_screen(o + Vector2.from_angle(ang) * float(ud["length"])))
	return pts


# ---------------------------------------------------------------- mage

func _chain(u: VDUnit, ud: Dictionary, first: VDUnit) -> bool:
	var path := chain_path(u, first, ud)
	if path.is_empty():
		return false
	u.casting = true
	u.attack_anim(path[0].position)
	_chain_run(u, ud, path, b._run_id)
	return true


## 번개 경로: first(없거나 쓰러졌으면 가장 가까운 적)에서 시작해 CHAIN_REACH 칸 안의 가장 가까운 새 적으로 튕긴다.
func chain_path(u: VDUnit, first: VDUnit, ud: Dictionary) -> Array[VDUnit]:
	var left := _alive(b.enemies)
	var path: Array[VDUnit] = []
	if left.is_empty():
		return path
	var cur: VDUnit = first if first != null and is_instance_valid(first) and first.alive else b._nearest(u, left)
	while cur != null and path.size() < int(ud["bounces"]):
		path.append(cur)
		left.erase(cur)
		var nxt: VDUnit = null
		var best := CHAIN_REACH + 1
		for e in left:
			var d := cur.dist_to(e)
			if d < best:
				best = d
				nxt = e
		cur = nxt
	return path


func _chain_run(u: VDUnit, ud: Dictionary, path: Array[VDUnit], run: int) -> void:
	var dmg := floorf(u.atk * float(ud["dmg"]))
	var prev := b._chest(u) + Vector2(0, -20)
	b.audio.play("lightning", 0.03, 2.0)
	for i in path.size():
		if not _still_on(run):
			break
		var e: VDUnit = path[i]
		if not is_instance_valid(e):
			continue
		var to := b._chest(e)
		bolt(b.fx_root, prev, to, Color(0.75, 0.85, 1.0), 0.16)
		prev = to
		if i == path.size() - 1:
			await b.get_tree().create_timer(SKY_STRIKE_BEAT, false).timeout
			if not _still_on(run) or not is_instance_valid(e):
				break
			# 마지막 적: 하늘에서 큰 번개가 내리꽂힌다 + 감전
			b.vfx.spawn("lightning", b.fx_root, e.position + Vector2(0, e._top * 0.6), 0.9, 0.0, Color(0.7, 0.85, 1.0))
			b.vfx.spawn("shockwave", b.ground_fx, e.position, 0.8, 0.0, Color(0.6, 0.8, 1.6), Vector2(1.0, 0.5))
			b.shockwave.add(b._chest(e), "kill")
			b.audio.play("lightning", 0.03, 4.0, 0.8)
			b.camera.shake(0.6)
			b.camera.hitstop(0.08)
			e.stun(float(ud["finish_stun"]))
			_hit(e, dmg * 1.5, "burst", Color(0.7, 0.85, 1.0), 0.5)
		else:
			b.audio.play("mage_hit", 0.06, -4.0, 1.4)
			b.camera.shake(0.15)
			_hit(e, dmg, "hit_light", Color(0.7, 0.85, 1.0), 1.4)
			await b.get_tree().create_timer(CHAIN_STEP, false).timeout
	if is_instance_valid(u):
		u.casting = false


## 지그재그 번개 선: 두 겹(굵은 빛 + 흰 심)으로 그렸다가 dur 초에 걸쳐 사라진다.
static func bolt(parent: Node, from: Vector2, to: Vector2, col: Color, dur: float) -> void:
	var pts := PackedVector2Array([from])
	var n := 7
	var side := (to - from).orthogonal().normalized()
	for i in range(1, n):
		pts.append(from.lerp(to, float(i) / n) + side * randf_range(-16.0, 16.0))
	pts.append(to)
	for layer in 2:
		var l := Line2D.new()
		l.points = pts
		l.width = 12.0 if layer == 0 else 4.0
		l.default_color = Color(col, 0.55) if layer == 0 else Color(1, 1, 1, 0.95)
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
		if layer == 0:
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			l.material = m
		parent.add_child(l)
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 0.0, dur).set_delay(dur * 0.4)
		tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- healer

func _prayer(u: VDUnit, ud: Dictionary) -> bool:
	b.audio.play("heal", 0.03, 4.0)
	b.audio.play("chime", 0.03, 0.0, 0.8)
	b.vfx.loop("magic_circle", b.ground_fx, u.position, 1.0, 0.45, 0.0, Color(1.0, 0.95, 0.6), Vector2(1.0, 0.5), 0.35, 1.2)
	var target := b.first_fallen()
	if target != null:
		var at := b.free_cell_near(target.cell, u.cell)
		target.cell = at
		target.revive(float(ud["revive_hp"]))
		b.on_hero_revived(target)
		var p := target.position
		b.vfx.spawn("lightning", b.fx_root, p + Vector2(0, target._top * 0.6), 0.9, 0.0, Color(1.0, 0.92, 0.55))
		b.vfx.spawn("heal", b.fx_root, b._chest(target), 1.0, 0.0, Color(1.0, 1.0, 0.8))
		b.vfx.spawn("shockwave", b.ground_fx, p, 1.1, 0.0, Color(1.4, 1.3, 0.7), Vector2(1.0, 0.5))
		b.vfx.loop("magic_circle", b.ground_fx, p, 1.2, 0.3, 0.0, Color(1.0, 0.95, 0.6), Vector2(1.0, 0.5), 0.35, 2.0)
		b.dmg_log.spawn_status(b._chest(target) + Vector2(0, -24), "부활!", Color(1.0, 0.92, 0.5), target)
		b.camera.shake(0.4)
		return true
	for a in _alive(b.allies):
		var before := a.hp
		a.heal(floorf(a.max_hp * float(ud["heal_hp"])))
		b.vfx.spawn("heal", b.fx_root, b._chest(a), 0.8, 0.0, Color(0.9, 1.0, 0.8))
		var gain := int(a.hp - before)
		if gain > 0:
			b.dmg_log.spawn_status(b._chest(a), "+%d" % gain, Color(0.55, 1.0, 0.6), a)
	return true


# ---------------------------------------------------------------- helpers

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
