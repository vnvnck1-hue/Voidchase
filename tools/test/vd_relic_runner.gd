## 유물 성좌판 자동 테스트: 유물 5종을 보관함에 넣고 열린 4칸에 배치 → 전투 N방 → 발동 횟수·칸 해금·침식/정화·배치 문법을 확인.
##   godot --headless --path . res://tools/test/VDRelicRunner.tscn -- --cycles=3 --speed=4
extends Node

var cycles := 3
var timeout := 150.0
var speed := 4.0

var _b: VDBattle
var _t := 0.0
var _started := false
var _cleared := 0
var _fails: Array[String] = []
var _open_before := 0
var out_dir := ""            # --out=DIR 이면 창이 있을 때 단계별 스크린샷 저장
var _battle_t := 0.0
var _battle_shot := false
var burstshow := false
var fxshow := false          # --fxshow : 전투 대신 투사체 연출만 띄우고 시간차 캡처


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cycles="):
			cycles = int(a.substr(9))
		elif a.begins_with("--timeout="):
			timeout = float(a.substr(10))
		elif a.begins_with("--speed="):
			speed = float(a.substr(8))
		elif a == "--fxshow":
			fxshow = true
		elif a == "--burstshow":
			fxshow = true
			burstshow = true
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(out_dir)
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)
	_b.state_changed.connect(_on_state)
	_b.game_over.connect(func(w: int) -> void:
		print("[relic-test] game over at wave %d" % w)
		_finish())
	Engine.time_scale = speed
	print("[relic-test] ready  cycles=%d speed=%.1f" % [cycles, speed])


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.001)
	if _t > timeout:
		_fails.append("TIMEOUT after %.1fs (state=%s)" % [_t, VDBattle.State.keys()[_b.state]])
		_finish()
		return
	if not _started and _t > 0.5:
		_started = true
		_setup_board()
		if fxshow:
			_fx_show()
			return
		_shot_later("01_placement", 0.3)
		_turn_later(0.5)
		_start_later(1.6)
	if _b.state == VDBattle.State.BATTLE:
		_battle_t += delta
		if not _battle_shot and _battle_t > 1.2:
			_battle_shot = true
			_shot("02_battle_room%d" % _b.room["id"])


## 보드 모델 검사 + 초기 배치.
func _setup_board() -> void:
	var board: VDRelicBoard = _b.relic_board
	_check(board.open_count() == VDRelicData.START_UNLOCKED, "start unlocked == %d (got %d)" % [VDRelicData.START_UNLOCKED, board.open_count()])
	_check(board.tray.size() == VDRelicData.STARTING_TRAY.size(), "starting tray size")
	for id in VDRelicData.RELIC_ORDER:
		if not board.tray.has(id):
			board.add_to_tray(id)
	_check(board.tray.size() == 5, "tray has all 5 relics (got %d)" % board.tray.size())
	# 잠긴 칸에는 못 놓는다
	_check(not board.place_from_tray(0, Vector2i(0, 2)), "cannot place on locked cell")
	# 별 깃털은 최상단에, 서리 결정은 뇌운 조각 아래(위 칸 유물 → 둔화 2배), 잉걸불은 빈 이웃이 많은 자리
	_place("star_feather", Vector2i(0, 0))
	_place("thunder_shard", Vector2i(1, 0))
	_place("frost_crystal", Vector2i(1, 1))
	_place("essence_vial", Vector2i(0, 1))
	_check(board.tray.size() == 1 and board.tray[0] == "ember", "ember left in tray")
	_check(board.relic_above(Vector2i(1, 1)), "frost has relic above")
	_check(board.adjacent_relics(Vector2i(1, 0)) == 3, "thunder adjacent == 3 (got %d)" % board.adjacent_relics(Vector2i(1, 0)))
	_check(_b.relics._grammar_ok(Vector2i(0, 0), "star_feather"), "star feather ok on top row")
	# 맞바꾸기: 별 깃털을 (0,1) 로 옮기면 정수병과 자리가 바뀌고 문법에 걸린다
	_check(board.move(Vector2i(0, 0), Vector2i(0, 1)), "swap move")
	_check(board.relic_at(Vector2i(0, 0)) == "essence_vial" and board.relic_at(Vector2i(0, 1)) == "star_feather", "swap result")
	_check(not _b.relics._grammar_ok(Vector2i(0, 1), "star_feather"), "star feather blocked off top row")
	_check(board.move(Vector2i(0, 1), Vector2i(0, 0)), "swap back")
	# 보관함으로 내리고 다시 올리기
	_check(board.to_tray(Vector2i(0, 1)), "to tray")
	_check(board.place_from_tray(board.tray.find("essence_vial"), Vector2i(0, 1)), "back from tray")
	_open_before = board.open_count()
	print("[relic-test] placed: %s  tray=%s" % [str(board.placed()), str(board.tray)])
	# 투사체 출발점이 전장 좌표로 나오는지
	var wp: Vector2 = _b.relic_hud.cell_world_pos(Vector2i(1, 0))
	_check(wp.is_finite(), "cell_world_pos finite: %s" % str(wp))


