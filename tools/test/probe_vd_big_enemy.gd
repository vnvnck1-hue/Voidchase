## 대형 적(4칸, 공허 망루) 헤드리스 점검: 6구역 편성으로 다시 소환 → 전투를 돌리며
## 매 프레임 모든 유닛 footprint 가 방 안에 있고 서로 겹치지 않는지, 망루가 움직이고 공격하는지 본다.
##   godot --headless --path . res://tools/test/VDBigEnemyProbe.tscn -- --wave=6 --speed=4
## 창으로 띄우고 --out=<폴더> 를 주면 등장 직후·전투 중 스크린샷을 남긴다 (서브 모니터 인자 필수).
extends Node

var _b: VDBattle
var _t := 0.0
var _phase := 0
var _fail := 0
var _wave := 6
var _speed := 4.0
var _big: Array[VDUnit] = []
var _start_cells := {}
var _moved := {}
var _ally_hp := 0.0
var _out := ""
var _shots := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wave="):
			_wave = int(a.substr(7))
		elif a.begins_with("--speed="):
			_speed = float(a.substr(8))
		elif a.begins_with("--out="):
			_out = a.substr(6)
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.001)
	match _phase:
		0:
			if _t > 1.0 and not _b._spawning:
				# 첫 방 적을 치우고 지정 구역 편성으로 다시 소환
				for e in _b.enemies:
					e.queue_free()
				_b.enemies.clear()
				_b.wave = _wave
				_b._spawn_wave(_b._run_id)
				_phase = 1
		1:
			if not _b._spawning:
				for e in _b.enemies:
					if e.size > 1:
						_big.append(e)
						_start_cells[e] = e.cell
				print("[probe] wave %d enemies=%s big=%d" % [_wave, str(_b.enemies.map(func(e: VDUnit) -> String: return "%s@%s" % [e.id, e.cell])), _big.size()])
				if _big.is_empty():
					print("[probe] FAIL no big enemy spawned")
					_fail += 1
				_check("spawn")
				_shot("1_spawned")
				_ally_hp = _sum_hp(_b.allies)
				Engine.time_scale = _speed
				_b.start_battle()
				_phase = 2
		2:
			_check("battle")
			if _shots == 1 and _b.state == VDBattle.State.BATTLE and _t > 4.0:
				_shot("2_battle")
			for e in _big:
				if is_instance_valid(e) and e.alive and e.cell != _start_cells[e]:
					_moved[e] = true
			if _b.state == VDBattle.State.CHOOSE_PATH or _b.state == VDBattle.State.TRANSITION or _b.state == VDBattle.State.GAMEOVER or _t > 90.0:
				_finish()
				return



func _shot(name: String) -> void:
	_shots += 1
	if _out == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().get_texture().get_image().save_png(_out.path_join("big_enemy_%s.png" % name))


func _sum_hp(list: Array[VDUnit]) -> float:
	var s := 0.0
	for u in list:
		s += u.hp
	return s


func _check(tag: String) -> void:
	var seen := {}
	for list in [_b.allies, _b.enemies]:
		for u in list:
			if not is_instance_valid(u) or not u.alive:
				continue
			for c in u.footprint():
				if not VDMap.in_room(_b.room, c) and _b.state == VDBattle.State.BATTLE:
					print("[probe] FAIL %s: %s cell %s outside room" % [tag, u.id, c])
					_fail += 1
				if seen.has(c):
					print("[probe] FAIL %s: %s overlaps %s at %s" % [tag, u.id, seen[c], c])
					_fail += 1
				seen[c] = u.id
	if _fail > 20:
		_finish()
		get_tree().quit(1)


func _finish() -> void:
	var kills := 0
	for e in _big:
		if not is_instance_valid(e) or not e.alive:
			kills += 1
	print("[probe] state=%s t=%.1f  big moved=%d/%d  big down=%d  ally hp lost=%d  fails=%d" % [
		VDBattle.State.keys()[_b.state], _t, _moved.size(), _big.size(), kills, int(_ally_hp - _sum_hp(_b.allies)), _fail])
	print("[probe] %s" % ("PASS" if _fail == 0 and not _big.is_empty() else "FAIL"))
	Engine.time_scale = 1.0
	set_process(false)
	get_tree().quit(0 if _fail == 0 else 1)
