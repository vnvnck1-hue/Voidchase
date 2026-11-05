extends Node
## 갈림길 선택 렉 측정: 전투를 빨리 돌리고(배속) 갈림길에서 1배속으로 길을 고른 뒤, 프레임 간격이 긴 프레임을 상태와 함께 찍는다.
## 실제 렌더러가 필요하다 (창 모드, 서브 모니터):
##   godot --path . --screen 1 --position 4380,80 --resolution 1280x720 res://tools/test/ProbeForkLag.tscn -- --test

const LONG_MS := 24.0

var b: VDBattle
var _prev := 0
var _label := "boot"
var _forks := 0
var _done := false


func _ready() -> void:
	b = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	b.state_changed.connect(_on_state)
	get_tree().process_frame.connect(_on_frame)
	_go()


func _go() -> void:
	for i in 30:
		await get_tree().process_frame
	Engine.time_scale = 4.0
	b.start_battle()


func _on_frame() -> void:
	var now := Time.get_ticks_usec()
	if _prev > 0:
		var ms := (now - _prev) / 1000.0
		if ms > LONG_MS:
			print("  LONG frame %.1f ms  [%s]  state=%s" % [ms, _label, VDBattle.State.keys()[b.state]])
	_prev = now


func _on_state(s: int) -> void:
	_label = VDBattle.State.keys()[s]
	print("[probe] state -> %s (t=%d ms)" % [_label, Time.get_ticks_msec()])
	if s == VDBattle.State.CHOOSE_PATH:
		Engine.time_scale = 1.0
		_pick()
	elif s == VDBattle.State.PLACEMENT and _forks > 0:
		if _forks >= 3:
			_finish()
		else:
			Engine.time_scale = 4.0
			b.call_deferred("start_battle")


func _pick() -> void:
	for i in 60:
		await get_tree().process_frame
	if b.state != VDBattle.State.CHOOSE_PATH:
		return
	_forks += 1
	_label = "choose_path #%d" % _forks
	var t0 := Time.get_ticks_usec()
	b.choose_path(0)
	print("[probe] choose_path(0) of %d exits took %.1f ms" % [b.exits.size(), (Time.get_ticks_usec() - t0) / 1000.0])


func _finish() -> void:
	if _done:
		return
	_done = true
	for i in 120:
		await get_tree().process_frame
	print("[probe] done")
	get_tree().quit()
