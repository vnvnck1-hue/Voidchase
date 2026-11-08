## 강적 등장 연출 헤드리스 점검: 지정 구역들로 다시 소환하며
##  - 중급·보스 중 가장 센 적이 맨 마지막에 나오는지 (등급 → 체력 기준)
##  - 바로 앞 적과 champ_delay + champ_lead 이상 시간차가 나는지
##  - 괴성(boss_roar)이 강적마다 한 번 울리고, 착지 흔들림이 일반 적보다 센지
##  - 일반 적뿐인 구역에서는 괴성이 없는지
##   godot --headless --path . res://tools/test/VDChampionProbe.tscn -- --waves=1,3,5,6,10
## 창으로 띄우고 --out=<폴더> 를 주면 괴성 중·착지 직후 스크린샷을 남긴다 (서브 모니터 인자 필수).
extends Node

var _b: VDBattle
var _t := 0.0
var _waves: Array[int] = [1, 3, 5, 6, 10]
var _wi := -1
var _fail := 0
var _out := ""
var _seen := 0                 # 지금까지 enemies 에 들어온 수
var _times: Array[float] = []  # 적이 들어온 시각
var _roars0 := 0
var _champ: VDUnit
var _champ_t := -1.0
var _peak_normal := 0.0
var _peak_champ := 0.0
var _shot_warn := false
var _shot_land := false
var _wait := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--waves="):
			_waves.clear()
			for s in a.substr(8).split(","):
				_waves.append(int(s))
		elif a.begins_with("--out="):
			_out = a.substr(6)
	_b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(_b)
	_b.champion_spawned.connect(func(u: VDUnit) -> void:
		_champ = u
		_champ_t = _t)


func _process(delta: float) -> void:
	_t += delta
	var trauma: float = _b.camera._trauma
	if _wi < 0:
		if _t > 1.0 and not _b._spawning:
			_next_wave()
		return
	if _champ == null:
		_peak_normal = maxf(_peak_normal, trauma)
		if not _shot_warn and _times.size() > 0 and _t - _times[-1] > VDSummonFx.g("champ_delay") + 0.3 and int(_b.audio.play_count.get("boss_roar", 0)) > _roars0:
			_shot_warn = true
			_shot("w%d_1_roar" % _waves[_wi])
	else:
		_peak_champ = maxf(_peak_champ, trauma)
		if not _shot_land and _t - _champ_t > 0.2:
			_shot_land = true
			_shot("w%d_2_landed" % _waves[_wi])
	while _seen < _b.enemies.size():
		_times.append(_t)
		_seen += 1
	if not _b._spawning:
		_wait += delta
		if _wait > 0.6:
			_judge()
			_next_wave()


func _next_wave() -> void:
	_wi += 1
	if _wi >= _waves.size():
		print("[champ] %s  fails=%d" % ["PASS" if _fail == 0 else "FAIL", _fail])
		get_tree().quit(0 if _fail == 0 else 1)
		set_process(false)
		return
	for e in _b.enemies:
		e.queue_free()
	_b.enemies.clear()
	_seen = 0
	_times.clear()
	_champ = null
	_champ_t = -1.0
	_peak_normal = 0.0
	_peak_champ = 0.0
	_shot_warn = false
	_shot_land = false
	_wait = 0.0
	_roars0 = int(_b.audio.play_count.get("boss_roar", 0))
	_b.wave = _waves[_wi]
	_b._spawn_wave(_b._run_id)


func _judge() -> void:
	var w := _waves[_wi]
	var ids: Array = _b.enemies.map(func(e: VDUnit) -> String: return e.id)
	var roars := int(_b.audio.play_count.get("boss_roar", 0)) - _roars0
	var types: Array[String] = []
	for id in ids:
		types.append(id)
	var want := VDBattle._champion_index(types)
	print("[champ] wave %d order=%s roars=%d" % [w, str(ids), roars])
	if want < 0:
		_expect(_champ == null and roars == 0, "wave %d: 일반 적뿐 → 강적·괴성 없음" % w)
		return
	var strongest: String = types[want]
	_expect(_champ != null and _champ == _b.enemies[-1], "wave %d: 강적이 맨 마지막 (%s)" % [w, ids[-1]])
	_expect(ids[-1] == strongest, "wave %d: 마지막이 가장 센 적 %s" % [w, strongest])
	_expect(roars == 1, "wave %d: 괴성 1회 (%d)" % [w, roars])
	if _times.size() >= 2:
		var gap := _times[-1] - _times[-2]
		var need := VDSummonFx.g("champ_delay") + VDSummonFx.g("champ_lead")
		_expect(gap >= need - 0.05, "wave %d: 앞 적과 시간차 %.2fs ≥ %.2fs" % [w, gap, need])
	_expect(_peak_champ > _peak_normal + 0.2, "wave %d: 강적 흔들림 %.2f > 일반 %.2f" % [w, _peak_champ, _peak_normal])


func _expect(ok: bool, what: String) -> void:
	print("[champ] %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fail += 1


func _shot(name: String) -> void:
	if _out == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().get_texture().get_image().save_png(_out.path_join("champion_%s.png" % name))
