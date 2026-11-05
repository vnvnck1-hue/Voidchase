## 유물 발동기: 전투 이벤트(평타·처치·틱)를 받아 성좌판 위 유물의 트리거를 검사하고 효과를 실행한다.
## 배치 문법(인접 수·빈 이웃·바로 위·최상단·침식 인접)은 발동 순간에 보드를 읽어 계산한다.
## 모든 효과는 VDBattle.relic_damage / 유닛 상태 필드로 들어가므로 영웅 피해와 같은 길을 쓴다.
class_name VDRelicRuntime
extends RefCounted

signal fired(cell: Vector2i, id: String)

const INTERNAL_CD := 0.25      # 같은 유물이 연달아 발동하지 못하는 최소 간격 (폭주 방지)
const BURN_TICK := 0.5         # 화상 피해를 적용하는 간격

var b: VDBattle
var board: VDRelicBoard
var origin_of: Callable        # (cell) -> 전장 월드 좌표 (HUD 가 준다). 없으면 대상 위에서 떨어진다
var fire_count := {}           # 테스트용: 유물 id -> 발동 횟수
var _inst := {}                # cell -> {"id", "cd", "count", "fired_once", "icd"}
var _burn := {}                # VDUnit -> {"acc": float}
var _battle_t := 0.0


func _init(battle: VDBattle, board_: VDRelicBoard) -> void:
	b = battle
	board = board_
	board.changed.connect(_sync)


func reset() -> void:
	_inst.clear()
	_burn.clear()
	fire_count.clear()
	_sync()


## 보드가 바뀌면 인스턴스를 맞춘다 (같은 자리에 같은 유물이면 카운터는 유지).
func _sync() -> void:
	var fresh := {}
	for p in board.placed():
		var c: Vector2i = p["cell"]
		if _inst.has(c) and _inst[c]["id"] == p["id"]:
			fresh[c] = _inst[c]
		else:
			fresh[c] = {"id": p["id"], "cd": 0.0, "count": 0, "fired_once": false, "icd": 0.0}
	_inst = fresh


func on_battle_start() -> void:
	_battle_t = 0.0
	_burn.clear()
	for c in _inst:
		var it: Dictionary = _inst[c]
		it["fired_once"] = false
		it["icd"] = 0.0
		it["cd"] = _cooldown_of(c, it["id"])   # 쿨다운형은 전투 시작 후 한 주기 뒤 첫 발동


func on_battle_end() -> void:
	_burn.clear()


# ---------------------------------------------------------------- events

func on_ally_attack(u: VDUnit, target: VDUnit) -> void:
	for c in _inst:
		var it: Dictionary = _inst[c]
		var tr: Dictionary = VDRelicData.def(it["id"])["trigger"]
		match tr["type"]:
			"counter":
				if tr["event"] == "ally_attack":
					it["count"] = int(it["count"]) + 1
					if it["count"] >= int(tr["count"]):
						it["count"] = 0
						_fire(c, {"attacker": u, "target": target})
			"event":
				if tr["event"] == "hero_attack" and tr.get("hero", u.id) == u.id:
					_fire(c, {"attacker": u, "target": target})


func on_enemy_killed(e: VDUnit) -> void:
	for c in _inst:
		var it: Dictionary = _inst[c]
		var tr: Dictionary = VDRelicData.def(it["id"])["trigger"]
		if tr["type"] == "event" and tr["event"] == "enemy_killed":
			_fire(c, {"victim": e, "killer": e.last_hit_by})


func tick(dt: float) -> void:
	_battle_t += dt
	for c in _inst:
		var it: Dictionary = _inst[c]
		it["icd"] = maxf(0.0, float(it["icd"]) - dt)
		var tr: Dictionary = VDRelicData.def(it["id"])["trigger"]
		match tr["type"]:
			"cooldown":
				it["cd"] = float(it["cd"]) - dt
				if it["cd"] <= 0.0:
					if _fire(c, {}):
						it["cd"] = _cooldown_of(c, it["id"])
					else:
						it["cd"] = 0.5   # 대상이 없으면 잠시 뒤 다시
			"threshold":
				if it["fired_once"]:
					continue
				for a in b.allies:
					if a.alive and a.hp / a.max_hp <= float(tr["hp_ratio"]):
						if _fire(c, {"ally": a}):
							it["fired_once"] = true
						break
	_tick_burn(dt)


# ---------------------------------------------------------------- firing

## 발동. 효과가 실제로 적용됐으면 true (대상이 없거나 제약에 걸리면 false).
func _fire(c: Vector2i, ctx: Dictionary) -> bool:
	var it: Dictionary = _inst[c]
	var id: String = it["id"]
	# 내부 쿨다운은 시간·카운터형에만 건다. 처치·공격 같은 이벤트형은 같은 프레임의 다중 처치도 전부 받아야 한다.
	var tr_type: String = VDRelicData.def(id)["trigger"]["type"]
	if b.state != VDBattle.State.BATTLE or (tr_type != "event" and float(it["icd"]) > 0.0):
		return false
	if not _grammar_ok(c, id):
		return false
	var ok := _apply(c, id, ctx)
	if ok:
		it["icd"] = INTERNAL_CD
		fire_count[id] = int(fire_count.get(id, 0)) + 1
		fired.emit(c, id)
	return ok


