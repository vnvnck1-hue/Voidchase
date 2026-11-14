## 필드 모양 10종 + 필드 기믹(증폭 패널 · 방전 격자) 자동 테스트 (2026-11-11).
##   1) VDMap.validate(): 모든 모양이 규칙(행 길이·입구/출구 바닥·A/E 칸 수)을 지킨다
##   2) 맵 생성 스트레스: 시드 60개 × 방 14개 — 출구가 항상 생기고, 복도 끝이 새 방 입구와 맞닿고,
##      방 안 바닥이 모두 이어져 있고, 대형 적(2x2)이 적 구역에서 아군 구역 앞까지 갈 수 있다
##   3) 모양마다 새 판: 영웅이 A 칸에 서고, 적이 계획대로 다 등장하고, 첫 방엔 기믹 두 종류가 다 있다 (창이 있으면 배치 화면 저장)
##   4) 증폭 패널: 그 칸에 영웅을 세우고 전투 시작 → field_bonus. 방전 격자: 적을 격자에 올리고 주기를 당김 → 피해·기절
##   5) 방 하나를 끝까지 싸워 넘어간다 (전장이 아닌 새 모양에서, 다음 방 도착까지)
##   godot --headless --path . res://tools/test/VDFieldProbe.tscn -- --speed=6
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/VDFieldProbe.tscn -- --out=docs/field_shapes --speed=2
extends Node

var speed := 6.0
var out_dir := ""
var shapes: Array = []
var _b: VDBattle
var _fails: Array[String] = []


func _ready() -> void:
	shapes = VDMap.TEMPLATES.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--speed="):
			speed = float(a.substr(8))
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
		elif a.begins_with("--shapes="):
			shapes = Array(a.substr(9).split(","))
	_test_templates()
	_test_generation()
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)
	_run.call_deferred()


# ---------------------------------------------------------------- 1) 2) 맵만

func _test_templates() -> void:
	var bad := VDMap.validate()
	_check(bad.is_empty(), "templates valid %s" % str(bad))
	_check(VDMap.TEMPLATES.size() >= 10, "10 shapes (%d)" % VDMap.TEMPLATES.size())
	var sizes := {}
	for s: String in VDMap.TEMPLATES:
		sizes["%dx%d" % [VDMap.shape_len(s), VDMap.TEMPLATES[s]["rows"].size()]] = true
	_check(sizes.size() >= 6, "varied sizes %s" % str(sizes.keys()))
	for s: String in VDMap.TEMPLATES:
		var m := VDMap.new()
		m.rng.seed = 1
		var room := m.create_root(s)
		_check(_connected(room), "%s: floor connected" % s)
		_check(_big_path(room), "%s: 2x2 path from E to A side" % s)


func _test_generation() -> void:
	var seen := {}
	var kinds := {"amp": 0, "shock": 0}
	var rooms := 0
	var sides := 0
	for sd in 300:
		var m := VDMap.new()
		m.rng.seed = 1000 + sd
		var room := m.create_root()
		for step in 14:
			seen[room["shape"]] = true
			rooms += 1
			var has := {}
			for l in room["fields"]:
				has[room["fields"][l]] = true
				if not room["cells"].has(l):
					_fails.append("field outside room (seed %d)" % sd)
				elif room["fields"][l] == "shock" and room["cells"][l] != ".":
					_fails.append("shock tile not on neutral floor (seed %d)" % sd)
			for k in has:
				kinds[k] += 1
			if has.is_empty():
				_fails.append("room without field gimmick (seed %d step %d %s)" % [sd, step, room["shape"]])
			var exits: Array = m.generate_exits(room)
			if exits.is_empty():
				_fails.append("no exit (seed %d step %d %s)" % [sd, step, room["shape"]])
				break
			for ex: Dictionary in exits:
				var nr: Dictionary = m.rooms[ex["room_id"]]
				var cor: Array = ex["corridor"]
				sides += int(ex["kind"] == "side")
				# 복도 마지막 두 칸에서 한 걸음 더 가면 새 방의 입구 두 칸
				var door := {}
				for k in 2:
					door[VDMap.to_world(nr, 0, int(nr["door_c"]) + k)] = true
				for k in 2:
					var tip: Vector2i = cor[cor.size() - 1 - k] + nr["dir"]
					if not door.has(tip):
						_fails.append("corridor misses door (seed %d step %d %s -> %s %s)" % [sd, step, room["shape"], nr["shape"], ex["kind"]])
				# 복도 첫 두 칸은 이 방 바닥과 맞닿는다
				for k in 2:
					var c0: Vector2i = cor[k]
					var touch := false
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if VDMap.in_room(room, c0 + d):
							touch = true
					if not touch:
						_fails.append("corridor not attached (seed %d step %d %s %s)" % [sd, step, room["shape"], ex["kind"]])
			room = m.rooms[exits[m.rng.randi_range(0, exits.size() - 1)]["room_id"]]
	_check(seen.size() == VDMap.TEMPLATES.size(), "all shapes appear in generation (%d/%d)" % [seen.size(), VDMap.TEMPLATES.size()])
	_check(sides > 0, "side exits generated (%d)" % sides)
	_check(kinds["amp"] > rooms / 2 and kinds["shock"] > rooms / 2, "field gimmicks spread: amp %d shock %d of %d rooms" % [kinds["amp"], kinds["shock"], rooms])


