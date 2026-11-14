## 전투 엠비언트 검사 (헤드리스): 두 층이 반복 재생되고, 페이드인 뒤 목표 음량에 닿고, 일시정지 중에도 돌고, 끄고 켜지는지.
##   Godot --headless --path . res://tools/test/AmbienceProbe.tscn
extends Node

var failures: Array[String] = []


func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
	print("[amb] %s %s" % ["PASS" if ok else "FAIL", description])


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var b: VDBattle = load("res://scenes/void_defense/VoidDefense.tscn").instantiate()
	add_child(b)
	await get_tree().process_frame
	var amb := b.ambience
	_check(amb != null and amb.players.size() == 2, "two ambience layers")
	for p in amb.players:
		var s := p.stream as AudioStreamWAV
		_check(s != null and s.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops forward" % p.stream.resource_path.get_file())
		_check(p.playing, "%s playing" % p.stream.resource_path.get_file())
	_check(amb.players[0].volume_db < -40.0, "starts faded out (%.1f dB)" % amb.players[0].volume_db)
	await get_tree().create_timer(3.5).timeout
	for i in 2:
		var base: float = VDAmbience.LAYERS[i][1]
		var amp: float = VDAmbience.LAYERS[i][2]
		var v := amb.players[i].volume_db
		_check(absf(v - base) <= amp + 0.05, "layer %d at target %.1f dB (base %.1f)" % [i, v, base])
	get_tree().paused = true
	var before := amb.players[0].get_playback_position()
	await get_tree().create_timer(0.5, true).timeout
	_check(amb.players[0].playing and amb.players[0].get_playback_position() != before, "keeps playing while tree paused")
	get_tree().paused = false
	amb.toggle()
	_check(not amb.players[0].playing and not amb.players[1].playing, "toggle off stops")
	amb.toggle()
	_check(amb.players[0].playing and amb.players[1].playing, "toggle on resumes")
	print("[amb] %s (%d failures)" % ["ALL PASS" if failures.is_empty() else "FAILED", failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