func _place(id: String, c: Vector2i) -> void:
	var board: VDRelicBoard = _b.relic_board
	var i := board.tray.find(id)
	_check(i >= 0 and board.place_from_tray(i, c), "place %s at %s" % [id, str(c)])


func _on_state(s: int) -> void:
	print("[relic-test] state -> %s" % VDBattle.State.keys()[s])
	if s == VDBattle.State.CHOOSE_PATH and _b.exits.size() >= 2:
		_choose_later(randi() % _b.exits.size())
	elif s == VDBattle.State.PLACEMENT and _started:
		_cleared += 1
		_battle_t = 0.0
		_battle_shot = false
		_shot_later("03_offer%d" % _cleared, 0.4)   # 보상 선택 패널이 떠 있는 순간
		_after_clear_later(0.7)
		if _cleared >= cycles:
			_finish_later(1.4)
		else:
			_start_later(1.6)


func _choose_later(pick: int) -> void:
	await get_tree().create_timer(0.6).timeout
	if is_inside_tree():
		_b.choose_path(pick)


## 클리어 뒤: 칸이 열렸는지, 보상을 고를 수 있는지, 침식·정화가 되는지.
func _after_clear() -> void:
	var board: VDRelicBoard = _b.relic_board
	var hud: VDRelicHud = _b.relic_hud
	print("[relic-test] after clear %d: open=%d corrupt=%d tray=%s fired=%s essence=%d" % [_cleared, board.open_count(), board.corrupt_count(), str(board.tray), str(_b.relics.fire_count), _b.essence])
	_check(board.open_count() >= _open_before + 1 or board.open_count() == VDRelicData.BOARD_CELLS.size(), "cell unlocked after clear")
	_open_before = board.open_count()
	_check(hud.has_offer(), "reward offer shown")
	var before := board.tray.size()
	hud.pick("thunder_shard")
	_check(board.tray.size() == before + 1, "pick adds to tray")
	if _cleared == 1:
		# 침식을 강제로 만들고 정화한다. 클리어 보상의 35% 침식이 유일한 빈 칸을 이미 먹었으면 그 칸을 쓴다
		var c := board.corrupt_random()
		if c.x < 0:
			for cc in VDRelicData.BOARD_CELLS:
				if board.state_of(cc) == VDRelicBoard.Cell.CORRUPT:
					c = cc
					break
		_check(c.x >= 0, "forced corruption (or one already present)")
		if c.x >= 0:
			_check(board.state_of(c) == VDRelicBoard.Cell.CORRUPT, "cell is corrupt")
			_check(not board.can_place(c), "cannot place on corrupt cell")
			var ess := _b.essence
			_b.essence = VDRelicData.PURIFY_COST - 1
			_check(not hud.try_purify(c), "purify refused without essence")
			_b.essence = VDRelicData.PURIFY_COST + 5
			_check(hud.try_purify(c) and _b.essence == 5, "purify spends essence")
			_b.essence = ess
	# 새로 열린 칸이 있으면 보관함 유물을 올린다 (잉걸불 → 빈 이웃 많은 자리)
	for c in VDRelicData.BOARD_CELLS:
		if board.can_place(c) and board.relic_at(c) == "" and not board.tray.is_empty():
			board.place_from_tray(0, c)
			break