## 침식 인접 패널티 (모든 유물 공통) — 효과 배율.
func power_of(c: Vector2i) -> float:
	return maxf(0.0, 1.0 - VDRelicData.CORRUPT_PENALTY * board.corrupt_neighbors(c))


## 위치 조건: 별 깃털은 최상단 줄에서만.
func _grammar_ok(c: Vector2i, id: String) -> bool:
	if id == "star_feather":
		return board.is_top_row(c)
	return true


func _cooldown_of(c: Vector2i, id: String) -> float:
	var tr: Dictionary = VDRelicData.def(id)["trigger"]
	var base := float(tr.get("sec", 1.0))
	if id == "ember":
		base *= 1.0 - minf(0.5, 0.1 * board.empty_neighbors(c))
	return base


func _apply(c: Vector2i, id: String, ctx: Dictionary) -> bool:
	var ef: Dictionary = VDRelicData.def(id)["effect"]
	var power := power_of(c)
	if power <= 0.0:
		return false
	var col := VDRelicData.color_of(id)
	var run := b._run_id
	match ef["type"]:
		"lightning":
			var t := _nearest_enemy()
			if t == null:
				return false
			var dmg := float(ef["damage"]) * (1.0 + 0.2 * board.adjacent_relics(c)) * power
			var fx := VDRelicFx.bolt(b.fx_root, _origin(c, b._chest(t) + Vector2(0, -260)), b._chest(t), col, _track(t))
			b.audio.play("mage_cast", 0.05, 4.0)
			fx.impact.connect(func() -> void:
				if not _live(run) or not is_instance_valid(t) or not t.alive:
					return
				b.vfx.spawn("lightning", b.fx_root, t.position + Vector2(0, t._top * 0.6), 0.45, 0.0, col)
				b.relic_damage(t, dmg, id, col, true)
				b.audio.play("mage_hit", 0.05, 2.0)
				b.camera.shake(0.45)
				b.camera.hitstop(0.03))
		"burn":
			var t := _random_enemy()
			if t == null:
				return false
			var dps := float(ef["dps"]) * power
			var sec := float(ef["sec"])
			var fx := VDRelicFx.comet(b.fx_root, _origin(c, b._chest(t) + Vector2(0, -200)), b._chest(t), col, _track(t))
			b.audio.play("gun", 0.08, -6.0)
			fx.impact.connect(func() -> void:
				if not _live(run) or not is_instance_valid(t) or not t.alive:
					return
				t.burn_timer = maxf(t.burn_timer, sec)
				t.burn_dps = dps
				if not _burn.has(t):
					_burn[t] = {"acc": 0.0}
				b.vfx.spawn("burst", b.fx_root, b._chest(t), 0.35, randf() * TAU, col)
				b.relic_damage(t, dps * BURN_TICK, id, col, false)
				b.dmg_log.spawn_status(b._chest(t) + Vector2(0, -30), "화상", col, t)
				b.audio.play("knight_hit", 0.08, -8.0)
				b.camera.shake(0.3))
		"slow":
			var t: VDUnit = ctx.get("target")
			if t == null or not is_instance_valid(t) or not t.alive or t.team != 1:
				return false
			var sec := float(ef["sec"]) * (2.0 if board.relic_above(c) else 1.0) * power
			var mult := float(ef["mult"])
			var fx := VDRelicFx.frost(b.fx_root, _origin(c, b._chest(t) + Vector2(0, -200)), b._chest(t), col, _track(t))
			fx.impact.connect(func() -> void:
				if not _live(run) or not is_instance_valid(t) or not t.alive:
					return
				t.slow_timer = maxf(t.slow_timer, sec)
				t.slow_mult = mult
				b.dmg_log.spawn_status(b._chest(t) + Vector2(0, -30), "둔화", col, t)
				b.audio.play("mage_hit", 0.05, -6.0))
		"shield":
			var a: VDUnit = ctx.get("ally")
			if a == null or not a.alive:
				return false
			var amount := a.max_hp * float(ef["ratio"]) * power
			var fx := VDRelicFx.feather(b.fx_root, _origin(c, b._chest(a) + Vector2(0, -220)), b._chest(a), col, _track(a))
			fx.impact.connect(func() -> void:
				if not _live(run) or not is_instance_valid(a) or not a.alive:
					return
				a.shield = maxf(a.shield, amount)
				b.vfx.spawn("heal", b.fx_root, b._chest(a), 0.6, 0.0, col)
				b.dmg_log.spawn_status(b._chest(a) + Vector2(0, -30), "보호막 %d" % int(a.shield), col, a)
				b.audio.play("heal", 0.05, -2.0))
		"essence":
			var amount := int(round((int(ef["amount"]) + board.adjacent_relics(c)) * power))
			if amount <= 0:
				return false
			b.essence += amount
			b._refresh_essence()
			var killer = ctx.get("killer")
			if killer is VDUnit and is_instance_valid(killer) and killer.team == 0 and killer.alive:
				killer.gain_mana(float(ef["mana"]) * power)
			var v: VDUnit = ctx.get("victim")
			if v != null and is_instance_valid(v):
				b.dmg_log.spawn_status(b._chest(v) + Vector2(0, -44), "유물 +%d" % amount, col, v)
				if origin_of.is_valid():
					VDRelicFx.essence(b.fx_root, b._chest(v), origin_of.call(c), col)
	return true


