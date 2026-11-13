## 적 특수 스킬 점검: 지정 구역으로 다시 소환 → 전투를 돌리며
##  - 공허 망루 공허 섬광포: 시전되고 1.5초 동안 레이저 10타가 들어가는지
##  - 공허 군주 공허 강하: 시전 순간 체력이 가장 낮은 아군 바로 옆(1칸)에 내려앉는지
##   godot --headless --path . res://tools/test/VDEnemySkillProbe.tscn -- --stage=10  (보스 스테이지 → 공허 군주. 5·15… 는 공허 감시자: tools/test/ParryCapture.tscn)
##   godot --headless --path . res://tools/test/VDEnemySkillProbe.tscn -- --stage=3   (대형 적 스테이지 → 공허 망루)
## 적 구성은 스테이지·스테이지 안 웨이브로 정해진다 (2026-11-08 스테이지/웨이브 이식): 그 스테이지의 마지막 웨이브를 바로 소환한다.
## 창으로 띄우고 --out=<폴더> 를 주면 시전 강조·레이저·강하 착지 순간 스크린샷을 남긴다 (서브 모니터 인자 필수).
extends Node

var _b: VDBattle
var _t := 0.0
var _phase := 0
var _stage := 10
var _out := ""
var _fail := 0
var _cast_t := -1.0
var _hits0 := 0
var _shots := {}
var _weak_id := ""
var _trace := false
var _land_t := -1.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			_stage = int(a.substr(8))
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--trace":
			_trace = true
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)


func _id() -> String:
	return "boss" if VDData.is_boss_stage(_stage) else "longneck"


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.001)
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
				# 아군 체력을 서로 다르게: 한 명을 가장 약하게
				var weak: VDUnit = _b.allies[_b.allies.size() - 1]
				for a in _b.allies:
					a.hp = a.max_hp * (0.35 if a == weak else 0.9)
					a.mana_gain = 0.0   # 아군 궁극기(빙결·기절)가 스킬을 끊지 않게
				for e in _b.enemies:
					e.max_hp *= 4.0     # 스킬을 보기 전에 쓰러지지 않게
					e.hp = e.max_hp
				_weak_id = weak.id
				_b.start_battle()
				_t = 0.0
				_phase = 2
		2:
			var n := int(_b.enemy_skills.cast_count.get(_id(), 0))
			if n >= 1 and _cast_t < 0.0:
				_cast_t = _t
				_hits0 = _b.enemy_skills.laser_hits
				print("[eskill] %s cast at %.2fs" % [_id(), _t])
			if _cast_t >= 0.0:
				var dt := _t - _cast_t
				if _trace and int(dt * 4.0) != int((dt - delta / maxf(Engine.time_scale, 0.001)) * 4.0):
					var c := _b.enemies.filter(func(e: VDUnit) -> bool: return e.id == _id())
					print("[eskill] trace dt=%.2f scale=%.3f casting=%s winding=%s stun=%s beams=%s" % [dt, Engine.time_scale,
						str(c.map(func(e: VDUnit) -> bool: return e.casting)), str(c.map(func(e: VDUnit) -> bool: return e.winding)),
						str(c.map(func(e: VDUnit) -> float: return e.stun_timer)), str(_b.enemy_skills.beam_log)])
				_shot_at(dt, 0.35, "1_announce")
				# 처치 슬로모션·히트스탑이 겹치면 실제 시간으로는 늘어나므로, 진행 상태로 판단한다
				var es := _b.enemy_skills
				var done := false
				if _id() == "longneck":
					if es.laser_hits - _hits0 >= 5:
						_shot_at(dt, 0.0, "2_beam")
					done = not es.beam_log.is_empty()
				elif not es.last_descent.is_empty():
					if _land_t < 0.0:
						_land_t = _t
					_shot_at(_t - _land_t, 0.5, "2_landed")
					done = _t - _land_t > 1.2
				if (done and dt > 1.0) or dt > 10.0:
					_judge()
					_phase = 3
			elif _t > 30.0:
				print("[eskill] FAIL %s never cast" % _id())
				_fail += 1
				_finish()


func _shot_at(dt: float, at: float, name: String) -> void:
	if dt < at or _shots.has(name):
		return
	_shots[name] = true
	if _out == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().get_texture().get_image().save_png(_out.path_join("eskill_s%d_%s.png" % [_stage, name]))


func _judge() -> void:
	var es := _b.enemy_skills
	if _id() == "longneck":
		print("[eskill] beam_log %s" % str(es.beam_log))
		_expect(not es.beam_log.is_empty() and es.beam_log[0] == 10, "레이저 10연타 %s" % str(es.beam_log))
	else:
		var d: Dictionary = es.last_descent
		print("[eskill] descent %s" % str(d))
		_expect(not d.is_empty(), "공허 강하 시전")
		_expect(d.get("weakest", false), "대상 = 체력이 가장 낮은 아군 (%s, 약하게 만든 아군 %s)" % [d.get("target", "?"), _weak_id])
		_expect(d.get("adjacent", false), "대상 바로 옆에 착지 %s" % str(d.get("land")))
	_finish()


func _expect(ok: bool, what: String) -> void:
	print("[eskill] %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fail += 1


func _finish() -> void:
	print("[eskill] %s fails=%d" % ["PASS" if _fail == 0 else "FAIL", _fail])
	set_process(false)
	get_tree().quit(0 if _fail == 0 else 1)