func _after_clear_later(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
	if is_inside_tree():
		_after_clear()
		_shot_later("04_after_pick%d" % _cleared, 0.2)


## 투사체 5종을 동시에 띄우고 0.08초 간격으로 캡처한다 (연출 확인용, 전투 없음).
func _fx_show() -> void:
	var hud: VDRelicHud = _b.relic_hud
	if burstshow:
		# 버스트 셰이더 단독 확인: t 를 고정한 쿼드 4개
		var x := 0.0
		for tv in [0.02, 0.15, 0.35, 0.7]:
			var sp := Sprite2D.new()
			sp.texture = VDRelicFx.quad_texture()
			sp.position = _b._chest(_b.allies[0]) + Vector2(x, 160.0)
			sp.scale = Vector2.ONE * 3.0
			sp.z_index = 60
			var m := ShaderMaterial.new()
			m.shader = VDRelicFx.BurstShader
			m.set_shader_parameter("t", tv)
			m.set_shader_parameter("seed", 3.0)
			sp.material = m
			_b.fx_root.add_child(sp)
			x += 220.0
		await get_tree().create_timer(0.3).timeout
		_shot("burst_static")
		await get_tree().create_timer(0.3).timeout
		get_tree().quit(0)
		return
	var foes := _b.enemies.filter(func(e: VDUnit) -> bool: return e.alive)
	var e0: VDUnit = foes[0]
	var e1: VDUnit = foes[1 % foes.size()]
	var e2: VDUnit = foes[2 % foes.size()]
	var ally: VDUnit = _b.allies[0]
	var chest := func(u: VDUnit) -> Vector2: return _b._chest(u)
	VDRelicFx.bolt(_b.fx_root, hud.cell_world_pos(Vector2i(1, 0)), chest.call(e0), VDRelicData.TAG_COLOR["번개"])
	VDRelicFx.comet(_b.fx_root, hud.cell_world_pos(Vector2i(0, 1)), chest.call(e1), VDRelicData.TAG_COLOR["화염"])
	VDRelicFx.frost(_b.fx_root, hud.cell_world_pos(Vector2i(1, 1)), chest.call(e2), VDRelicData.TAG_COLOR["서리"])
	VDRelicFx.feather(_b.fx_root, hud.cell_world_pos(Vector2i(0, 0)), chest.call(ally), VDRelicData.TAG_COLOR["수호"])
	VDRelicFx.essence(_b.fx_root, chest.call(e0), hud.cell_world_pos(Vector2i(0, 1)), VDRelicData.TAG_COLOR["정수"])
	for i in 12:
		_shot_later("fx_%02d" % i, 0.06 + i * 0.08)
	await get_tree().create_timer(1.4).timeout
	print("[relic-test] fxshow done")
	get_tree().quit(0)


## 턴테이블: 3번째 캐릭터를 골라 돌리고 찍는다 (선택 캐릭터가 앞·밝게, 나머지 뒤·딤드).
func _turn_later(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
	if not is_inside_tree():
		return
	var tt: VDTurntable = _b.turntable
	_check(tt != null and tt.selected == 0, "turntable starts at 0")
	tt.select(3)
	_check(tt.selected == 3, "turntable select(3)")
	await get_tree().create_timer(0.6).timeout
	if is_inside_tree():
		_shot("01b_turntable")
		tt.select_next(-1)
		_check(tt.selected == 2, "turntable select_next(-1) -> 2")


func _start_later(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
	if is_inside_tree():
		_b.start_battle()


func _finish_later(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
	if is_inside_tree():
		_finish()


func _shot_later(name: String, sec: float) -> void:
	await get_tree().create_timer(sec).timeout
	if is_inside_tree():
		_shot(name)


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("[relic-test] shot %s" % path)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("[relic-test] ok: " + what)
	else:
		_fails.append(what)
		print("[relic-test] FAIL: " + what)


func _finish() -> void:
	var fc: Dictionary = _b.relics.fire_count
	for id in ["thunder_shard", "frost_crystal", "essence_vial"]:
		_check(int(fc.get(id, 0)) > 0, "%s fired (%d)" % [id, int(fc.get(id, 0))])
	print("[relic-test] ember fired %d (placed from room 2), star_feather fired %d (needs an ally under 50%%)" % [int(fc.get("ember", 0)), int(fc.get("star_feather", 0))])
	print("[relic-test] DONE rooms=%d wave=%d essence=%d fired=%s fails=%d" % [_cleared, _b.wave, _b.essence, str(fc), _fails.size()])
	for f in _fails:
		print("[relic-test]   - " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)
