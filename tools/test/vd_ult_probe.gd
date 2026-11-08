## 궁극기 확인: 전투가 붙으면 영웅마다 궁극기 게이지를 채우고 카드 탭(try_ult)으로 쓴다.
## 건너·마법사는 조준 화면을 열고, 마우스 이동·클릭을 입력 이벤트로 넣어 조준 → 시전까지 간다.
## 힐러는 기사를 먼저 쓰러뜨린 뒤 부활시키는지 본다. 창이 있으면 조준 화면·시전 장면을 찍는다.
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/VDUltProbe.tscn -- --out=D:/shots
extends Node

var out_dir := "user://vd_ult_probe"
var _b: VDBattle
var _fails: Array[String] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	_b.process_mode = Node.PROCESS_MODE_PAUSABLE   # 이 노드는 일시정지 중에도 돌지만 전투는 멈춰야 한다
	add_child(_b)
	_run()


func _run() -> void:
	await _wait(1.0)
	_b.start_battle()
	while _b.state != VDBattle.State.BATTLE:
		await get_tree().process_frame
	for e in _b.enemies:   # 궁극기 넷을 한 전투에서 다 보도록 적을 단단하게
		e.max_hp *= 30.0
		e.hp = e.max_hp
	await _wait(1.6)
	# 1) 힐러 부활: 기사를 쓰러뜨리고 힐러 궁극기
	var knight := _hero("knight")
	knight.take_damage(99999.0)
	await _wait(1.2)
	_check(not knight.alive and _b.first_fallen() == knight, "knight fallen")
	_fill("healer")
	_b.try_ult("healer")
	await _wait_ult_done()
	_check(knight.alive, "healer revived knight (hp %d/%d)" % [int(knight.hp), int(knight.max_hp)])
	_shot("10_after_revive")
	# 2) 기사 충격파 (조준 없음)
	_fill("knight")
	_b.try_ult("knight")
	await _wait_real(0.35)
	_shot("11_knight_intro")
	await _wait_ult_done()
	_shot("12_knight_after")
	# 3) 건너 집중 포화: 조준 화면 → 가장 가까운 적 쪽 클릭
	_fill("gunner")
	_b.try_ult("gunner")
	_check(_b.ult_aim.active and get_tree().paused, "gunner aim opened + paused")
	var e := _b._nearest(_hero("gunner"), _b.enemies)
	if e:
		_move_mouse(e.position)
		await _wait_real(0.3)
		await _shot("13_gunner_aim")
		_click(e.position)
	await _wait_real(0.2)
	_check(not _b.ult_aim.active, "gunner aim closed after click")
	await _wait_ult_done()
	# 4) 마법사 체인 라이트닝: 적 하나를 노려 클릭 (그 전에 한 번 취소도 해 본다)
	_fill("mage")
	_b.try_ult("mage")
	_b.ult_aim.cancel()
	_check(not _b.ult_aim.active and not get_tree().paused and _hero("mage").ult_full(), "mage aim cancel keeps gauge")
	_b.try_ult("mage")
	var far := _farthest_enemy()
	if far:
		_move_mouse(_b._chest(far))
		await _wait_real(0.3)
		await _shot("14_mage_aim")
		_click(_b._chest(far))
	await _wait_real(1.4)
	_shot("15_mage_cutin_or_chain")
	await _wait_ult_done()
	_shot("16_mage_after")
	# 카드 UI: 궁극기 게이지가 찬 카드(금빛 테 + "궁극기!")와 덜 찬 카드
	_hero("gunner").gain_ult(VDData.MAX_ULT)
	_hero("knight").ult = 45.0
	await _wait_real(0.5)
	await _shot("17_cards_ready")
	print("[ult-probe] casts=%s intro_log=%s" % [str(_b.ults.cast_count), str(_b.ult.cast_log)])
	for id in ["healer", "knight", "gunner", "mage"]:
		_check(int(_b.ults.cast_count.get(id, 0)) >= 1, "%s ultimate cast" % id)
	print("[ult-probe] %s  fails=%s" % ["OK" if _fails.is_empty() else "FAIL", str(_fails)])
	get_tree().paused = false
	get_tree().quit(0 if _fails.is_empty() else 1)


func _hero(id: String) -> VDUnit:
	for a in _b.allies:
		if a.id == id:
			return a
	return null


func _farthest_enemy() -> VDUnit:
	var m := _hero("mage")
	var best: VDUnit = null
	for e in _b.enemies:
		if e.alive and (best == null or m.dist_to(e) > m.dist_to(best)):
			best = e
	return best


func _fill(id: String) -> void:
	var u := _hero(id)
	u.gain_ult(VDData.MAX_ULT)
	print("[ult-probe] fill %s: full=%s casting=%s stun=%.2f alive=%s ult.active=%s aim=%s state=%s paused=%s" % [id, str(u.ult_full()), str(u.casting), u.stun_timer, str(u.alive), str(_b.ult.active), str(_b.ult_aim.active), VDBattle.State.keys()[_b.state], str(get_tree().paused)])


func _check(ok: bool, what: String) -> void:
	print("[ult-probe] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


## 월드 좌표 → 화면(캔버스) 좌표. 창 모드에선 실제 OS 커서가 이벤트 위치를 덮으므로 조준 화면에 직접 넣는다.
func _to_screen(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world


func _move_mouse(world: Vector2) -> void:
	_b.ult_aim.mouse_override = _to_screen(world)
	_b.ult_aim._update_target()


func _click(world: Vector2) -> void:
	_b.ult_aim.press(_to_screen(world))
	_b.ult_aim.mouse_override = null


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


func _wait_real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


## 궁극기 연출(멈춤)이 끝나고 무대가 밝아질 때까지 + 여유.
func _wait_ult_done() -> void:
	await _wait_real(0.2)
	while _b.ult.active or get_tree().paused:
		await get_tree().process_frame
	await _wait_real(1.6)


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("[ult-probe] shot " + name)
