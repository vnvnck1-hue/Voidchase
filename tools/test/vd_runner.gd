## VOID DEFENSE 자동 테스트: 배치 완료 → 전투 → 클리어 → 갈림길 선택(랜덤) → 이동 → 다음 방 배치까지
## N 사이클 돌려 전진 루프가 이어지는지 확인한다. 창이 있으면 단계별 스크린샷도 저장.
##   godot --headless --path . res://tools/test/VDRunner.tscn -- --cycles=3 --speed=4
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/VDRunner.tscn -- --out=D:/shots
extends Node

var out_dir := "user://vd_shots"
var cycles := 1
var timeout := 120.0
var speed := 1.0

var _b: VDBattle
var _t := 0.0
var _started := false
var _cleared := 0
var _battle_t := 0.0
var _shot_battle := false
var _battle_shots := {}
var _quitting := false
var _rooms_visited: Array[int] = []
var _formation_checked := 0
var _casts_seen := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--cycles="):
			cycles = int(a.substr(9))
		elif a.begins_with("--timeout="):
			timeout = float(a.substr(10))
		elif a.begins_with("--speed="):
			speed = float(a.substr(8))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)
	_b.wave_cleared.connect(_on_cleared)
	_b.game_over.connect(_on_game_over)
	_b.state_changed.connect(_on_state)
	Engine.time_scale = speed
	print("[runner] ready  cycles=%d speed=%.1f headless=%s" % [cycles, speed, str(_is_headless())])


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.001)
	if _t > timeout:
		print("[runner] TIMEOUT after %.1fs (state=%s)" % [_t, VDBattle.State.keys()[_b.state]])
		_quit(1)
		return
	if not _started and _t > 0.5:
		_started = true
		# 진형을 일부러 바꿔서 다음 방에서도 같은 자리로 가는지 본다
		_b.place_hero("knight", Vector2i(3, 0))
		_b.place_hero("healer", Vector2i(0, 5))
		_shot("01_placement")
		print("[runner] start_battle()  formation knight=(3,0) healer=(0,5)")
		_b.start_battle()
	if _b.state == VDBattle.State.BATTLE:
		_battle_t += delta
		# 스킬 시전 직후 한 장씩 (연출이 한창일 0.2초 뒤)
		var casts := 0
		for k in _b.skills.cast_count:
			casts += int(_b.skills.cast_count[k])
		if casts > _casts_seen:
			_casts_seen = casts
			_skill_shot_later(casts)
		# 전투 중 여러 장: 교전이 붙는 1.5초 뒤부터 0.35초 간격으로 6장
		var idx := int((_battle_t - 1.5) / 0.35)
		if idx >= 0 and idx < 6 and not _battle_shots.has(idx):
			_battle_shots[idx] = true
			_shot("02_battle_room%d_%d" % [_b.room["id"], idx])


func _on_state(s: int) -> void:
	print("[runner] state -> %s" % VDBattle.State.keys()[s])
	if s == VDBattle.State.CHOOSE_PATH:
		_shot("03_choose_room%d" % _b.room["id"])
		if _b.exits.size() >= 2:
			var pick := randi() % _b.exits.size()
			print("[runner] branch with %d exits -> choosing %d" % [_b.exits.size(), pick])
			_choose_later(pick)
	elif s == VDBattle.State.PLACEMENT and _started:
		_rooms_visited.append(_b.room["id"])
		_check_formation()
		_placement_shot_later(_b.room["id"])   # 적이 다 등장한 뒤(약 1.6초) 배치 화면을 찍는다
		if _cleared >= cycles:
			print("[runner] DONE  cycles=%d  rooms=%s  wave=%d  essence=%d  heroes_alive=%d  formation_ok=%d" % [_cleared, str(_rooms_visited), _b.wave, _b.essence, _alive(), _formation_checked])
			print("[runner] map: rooms=%d tiles=%d" % [_b.map.rooms.size(), _b.map.tiles.size()])
			print("[runner] sfx plays: %s" % str(_b.audio.play_count))
			print("[runner] vfx plays: %s" % str(_b.vfx.play_count))
			print("[runner] skill casts: %s" % str(_b.skills.cast_count))
			print("[runner] damage numbers spawned: %d  preset=%s" % [_b.dmg_log.count_spawned, VDDamageLog.preset])
			_quit(0)
		else:
			_shot_battle = false
			_battle_shots.clear()
			_battle_t = 0.0
			_b.call_deferred("start_battle")


func _skill_shot_later(n: int) -> void:
	await get_tree().create_timer(0.2).timeout
	if is_inside_tree():
		_shot("05_skill_%02d" % n)
	await get_tree().create_timer(0.3).timeout
	if is_inside_tree():
		_shot("05_skill_%02d_b" % n)


## 배치 단계: 적 선등장이 끝난 뒤 찍어야 적 위치가 보인다.
func _placement_shot_later(room_id: int) -> void:
	await get_tree().create_timer(1.6).timeout
	if is_inside_tree():
		_shot("04_placement_room%d" % room_id)


## 갈림길 표시가 화면에 잡히도록 잠깐 기다렸다가 선택.
func _choose_later(pick: int) -> void:
	await get_tree().create_timer(1.0).timeout
	_shot("03b_choose_ui_room%d" % _b.room["id"])
	await get_tree().create_timer(0.2).timeout
	_b.choose_path(pick)


## 새 방에서 영웅이 저장된 진형(로컬 a,c)에 서 있는지 확인.
func _check_formation() -> void:
	var ok := true
	for a in _b.allies:
		var l: Vector2i = VDMap.to_local(_b.room, a.cell)
		var f: Vector2i = _b.formation[a.id]
		if VDMap.zone(_b.room, a.cell) != "A":
			ok = false
			print("[runner] HERO NOT IN ALLY ZONE %s at %s (room shape %s)" % [a.id, str(l), _b.room["shape"]])
		if l != f:
			ok = false
			print("[runner] FORMATION MISMATCH %s: at %s expected %s" % [a.id, str(l), str(f)])
		if not VDMap.in_room(_b.room, a.cell):
			ok = false
			print("[runner] HERO OUTSIDE ROOM %s" % a.id)
	if ok:
		_formation_checked += 1
		print("[runner] formation ok in room %d (%s): %s  enemies_visible=%d" % [_b.room["id"], _b.room["shape"], str(_b.formation), _b.enemies.size()])


func _on_cleared(w: int) -> void:
	_cleared += 1
	print("[runner] wave %d cleared (%d/%d)" % [w, _cleared, cycles])


func _on_game_over(w: int) -> void:
	print("[runner] GAME OVER at wave %d" % w)
	_shot("99_gameover")
	_quit(2)


func _alive() -> int:
	var n := 0
	for a in _b.allies:
		if a.alive:
			n += 1
	return n


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _shot(name: String) -> void:
	if _is_headless():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("[runner] shot " + path)


func _quit(code: int) -> void:
	if _quitting:
		return
	_quitting = true
	await get_tree().create_timer(0.4).timeout
	get_tree().quit(code)