## 착탄 콜백이 돌 때 아직 같은 전투인지.
func _live(run: int) -> bool:
	return run == b._run_id and b.state == VDBattle.State.BATTLE


## 움직이는 대상을 따라가는 추적 콜백 (죽거나 사라지면 마지막 자리).
func _track(t: VDUnit) -> Callable:
	var last := b._chest(t)
	return func() -> Vector2:
		if is_instance_valid(t) and t.alive:
			last = b._chest(t)
		return last


func _tick_burn(dt: float) -> void:
	for t in _burn.keys():
		if not is_instance_valid(t) or not t.alive or t.burn_timer <= 0.0:
			_burn.erase(t)
			continue
		var st: Dictionary = _burn[t]
		st["acc"] = float(st["acc"]) + dt
		if st["acc"] >= BURN_TICK:
			st["acc"] = float(st["acc"]) - BURN_TICK
			b.relic_damage(t, t.burn_dps * BURN_TICK, "ember", VDRelicData.TAG_COLOR["화염"], false)


# ---------------------------------------------------------------- helpers

func _origin(c: Vector2i, fallback: Vector2) -> Vector2:
	if origin_of.is_valid():
		return origin_of.call(c)
	return fallback


## 아군 누군가에게 가장 가까운 적.
func _nearest_enemy() -> VDUnit:
	var best: VDUnit = null
	var best_d := 1 << 30
	for e in b.enemies:
		if not e.alive:
			continue
		for a in b.allies:
			if not a.alive:
				continue
			var d := VDData.manhattan(a.cell, e.cell)
			if d < best_d:
				best_d = d
				best = e
	return best


func _random_enemy() -> VDUnit:
	var pool: Array[VDUnit] = []
	for e in b.enemies:
		if e.alive:
			pool.append(e)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


## HUD 표시용: 진행 상태 문자열과 0~1 게이지.
func gauge(c: Vector2i) -> Dictionary:
	if not _inst.has(c):
		return {"text": "", "ratio": 0.0}
	var it: Dictionary = _inst[c]
	var tr: Dictionary = VDRelicData.def(it["id"])["trigger"]
	match tr["type"]:
		"counter":
			return {"text": "%d/%d" % [int(it["count"]), int(tr["count"])], "ratio": float(it["count"]) / float(tr["count"])}
		"cooldown":
			var full := _cooldown_of(c, it["id"])
			var left := clampf(float(it["cd"]), 0.0, full)
			return {"text": "%.1fs" % left if b.state == VDBattle.State.BATTLE else "%.1fs" % full, "ratio": 1.0 - left / maxf(full, 0.01)}
		"threshold":
			return {"text": "사용됨" if it["fired_once"] else "대기", "ratio": 0.0 if it["fired_once"] else 1.0}
	return {"text": "", "ratio": 0.0}


## 툴팁용: 지금 자리에서의 배치 보정 설명.
func describe(c: Vector2i) -> String:
	var id := board.relic_at(c)
	if id == "":
		return ""
	var lines: Array[String] = []
	match id:
		"thunder_shard":
			lines.append("인접 유물 %d → 피해 +%d%%" % [board.adjacent_relics(c), 20 * board.adjacent_relics(c)])
		"ember":
			lines.append("빈 이웃 %d → 대기 %.1f초" % [board.empty_neighbors(c), _cooldown_of(c, id)])
		"frost_crystal":
			lines.append("위 칸 유물 %s → 둔화 %s" % ["있음" if board.relic_above(c) else "없음", "4초" if board.relic_above(c) else "2초"])
		"star_feather":
			lines.append("최상단 줄 → 작동" if board.is_top_row(c) else "최상단 줄이 아님 → 비활성")
		"essence_vial":
			lines.append("인접 유물 %d → 처치당 정수 +%d" % [board.adjacent_relics(c), 2 + board.adjacent_relics(c)])
	var cn := board.corrupt_neighbors(c)
	if cn > 0:
		lines.append("침식 인접 %d → 효과 −%d%%" % [cn, int(VDRelicData.CORRUPT_PENALTY * 100 * cn)])
	return "\n".join(lines)