func _connected(room: Dictionary) -> bool:
	var cells: Dictionary = room["cells"]
	var start := Vector2i(0, int(room["door_c"]))
	var seen := {start: true}
	var open: Array[Vector2i] = [start]
	while not open.is_empty():
		var c: Vector2i = open.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if cells.has(n) and not seen.has(n):
				seen[n] = true
				open.append(n)
	return seen.size() == cells.size()


## 2x2 발자국이 E 칸을 밟은 자리에서 출발해 A 구역과 닿는 자리까지 갈 수 있는가.
func _big_path(room: Dictionary) -> bool:
	var cells: Dictionary = room["cells"]
	var fits := func(c: Vector2i) -> bool:
		return cells.has(c) and cells.has(c + Vector2i(1, 0)) and cells.has(c + Vector2i(0, 1)) and cells.has(c + Vector2i(1, 1))
	var open: Array[Vector2i] = []
	var seen := {}
	for l: Vector2i in cells:
		if cells[l] == "E" and fits.call(l) and not seen.has(l):
			seen[l] = true
			open.append(l)
	if open.is_empty():
		return false
	while not open.is_empty():
		var c: Vector2i = open.pop_back()
		for x in [-1, 0, 1, 2]:
			for y in [-1, 0, 1, 2]:
				if cells.get(c + Vector2i(x, y), "") == "A":
					return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if fits.call(n) and not seen.has(n):
				seen[n] = true
				open.append(n)
	return false


# ---------------------------------------------------------------- 3) 4) 5) 전투

func _run() -> void:
	await get_tree().create_timer(0.3).timeout
	Engine.time_scale = speed
	for s in shapes:
		await _run_shape(String(s))
	await _test_gimmicks("ring")
	await _test_clear("bridge")
	Engine.time_scale = 1.0
	print("[field-test] DONE fails=%d %s" % [_fails.size(), str(_fails)])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _restart(shape: String) -> bool:
	_b.force_shape = shape
	_b.restart()
	var t0 := Time.get_ticks_msec()
	while _b.state != VDBattle.State.PLACEMENT or _b._spawning:
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > 40000:
			_fails.append("%s: placement timeout" % shape)
			return false
	return true


func _run_shape(shape: String) -> void:
	if not await _restart(shape):
		return
	var room: Dictionary = _b.room
	_check(room["shape"] == shape, "%s: root room shape" % shape)
	var in_zone := _b.allies.all(func(a: VDUnit) -> bool: return VDMap.zone(room, a.cell) == "A")
	_check(in_zone, "%s: heroes start in A zone" % shape)
	var cells := {}
	for a in _b.allies:
		cells[a.cell] = true
	_check(cells.size() == _b.allies.size(), "%s: heroes on distinct cells" % shape)
	var want := VDData.wave_enemies(1, 1).size()
	_check(_b.enemies.size() == want, "%s: all enemies spawned (%d/%d)" % [shape, _b.enemies.size(), want])
	_check(_b.enemies.all(func(e: VDUnit) -> bool: return VDMap.zone(room, e.cell) == "E"), "%s: enemies in E zone" % shape)
	_check(not VDMap.field_cells(room, "amp").is_empty() and not VDMap.field_cells(room, "shock").is_empty(), "%s: first room has both field gimmicks" % shape)
	_check(_b._room_zoom() <= 1.0 and _b._room_zoom() >= 0.8, "%s: room zoom %.2f" % [shape, _b._room_zoom()])
	if out_dir != "":
		await get_tree().create_timer(1.2 * speed).timeout   # 줌·도착 연출이 가라앉은 뒤
	await _shot("shape_%s" % shape)


