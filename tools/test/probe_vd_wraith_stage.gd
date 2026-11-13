## 공허 망령 실전 점검: 연습장이 아니라 실제 스테이지(기본 4 = 망령이 나오는 첫 스테이지)의 마지막 웨이브를 그대로 소환해
## 영웅 4명이 자동으로 싸우게 두고(궁극기도 차는 대로 자동 사용) 실속도로 지켜본다.
##   - 망령이 그 웨이브에 4칸 중보스로 나오는가, 타일에 묶이지 않고 떠다니는가(밟은 칸이 위치를 따라오는가)
##   - 스스로 촉수 난타·순간이동을 쓰는가, 순간이동 뒤 촉수 연계 / 궁극기 회피가 몇 번 나왔는가 (확률이라 횟수만 적는다)
##   godot --headless --path . res://tools/test/VDWraithStageProbe.tscn -- --stage=4 --secs=45
## 창으로 띄우고 --out=<폴더> 를 주면 촉수 난타가 나오는 동안 실속도 프레임을 0.08초마다 남긴다 (서브 모니터 인자 필수).
extends Node

var _b: VDBattle
var _t := 0.0
var _phase := 0
var _stage := 4
var _secs := 45.0
var _out := ""
var _fail := 0
var _u: VDUnit
var _path := 0.0
var _last := Vector2.ZERO
var _cells := {}
var _cell_ok := true
var _shot_t := 0.0
var _shots := 0
var _casts_seen := 0
var _was_casting := false
var _overlap := false
var _idle_shots := 0
var _hp_prev := 1e12
var _off_frames := 0
var _off_worst := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			_stage = int(a.substr(8))
		elif a.begins_with("--secs="):
			_secs = float(a.substr(7))
		elif a.begins_with("--out="):
			_out = a.substr(6)
			DirAccess.make_dir_recursive_absolute(_out)
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.001)
	_t += real
	match _phase:
		0:
			if _t > 1.0 and not _b._spawning:
				for e in _b.enemies:
					e.queue_free()
				_b.enemies.clear()
				_b.stage = _stage
				_b.wave_in_stage = VDData.waves_in_stage(_stage)
				_b.gimmick = ""
				_b._spawn_wave(_b._run_id)
				_phase = 1
		1:
			if not _b._spawning:
				for e in _b.enemies:
					if e.id == "wraith":
						_u = e
						e.max_hp *= 60.0    # 지켜보는 동안 쓰러지지 않게 (영웅 넷이 궁극기를 계속 쓴다)
						e.hp = e.max_hp
				for a in _b.allies:
					a.max_hp *= 4.0
					a.hp = a.max_hp
					a.ult = 60.0            # 궁극기가 일찍 차서 회피를 볼 수 있게
				_expect(_u != null, "스테이지 %d 마지막 웨이브에 공허 망령 등장 (적 %d)" % [_stage, _b.enemies.size()])
				if _u == null:
					_finish()
					return
				_expect(_u.size == 2 and _u.floating, "4칸 중보스 · 떠다니는 유닛")
				_b.auto_ult = true
				_b.start_battle()
				_last = _u.position
				_t = 0.0
				_phase = 2
		2:
			if is_instance_valid(_u) and _u.hp < _hp_prev - _u.max_hp * 0.04:
				print("[wraith-stage] trace %.1fs: hp %.0f -> %.0f / %.0f (stun %.1f casting %s cell %s in_room %s)" % [_t, _hp_prev, _u.hp, _u.max_hp, _u.stun_timer, _u.casting, _u.cell, VDMap.in_room(_b.room, _u.cell)])
			if is_instance_valid(_u):
				_hp_prev = _u.hp
			if not is_instance_valid(_u) or not _u.alive:
				print("[wraith-stage] note: 망령이 %.1f초에 쓰러짐" % _t)
				_judge()
				return
			if _b.state != VDBattle.State.BATTLE:
				if _t > 3.0:
					print("[wraith-stage] note: 전투가 %.1f초에 끝남 (state %d)" % [_t, _b.state])
					_judge()
				return
			if not _u.has_meta("blinking"):
				var step := _u.position.distance_to(_last)
				if step < 80.0:
					_path += step
				_cells[_u.cell] = true
				# 트윈은 노드 처리 뒤에 돌아서, 트윈이 위치를 옮긴 프레임에는 칸이 한 프레임 늦는다 → 3프레임 넘게 어긋날 때만 문제로 본다
				if VDFloatMove.cell_at(_u, _u.position) != _u.cell:
					_off_frames += 1
					_off_worst = maxi(_off_worst, _off_frames)
					if _off_frames > 3:
						_cell_ok = false
				else:
					_off_frames = 0
				for o in _b.allies + _b.enemies:
					if o != _u and o.alive and _u.dist_to(o) == 0:
						_overlap = true
			_last = _u.position
			# 촉수 난타가 나오는 동안 실속도 프레임
			var casting := _u.get_node_or_null("Tentacles") != null
			if casting and not _was_casting:
				_casts_seen += 1
				_shot_t = 0.0
			_was_casting = casting
			if casting and _casts_seen <= 2:
				_shot_t -= real
				if _shot_t <= 0.0 and _shots < 28:
					_shot_t = 0.08
					_shot("cast%d_%02d" % [_casts_seen, _shots])
					_shots += 1
			elif _idle_shots < 5 and _t > 2.0 + _idle_shots * 1.2:
				_shot("move_%02d" % _idle_shots)
				_idle_shots += 1
			if _t > _secs:
				_judge()


func _shot(name: String) -> void:
	if _out == "" or DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))


func _judge() -> void:
	var es := _b.enemy_skills
	var fm := _b.float_move
	print("[wraith-stage] %.1fs: 촉수 난타 %d회 (%d타) · 순간이동 %d회 · 순간이동 뒤 촉수 연계 %d회 · 궁극기 회피 %d회 · 이동 %.0fpx (빠르게 %d, 천천히 %d) · 밟은 칸 %d개 · 다른 유닛과 겹침 %s" % [
		_t, int(es.cast_count.get("wraith", 0)), es.tentacle_hits, int(es.cast_count.get("wraith_blink", 0)), es.followups, es.dodges,
		_path, fm.fast_moves, fm.slow_moves, _cells.size(), _overlap])
	_expect(int(es.cast_count.get("wraith", 0)) >= 1 and es.tentacle_hits > 0, "스스로 촉수 난타를 썼다")
	_expect(int(es.cast_count.get("wraith_blink", 0)) + es.dodges >= 1, "순간이동을 했다")
	_expect(_path > 300.0 and _cells.size() >= 3, "타일에 묶이지 않고 떠다녔다")
	_expect(fm.fast_moves >= 1 and fm.slow_moves >= 1, "빠른 이동과 느린 위빙이 모두 나왔다")
	_expect(_cell_ok, "밟은 칸이 떠 있는 위치와 맞는다 (가장 길게 어긋난 구간 %d프레임)" % _off_worst)
	_finish()


func _expect(ok: bool, what: String) -> void:
	print("[wraith-stage] %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fail += 1


func _finish() -> void:
	print("[wraith-stage] %s fails=%d" % ["PASS" if _fail == 0 else "FAIL", _fail])
	set_process(false)
	get_tree().quit(0 if _fail == 0 else 1)