func _test_gimmicks(shape: String) -> void:
	if not await _restart(shape):
		return
	var room: Dictionary = _b.room
	var f = _b.field
	# 증폭 패널: 아군 구역의 패널 칸에 건너를 세운다 (다른 영웅이 서 있으면 그 영웅으로)
	var amp_cell := Vector2i(-999, -999)
	for c in VDMap.field_cells(room, "amp"):
		if VDMap.zone(room, c) == "A":
			amp_cell = c
	_check(amp_cell.x != -999, "amp tile in A zone")
	var hero: VDUnit = _b._unit_at(amp_cell, _b.allies)
	if hero == null:
		_check(_b.place_hero("gunner", VDMap.to_local(room, amp_cell)), "gunner placed on amp tile")
		hero = _b._unit_at(amp_cell, _b.allies)
	_check(hero != null and is_zero_approx(hero.field_bonus), "no bonus before battle")
	await _shot("gimmick_01_placement")
	var before: Dictionary = f.count.duplicate()
	_b.start_battle()
	while _b.state != VDBattle.State.BATTLE:
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(int(f.count["amp_on"]) > int(before["amp_on"]), "amp triggered (%d)" % (int(f.count["amp_on"]) - int(before["amp_on"])))
	# 패널을 밟고 있는 영웅은 보너스, 아닌 영웅은 0
	var ok := true
	for a in _b.allies:
		var on: bool = a.alive and f.is_amp(a.cell)
		if not is_equal_approx(a.field_bonus, f.AMP_BONUS if on else 0.0):
			ok = false
	_check(ok, "field_bonus matches standing tile")
	# 방전 격자: 적 하나를 격자 칸에 올리고 방전 직전으로 당긴다
	var shock: Array[Vector2i] = VDMap.field_cells(room, "shock")
	var e: VDUnit = null
	var at := Vector2i(-999, -999)
	for c in shock:
		if not _b._occupied(c):
			at = c
			break
	for x in _b.enemies:
		if x.alive and x.size == 1:
			e = x
			break
	_check(e != null and at.x != -999, "enemy + free shock tile")
	if e == null or at.x == -999:
		return
	f._t = f.SHOCK_IDLE + 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(f.warning() and f.is_hazard(at), "shock tile is a hazard while warning")
	await _shot("gimmick_02_warn")
	e.cell = at
	e.snap_to_cell()
	var hp0 := e.hp
	f._t = f.SHOCK_IDLE + f.SHOCK_WARN - 0.001
	var shocks: int = f.count["shock"]
	var hits: int = f.count["shock_hits"]
	while int(f.count["shock"]) == shocks:
		await get_tree().physics_frame
	_check(int(f.count["shock_hits"]) > hits, "shock hit an enemy (%d)" % (int(f.count["shock_hits"]) - hits))
	_check(e.hp < hp0 or not e.alive, "enemy damaged by shock (%.0f -> %.0f)" % [hp0, e.hp])
	_check(not e.alive or e.stun_timer > 0.0, "enemy stunned by shock")
	_check(not f.warning(), "shock cycle restarted")
	await _shot("gimmick_03_discharge")
	# 전투가 끝나면 보너스가 풀린다
	for x in _b.enemies.duplicate():
		if x.alive:
			x.take_damage(x.hp + 99999.0)
	while _b.state == VDBattle.State.BATTLE and _b.wave_in_stage < 2:
		await get_tree().process_frame
	_b._set_state(VDBattle.State.TRANSITION)
	_check(_b.allies.all(func(a: VDUnit) -> bool: return is_zero_approx(a.field_bonus)), "bonus cleared after battle")


## 새 모양에서 방 하나를 끝까지 싸우고 다음 방에 도착한다.
func _test_clear(shape: String) -> void:
	if not await _restart(shape):
		return
	var first_id: int = _b.room["id"]
	_b.auto_ult = true
	_b.start_battle()
	var t0 := Time.get_ticks_msec()
	var chosen := false
	while _b.room["id"] == first_id or _b.state != VDBattle.State.PLACEMENT or _b._spawning:
		await get_tree().process_frame
		if _b.state == VDBattle.State.GAMEOVER:
			_fails.append("%s: game over in first room" % shape)
			return
		if _b.state == VDBattle.State.BATTLE and Time.get_ticks_msec() - t0 > 15000:
			# 테스트는 길 찾기·넘어가기를 본다: 오래 걸리면 남은 적을 정리한다
			for x in _b.enemies.duplicate():
				if x.alive and not x.casting:
					x.take_damage(x.hp + 99999.0)
		if _b.state == VDBattle.State.CHOOSE_PATH and not chosen:
			chosen = true
			await _shot("clear_01_fork")
			_b.choose_path(_b.exits.size() - 1)
		if Time.get_ticks_msec() - t0 > 120000:
			_fails.append("%s: clear timeout (state %s)" % [shape, VDBattle.State.keys()[_b.state]])
			return
	var room: Dictionary = _b.room
	_check(room["id"] != first_id, "arrived in next room (%s)" % room["shape"])
	_check(room["shape"] != shape, "next room has a different shape")
	_check(_b.allies.all(func(a: VDUnit) -> bool: return not a.alive or VDMap.zone(room, a.cell) == "A"), "heroes re-formed in next room's A zone")
	_check(_b.enemies.size() > 0 and _b.enemies.all(func(e: VDUnit) -> bool: return VDMap.in_room(room, e.cell)), "enemies spawned in next room (%d)" % _b.enemies.size())
	if out_dir != "":
		await get_tree().create_timer(1.2 * speed).timeout
	await _shot("clear_02_next_%s" % room["shape"])


func _check(ok: bool, what: String) -> void:
	print("[field-test] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _shot(shot_name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out_dir).path_join(shot_name + ".png"))
